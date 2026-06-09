#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de OpenCodeStreamSupport.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Exercita as funcoes de parsing do stream do opencode com fixtures JSONL sinteticas
    (sem opencode nem rede). Cobre: mensagem unica, multi-mensagem (preambulos + final),
    mensagem final fragmentada em varias partes, evento de erro, ausencia de texto e
    linhas invalidas. Determinístico.
    Sentinela de sucesso: OK: Test-OpenCodeStreamSupportSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'OpenCodeStreamSupport.ps1')

$fail = 0
function Assert-Eq {
    param([string]$Name, $Got, $Expected)
    if ([string]$Got -eq [string]$Expected) {
        Write-Host ("PASS  {0}" -f $Name) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0}: got=[{1}] esperado=[{2}]" -f $Name, $Got, $Expected) -ForegroundColor Red
    }
}

# 1) Mensagem unica
$linesSingle = @(
    '{"type":"step_start","part":{}}',
    '{"type":"text","part":{"messageID":"m1","text":"Resposta unica."}}',
    '{"type":"step_finish","part":{}}'
)
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesSingle
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'single: count partes'  (@($parts).Count) 1
Assert-Eq 'single: finalText'     (Get-OpenCodeFinalText -TextParts $parts) 'Resposta unica.'
Assert-Eq 'single: erro nulo'     ($null -eq (Get-OpenCodeStreamErrorMessage -Events $ev)) $true

# 2) Multi-mensagem: preambulos + resposta final na ultima mensagem
$linesMulti = @(
    '{"type":"text","part":{"messageID":"m1","text":"preambulo 1"}}',
    '{"type":"tool_use","part":{"tool":"bash"}}',
    '{"type":"text","part":{"messageID":"m2","text":"preambulo 2"}}',
    '{"type":"text","part":{"messageID":"m3","text":"RESPOSTA FINAL"}}'
)
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesMulti
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'multi: count partes'   (@($parts).Count) 3
Assert-Eq 'multi: finalText (so ultima msg)' (Get-OpenCodeFinalText -TextParts $parts) 'RESPOSTA FINAL'
Assert-Eq 'multi: allText junta tudo' (Get-OpenCodeAllText -TextParts $parts) "preambulo 1`n`npreambulo 2`n`nRESPOSTA FINAL"

# 3) Mensagem final fragmentada em duas partes (mesmo messageID)
$linesFrag = @(
    '{"type":"text","part":{"messageID":"m1","text":"pre"}}',
    '{"type":"text","part":{"messageID":"m2","text":"parte A "}}',
    '{"type":"text","part":{"messageID":"m2","text":"parte B"}}'
)
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesFrag
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'frag: finalText concatena ultima msg' (Get-OpenCodeFinalText -TextParts $parts) 'parte A parte B'

# 4) Evento de erro
$linesErr = @(
    '{"type":"text","part":{"messageID":"m1","text":"oi"}}',
    '{"type":"error","error":{"data":{"message":"model does not support tools"}}}'
)
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesErr
Assert-Eq 'erro: mensagem extraida' (Get-OpenCodeStreamErrorMessage -Events $ev) 'model does not support tools'

# 5) Sem evento de texto
$linesNoText = @('{"type":"step_start","part":{}}', '{"type":"step_finish","part":{}}')
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesNoText
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'sem-texto: count 0'    (@($parts).Count) 0
Assert-Eq 'sem-texto: finalText vazio' (Get-OpenCodeFinalText -TextParts $parts) ''

# 6) Linhas vazias/invalidas sao ignoradas
$linesJunk = @('', '   ', 'isto nao e json', '{"type":"text","part":{"messageID":"m1","text":"ok"}}')
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesJunk
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'junk: ignora invalidas, 1 parte' (@($parts).Count) 1
Assert-Eq 'junk: finalText'       (Get-OpenCodeFinalText -TextParts $parts) 'ok'

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-OpenCodeStreamSupportSelfTest.ps1" }
Write-Host 'OK: Test-OpenCodeStreamSupportSelfTest.ps1' -ForegroundColor Cyan
