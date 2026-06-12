#requires -Version 7.4

<#
.SYNOPSIS
    Regressão mínima do contrato Start-GeneXusKbBuildDetached.ps1.

.DESCRIPTION
    Cobre, sem GeneXus, sem MSBuild e sem registrar Tarefa Agendada real:
    - modo payload: wrapper falso com exit 0 -> sentinela { done:true, exitCode:0 };
    - modo payload: wrapper falso com exit 45 -> sentinela exitCode 45 e exit do processo 45;
    - modo payload: wrapper falso que lança exceção -> sentinela exitCode 90;
    - modo payload: sentinela é JSON bem-formado com os campos do contrato e escrita atômica
      (sem .tmp residual);
    - modo launch: WorkingDirectory sob Program Files (x86) -> exit 46, status bloqueado,
      sem registrar tarefa.

    NÃO cobre o caminho feliz do modo launch (registra e dispara Tarefa Agendada real), por
    efeito colateral no Task Scheduler — esse caminho é validado em uso controlado.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$scriptPath = Join-Path $scriptDir 'Start-GeneXusKbBuildDetached.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Start-GeneXusKbBuildDetached.ps1 nao encontrado: $scriptPath"
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

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("start-detached-{0}" -f ([guid]::NewGuid().ToString('N')))
New-Item -Path $workRoot -ItemType Directory -Force | Out-Null

function New-MockBuildWrapper {
    param([int]$ExitWith, [switch]$Throw)
    $path = Join-Path $workRoot ("mock-build-{0}.ps1" -f ([guid]::NewGuid().ToString('N')))
    if ($Throw.IsPresent) {
        $body = "throw 'mock build wrapper failure'"
    } else {
        $body = "exit $ExitWith"
    }
    [System.IO.File]::WriteAllText($path, $body + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
    return $path
}

function Invoke-PayloadMode {
    param([string]$MockBuildPath)
    $sentinel = Join-Path $workRoot ("sentinel-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $logPath  = Join-Path $workRoot ("result-{0}.json"   -f ([guid]::NewGuid().ToString('N')))
    $spec = [ordered]@{
        buildScriptPath = $MockBuildPath
        buildArgs       = @()
        sentinelPath    = $sentinel
        logPath         = $logPath
        taskName        = 'XpzBuildDetached_NaoExiste_00000000'
    }
    $specPath = Join-Path $workRoot ("spec-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($specPath, ($spec | ConvertTo-Json -Depth 6) + [Environment]::NewLine, (Get-Utf8NoBomEncoding))

    $out = & pwsh -NoProfile -File $scriptPath -RunDetachedPayload -PayloadSpecPath $specPath 2>&1
    $code = $LASTEXITCODE
    $sentinelObj = $null
    if (Test-Path -LiteralPath $sentinel -PathType Leaf) {
        try { $sentinelObj = (Get-Content -LiteralPath $sentinel -Raw) | ConvertFrom-Json } catch { $sentinelObj = $null }
    }
    return [pscustomobject]@{
        ExitCode    = $code
        SentinelPath = $sentinel
        Sentinel    = $sentinelObj
        TmpExists   = (Test-Path -LiteralPath ($sentinel + '.tmp') -PathType Leaf)
        Raw         = ($out | Out-String)
    }
}

try {
    # --- 1) payload com exit 0 ---------------------------------------------------
    $mock0 = New-MockBuildWrapper -ExitWith 0
    $r0 = Invoke-PayloadMode -MockBuildPath $mock0
    Assert-That ($r0.ExitCode -eq 0) "payload exit 0: processo retorna 0 (obtido: $($r0.ExitCode))"
    Assert-That ($null -ne $r0.Sentinel) 'payload exit 0: sentinela gravada e JSON bem-formado'
    if ($null -ne $r0.Sentinel) {
        Assert-That ($r0.Sentinel.done -eq $true) 'payload exit 0: sentinela done=true'
        Assert-That ($r0.Sentinel.exitCode -eq 0) "payload exit 0: sentinela exitCode 0 (obtido: $($r0.Sentinel.exitCode))"
        Assert-That (-not [string]::IsNullOrWhiteSpace([string]$r0.Sentinel.finishedAt)) 'payload exit 0: sentinela tem finishedAt'
        Assert-That (-not [string]::IsNullOrWhiteSpace([string]$r0.Sentinel.logPath)) 'payload exit 0: sentinela tem logPath'
    }
    Assert-That (-not $r0.TmpExists) 'payload exit 0: escrita atomica (sem .tmp residual)'

    # --- 2) payload com exit 45 (compilou com erros) -----------------------------
    $mock45 = New-MockBuildWrapper -ExitWith 45
    $r45 = Invoke-PayloadMode -MockBuildPath $mock45
    Assert-That ($r45.ExitCode -eq 45) "payload exit 45: processo propaga 45 (obtido: $($r45.ExitCode))"
    Assert-That (($null -ne $r45.Sentinel) -and ($r45.Sentinel.exitCode -eq 45)) "payload exit 45: sentinela exitCode 45"

    # --- 3) payload com wrapper que lança excecao -> 90 --------------------------
    $mockThrow = New-MockBuildWrapper -ExitWith 0 -Throw
    $rThrow = Invoke-PayloadMode -MockBuildPath $mockThrow
    Assert-That ($rThrow.ExitCode -eq 90) "payload throw: processo retorna 90 (obtido: $($rThrow.ExitCode))"
    Assert-That (($null -ne $rThrow.Sentinel) -and ($rThrow.Sentinel.exitCode -eq 90)) 'payload throw: sentinela exitCode 90 (sentinela sempre gravada no finally)'

    # --- 4) launch com WorkingDirectory sob Program Files (x86) -> 46 ------------
    $unsafeWork = 'C:\Program Files (x86)\xpz-detached-test-naoexiste'
    $safeLog = Join-Path $workRoot ("launch-result-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $outLaunch = & pwsh -NoProfile -File $scriptPath -KbPath 'C:\KBs\NaoImporta' -WorkingDirectory $unsafeWork -LogPath $safeLog 2>&1
    $codeLaunch = $LASTEXITCODE
    $launchObj = $null
    try { $launchObj = ($outLaunch | Out-String | ConvertFrom-Json) } catch { $launchObj = $null }
    Assert-That ($codeLaunch -eq 46) "launch Program Files: exit 46 (obtido: $codeLaunch)"
    Assert-That (($null -ne $launchObj) -and ($launchObj.status -eq 'bloqueado por politica de seguranca')) 'launch Program Files: status bloqueado'
    Assert-That (($null -ne $launchObj) -and ($launchObj.started -eq $false)) 'launch Program Files: started=false (tarefa nao registrada)'
    Assert-That (-not (Test-Path -LiteralPath $unsafeWork -PathType Container)) 'launch Program Files: nao criou diretorio sob Program Files'
} finally {
    if (Test-Path -LiteralPath $workRoot -PathType Container) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($script:failures -gt 0) {
    throw "Contrato Start-GeneXusKbBuildDetached: $($script:failures) assercao(oes) falharam."
}
Write-Host "Contrato Start-GeneXusKbBuildDetached: OK" -ForegroundColor Green
exit 0
