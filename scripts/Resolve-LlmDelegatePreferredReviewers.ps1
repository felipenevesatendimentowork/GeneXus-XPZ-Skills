#requires -Version 7.4
<#
.SYNOPSIS
    Le a lista curada de revisores preferidos e a cruza com o manifesto de capacidade,
    devolvendo a composicao SUGERIDA do painel de revisao por pares.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.

    INVARIANTE (preferencia != autorizacao): este resolvedor NAO emite veredito de
    autorizacao e NAO consome capabilities.json como verdade do gate. A autorizacao
    continua sendo do Resolve-LlmDelegateAuthorization.ps1, chamado POR REVISOR no momento
    do envio (reavalia destino+sensibilidade). Aqui so se sugere "o que voce prefere que
    esta disponivel".

    Cruza:
      - preferencia (preferred-reviewers.json) — o que o usuario curou
      - disponivel (capabilities.json) — best-effort: o manifesto pode NAO enumerar opencode
        (config minima), entao availableInManifest=false ali nao prova indisponibilidade.

    A regra de PAPEL do README (forte vs voz adicional; veto duro) e aplicada pelo agente
    /pela metodologia do 15 ao montar o painel — nao por este script (papel "forte/fraco"
    nao e dado de maquina). O veto duro ja foi descartado na gravacao (Set-...).

    Sem o arquivo de preferencia -> hasPreferences=false (a oferta cai no comportamento
    atual: catalogo + politica do README).

    Saida: objeto JSON de maquina no stdout.
.PARAMETER PreferredPath
    Caminho do preferred-reviewers.json. Default: %LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json.
.PARAMETER CapabilitiesPath
    Caminho do capabilities.json. Default: %LOCALAPPDATA%\xpz-llm-delegate\capabilities.json.
.EXAMPLE
    .\Resolve-LlmDelegatePreferredReviewers.ps1
#>
[CmdletBinding()]
param(
    [string] $PreferredPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate' | Join-Path -ChildPath 'preferred-reviewers.json'),
    [string] $CapabilitiesPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate' | Join-Path -ChildPath 'capabilities.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) { return $Obj.PSObject.Properties[$Name].Value }
    return $null
}

$note = 'Sugestao de composicao; NAO e autorizacao. O gate Resolve-LlmDelegateAuthorization.ps1 reavalia destino+sensibilidade POR REVISOR no envio. availableInManifest e best-effort: o manifesto pode nao enumerar opencode (config minima).'

if (-not (Test-Path -LiteralPath $PreferredPath -PathType Leaf)) {
    [pscustomobject]@{
        hasPreferences = $false
        reason         = 'no-preferred-file'
        reviewers      = @()
        note           = $note
    } | ConvertTo-Json -Depth 8
    return
}

$pref = $null
try { $pref = Get-Content -LiteralPath $PreferredPath -Raw | ConvertFrom-Json } catch {
    [pscustomobject]@{
        hasPreferences = $false
        reason         = "preferred-file-unreadable: $($_.Exception.Message)"
        reviewers      = @()
        note           = $note
    } | ConvertTo-Json -Depth 8
    return
}

$reviewers = @(Get-Prop $pref 'reviewers')

# Conjunto de chaves de destino enumeradas no manifesto (best-effort).
$available = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if (Test-Path -LiteralPath $CapabilitiesPath -PathType Leaf) {
    try {
        $cap = Get-Content -LiteralPath $CapabilitiesPath -Raw | ConvertFrom-Json
        foreach ($b in @(Get-Prop $cap 'backends')) {
            foreach ($m in @(Get-Prop $b 'models')) {
                $cm = [string](Get-Prop $m 'canonicalModel')
                if (-not [string]::IsNullOrWhiteSpace($cm)) { [void]$available.Add($cm) }
            }
        }
    } catch { }
}

$out = [System.Collections.Generic.List[object]]::new()
foreach ($r in $reviewers) {
    $target = [string](Get-Prop $r 'targetModelKey')
    $out.Add([pscustomobject]@{
            backend             = [string](Get-Prop $r 'backend')
            targetModelKey      = $target
            invokeArgs          = (Get-Prop $r 'invokeArgs')
            availableInManifest = $available.Contains($target)
        })
}

[pscustomobject]@{
    hasPreferences = $true
    updatedAt      = [string](Get-Prop $pref 'updatedAt')
    reviewers      = @($out)
    note           = $note
} | ConvertTo-Json -Depth 8
