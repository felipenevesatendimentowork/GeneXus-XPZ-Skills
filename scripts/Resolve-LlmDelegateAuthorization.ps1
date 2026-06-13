#requires -Version 7.4
<#
.SYNOPSIS
    Gate de confidencialidade da skill xpz-llm-delegate: decide se um payload pode ser
    enviado a um modelo (allow / ask / deny), combinando sensibilidade declarada,
    localidade do modelo e politica por-KB.
.DESCRIPTION
    Nucleo backend-agnostico da skill. A localidade e resolvida pelo resolvedor do backend
    selecionado por -Backend: opencode -> Resolve-OpenCodeModelLocality.ps1; codex ->
    Resolve-CodexModelLocality.ps1; claude-code -> Resolve-ClaudeCodeModelLocality.ps1;
    copilot -> Resolve-CopilotModelLocality.ps1; gemini -> Resolve-GeminiModelLocality.ps1
    (mesma pasta). A chave que casa na politica e o
    provider/modelo de DESTINO (canonicalModel do resolvedor), nao o backend/adapter: dois
    backends que enviam para o mesmo provider casam a mesma regra (ex: 'openai/*').

    Lógica deterministica:

        payload = public                  -> allow  (qualquer modelo; dado publico)
        payload = kb-sensitive:
            localidade local              -> allow  (dado não sai da maquina)
            localidade external/unknown   -> consulta a politica por-KB:
                allow-external (p/ modelo) -> allow  (anunciar destino mesmo assim)
                deny-external              -> deny
                ask / não definido         -> ask    (exige autorizacao explicita do usuário)

    'ask' significa: o agente deve obter autorizacao explicita do usuário antes de enviar,
    e pode oferecer persistir a escolha no arquivo de politica (liberacao duravel).

    Arquivo de politica (opcional, por pasta paralela de KB), JSON:
        {
          "schemaVersion": 1,
          "defaultExternal": "ask",
          "models": {
            "openai/gpt-5.4": "allow-external",
            "ollama-cloud/*": "deny-external"
          }
        }
    Resolucao do modelo na politica: chave exata -> curinga 'provider/*' -> curinga '*'
    -> defaultExternal -> 'ask' (quando não ha arquivo).

    Saida: objeto JSON de maquina no stdout.
.PARAMETER Model
    Modelo. No backend opencode, formato provider/modelo (ex: openai/gpt-5.4). No backend
    codex, o nome nu (ex: gpt-5.5); quando omitido, o resolvedor codex tenta derivar o
    default da config do Codex.
.PARAMETER Backend
    Backend de delegacao: 'opencode' (default), 'codex', 'claude-code', 'copilot' ou
    'gemini'. Seleciona o resolvedor de localidade.
.PARAMETER Oss
    (codex) Invocacao OSS local (--oss); implica modelo local. Repassado ao resolvedor codex.
.PARAMETER LocalProvider
    (codex) Provider OSS local quando -Oss: 'ollama' ou 'lmstudio'. Repassado ao resolvedor codex.
.PARAMETER Profile
    (codex) Profile da config do Codex (-p); resolve o provider de destino. Repassado ao resolvedor codex.
.PARAMETER PayloadSensitivity
    Classe do payload declarada pelo chamador: 'kb-sensitive' (conteúdo de pasta paralela
    de KB) ou 'public' (diff do repo publico, molde sanitizado, README).
.PARAMETER PolicyPath
    Caminho do opencode-delegation-policy.json da pasta paralela. Opcional; ausente => 'ask'.
.PARAMETER ConfigPath
    Caminho da config do backend, repassado ao resolvedor de localidade: opencode.json no
    backend opencode; config.toml do Codex quando -Backend codex. Opcional.
.EXAMPLE
    .\Resolve-LlmDelegateAuthorization.ps1 -Model ollama/qwen2.5-coder:7b_8192ctx -PayloadSensitivity kb-sensitive
.EXAMPLE
    .\Resolve-LlmDelegateAuthorization.ps1 -Model openai/gpt-5.4 -PayloadSensitivity public
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Model,
    [Parameter(Mandatory)] [ValidateSet('kb-sensitive', 'public')] [string] $PayloadSensitivity,
    [ValidateSet('opencode', 'codex', 'claude-code', 'copilot', 'gemini')] [string] $Backend = 'opencode',
    [switch] $Oss,
    [ValidateSet('ollama', 'lmstudio')] [string] $LocalProvider,
    [string] $Profile,
    [string] $PolicyPath,
    [string] $ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function New-AuthResult {
    param(
        [string]$Locality, [string]$BaseUrl, [string]$Verdict,
        [string]$PolicyDecision, [string]$PolicySource, [string]$Reason
    )
    [pscustomobject]@{
        model              = $Model
        backend            = $Backend
        targetModelKey     = $matchKey
        payloadSensitivity = $PayloadSensitivity
        locality           = $Locality
        baseUrl            = $BaseUrl
        verdict            = $Verdict
        policyDecision     = $PolicyDecision
        policySource       = $PolicySource
        reason             = $Reason
    } | ConvertTo-Json -Compress
}

# 1) Resolve a localidade do modelo (resolvedor por backend)
$resolverName = switch ($Backend) {
    'codex'       { 'Resolve-CodexModelLocality.ps1' }
    'claude-code' { 'Resolve-ClaudeCodeModelLocality.ps1' }
    'copilot'     { 'Resolve-CopilotModelLocality.ps1' }
    'gemini'      { 'Resolve-GeminiModelLocality.ps1' }
    default       { 'Resolve-OpenCodeModelLocality.ps1' }
}
$localityScript = Join-Path $PSScriptRoot $resolverName
if (-not (Test-Path -LiteralPath $localityScript -PathType Leaf)) {
    throw "BLOCK: resolvedor de localidade nao encontrado: $localityScript"
}
$localityArgs = @{ Model = $Model }
if ($Backend -in @('opencode', 'codex') -and $PSBoundParameters.ContainsKey('ConfigPath')) {
    $localityArgs['ConfigPath'] = $ConfigPath
}
if ($Backend -eq 'codex') {
    if ($Oss) { $localityArgs['Oss'] = $true }
    if ($PSBoundParameters.ContainsKey('LocalProvider')) { $localityArgs['LocalProvider'] = $LocalProvider }
    if ($PSBoundParameters.ContainsKey('Profile')) { $localityArgs['Profile'] = $Profile }
}
$localityJson = & $localityScript @localityArgs
$loc = $localityJson | ConvertFrom-Json
$locality = [string]$loc.locality
$baseUrl  = [string]$loc.baseUrl
# Chave de DESTINO para casar a politica: o canonicalModel quando o resolvedor o fornece
# (codex normaliza para o provider de destino); senao o proprio Model (opencode ja e canonico).
$matchKey = [string](Get-Prop $loc 'canonicalModel')
if ([string]::IsNullOrWhiteSpace($matchKey)) { $matchKey = $Model }

# 2) Payload publico: sempre liberado
if ($PayloadSensitivity -eq 'public') {
    New-AuthResult -Locality $locality -BaseUrl $baseUrl -Verdict 'allow' `
        -PolicyDecision 'n/a' -PolicySource 'n/a' `
        -Reason 'payload publico; envio liberado a qualquer modelo'
    return
}

# 3) Payload sensivel + modelo local: o dado não sai da maquina
if ($locality -eq 'local') {
    New-AuthResult -Locality $locality -BaseUrl $baseUrl -Verdict 'allow' `
        -PolicyDecision 'n/a' -PolicySource 'n/a' `
        -Reason 'payload sensivel, mas modelo local (loopback); o dado nao sai da maquina'
    return
}

# 4) Payload sensivel + modelo externo/unknown: consulta a politica por-KB
$policyDecision = $null
$policySource   = $null

if ($PolicyPath -and (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
    try {
        $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
    } catch {
        New-AuthResult -Locality $locality -BaseUrl $baseUrl -Verdict 'ask' `
            -PolicyDecision $null -PolicySource $PolicyPath `
            -Reason "politica ilegivel/invalida ($($_.Exception.Message)); exige autorizacao explicita"
        return
    }

    $models = Get-Prop $policy 'models'
    $providerWildcard = (@($matchKey -split '/', 2)[0]) + '/*'
    foreach ($key in @($matchKey, $providerWildcard, '*')) {
        $decision = Get-Prop $models $key
        if ($null -ne $decision) {
            $policyDecision = [string]$decision
            $policySource   = "models['$key']"
            break
        }
    }

    if ($null -eq $policyDecision) {
        $def = Get-Prop $policy 'defaultExternal'
        if ($null -ne $def) {
            $policyDecision = [string]$def
            $policySource   = 'defaultExternal'
        }
    }
} else {
    $policySource = 'sem-arquivo-de-politica'
}

# 5) Verdito a partir da decisão da politica
switch ($policyDecision) {
    'allow-external' {
        New-AuthResult -Locality $locality -BaseUrl $baseUrl -Verdict 'allow' `
            -PolicyDecision $policyDecision -PolicySource $policySource `
            -Reason 'politica autoriza este modelo externo para conteudo desta KB; anuncie o destino ao usuario'
    }
    'deny-external' {
        New-AuthResult -Locality $locality -BaseUrl $baseUrl -Verdict 'deny' `
            -PolicyDecision $policyDecision -PolicySource $policySource `
            -Reason 'politica proibe enviar conteudo desta KB a este modelo externo'
    }
    default {
        New-AuthResult -Locality $locality -BaseUrl $baseUrl -Verdict 'ask' `
            -PolicyDecision $policyDecision -PolicySource $policySource `
            -Reason 'sem autorizacao duravel; exige autorizacao explicita do usuario (e oferta de persistir no arquivo de politica)'
    }
}
