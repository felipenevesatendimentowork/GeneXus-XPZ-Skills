#requires -Version 7.4
<#
.SYNOPSIS
    Monitor incremental de um job assincrono do Codex (disparado por Start-CodexJob.ps1).
.DESCRIPTION
    Backend codex da skill xpz-llm-delegate. Segue o processo informado (-ProcessId) e le o
    <GUID>.stream.jsonl incrementalmente, traduzindo os eventos do `codex exec --json` em
    linhas legiveis: comandos executados pelo agente, mensagens e uso de tokens. Encerra
    quando o processo termina, gravando <GUID>.result.json com a resposta final (lida do
    output-last-message <GUID>.lastmsg.txt) e o uso de tokens.

    Eventos do codex exec --json (um objeto por linha): thread.started, turn.started,
    item.started / item.completed (item.type em command_execution | agent_message | ...),
    turn.completed (com 'usage'). A resposta final NAO e extraida do stream: vem do arquivo
    de output-last-message, mais robusto.

    Espelha o padrao de Watch-OpenCodeJob.ps1.
.PARAMETER JobId
    GUID do job (nome-base dos arquivos em -TempDir).
.PARAMETER ProcessId
    PID do processo codex cuja vida delimita o monitoramento.
.PARAMETER TempDir
    Pasta dos arquivos de job. Default: <temp do usuario>\codex-jobs.
.PARAMETER IntervalSeconds
    Intervalo de polling. Default 2. Faixa 1-30.
.PARAMETER SilenceThresholdSeconds
    Segundos sem nova linha antes de alertar. Default 120. Faixa 30-3600.
.EXAMPLE
    .\Watch-CodexJob.ps1 -JobId a1b2c3 -ProcessId 12345
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $JobId,
    [Parameter(Mandatory = $true)] [int]    $ProcessId,
    [string] $TempDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'codex-jobs'),
    [ValidateRange(1, 30)]   [int] $IntervalSeconds = 2,
    [ValidateRange(30, 3600)][int] $SilenceThresholdSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$base        = Join-Path $TempDir $JobId
$streamPath  = "$base.stream.jsonl"
$reqPath     = "$base.request.json"
$errPath     = "$base.stderr.txt"
$lastMsgPath = "$base.lastmsg.txt"
$resultPath  = "$base.result.json"

# Acumuladores de resultado
$script:lastError    = $null
$script:inputTokens  = 0
$script:outputTokens = 0

# Funcoes de descoberta/erro do Codex (Get-CodexExecErrorMessage)
. (Join-Path $PSScriptRoot 'CodexCliSupport.ps1')

# Helpers
function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Write-Line {
    param([string]$Message, [string]$Color = 'Gray')
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor $Color
}

function Read-NewLines {
    param([ref]$Offset)
    $lines = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $streamPath -PathType Leaf)) { return $lines }
    try {
        $fs = [System.IO.FileStream]::new(
            $streamPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        [void]$fs.Seek($Offset.Value, [System.IO.SeekOrigin]::Begin)
        $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
        $l = $reader.ReadLine()
        while ($null -ne $l) { $lines.Add($l); $l = $reader.ReadLine() }
        $Offset.Value = $fs.Position
        $reader.Dispose(); $fs.Dispose()
    } catch {
        Write-Line "AVISO: falha ao ler stream: $($_.Exception.Message)" 'DarkYellow'
    }
    return $lines
}

function Show-Event {
    param($Json)
    $type = [string](Get-Prop $Json 'type')
    switch ($type) {
        'item.started' {
            $item = Get-Prop $Json 'item'
            if ([string](Get-Prop $item 'type') -eq 'command_execution') {
                $c = [string](Get-Prop $item 'command')
                if ($c.Length -gt 70) { $c = $c.Substring(0, 70) + '...' }
                Write-Line ("CMD   inicia: {0}" -f $c) 'Yellow'
            }
        }
        'item.completed' {
            $item = Get-Prop $Json 'item'
            $itype = [string](Get-Prop $item 'type')
            if ($itype -eq 'command_execution') {
                $code = Get-Prop $item 'exit_code'
                Write-Line ("CMD   fim (exit {0})" -f $code) 'DarkYellow'
            } elseif ($itype -eq 'agent_message') {
                $t = [string](Get-Prop $item 'text')
                $preview = $t
                if ($preview.Length -gt 100) { $preview = $preview.Substring(0, 100) + '...' }
                Write-Line ("TEXTO: {0}" -f $preview) 'Green'
            }
        }
        'turn.completed' {
            $usage = Get-Prop $Json 'usage'
            $inp = Get-Prop $usage 'input_tokens'
            $outp = Get-Prop $usage 'output_tokens'
            if ($null -ne $inp)  { $script:inputTokens  = [int]$inp }
            if ($null -ne $outp) { $script:outputTokens = [int]$outp }
            Write-Line ("turno concluido | tokens in {0} / out {1}" -f $script:inputTokens, $script:outputTokens) 'DarkCyan'
        }
        'error' {
            $emsg = Get-Prop $Json 'message'
            if ([string]::IsNullOrWhiteSpace($emsg)) { $emsg = ($Json | ConvertTo-Json -Compress) }
            $script:lastError = [string]$emsg
            Write-Line ("ERRO no agente: {0}" -f $emsg) 'Red'
        }
        default { }
    }
}

# Header
Write-Host "=== Watch-CodexJob ==========================================" -ForegroundColor White
if (Test-Path -LiteralPath $reqPath -PathType Leaf) {
    try {
        $req = Get-Content -LiteralPath $reqPath -Raw | ConvertFrom-Json
        Write-Line ("Job   : {0}" -f (Get-Prop $req 'jobId'))  'White'
        Write-Line ("Modelo: {0}" -f (Get-Prop $req 'model'))  'White'
        $pr = [string](Get-Prop $req 'prompt')
        if ($pr.Length -gt 80) { $pr = $pr.Substring(0, 80) + '...' }
        Write-Line ("Prompt: {0}" -f $pr) 'White'
    } catch { }
}
Write-Line ("PID   : {0}" -f $ProcessId) 'White'
Write-Host "-------------------------------------------------------------" -ForegroundColor White

# Aguardar stream aparecer (ate 30s)
$waited = 0
while (-not (Test-Path -LiteralPath $streamPath -PathType Leaf) -and $waited -lt 30) {
    Write-Line "Aguardando stream do codex..." 'DarkGray'
    Start-Sleep -Seconds 2; $waited += 2
}

# Loop principal
$offset         = [long]0
$lastActivity   = [DateTime]::Now
$silenceAlerted = $false

try {
    :loop while ($true) {
        $alive = $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
        $new   = @(Read-NewLines ([ref]$offset))

        if ($new.Count -gt 0) {
            $lastActivity   = [DateTime]::Now
            $silenceAlerted = $false
            foreach ($line in $new) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try { $j = $line | ConvertFrom-Json } catch { continue }
                Show-Event $j
            }
        } else {
            $silenceSec = [int]([DateTime]::Now - $lastActivity).TotalSeconds
            if ($silenceSec -ge $SilenceThresholdSeconds -and -not $silenceAlerted) {
                $silenceAlerted = $true
                $procLabel = if ($alive) { "PID $ProcessId ativo" } else { "PID $ProcessId encerrado" }
                Write-Line ("SILENCIO ha ${SilenceThresholdSeconds}s - $procLabel") 'DarkYellow'
            }
        }

        if (-not $alive) {
            Start-Sleep -Seconds 2
            $tail = @(Read-NewLines ([ref]$offset))
            foreach ($line in $tail) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try { $j = $line | ConvertFrom-Json } catch { continue }
                Show-Event $j
            }
            break loop
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
} finally {
    # Resposta final = output-last-message do codex (nao o parse do stream)
    $final = ''
    if (Test-Path -LiteralPath $lastMsgPath -PathType Leaf) {
        $final = (Get-Content -LiteralPath $lastMsgPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue)
    }
    if ($null -ne $final) { $final = $final.TrimEnd("`r", "`n") }

    $errText = ''
    if (Test-Path -LiteralPath $errPath -PathType Leaf) {
        $errText = (Get-Content -LiteralPath $errPath -Raw -ErrorAction SilentlyContinue)
    }
    # Classificacao: a resposta final manda. So investiga erro (do stream ou do stderr) quando
    # NAO ha resposta — evita o falso 'error' quando o stderr async traz "ERROR: {...}" de
    # comandos internos do agente. Ver Resolve-CodexJobStatus em CodexCliSupport.ps1.
    $statusInfo = Resolve-CodexJobStatus -FinalText $final -StreamError $script:lastError -Stderr $errText
    $status = $statusInfo.status
    $script:lastError = $statusInfo.error

    $result = [ordered]@{
        jobId        = $JobId
        status       = $status
        finalText    = $final
        error        = $script:lastError
        inputTokens  = $script:inputTokens
        outputTokens = $script:outputTokens
        stderr       = $errText
        finishedAt   = (Get-Date).ToString('o')
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding utf8

    Write-Host "-------------------------------------------------------------" -ForegroundColor White
    Write-Host "RESPOSTA FINAL:" -ForegroundColor Green
    Write-Host $final
    Write-Host ("tokens in {0} / out {1}" -f $script:inputTokens, $script:outputTokens) -ForegroundColor DarkCyan
    Write-Host ("result.json: {0}" -f $resultPath) -ForegroundColor DarkGray
}
