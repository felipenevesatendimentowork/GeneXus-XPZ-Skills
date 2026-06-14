#requires -Version 7.4
<#
.SYNOPSIS
    Self-test das funcoes puras de GeminiCliSupport.ps1.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeminiCliSupport.ps1')

$fail = 0
function Assert-Equal {
    param([string]$Label, $Got, $Expected)
    if ([string]$Got -eq [string]$Expected) {
        Write-Host ("PASS  {0}" -f $Label) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0} -> '{1}' (esperado '{2}')" -f $Label, $Got, $Expected) -ForegroundColor Red
    }
}

Assert-Equal 'parse versao' (ConvertFrom-GeminiVersionText 'gemini 0.35.3') ([version]'0.35.3')
Assert-Equal 'parse invalido -> null' (ConvertFrom-GeminiVersionText 'sem versao') $null

$helpOk = @'
--prompt
--approval-mode
--output-format
--model
'@
Assert-Equal 'help com flags exigidas' (Test-GeminiHelpSupportsContract $helpOk) $true
Assert-Equal 'help incompleto' (Test-GeminiHelpSupportsContract '--prompt --model') $false

$err = Get-GeminiErrorMessage -StdoutText '' -StderrText 'Error: invalid model'
Assert-Equal 'extrai erro simples' $err 'Error: invalid model'
$semErr = Get-GeminiErrorMessage -StdoutText 'tudo certo' -StderrText ''
Assert-Equal 'sem erro -> null' $semErr $null

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-GeminiCliSupportSelfTest.ps1" }
Write-Host 'OK: Test-GeminiCliSupportSelfTest.ps1' -ForegroundColor Cyan
