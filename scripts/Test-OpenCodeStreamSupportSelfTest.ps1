#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de OpenCodeStreamSupport.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Exercita as funções de parsing do stream do opencode com fixtures JSONL sinteticas
    (sem opencode nem rede). Cobre: mensagem única, multi-mensagem (preambulos + final),
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

# 1) Mensagem única
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

# 2) Multi-mensagem: preambulos + resposta final na última mensagem
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

# 6) Linhas vazias/invalidas são ignoradas
$linesJunk = @('', '   ', 'isto nao e json', '{"type":"text","part":{"messageID":"m1","text":"ok"}}')
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesJunk
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'junk: ignora invalidas, 1 parte' (@($parts).Count) 1
Assert-Eq 'junk: finalText'       (Get-OpenCodeFinalText -TextParts $parts) 'ok'

# ── Achado D: sinal de conclusao (step_finish/reason) + veredito de precedencia ────────────

function Get-Verdict {
    # Helper: deriva signal das fixtures e aplica o veredito sobre o finalText real.
    param([string[]]$Lines)
    $ev = ConvertFrom-OpenCodeStreamLines -Lines $Lines
    $sig = Get-OpenCodeCompletionSignal -Events $ev
    $final = Get-OpenCodeFinalText -TextParts (Get-OpenCodeTextParts -Events $ev)
    return (Get-OpenCodeCompletionVerdict -HasStepFinish $sig.hasStepFinish -Reason $sig.reason -FinalText $final)
}

# 7) reason=stop + texto -> ok
$linesStop = @(
    '{"type":"text","part":{"messageID":"m1","text":"resposta final"}}',
    '{"type":"step_finish","part":{"reason":"stop"}}'
)
$sig = Get-OpenCodeCompletionSignal -Events (ConvertFrom-OpenCodeStreamLines -Lines $linesStop)
Assert-Eq 'stop: hasStepFinish' $sig.hasStepFinish $true
Assert-Eq 'stop: reason'        $sig.reason 'stop'
Assert-Eq 'stop: verdict ok'    (Get-Verdict $linesStop).status 'ok'

# 8) reason=length -> truncated (caso classico de truncamento)
$linesLen = @(
    '{"type":"text","part":{"messageID":"m1","text":"preambulo truncado"}}',
    '{"type":"step_finish","part":{"reason":"length"}}'
)
$vLen = Get-Verdict $linesLen
Assert-Eq 'length: verdict truncated' $vLen.status 'truncated'
Assert-Eq 'length: mensagem cita reason' ($vLen.message -match 'reason=length') $true

# 9) sem step_finish algum -> no-completion (sinal ausente)
$linesNoFin = @('{"type":"text","part":{"messageID":"m1","text":"so preambulo, stream cortou"}}')
$sig = Get-OpenCodeCompletionSignal -Events (ConvertFrom-OpenCodeStreamLines -Lines $linesNoFin)
Assert-Eq 'noFin: hasStepFinish'  $sig.hasStepFinish $false
Assert-Eq 'noFin: verdict no-completion' (Get-Verdict $linesNoFin).status 'no-completion'

# 10) step_finish presente mas SEM campo reason -> no-completion (reason nulo = ausente, sem excecao)
$linesNoReason = @(
    '{"type":"text","part":{"messageID":"m1","text":"texto"}}',
    '{"type":"step_finish","part":{}}'
)
$sig = Get-OpenCodeCompletionSignal -Events (ConvertFrom-OpenCodeStreamLines -Lines $linesNoReason)
Assert-Eq 'noReason: hasStepFinish' $sig.hasStepFinish $true
Assert-Eq 'noReason: reason vazio'  $sig.reason ''
Assert-Eq 'noReason: verdict no-completion' (Get-Verdict $linesNoReason).status 'no-completion'

# 11) reason=stop mas texto final vazio -> empty
$linesEmpty = @('{"type":"step_finish","part":{"reason":"stop"}}')
Assert-Eq 'empty: verdict empty' (Get-Verdict $linesEmpty).status 'empty'

# 12) Regressao do Achado D: preambulo presente (finalText NAO vazio) + reason=tool-calls
#     -> truncated; o adapter NAO deve devolver o preambulo como resposta.
$linesPreamble = @(
    '{"type":"text","part":{"messageID":"m1","text":"deixa eu ler os arquivos primeiro..."}}',
    '{"type":"step_finish","part":{"reason":"tool-calls"}}'
)
$evPre = ConvertFrom-OpenCodeStreamLines -Lines $linesPreamble
$finalPre = Get-OpenCodeFinalText -TextParts (Get-OpenCodeTextParts -Events $evPre)
Assert-Eq 'preamble: finalText nao-vazio' ([string]::IsNullOrWhiteSpace($finalPre)) $false
Assert-Eq 'preamble: verdict truncated (nao devolve preambulo)' (Get-Verdict $linesPreamble).status 'truncated'

# 13) "Ultimo step_finish governa": multiplos step_finish, o ULTIMO sem reason -> no-completion.
#     Contrato que o Watch-OpenCodeJob deve espelhar (sempre sobrescrever lastFinishReason,
#     nunca herdar o reason de um step_finish anterior). Achado da revisao do diff (Codex).
$linesMultiFin = @(
    '{"type":"text","part":{"messageID":"m1","text":"parcial"}}',
    '{"type":"step_finish","part":{"reason":"stop"}}',
    '{"type":"text","part":{"messageID":"m2","text":"mais texto"}}',
    '{"type":"step_finish","part":{}}'
)
$sig = Get-OpenCodeCompletionSignal -Events (ConvertFrom-OpenCodeStreamLines -Lines $linesMultiFin)
Assert-Eq 'multiFin: ultimo step_finish governa (reason vazio)' $sig.reason ''
Assert-Eq 'multiFin: verdict no-completion (nao herda stop anterior)' (Get-Verdict $linesMultiFin).status 'no-completion'

# 14) Parametrico: qualquer reason != stop -> truncated (vocabulario aberto do opencode).
foreach ($r in @('length', 'tool-calls', 'content_filter', 'unknown', 'max_tokens')) {
    $linesR = @(
        '{"type":"text","part":{"messageID":"m1","text":"preambulo"}}',
        ('{"type":"step_finish","part":{"reason":"' + $r + '"}}')
    )
    Assert-Eq ("param: reason=$r -> truncated") (Get-Verdict $linesR).status 'truncated'
}

# 15) Prioridade do erro explicito (G1, claude-opus): mesmo com reason=stop + texto (verdict ok),
#     Get-OpenCodeStreamErrorMessage detecta o erro -> os chamadores (Invoke-OpenCode/Watch) o
#     lancam ANTES de consultar o veredito. O teste fixa a deteccao e a nao-interferencia.
$linesErrFirst = @(
    '{"type":"text","part":{"messageID":"m1","text":"ok"}}',
    '{"type":"step_finish","part":{"reason":"stop"}}',
    '{"type":"error","error":{"data":{"message":"boom no agente"}}}'
)
$evErrFirst = ConvertFrom-OpenCodeStreamLines -Lines $linesErrFirst
Assert-Eq 'errFirst: erro detectado' (Get-OpenCodeStreamErrorMessage -Events $evErrFirst) 'boom no agente'
Assert-Eq 'errFirst: verdict isolado seria ok (erro tratado a parte no chamador)' (Get-Verdict $linesErrFirst).status 'ok'

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-OpenCodeStreamSupportSelfTest.ps1" }
Write-Host 'OK: Test-OpenCodeStreamSupportSelfTest.ps1' -ForegroundColor Cyan
