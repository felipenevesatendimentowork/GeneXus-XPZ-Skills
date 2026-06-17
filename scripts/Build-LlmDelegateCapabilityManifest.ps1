#requires -Version 7.4
<#
.SYNOPSIS
    Sonda os backends de LLM da skill xpz-llm-delegate instalados na maquina e grava um
    manifesto de CAPACIDADE sanitizado (quais backends/modelos estao disponiveis e se
    sao locais ou externos), para alimentar a OFERTA de painel de revisao por pares sem
    re-sondar a cada uso.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia de revisao por pares em
    15-revisao-por-pares.md. O manifesto e fato da MAQUINA (machine-level), gravado fora
    do git (default %LOCALAPPDATA%\xpz-llm-delegate\capabilities.json).

    DICA, NUNCA VERDADE DO GATE: este manifesto serve a oferta/UI. O gate de
    confidencialidade (Resolve-LlmDelegateAuthorization.ps1) NAO consome este arquivo;
    ele reavalia destino e sensibilidade deterministicamente a cada uso. Nao acoplar.

    SANITIZACAO POR DESENHO: o manifesto grava SOMENTE metadados nao sensiveis -
    canonicalModel, backend, locality, reasonCode (codigo curto, sem host/baseURL) e
    sourceKind. NUNCA grava token, chave de API, baseURL/host, header, caminho de config,
    prompt nem politica por-KB. O self-test prova essa ausencia.

    ENUMERACAO: so opencode (provider/modelo em opencode.json) e Codex (config.toml) tem
    fonte de enumeracao de modelos. Claude Code, Copilot e Gemini nao tem enumeracao
    nativa - registrados como instalados com models=[] e enumeration=none-native; o modelo
    default deles vive na doc da skill/no 14, nao aqui.

    ESTAVEL vs VOLATIL: o que o manifesto grava (instalado? local/externo?) e estavel e
    cacheavel. A SAUDE do backend ("responde agora?") e volatil e fica em lastHealthCheck
    (null por padrao) - reverificada de leve no momento da revisao, nao nesta sondagem.

    Reuso: chama Resolve-OpenCodeModelLocality.ps1 / Resolve-CodexModelLocality.ps1 em
    processo para a localidade de cada modelo (a chave de destino canonica). A enumeracao
    em si (listar os modelos) e logica nova, pois os resolvers classificam UM modelo dado.
.PARAMETER OutputPath
    Caminho do manifesto machine-level. Default: %LOCALAPPDATA%\xpz-llm-delegate\capabilities.json.
.PARAMETER SnapshotPath
    Quando informado, grava tambem um snapshot por-KB (cache re-derivavel) com snapshotAt e
    sourceGeneratedAt. O setup da pasta paralela usa Temp\llm-delegate-capabilities.snapshot.json.
.PARAMETER OpenCodeConfigPath
    Caminho do opencode.json. Default: ~/.config/opencode/opencode.json.
.PARAMETER CodexConfigPath
    Caminho do config.toml do Codex. Default: ~/.codex/config.toml.
.EXAMPLE
    .\Build-LlmDelegateCapabilityManifest.ps1
.EXAMPLE
    .\Build-LlmDelegateCapabilityManifest.ps1 -SnapshotPath 'C:\KB\Parallel\Temp\llm-delegate-capabilities.snapshot.json'
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate' | Join-Path -ChildPath 'capabilities.json'),
    [string] $SnapshotPath,
    [string] $OpenCodeConfigPath = (Join-Path $HOME '.config' | Join-Path -ChildPath 'opencode' | Join-Path -ChildPath 'opencode.json'),
    [string] $CodexConfigPath = (Join-Path $HOME '.codex' | Join-Path -ChildPath 'config.toml')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot
$openResolver = Join-Path $scriptsDir 'Resolve-OpenCodeModelLocality.ps1'
$codexResolver = Join-Path $scriptsDir 'Resolve-CodexModelLocality.ps1'

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Test-CommandPresent {
    param([string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

# Mapeia a saida do resolver para um reasonCode CURTO e sanitizado (sem host/baseURL).
function ConvertTo-ReasonCode {
    param([string]$Locality)
    switch ($Locality) {
        'local' { 'loopback-local' }
        'external' { 'external' }
        default { 'unknown' }
    }
}

function Get-OpenCodeModelEntries {
    param([string]$ConfigPath)
    $entries = @()
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $entries }
    $cfg = $null
    try { $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json } catch { return $entries }
    $providers = Get-Prop $cfg 'provider'
    if ($null -eq $providers) { return $entries }
    foreach ($prop in $providers.PSObject.Properties) {
        $provName = $prop.Name
        $modelsNode = Get-Prop $prop.Value 'models'
        if ($null -eq $modelsNode) { continue }
        foreach ($modelProp in $modelsNode.PSObject.Properties) {
            $canonical = "$provName/$($modelProp.Name)"
            $locality = 'unknown'
            try {
                $resJson = & $openResolver -Model $canonical -ConfigPath $ConfigPath
                if ($resJson) {
                    $res = $resJson | ConvertFrom-Json
                    $locality = [string](Get-Prop $res 'locality')
                }
            } catch { $locality = 'unknown' }
            $sourceKind = if (@('ollama-cloud', 'opencode-go') -contains $provName) { 'known-cloud' } else { 'config' }
            $entries += [pscustomobject]@{
                canonicalModel = $canonical
                locality       = $locality
                reasonCode     = ConvertTo-ReasonCode $locality
                sourceKind     = $sourceKind
            }
        }
    }
    return $entries
}

function Get-CodexProfileIds {
    param([string]$ConfigPath)
    $ids = @()
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $ids }
    foreach ($rawLine in (Get-Content -LiteralPath $ConfigPath -Encoding utf8)) {
        $m = [regex]::Match($rawLine.Trim(), '^\[profiles\.([^\]]+)\]')
        if ($m.Success) { $ids += $m.Groups[1].Value.Trim() }
    }
    return $ids
}

function Get-CodexModelEntries {
    param([string]$ConfigPath)
    $entries = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Cada invocacao do resolver: $null = default (deriva o model de topo da config);
    # caso contrario, um profile declarado. Chamada DIRETA (sem splat de array, que nao
    # vincula parametro nomeado de forma confiavel) e sem funcao aninhada (que quebraria
    # o `+=` por escopo); a List muta por referencia via .Add().
    $profilesToProbe = @($null) + @(Get-CodexProfileIds -ConfigPath $ConfigPath)

    foreach ($profileId in $profilesToProbe) {
        try {
            if ([string]::IsNullOrWhiteSpace([string]$profileId)) {
                $resJson = & $codexResolver -ConfigPath $ConfigPath
            }
            else {
                $resJson = & $codexResolver -Profile $profileId -ConfigPath $ConfigPath
            }
            if (-not $resJson) { continue }
            $res = $resJson | ConvertFrom-Json
            $canonical = [string](Get-Prop $res 'canonicalModel')
            if ([string]::IsNullOrWhiteSpace($canonical)) { continue }
            if (-not $seen.Add($canonical)) { continue }
            $locality = [string](Get-Prop $res 'locality')
            $entries.Add([pscustomobject]@{
                canonicalModel = $canonical
                locality       = $locality
                reasonCode     = ConvertTo-ReasonCode $locality
                sourceKind     = 'config'
            })
        } catch { }
    }
    return $entries
}

# --- Monta os backends -----------------------------------------------------

$backends = @()

$backends += [pscustomobject]@{
    backend     = 'opencode'
    installed   = (Test-CommandPresent 'opencode')
    enumeration = 'config'
    models      = @(Get-OpenCodeModelEntries -ConfigPath $OpenCodeConfigPath)
}

$backends += [pscustomobject]@{
    backend     = 'codex'
    installed   = (Test-CommandPresent 'codex')
    enumeration = 'config'
    models      = @(Get-CodexModelEntries -ConfigPath $CodexConfigPath)
}

foreach ($b in @(
        @{ name = 'claude-code'; cmd = 'claude' }
        @{ name = 'copilot'; cmd = 'copilot' }
        @{ name = 'gemini'; cmd = 'gemini' }
    )) {
    $backends += [pscustomobject]@{
        backend     = $b.name
        installed   = (Test-CommandPresent $b.cmd)
        enumeration = 'none-native'
        models      = @()
    }
}

$generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$manifest = [pscustomobject]@{
    schemaVersion   = 1
    generatedAt     = $generatedAt
    backends        = $backends
    lastHealthCheck = $null
}

# --- Grava o manifesto machine-level ---------------------------------------

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$manifestJson = $manifest | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $OutputPath -Value $manifestJson -Encoding utf8

# --- Snapshot por-KB opcional (cache re-derivavel) -------------------------

if (-not [string]::IsNullOrWhiteSpace($SnapshotPath)) {
    $snapDir = Split-Path -Parent $SnapshotPath
    if ($snapDir -and -not (Test-Path -LiteralPath $snapDir)) {
        New-Item -ItemType Directory -Path $snapDir -Force | Out-Null
    }
    $snapshot = [pscustomobject]@{
        schemaVersion     = 1
        snapshotAt        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        sourceGeneratedAt = $generatedAt
        backends          = $backends
        lastHealthCheck   = $null
    }
    Set-Content -LiteralPath $SnapshotPath -Value ($snapshot | ConvertTo-Json -Depth 8) -Encoding utf8
}

# Saida de maquina: o manifesto.
$manifestJson
