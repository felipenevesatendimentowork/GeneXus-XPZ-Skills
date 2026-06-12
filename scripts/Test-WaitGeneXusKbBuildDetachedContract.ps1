#requires -Version 7.4

<#
.SYNOPSIS
    Regressão mínima do contrato Wait-GeneXusKbBuildDetached.ps1.

.DESCRIPTION
    Cobre, sem Tarefa Agendada real e sem build, os caminhos de decisão da espera
    sentinela-ou-heartbeat (a tarefa nomeada NÃO existe — heartbeat "parado"):
    - sentinela `done=true` presente -> outcome `concluido`, processo exit 0, exitCode do
      build propagado (inclusive quando o build foi bloqueado: a espera conclui igual,
      pois reporta a ESPERA, não o veredito do build);
    - sentinela ausente + tarefa inexistente + arquivo de erro ao lado -> após a margem de
      corrida, outcome `falha-anomala`, processo exit 70, `error` preenchido, `taskExists` false.

    NÃO cobre o caminho `timeout` nem a janela de corrida com sentinela tardia (exigiriam uma
    Tarefa Agendada real em estado `Running`); validados em uso controlado.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$scriptPath = Join-Path $scriptDir 'Wait-GeneXusKbBuildDetached.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Wait-GeneXusKbBuildDetached.ps1 nao encontrado: $scriptPath"
}

$utf8NoBomEncodingSupportPath = Join-Path $scriptDir 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$script:failures = 0
function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        $script:failures++
        Write-Host "FAIL: $Message" -ForegroundColor Red
    } else {
        Write-Host "ok  : $Message"
    }
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wait-detached-{0}" -f ([guid]::NewGuid().ToString('N')))
New-Item -Path $workRoot -ItemType Directory -Force | Out-Null

$missingTask = 'XpzBuildDetached_NaoExiste_ffffffff'

function New-Sentinel {
    param([int]$ExitCode, [bool]$LogExists)
    $sentinel = Join-Path $workRoot ("sentinel-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $logPath  = Join-Path $workRoot ("result-{0}.json"   -f ([guid]::NewGuid().ToString('N')))
    $payload = [ordered]@{
        done       = $true
        exitCode   = $ExitCode
        logPath    = $logPath
        logExists  = $LogExists
        error      = ''
        stdoutPath = (Join-Path $workRoot 'detached-payload-stdout.log')
        stderrPath = (Join-Path $workRoot 'detached-payload-stderr.log')
        finishedAt = '2026-06-12T00:00:00-03:00'
    }
    [System.IO.File]::WriteAllText($sentinel, ($payload | ConvertTo-Json -Depth 6) + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
    return $sentinel
}

function Invoke-Wait {
    param([string]$SentinelPath, [int]$RaceGraceSeconds = 1, [int]$PollIntervalSeconds = 1)
    $out = & pwsh -NoProfile -File $scriptPath -SentinelPath $SentinelPath -TaskName $missingTask -RaceGraceSeconds $RaceGraceSeconds -PollIntervalSeconds $PollIntervalSeconds 2>&1
    $code = $LASTEXITCODE
    $obj = $null
    try { $obj = ($out | Out-String | ConvertFrom-Json) } catch { $obj = $null }
    return [pscustomobject]@{ ExitCode = $code; Result = $obj; Raw = ($out | Out-String) }
}

try {
    # --- 1) sentinela done=true, exitCode 0 -> concluido ------------------------
    $s1 = New-Sentinel -ExitCode 0 -LogExists $true
    $r1 = Invoke-Wait -SentinelPath $s1
    Assert-That ($r1.ExitCode -eq 0) "concluido/exit0: processo exit 0 (obtido: $($r1.ExitCode))"
    Assert-That (($null -ne $r1.Result) -and ($r1.Result.outcome -eq 'concluido')) 'concluido/exit0: outcome=concluido'
    Assert-That (($null -ne $r1.Result) -and ($r1.Result.exitCode -eq 0)) 'concluido/exit0: exitCode do build = 0 propagado'
    Assert-That (($null -ne $r1.Result) -and ($r1.Result.sentinelPresent -eq $true)) 'concluido/exit0: sentinelPresent=true'

    # --- 2) sentinela done=true com build bloqueado (exitCode 46) -> concluido --
    $s2 = New-Sentinel -ExitCode 46 -LogExists $true
    $r2 = Invoke-Wait -SentinelPath $s2
    Assert-That ($r2.ExitCode -eq 0) "concluido/build-bloqueado: espera conclui (exit 0) mesmo com build exitCode 46 (obtido: $($r2.ExitCode))"
    Assert-That (($null -ne $r2.Result) -and ($r2.Result.outcome -eq 'concluido') -and ($r2.Result.exitCode -eq 46)) 'concluido/build-bloqueado: outcome=concluido, exitCode do build=46'

    # --- 3) sem sentinela + tarefa inexistente + error file -> falha-anomala ----
    $s3 = Join-Path $workRoot ("sentinel-{0}.json" -f ([guid]::NewGuid().ToString('N')))  # NAO criado
    $errFile = Join-Path (Split-Path -Parent $s3) 'detached-payload-error.log'
    [System.IO.File]::WriteAllText($errFile, "EXCEPTION: simulada para teste de falha-anomala" + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
    $r3 = Invoke-Wait -SentinelPath $s3 -RaceGraceSeconds 1 -PollIntervalSeconds 1
    Assert-That ($r3.ExitCode -eq 70) "falha-anomala: processo exit 70 (obtido: $($r3.ExitCode))"
    Assert-That (($null -ne $r3.Result) -and ($r3.Result.outcome -eq 'falha-anomala')) 'falha-anomala: outcome=falha-anomala'
    Assert-That (($null -ne $r3.Result) -and ($r3.Result.taskExists -eq $false)) 'falha-anomala: taskExists=false (tarefa nao existe)'
    Assert-That (($null -ne $r3.Result) -and ($r3.Result.sentinelPresent -eq $false)) 'falha-anomala: sentinelPresent=false'
    Assert-That (($null -ne $r3.Result) -and (-not [string]::IsNullOrWhiteSpace([string]$r3.Result.error))) 'falha-anomala: error preenchido a partir do detached-payload-error.log'
    if (Test-Path -LiteralPath $errFile -PathType Leaf) { Remove-Item -LiteralPath $errFile -Force }
} finally {
    if (Test-Path -LiteralPath $workRoot -PathType Container) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($script:failures -gt 0) {
    throw "Contrato Wait-GeneXusKbBuildDetached: $($script:failures) assercao(oes) falharam."
}
Write-Host "Contrato Wait-GeneXusKbBuildDetached: OK" -ForegroundColor Green
exit 0
