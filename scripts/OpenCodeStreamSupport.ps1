#requires -Version 7.4
<#
.SYNOPSIS
    Funções compartilhadas de parsing do stream JSON do opencode (skill xpz-llm-delegate).
.DESCRIPTION
    Modulo dot-source consumido por Invoke-OpenCode.ps1 e Watch-OpenCodeJob.ps1 para evitar
    duplicar a lógica de extracao. Sem efeitos colaterais; não invoca opencode.

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
