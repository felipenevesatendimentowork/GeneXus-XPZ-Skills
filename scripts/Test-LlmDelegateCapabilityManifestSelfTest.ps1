#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test do Build-LlmDelegateCapabilityManifest.ps1 (skill xpz-llm-delegate).
#
# Cobre:
#  (A) Enumeracao + localidade: a partir de um opencode.json fixture com um provider
#      loopback (local) e um provider externo, o manifesto lista os dois modelos com a
#      localidade correta.
#  (B) Sanitizacao por desenho: o manifesto NAO contem segredo-isca (apiKey, host externo,
#      baseURL, caminho de config) plantados no fixture.
#  (C) Schema: schemaVersion/generatedAt/backends presentes; os 5 backends; os tres
#      none-native com models=[]; lastHealthCheck null.
#  (D) Snapshot por-KB: snapshotAt presente e sourceGeneratedAt == generatedAt do manifesto.

$scriptsDir = $PSScriptRoot
$scriptUnderTest = Join-Path $scriptsDir 'Build-LlmDelegateCapabilityManifest.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $scriptUnderTest -PathType Leaf) "Script sob teste ausente: $scriptUnderTest"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-llm-cap-selftest-' + [System.Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

# Segredos-isca: devem NUNCA aparecer no manifesto.
$secretApiKey = 'sk-TOPSECRET-TOKEN-isca-123'
$externalHost = 'secret-host.internal.example'

try {
    $openCfg = Join-Path $tempRoot 'opencode.json'
    @"
{
  "provider": {
    "ollama": {
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": { "qwen2.5-coder:7b": {} }
    },
    "myexternal": {
      "options": { "baseURL": "https://$externalHost/v1", "apiKey": "$secretApiKey" },
      "models": { "big-model": {} }
    }
  }
}
"@ | Set-Content -LiteralPath $openCfg -Encoding utf8

    # config.toml real do Codex: model de topo (openai builtin -> external) + um profile
    # OSS local (loopback -> local). Exercita a enumeracao Codex (regressao do bug de escopo).
    $codexCfg = Join-Path $tempRoot 'config.toml'
    @"
model = "gpt-5.5"

[profiles.local-oss]
model = "qwen2.5-coder:7b"
model_provider = "ollama"

[model_providers.ollama]
base_url = "http://localhost:11434/v1"
"@ | Set-Content -LiteralPath $codexCfg -Encoding utf8
    $outPath = Join-Path $tempRoot 'capabilities.json'
    $snapPath = Join-Path $tempRoot 'snap.json'

    & $scriptUnderTest -OutputPath $outPath -SnapshotPath $snapPath `
        -OpenCodeConfigPath $openCfg -CodexConfigPath $codexCfg 1> $null

    Assert-True (Test-Path -LiteralPath $outPath -PathType Leaf) 'Manifesto nao foi gravado.'
    $manifestText = [System.IO.File]::ReadAllText($outPath)
    $manifest = $manifestText | ConvertFrom-Json

    # (C) Schema
    Assert-True ($manifest.schemaVersion -eq 1) 'schemaVersion deveria ser 1.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$manifest.generatedAt)) 'generatedAt ausente.'
    Assert-True ($null -eq $manifest.lastHealthCheck) 'lastHealthCheck deveria ser null (saude e volatil).'
    $backendNames = @($manifest.backends | ForEach-Object { $_.backend })
    foreach ($expected in @('opencode', 'codex', 'claude-code', 'copilot', 'gemini')) {
        Assert-True ($backendNames -contains $expected) "Backend ausente do manifesto: $expected"
    }
    foreach ($b in $manifest.backends) {
        Assert-True ($b.installed -is [bool]) "Campo 'installed' do backend '$($b.backend)' deveria ser booleano."
    }
    foreach ($noneNative in @('claude-code', 'copilot', 'gemini')) {
        $b = $manifest.backends | Where-Object { $_.backend -eq $noneNative }
        Assert-True ($b.enumeration -eq 'none-native') "Backend '$noneNative' deveria ter enumeration=none-native."
        Assert-True (@($b.models).Count -eq 0) "Backend '$noneNative' deveria ter models=[] (sem enumeracao nativa)."
    }

    # (A) Enumeracao + localidade do opencode
    $oc = $manifest.backends | Where-Object { $_.backend -eq 'opencode' }
    Assert-True ($oc.enumeration -eq 'config') 'opencode deveria ter enumeration=config.'
    $local = $oc.models | Where-Object { $_.canonicalModel -eq 'ollama/qwen2.5-coder:7b' }
    Assert-True ($null -ne $local) 'Modelo loopback nao enumerado.'
    Assert-True ($local.locality -eq 'local') "Modelo loopback deveria ser local; veio '$($local.locality)'."
    Assert-True ($local.reasonCode -eq 'loopback-local') "reasonCode do loopback deveria ser loopback-local; veio '$($local.reasonCode)'."
    $ext = $oc.models | Where-Object { $_.canonicalModel -eq 'myexternal/big-model' }
    Assert-True ($null -ne $ext) 'Modelo externo nao enumerado.'
    Assert-True ($ext.locality -eq 'external') "Modelo externo deveria ser external; veio '$($ext.locality)'."

    # (A2) Enumeracao + localidade do Codex (regressao do bug de escopo em Add-FromResolver:
    # `$entries += ...` numa funcao aninhada nao atualizava o array do pai -> codex sempre vazio).
    $cx = $manifest.backends | Where-Object { $_.backend -eq 'codex' }
    Assert-True ($cx.enumeration -eq 'config') 'codex deveria ter enumeration=config.'
    Assert-True (@($cx.models).Count -ge 1) 'codex deveria enumerar ao menos 1 modelo a partir do config.toml (regressao do bug de escopo).'
    $cxTop = $cx.models | Where-Object { $_.canonicalModel -eq 'openai/gpt-5.5' }
    Assert-True ($null -ne $cxTop) 'codex deveria enumerar o modelo de topo openai/gpt-5.5.'
    Assert-True ($cxTop.locality -eq 'external') "modelo de topo do codex deveria ser external; veio '$($cxTop.locality)'."

    # (B) Sanitizacao por desenho
    foreach ($forbidden in @($secretApiKey, $externalHost, 'apiKey', 'baseURL', 'Authorization', '11434', $openCfg, $codexCfg)) {
        Assert-True (-not ($manifestText -like "*$forbidden*")) "Manifesto vazou conteudo sensivel proibido: '$forbidden'."
    }

    # (D) Snapshot por-KB
    Assert-True (Test-Path -LiteralPath $snapPath -PathType Leaf) 'Snapshot por-KB nao foi gravado.'
    $snap = [System.IO.File]::ReadAllText($snapPath) | ConvertFrom-Json
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$snap.snapshotAt)) 'snapshotAt ausente no snapshot.'
    Assert-True ($snap.sourceGeneratedAt -eq $manifest.generatedAt) 'sourceGeneratedAt do snapshot deveria casar com generatedAt do manifesto.'

    Write-Output 'OK: Test-LlmDelegateCapabilityManifestSelfTest.ps1'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
