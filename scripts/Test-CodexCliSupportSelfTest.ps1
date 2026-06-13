#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de contrato das funcoes puras de CodexCliSupport.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Valida Get-CodexExecErrorMessage (extracao de erro do stdout/stderr) e Resolve-CodexExe
    no modo -Override, sem depender da app Codex instalada. A descoberta automatica de
    binario (varredura por versao) depende do ambiente real e e exercitada pelos adapters.
    Sentinela de sucesso: OK: Test-CodexCliSupportSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CodexCliSupport.ps1')

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

# Get-CodexExecErrorMessage
$e1 = Get-CodexExecErrorMessage -StdoutText 'ERROR: {"type":"error","error":{"message":"boom"}}' -StderrText ''
Assert-Equal 'erro: extrai message' $e1 'boom'

$e2 = Get-CodexExecErrorMessage -StdoutText 'tudo certo, sem erro' -StderrText ''
Assert-Equal 'sem erro -> vazio' $e2 ''

$e3 = Get-CodexExecErrorMessage -StdoutText '' -StderrText 'ERROR: {"error":{"message":"The gpt-5.5 model requires a newer version of Codex."}}'
Assert-Equal 'erro no stderr (modelo novo)' $e3 'The gpt-5.5 model requires a newer version of Codex.'

$e4 = Get-CodexExecErrorMessage -StdoutText 'ERROR: {json invalido' -StderrText ''
Assert-Equal 'erro com json invalido -> texto cru' $e4 '{json invalido'

# Resolve-CodexExe -Override
$self = (Get-Command pwsh).Source
$rOk = Resolve-CodexExe -Override $self
Assert-Equal 'override existente devolve o caminho' $rOk $self

$threw = $false
try { Resolve-CodexExe -Override 'C:\__nao_existe__\codex.exe' | Out-Null } catch { $threw = $true }
Assert-Equal 'override inexistente lanca BLOCK' $threw $true

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-CodexCliSupportSelfTest.ps1" }
Write-Host 'OK: Test-CodexCliSupportSelfTest.ps1' -ForegroundColor Cyan
