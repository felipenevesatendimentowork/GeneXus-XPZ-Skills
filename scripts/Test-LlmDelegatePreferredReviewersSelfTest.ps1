#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test de Set-/Resolve-LlmDelegatePreferredReviewers.ps1 (skill xpz-llm-delegate).
#
# Cobre:
#  (A) Gravacao + schema de 2 eixos: targetModelKey + invokeArgs.model (derivado quando ausente).
#  (B) Sanitizacao por desenho: segredo-isca no invokeArgs (baseURL/token) NAO vaza.
#  (C) Veto duro: Nemotron 3 Ultra escolhido pelo usuario e DESCARTADO.
#  (D) Resolve cruza com capabilities.json (availableInManifest), com a invariante de que
#      preferencia != autorizacao (campo note presente; nada de veredito de gate).
#  (E) Sem arquivo de preferencia -> hasPreferences=false (fallback).

$scriptsDir = $PSScriptRoot
$setScript = Join-Path $scriptsDir 'Set-LlmDelegatePreferredReviewers.ps1'
$resolveScript = Join-Path $scriptsDir 'Resolve-LlmDelegatePreferredReviewers.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $setScript -PathType Leaf) "Script ausente: $setScript"
Assert-True (Test-Path -LiteralPath $resolveScript -PathType Leaf) "Script ausente: $resolveScript"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-llm-pref-selftest-' + [System.Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

$secretToken = 'sk-SECRET-isca-pref-789'
$secretHost = 'pref-secret-host.internal.example'

try {
    $prefPath = Join-Path $tempRoot 'preferred-reviewers.json'

    # Entrada: opencode (sem invokeArgs -> model derivado), codex (com segredo-isca a sanitizar),
    # e um veto duro (Nemotron 3 Ultra) que o usuario "escolheu" e deve ser descartado.
    $reviewersJson = @"
[
  { "backend": "opencode", "targetModelKey": "ollama-cloud/deepseek-v4-pro" },
  { "backend": "codex", "targetModelKey": "openai/gpt-5.5", "invokeArgs": { "model": "gpt-5.5", "baseURL": "https://$secretHost/v1", "token": "$secretToken" } },
  { "backend": "opencode", "targetModelKey": "ollama-cloud/nemotron-3-ultra" }
]
"@

    $setOut = & $setScript -ReviewersJson $reviewersJson -OutputPath $prefPath | ConvertFrom-Json

    # (A) gravacao
    Assert-True (Test-Path -LiteralPath $prefPath -PathType Leaf) 'preferred-reviewers.json nao foi gravado.'
    Assert-True ($setOut.written -eq 2) "Deveria gravar 2 revisores (veto descartado); gravou $($setOut.written)."
    Assert-True (@($setOut.discardedVeto) -contains 'ollama-cloud/nemotron-3-ultra') 'Nemotron 3 Ultra deveria ter sido descartado por veto duro.'

    $prefText = [System.IO.File]::ReadAllText($prefPath)
    $pref = $prefText | ConvertFrom-Json
    Assert-True ($pref.schemaVersion -eq 1) 'schemaVersion deveria ser 1.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$pref.updatedAt)) 'updatedAt ausente.'

    $oc = $pref.reviewers | Where-Object { $_.targetModelKey -eq 'ollama-cloud/deepseek-v4-pro' }
    Assert-True ($null -ne $oc) 'Revisor opencode ausente.'
    Assert-True ($oc.invokeArgs.model -eq 'ollama-cloud/deepseek-v4-pro') "model do opencode deveria ser derivado da chave de destino; veio '$($oc.invokeArgs.model)'."
    $cx = $pref.reviewers | Where-Object { $_.targetModelKey -eq 'openai/gpt-5.5' }
    Assert-True ($null -ne $cx) 'Revisor codex ausente.'
    Assert-True ($cx.invokeArgs.model -eq 'gpt-5.5') "model do codex deveria ser o nome nu 'gpt-5.5'; veio '$($cx.invokeArgs.model)'."

    # (B) sanitizacao: segredo-isca nao vaza
    foreach ($forbidden in @($secretToken, $secretHost, 'baseURL', 'token')) {
        Assert-True (-not ($prefText -like "*$forbidden*")) "preferred-reviewers.json vazou conteudo sensivel: '$forbidden'."
    }

    # (D) Resolve com manifesto fixture: codex disponivel; opencode (deepseek) ausente do manifesto.
    $capPath = Join-Path $tempRoot 'capabilities.json'
    @'
{
  "schemaVersion": 1,
  "generatedAt": "2026-06-17T00:00:00Z",
  "backends": [
    { "backend": "opencode", "installed": true, "enumeration": "config", "models": [] },
    { "backend": "codex", "installed": true, "enumeration": "config", "models": [ { "canonicalModel": "openai/gpt-5.5", "locality": "external", "reasonCode": "external", "sourceKind": "config" } ] }
  ],
  "lastHealthCheck": null
}
'@ | Set-Content -LiteralPath $capPath -Encoding utf8

    $res = & $resolveScript -PreferredPath $prefPath -CapabilitiesPath $capPath | ConvertFrom-Json
    Assert-True ($res.hasPreferences -eq $true) 'Resolve deveria reportar hasPreferences=true.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$res.note)) 'note (invariante preferencia != autorizacao) ausente.'
    $rcx = $res.reviewers | Where-Object { $_.targetModelKey -eq 'openai/gpt-5.5' }
    Assert-True ($rcx.availableInManifest -eq $true) 'codex (openai/gpt-5.5) deveria estar availableInManifest=true.'
    $roc = $res.reviewers | Where-Object { $_.targetModelKey -eq 'ollama-cloud/deepseek-v4-pro' }
    Assert-True ($roc.availableInManifest -eq $false) 'opencode (deepseek) deveria estar availableInManifest=false (manifesto nao enumera opencode aqui).'

    # (E) sem arquivo de preferencia -> fallback
    $res2 = & $resolveScript -PreferredPath (Join-Path $tempRoot 'nao-existe.json') -CapabilitiesPath $capPath | ConvertFrom-Json
    Assert-True ($res2.hasPreferences -eq $false) 'Sem arquivo, hasPreferences deveria ser false.'
    Assert-True ($res2.reason -eq 'no-preferred-file') "reason deveria ser 'no-preferred-file'; veio '$($res2.reason)'."

    Write-Output 'OK: Test-LlmDelegatePreferredReviewersSelfTest.ps1'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
