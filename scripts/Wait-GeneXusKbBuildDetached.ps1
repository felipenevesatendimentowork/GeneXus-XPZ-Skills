#requires -Version 7.4

<#
.SYNOPSIS
Aguarda a conclusão de um build desacoplado (Start-GeneXusKbBuildDetached.ps1) combinando
DOIS sinais — a sentinela e o heartbeat da Tarefa Agendada — para nunca ficar preso quando
o processo da tarefa morre de forma dura sem escrever a sentinela.

.DESCRIPTION
O modo desacoplado escreve a sentinela no sucesso E na falha (bloco finally). Mas se o
processo da tarefa for morto de forma dura — kill abrupto, OOM, ou estouro do
-ExecutionTimeLimit, que o Task Scheduler encerra sem deixar o finally rodar — a sentinela
nunca aparece. Quem aguarda só a existência da sentinela ficaria preso para sempre.

Este helper combina os dois sinais:
  (a) sentinela em -SentinelPath com `done=true`  -> conclusão normal (outcome `concluido`);
  (b) heartbeat: estado da Tarefa Agendada -TaskName via Get-ScheduledTask — quando a tarefa
      deixa de estar `Running` (parou ou foi removida) E a sentinela continua ausente, após
      uma curta MARGEM DE CORRIDA (-RaceGraceSeconds), é falha anômala (outcome `falha-anomala`).

A margem de corrida cobre o instante normal entre a tarefa deixar de estar `Running` e o
finally do payload escrever a sentinela: sem ela, um build que terminou bem seria reportado
como crash. Só depois de a margem expirar sem sentinela o desfecho é `falha-anomala`.

Não altera nada do build nem da tarefa — é somente leitura (Test-Path, Get-Content,
Get-ScheduledTask). Destinado a rodar em segundo plano enquanto o agente conversa.

.PARAMETER SentinelPath
Caminho do arquivo-sentinela (campo `sentinelPath` do JSON de lançamento de
Start-GeneXusKbBuildDetached.ps1).

.PARAMETER TaskName
Nome da Tarefa Agendada (campo `taskName` do JSON de lançamento). Usado como heartbeat.

.PARAMETER TimeoutSeconds
Segundos máximos de espera enquanto a tarefa segue `Running`. Default 0 = sem timeout.
Quando excedido com a tarefa ainda em execução e sem sentinela, retorna outcome `timeout`.

.PARAMETER PollIntervalSeconds
Intervalo de polling em segundos. Default 5.

.PARAMETER RaceGraceSeconds
Margem de corrida em segundos: ao detectar a tarefa parada sem sentinela, re-checa a
sentinela por este tempo antes de declarar `falha-anomala`. Default 10.

.OUTPUTS
JSON no stdout com `outcome` (`concluido`|`falha-anomala`|`timeout`), `exitCode` (do build,
da sentinela, quando `concluido`), `logPath`, `logExists`, `taskState`, `taskExists`,
`error` (conteúdo do detached-payload-error.log, quando houver), `stderrPath`,
`waitedSeconds` e `summary`. Exit code do processo: 0 `concluido`, 70 `falha-anomala`,
71 `timeout`.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SentinelPath,

    [Parameter(Mandatory = $true)]
    [string]$TaskName,

    [int]$TimeoutSeconds = 0,

    [ValidateRange(1, 60)]
    [int]$PollIntervalSeconds = 5,

    [ValidateRange(1, 300)]
    [int]$RaceGraceSeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$payloadDir     = Split-Path -Parent $SentinelPath
$errorFilePath  = Join-Path $payloadDir 'detached-payload-error.log'
$stderrFilePath = Join-Path $payloadDir 'detached-payload-stderr.log'

function Get-Prop {
    param($Object, [string]$Name)
    if (($null -ne $Object) -and ($Object.PSObject.Properties.Name -contains $Name)) {
        return $Object.$Name
    }
    return $null
}

function Read-SentinelObject {
    if (-not (Test-Path -LiteralPath $SentinelPath -PathType Leaf)) {
        return $null
    }
    try {
        return (Get-Content -LiteralPath $SentinelPath -Raw) | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Test-SentinelDone {
    param($Sentinel)
    return ((Get-Prop -Object $Sentinel -Name 'done') -eq $true)
}

function Get-TaskHeartbeat {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -eq $task) {
        return [ordered]@{ exists = $false; state = $null; running = $false }
    }
    $state = [string]$task.State
    return [ordered]@{ exists = $true; state = $state; running = ($state -eq 'Running') }
}

function Write-WaitResult {
    param(
        [string]$Outcome,
        $Sentinel,
        [string]$TaskState,
        [bool]$TaskExists,
        [int]$WaitedSeconds,
        [string]$Summary,
        [int]$ProcessExitCode
    )

    $errorText = ''
    if (Test-Path -LiteralPath $errorFilePath -PathType Leaf) {
        try { $errorText = Get-Content -LiteralPath $errorFilePath -Raw } catch { $errorText = '' }
    }

    $result = [ordered]@{
        outcome         = $Outcome
        sentinelPath    = $SentinelPath
        taskName        = $TaskName
        sentinelPresent = ($null -ne $Sentinel)
        exitCode        = (Get-Prop -Object $Sentinel -Name 'exitCode')
        logPath         = (Get-Prop -Object $Sentinel -Name 'logPath')
        logExists       = (Get-Prop -Object $Sentinel -Name 'logExists')
        taskState       = $TaskState
        taskExists      = $TaskExists
        errorFilePath   = $errorFilePath
        error           = $errorText
        stderrPath      = $stderrFilePath
        waitedSeconds   = $WaitedSeconds
        summary         = $Summary
    }
    Write-Output ($result | ConvertTo-Json -Depth 6)
    exit $ProcessExitCode
}

$startTime = [DateTime]::Now

while ($true) {
    $elapsed = [int]([DateTime]::Now - $startTime).TotalSeconds

    # Sinal (a): sentinela presente com done=true -> conclusão normal.
    $sentinel = Read-SentinelObject
    if (Test-SentinelDone -Sentinel $sentinel) {
        Write-WaitResult -Outcome 'concluido' -Sentinel $sentinel -TaskState 'finished' -TaskExists $false -WaitedSeconds $elapsed -Summary 'Sentinela presente (done=true). Build concluiu — ler exitCode/logPath.' -ProcessExitCode 0
    }

    # Sinal (b): heartbeat da tarefa.
    $hb = Get-TaskHeartbeat
    if (-not $hb.running) {
        # Tarefa parou (ou sumiu) sem sentinela: pode ser crash OU a janela de corrida normal
        # entre a tarefa parar e o finally escrever a sentinela. Re-checar pela margem de corrida.
        $graceStart = [DateTime]::Now
        while (([int]([DateTime]::Now - $graceStart).TotalSeconds) -lt $RaceGraceSeconds) {
            Start-Sleep -Seconds ([Math]::Min($PollIntervalSeconds, $RaceGraceSeconds))
            $sentinelGrace = Read-SentinelObject
            if (Test-SentinelDone -Sentinel $sentinelGrace) {
                $elapsedGrace = [int]([DateTime]::Now - $startTime).TotalSeconds
                Write-WaitResult -Outcome 'concluido' -Sentinel $sentinelGrace -TaskState $hb.state -TaskExists $hb.exists -WaitedSeconds $elapsedGrace -Summary 'Sentinela apareceu na margem de corrida apos a tarefa parar. Build concluiu.' -ProcessExitCode 0
            }
        }
        $elapsedFail = [int]([DateTime]::Now - $startTime).TotalSeconds
        Write-WaitResult -Outcome 'falha-anomala' -Sentinel $null -TaskState $hb.state -TaskExists $hb.exists -WaitedSeconds $elapsedFail -Summary 'A Tarefa Agendada parou de executar (ou sumiu) e a sentinela nao foi escrita apos a margem de corrida. Provavel kill abrupto / OOM / estouro de -ExecutionTimeLimit antes do bloco finally. Diagnostico em error e stderrPath.' -ProcessExitCode 70
    }

    # Timeout: só quando a tarefa segue Running além do limite.
    if ($TimeoutSeconds -gt 0 -and $elapsed -ge $TimeoutSeconds) {
        Write-WaitResult -Outcome 'timeout' -Sentinel $null -TaskState $hb.state -TaskExists $hb.exists -WaitedSeconds $elapsed -Summary ('Timeout de {0}s atingido com a tarefa ainda em execucao e sem sentinela. O build pode continuar; reexecutar a espera ou inspecionar manualmente.' -f $TimeoutSeconds) -ProcessExitCode 71
    }

    Start-Sleep -Seconds $PollIntervalSeconds
}
