#requires -Version 7.4
<#
.SYNOPSIS
    Self-test deterministico do resolvedor Copilot da xpz-llm-delegate.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'Resolve-CopilotModelLocality.ps1'
$out = & $target -Model 'gpt-5-mini' | ConvertFrom-Json
if ([string]$out.locality -ne 'external') { throw "BLOCK: locality esperado external; obtido $($out.locality)" }
if ([string]$out.canonicalModel -ne 'github-copilot/gpt-5-mini') { throw "BLOCK: canonicalModel inesperado: $($out.canonicalModel)" }

Write-Host 'OK: Test-CopilotModelLocalitySelfTest.ps1' -ForegroundColor Cyan
