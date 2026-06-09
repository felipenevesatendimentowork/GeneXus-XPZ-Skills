#requires -Version 7.4
<#
.SYNOPSIS
    Chama o opencode (one-shot, sincrono) e devolve a resposta em texto.
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Resolve o opencode.exe real (atras do
    shim npm), alimenta um stdin vazio (sem isso o 'run' trava esperando EOF) e captura
    a saida. Bloqueia ate a resposta (ou ate -TimeoutSec).

    Esta e a invocacao sincrona canonica. Para tarefas longas que voce quer disparar sem
    bloquear, use Start-OpenCodeJob.ps1.

    CONFIDENCIALIDADE: este script NAO decide para onde o dado pode ir. Antes de enviar
    payload sensivel (conteudo de pasta paralela de KB) a um modelo, o chamador deve passar
    pelo gate Resolve-LlmDelegateAuthorization.ps1, conforme a skill xpz-llm-delegate.
.PARAMETER Message
    Prompt a enviar ao agente (posicional, obrigatorio).
.PARAMETER Model
    Modelo no formato provider/modelo (ex: openai/gpt-5.4). Opcional: omitido usa o default
    da config do opencode (~/.config/opencode/opencode.json).
.PARAMETER Agent
    Nome do agente do opencode a usar. Opcional.
.PARAMETER Raw
    Devolve o stream JSON cru (um evento por linha) em vez do texto final.
.PARAMETER AllText
    Devolve toda a narracao (preambulos de passo + resposta final) concatenada, em vez de so a resposta final.
.PARAMETER TimeoutSec
    Tempo maximo de espera pela resposta (default 180s).
.EXAMPLE
    .\Invoke-OpenCode.ps1 "oi"
.EXAMPLE
    .\Invoke-OpenCode.ps1 "resuma este log" -Model openai/gpt-5.4
.EXAMPLE
    .\Invoke-OpenCode.ps1 "oi" -Raw      # stream JSON cru (tool-calls, custo, tokens)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $Message,
    [string] $Model,
    [string] $Agent,
    [switch] $Raw,
    [switch] $AllText,
    [int]    $TimeoutSec = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Garante saida UTF-8 (acentos) ao devolver o texto pelo stdout
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

# Acesso seguro a propriedade sob Set-StrictMode (objetos de ConvertFrom-Json)
function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

# 1) Resolve o .exe real por tras do shim .ps1/.cmd do npm
$exe = Get-ChildItem -Path "$env:APPDATA\npm\node_modules\opencode-ai" `
    -Recurse -Filter 'opencode.exe' -ErrorAction SilentlyContinue |
    Where-Object FullName -like '*windows-x64\bin\opencode.exe' |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $exe) { throw "BLOCK: opencode.exe nao encontrado sob $env:APPDATA\npm" }

# 2) Argumentos (JSON sempre; formatamos a saida depois)
$arguments = @('run', $Message, '--format', 'json')
if ($Model) { $arguments += @('--model', $Model) }
if ($Agent) { $arguments += @('--agent', $Agent) }

# 3) stdin vazio = EOF imediato (destrava o run)
$out = New-TemporaryFile; $err = New-TemporaryFile; $in = New-TemporaryFile
try {
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err -RedirectStandardInput $in
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        $p.Kill(); throw "BLOCK: opencode excedeu ${TimeoutSec}s e foi encerrado."
    }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: opencode saiu com codigo $($p.ExitCode).`nstderr:`n$(Get-Content $err -Raw)"
    }

    $lines = Get-Content -LiteralPath $out -Encoding utf8
    if ($Raw) { return $lines }

    $events = @($lines | ForEach-Object { try { $_ | ConvertFrom-Json } catch { } } | Where-Object { $null -ne $_ })

    # Erro explicito do agente no stream tem prioridade sobre a ausencia de texto
    $errors = @($events | Where-Object { (Get-Prop $_ 'type') -eq 'error' })
    if ($errors.Count -gt 0) {
        $msg = Get-Prop (Get-Prop (Get-Prop $errors[-1] 'error') 'data') 'message'
        if ([string]::IsNullOrWhiteSpace($msg)) { $msg = ($errors[-1] | ConvertTo-Json -Compress) }
        throw "BLOCK: opencode retornou erro no stream: $msg"
    }

    $textEvents = @($events | Where-Object { (Get-Prop $_ 'type') -eq 'text' -and -not [string]::IsNullOrEmpty([string](Get-Prop (Get-Prop $_ 'part') 'text')) })
    if ($textEvents.Count -eq 0) { throw "BLOCK: nenhum evento de texto na resposta. Use -Raw para inspecionar." }

    # -AllText: toda a narracao (preambulos de passo + resposta final), em ordem
    if ($AllText) {
        return (($textEvents | ForEach-Object { [string](Get-Prop (Get-Prop $_ 'part') 'text') }) -join "`n`n")
    }

    # Resposta final = todas as partes de texto da ULTIMA mensagem (messageID), concatenadas em ordem;
    # robusto a mensagem final fragmentada em varias partes. Run truncado ainda devolve o ultimo texto.
    $lastMsgId = [string](Get-Prop (Get-Prop $textEvents[-1] 'part') 'messageID')
    if (-not [string]::IsNullOrEmpty($lastMsgId)) {
        $finalParts = @($textEvents | Where-Object { [string](Get-Prop (Get-Prop $_ 'part') 'messageID') -eq $lastMsgId } | ForEach-Object { [string](Get-Prop (Get-Prop $_ 'part') 'text') })
        return ($finalParts -join '')
    }
    return [string](Get-Prop (Get-Prop $textEvents[-1] 'part') 'text')
}
finally {
    Remove-Item $out, $err, $in -Force -ErrorAction SilentlyContinue
}
