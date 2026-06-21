#requires -Version 7.4
<#
.SYNOPSIS
    Funções compartilhadas de parsing do stream JSON do opencode (skill xpz-llm-delegate).
.DESCRIPTION
    Módulo dot-source consumido por Invoke-OpenCode.ps1 e Watch-OpenCodeJob.ps1 para evitar
    duplicar a lógica de extracao. Não invoca opencode (o parsing é puro; a única leitura externa
    é Get-OpenCodeUsageLimitError, que apenas LÊ o log do opencode para diagnosticar HTTP 429).

    Eventos do `opencode run --format json`: um objeto JSON por linha, com `type`
    (`step_start`, `text`, `tool_use`, `step_finish`, `error`) e `part`. Cada evento `text`
    pertence a uma mensagem (`part.messageID`); a resposta final e a última mensagem.

    Contrato validado por Test-OpenCodeStreamSupportSelfTest.ps1.
#>

Set-StrictMode -Version Latest

function Get-OcProp {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function ConvertFrom-OpenCodeStreamLines {
    # Converte as linhas JSONL em eventos; ignora linhas vazias/nao-parseaveis.
    param([string[]]$Lines)
    $events = [System.Collections.Generic.List[object]]::new()
    foreach ($line in @($Lines)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $events.Add(($line | ConvertFrom-Json)) } catch { }
    }
    return $events
}

function Get-OpenCodeStreamErrorMessage {
    # Mensagem do último evento type=error, ou $null se não houver erro.
    param([object[]]$Events)
    $errs = @(@($Events) | Where-Object { (Get-OcProp $_ 'type') -eq 'error' })
    if ($errs.Count -eq 0) { return $null }
    $last = $errs[$errs.Count - 1]
    $msg = Get-OcProp (Get-OcProp (Get-OcProp $last 'error') 'data') 'message'
    if ([string]::IsNullOrWhiteSpace($msg)) { $msg = ($last | ConvertTo-Json -Compress) }
    return [string]$msg
}

function Get-OpenCodeTextParts {
    # Lista de [pscustomobject]{ mid; text } para eventos text com texto nao-vazio, em ordem.
    param([object[]]$Events)
    $parts = [System.Collections.Generic.List[object]]::new()
    foreach ($e in @($Events)) {
        if ((Get-OcProp $e 'type') -ne 'text') { continue }
        $part = Get-OcProp $e 'part'
        $text = [string](Get-OcProp $part 'text')
        if ([string]::IsNullOrEmpty($text)) { continue }
        $parts.Add([pscustomobject]@{ mid = [string](Get-OcProp $part 'messageID'); text = $text })
    }
    return $parts
}

function Get-OpenCodeFinalText {
    # Resposta final = concatenacao das partes de texto da ÚLTIMA mensagem (messageID).
    # Robusto a mensagem final fragmentada em varias partes; sem messageID, usa a última parte.
    param([object[]]$TextParts)
    $tp = @(@($TextParts) | Where-Object { $null -ne $_ })
    if ($tp.Count -eq 0) { return '' }
    $lastMid = [string]$tp[$tp.Count - 1].mid
    if ([string]::IsNullOrEmpty($lastMid)) { return [string]$tp[$tp.Count - 1].text }
    return (@($tp | Where-Object { [string]$_.mid -eq $lastMid } | ForEach-Object { [string]$_.text }) -join '')
}

function Get-OpenCodeAllText {
    # Toda a narracao (preambulos de passo + resposta final), em ordem.
    param([object[]]$TextParts)
    return (@(@($TextParts) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.text }) -join "`n`n")
}

function Get-OpenCodeCompletionSignal {
    # Sinal de conclusao do stream, a partir do ULTIMO evento step_finish e seu part.reason.
    # Achado D: leitura agentica que estoura passos encerra um step com reason != 'stop' (ou
    # sem step_finish algum), e o adapter devolvia o preambulo como se fosse a resposta final.
    # Retorna [pscustomobject]{ hasStepFinish; reason }:
    #   hasStepFinish=$false           -> nenhum step_finish no stream (conclusao ausente)
    #   hasStepFinish=$true; reason=''  -> step_finish presente mas sem campo reason (tratar como ausente)
    #   hasStepFinish=$true; reason='stop'|'length'|'tool-calls'|... -> reason explicito
    param([object[]]$Events)
    $steps = @(@($Events) | Where-Object { (Get-OcProp $_ 'type') -eq 'step_finish' })
    if ($steps.Count -eq 0) {
        return [pscustomobject]@{ hasStepFinish = $false; reason = '' }
    }
    $last = $steps[$steps.Count - 1]
    $reason = [string](Get-OcProp (Get-OcProp $last 'part') 'reason')
    return [pscustomobject]@{ hasStepFinish = $true; reason = $reason }
}

function Get-OpenCodeCompletionVerdict {
    # Precedencia FIXADA do Achado D (NAO trata erro explicito de stream; isso e tratado a parte,
    # com prioridade, por Get-OpenCodeStreamErrorMessage no chamador):
    #   (1) step_finish com reason != 'stop' (inclui 'length','tool-calls') -> truncated
    #   (2) sem step_finish OU reason vazio (sinal de conclusao ausente)     -> no-completion
    #   (3) texto final vazio, apos conclusao limpa (reason='stop')          -> empty
    #   senao                                                                -> ok
    # Cada caso e disjunto -> uma mensagem deterministica por cenario (fixtures do self-test).
    # 'reason' nulo/ausente e tratado como cadeia vazia (cai em (2)); NUNCA lanca sob StrictMode.
    #
    # Vocabulario de reason: SO 'stop' e sucesso. QUALQUER outro valor ('length', 'tool-calls',
    # 'content_filter', 'unknown', 'max_tokens', ...) cai em (1) truncated POR DESIGN — inclusive
    # 'tool-calls' com preambulo textual ja presente, que e justamente o vazamento do Achado D
    # (o turno viraria tool call e o preambulo nao e a resposta final). NAO "consertar" essa
    # precedencia. Risco a vigiar: se o opencode renomear 'stop' upstream (ex.: 'done'), toda
    # chamada legitima viraria truncated -> revisar aqui e em xpz-llm-delegate/SKILL.md (LIMITE
    # CONHECIDO opencode), onde fica registrada a versao do opencode contra a qual foi mapeado.
    param([bool]$HasStepFinish, [string]$Reason, [string]$FinalText)
    if ($HasStepFinish -and -not [string]::IsNullOrEmpty($Reason) -and $Reason -ne 'stop') {
        return [pscustomobject]@{ status = 'truncated'; reason = $Reason; message = "BLOCK: resposta truncada (reason=$Reason). Use -Raw para inspecionar." }
    }
    if (-not $HasStepFinish -or [string]::IsNullOrEmpty($Reason)) {
        return [pscustomobject]@{ status = 'no-completion'; reason = ''; message = 'BLOCK: resposta sem sinal de conclusao (step_finish/reason ausente). Use -Raw para inspecionar.' }
    }
    if ([string]::IsNullOrWhiteSpace($FinalText)) {
        return [pscustomobject]@{ status = 'empty'; reason = $Reason; message = 'BLOCK: nenhum evento de texto na resposta. Use -Raw para inspecionar.' }
    }
    return [pscustomobject]@{ status = 'ok'; reason = $Reason; message = '' }
}

function Get-OpenCodeUsageLimitError {
    # O opencode retenta o HTTP 429 (limite de uso do provider) em SILENCIO: stdout/stderr ficam
    # vazios e a chamada so estoura por -TimeoutSec, mascarando a causa como "timeout". O 429 e
    # gravado apenas no log proprio do opencode (~/.local/share/opencode/log/<ts>.log; respeita
    # XDG_DATA_HOME). Varre os logs escritos na janela do processo (mtime >= SinceTime - 5s) e
    # devolve a mensagem do limite, ou $null se nao houver 429 no periodo. SO LEITURA do log;
    # nao invoca opencode. -LogDir (override; default = dir real) habilita o self-test por fixture.
    param(
        [Parameter(Mandatory)][datetime]$SinceTime,
        [string]$LogDir
    )
    if ([string]::IsNullOrWhiteSpace($LogDir)) {
        $base = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { Join-Path $env:USERPROFILE '.local/share' }
        $LogDir = Join-Path $base 'opencode/log'
    }
    if (-not (Test-Path -LiteralPath $LogDir -PathType Container)) { return $null }
    $cutoff = $SinceTime.AddSeconds(-5)
    $logs = @(Get-ChildItem -LiteralPath $LogDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $cutoff } | Sort-Object LastWriteTime -Descending)
    foreach ($log in $logs) {
        $text = Get-Content -LiteralPath $log.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrEmpty($text)) { continue }
        if ($text -match '"statusCode":\s*429') {
            $m = [regex]::Match($text, 'reached your[^"\\]*usage limit[^"\\]*')
            if ($m.Success) { return $m.Value.Trim() }
            return 'HTTP 429 - limite de uso do provider'
        }
    }
    return $null
}
