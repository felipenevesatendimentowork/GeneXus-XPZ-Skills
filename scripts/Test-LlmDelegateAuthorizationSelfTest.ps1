#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de contrato de Resolve-LlmDelegateAuthorization.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Valida a tabela de decisão allow/ask/deny combinando sensibilidade do payload,
    localidade do modelo e politica por-KB, com config e politica sinteticas (sem opencode
    instalado nem rede). Determinístico.
    Sentinela de sucesso: OK: Test-LlmDelegateAuthorizationSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'Resolve-LlmDelegateAuthorization.ps1'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "BLOCK: alvo nao encontrado: $target" }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ocauth-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$cfg = Join-Path $tmp 'opencode.json'
@'
{
  "provider": {
    "ollama":   { "options": { "baseURL": "http://127.0.0.1:11434/v1" } },
    "remote-x": { "options": { "baseURL": "https://api.example.com/v1" } }
  }
}
'@ | Set-Content -LiteralPath $cfg -Encoding utf8
$pol = Join-Path $tmp 'opencode-delegation-policy.json'
@'
{
  "schemaVersion": 1,
  "defaultExternal": "ask",
  "models": {
    "openai/gpt-5.4": "allow-external",
    "remote-x/*": "deny-external"
  }
}
'@ | Set-Content -LiteralPath $pol -Encoding utf8

$fail = 0
function Assert-Verdict {
    param([string]$Model, [string]$Sensitivity, [string]$Expected, [switch]$WithPolicy, [string]$Note)
    $callArgs = @{ Model = $Model; PayloadSensitivity = $Sensitivity; ConfigPath = $cfg }
    if ($WithPolicy) { $callArgs['PolicyPath'] = $pol }
    $out = & $target @callArgs | ConvertFrom-Json
    $got = [string]$out.verdict
    $label = "{0} [{1}]{2}" -f $Model, $Sensitivity, ($(if ($WithPolicy) { ' +pol' } else { '' }))
    if ($got -eq $Expected) {
        Write-Host ("PASS  {0,-40} -> {1}  ({2})" -f $label, $got, $Note) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0,-40} -> {1} (esperado {2})  ({3})" -f $label, $got, $Expected, $Note) -ForegroundColor Red
    }
}

try {
    Assert-Verdict -Model 'remote-x/foo'   -Sensitivity 'public'       -Expected 'allow' -WithPolicy -Note 'payload publico'
    Assert-Verdict -Model 'ollama/foo'     -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'local: dado nao sai'
    Assert-Verdict -Model 'openai/gpt-5.4' -Sensitivity 'kb-sensitive' -Expected 'allow' -WithPolicy -Note 'politica allow-external exato'
    Assert-Verdict -Model 'remote-x/zzz'   -Sensitivity 'kb-sensitive' -Expected 'deny'  -WithPolicy -Note 'curinga remote-x/* deny'
    Assert-Verdict -Model 'opencode-go/x'  -Sensitivity 'kb-sensitive' -Expected 'ask'   -WithPolicy -Note 'nao listado -> defaultExternal ask'
    Assert-Verdict -Model 'remote-x/foo'   -Sensitivity 'kb-sensitive' -Expected 'ask'   -Note 'externo sem arquivo de politica -> ask'
} finally {
    Get-ChildItem -LiteralPath $tmp -File -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $tmp -Force -Recurse -ErrorAction SilentlyContinue
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-LlmDelegateAuthorizationSelfTest.ps1" }
Write-Host 'OK: Test-LlmDelegateAuthorizationSelfTest.ps1' -ForegroundColor Cyan
