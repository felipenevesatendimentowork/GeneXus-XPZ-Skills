#requires -Version 7.4
<#
.SYNOPSIS
    Self-test das funcoes puras de ClaudeCodeCliSupport.ps1.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ClaudeCodeCliSupport.ps1')

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

Assert-Equal 'parse versao' (ConvertFrom-ClaudeCodeVersionText '2.1.118 (Claude Code)') ([version]'2.1.118')
Assert-Equal 'parse invalido -> null' (ConvertFrom-ClaudeCodeVersionText 'sem versao') $null

$helpOk = @'
--model
--print
--output-format
--no-session-persistence
--permission-mode
--tools
'@
Assert-Equal 'help com flags exigidas' (Test-ClaudeCodeHelpSupportsContract $helpOk) $true
Assert-Equal 'help incompleto' (Test-ClaudeCodeHelpSupportsContract '--model') $false

$err = Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText 'Error: model not available'
Assert-Equal 'extrai erro simples' $err 'Error: model not available'

$s1 = Resolve-ClaudeCodeJobStatus -FinalText 'ok' -StreamError '' -Stderr 'Error: ruidoso'
Assert-Equal 'status resposta final manda' $s1.status 'completed'
$s2 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError 'stream boom' -Stderr ''
Assert-Equal 'status erro stream' $s2.status 'error'
$s3 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr 'Error: auth required'
Assert-Equal 'status erro stderr' $s3.status 'error'
$s4 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr ''
Assert-Equal 'status sem texto' $s4.status 'sem-texto'

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-ClaudeCodeCliSupportSelfTest.ps1" }
Write-Host 'OK: Test-ClaudeCodeCliSupportSelfTest.ps1' -ForegroundColor Cyan
