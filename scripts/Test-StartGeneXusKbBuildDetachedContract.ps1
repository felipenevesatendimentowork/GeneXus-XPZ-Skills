#requires -Version 7.4

<#
.SYNOPSIS
    Regressão mínima do contrato Start-GeneXusKbBuildDetached.ps1.

.DESCRIPTION
    Cobre, sem GeneXus, sem MSBuild e sem registrar Tarefa Agendada real:
    - modo payload com binding REAL de parâmetros: o mock tem a mesma assinatura do wrapper
      (parâmetros ValidateSet 'true'/'false'), de modo que um splat desalinhado falharia no
      binding — regressão direta do bug que o array splatting causava (corrigido com
      hashtable splatting);
    - wrapper que conclui escrevendo o LogPath e sai 0 -> sentinela exitCode 0, logExists true,
      error null, e o binding chegou correto ao mock (CompileMains='false', FailIfReorg='true');
    - wrapper que escreve LogPath e sai 45 -> sentinela exitCode 45, logExists true;
    - wrapper que lança exceção (sem log) -> sentinela exitCode 90, logExists false, error
      preenchido e detached-payload-error.log presente (catch NÃO engole mais o erro);
    - sentinela sempre traz logExists/error/stdoutPath/stderrPath e escrita atômica (sem .tmp);
    - modo launch: WorkingDirectory sob Program Files (x86) -> exit 46, status bloqueado.

    NÃO cobre o caminho feliz do modo launch (registra/dispara Tarefa Agendada real), por
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

# Mock com a MESMA assinatura do wrapper real: parâmetros ValidateSet 'true'/'false'. Se o
# splat desalinhar (bug do array splatting), o binding falha e o caso quebra — exatamente o
# que precisamos detectar. Com -WriteLog, grava no LogPath os valores recebidos, para o
# self-test confirmar que o binding chegou correto.
function New-MockBuildWrapper {
    param([int]$ExitWith, [switch]$Throw, [switch]$WriteLog)
    $path = Join-Path $workRoot ("mock-build-{0}.ps1" -f ([guid]::NewGuid().ToString('N')))
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('param(')
    $lines.Add('    [Parameter(Mandatory=$true)][string]$KbPath,')
    $lines.Add('    [Parameter(Mandatory=$true)][string]$WorkingDirectory,')
    $lines.Add('    [Parameter(Mandatory=$true)][string]$LogPath,')
    $lines.Add('    [ValidateSet("true","false")][string]$ForceRebuild="false",')
    $lines.Add('    [ValidateSet("true","false")][string]$CompileMains="false",')
    $lines.Add('    [ValidateSet("true","false")][string]$DetailedNavigation="false",')
    $lines.Add('    [ValidateSet("true","false")][string]$FailIfReorg="true",')
    $lines.Add('    [ValidateSet("true","false")][string]$DoNotExecuteReorg="false"')
    $lines.Add(')')
    if ($WriteLog.IsPresent) {
        $lines.Add('$received = [ordered]@{ KbPath=$KbPath; CompileMains=$CompileMains; FailIfReorg=$FailIfReorg; DoNotExecuteReorg=$DoNotExecuteReorg } | ConvertTo-Json -Compress')
        $lines.Add('[System.IO.File]::WriteAllText($LogPath, $received)')
    }
    if ($Throw.IsPresent) {
        $lines.Add("throw 'mock build wrapper failure'")
    } else {
        $lines.Add("exit $ExitWith")
    }
    [System.IO.File]::WriteAllText($path, ($lines -join [Environment]::NewLine) + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
    return $path
}

function Invoke-PayloadMode {
    param([string]$MockBuildPath)
    $sentinel = Join-Path $workRoot ("sentinel-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $logPath  = Join-Path $workRoot ("result-{0}.json"   -f ([guid]::NewGuid().ToString('N')))
    $spec = [ordered]@{
        buildScriptPath = $MockBuildPath
        buildParams     = [ordered]@{
            KbPath             = 'C:\KBs\Mock'
            WorkingDirectory   = $workRoot
            LogPath            = $logPath
            ForceRebuild       = 'false'
            CompileMains       = 'false'
            DetailedNavigation = 'false'
            FailIfReorg        = 'true'
            DoNotExecuteReorg  = 'false'
        }
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
    $logContent = $null
    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        try { $logContent = (Get-Content -LiteralPath $logPath -Raw) | ConvertFrom-Json } catch { $logContent = $null }
    }
    $errorFile = Join-Path $workRoot 'detached-payload-error.log'
    $errorFileText = ''
    if (Test-Path -LiteralPath $errorFile -PathType Leaf) {
        $errorFileText = Get-Content -LiteralPath $errorFile -Raw
    }
    return [pscustomobject]@{
        ExitCode      = $code
        Sentinel      = $sentinelObj
        LogContent    = $logContent
        TmpExists     = (Test-Path -LiteralPath ($sentinel + '.tmp') -PathType Leaf)
        ErrorFileText = $errorFileText
        Raw           = ($out | Out-String)
    }
}

try {
    # --- 1) binding REAL + log + exit 0 (regressao do bug de splat) --------------
    $mockOk = New-MockBuildWrapper -ExitWith 0 -WriteLog
    $r0 = Invoke-PayloadMode -MockBuildPath $mockOk
    Assert-That ($r0.ExitCode -eq 0) "binding/exit 0: processo retorna 0 (obtido: $($r0.ExitCode))"
    Assert-That ($null -ne $r0.Sentinel) 'binding/exit 0: sentinela gravada e JSON bem-formado'
    if ($null -ne $r0.Sentinel) {
        Assert-That ($r0.Sentinel.exitCode -eq 0) "binding/exit 0: sentinela exitCode 0 (obtido: $($r0.Sentinel.exitCode))"
        Assert-That ($r0.Sentinel.logExists -eq $true) 'binding/exit 0: sentinela logExists=true'
        Assert-That ([string]::IsNullOrEmpty([string]$r0.Sentinel.error)) 'binding/exit 0: sentinela sem error'
        Assert-That (-not [string]::IsNullOrWhiteSpace([string]$r0.Sentinel.stdoutPath)) 'binding/exit 0: sentinela tem stdoutPath'
        Assert-That (-not [string]::IsNullOrWhiteSpace([string]$r0.Sentinel.stderrPath)) 'binding/exit 0: sentinela tem stderrPath'
    }
    Assert-That ($null -ne $r0.LogContent) 'binding/exit 0: wrapper escreveu o LogPath (binding nao falhou)'
    if ($null -ne $r0.LogContent) {
        Assert-That ($r0.LogContent.CompileMains -eq 'false') "binding/exit 0: CompileMains chegou 'false' (obtido: $($r0.LogContent.CompileMains))"
        Assert-That ($r0.LogContent.FailIfReorg -eq 'true') "binding/exit 0: FailIfReorg chegou 'true' (obtido: $($r0.LogContent.FailIfReorg))"
        Assert-That ($r0.LogContent.DoNotExecuteReorg -eq 'false') "binding/exit 0: DoNotExecuteReorg chegou 'false' (obtido: $($r0.LogContent.DoNotExecuteReorg))"
    }
    Assert-That (-not $r0.TmpExists) 'binding/exit 0: escrita atomica (sem .tmp residual)'

    # --- 2) log + exit 45 --------------------------------------------------------
    $mock45 = New-MockBuildWrapper -ExitWith 45 -WriteLog
    $r45 = Invoke-PayloadMode -MockBuildPath $mock45
    Assert-That ($r45.ExitCode -eq 45) "exit 45: processo propaga 45 (obtido: $($r45.ExitCode))"
    Assert-That (($null -ne $r45.Sentinel) -and ($r45.Sentinel.exitCode -eq 45)) 'exit 45: sentinela exitCode 45'
    Assert-That (($null -ne $r45.Sentinel) -and ($r45.Sentinel.logExists -eq $true)) 'exit 45: sentinela logExists=true'

    # --- 3) wrapper que lanca excecao (sem log) -> 90 + error capturado ----------
    $mockThrow = New-MockBuildWrapper -ExitWith 0 -Throw
    $rThrow = Invoke-PayloadMode -MockBuildPath $mockThrow
    Assert-That ($rThrow.ExitCode -eq 90) "throw: processo retorna 90 (obtido: $($rThrow.ExitCode))"
    if ($null -ne $rThrow.Sentinel) {
        Assert-That ($rThrow.Sentinel.exitCode -eq 90) 'throw: sentinela exitCode 90'
        Assert-That ($rThrow.Sentinel.logExists -eq $false) 'throw: sentinela logExists=false (wrapper nao escreveu log)'
        Assert-That (-not [string]::IsNullOrWhiteSpace([string]$rThrow.Sentinel.error)) 'throw: sentinela error preenchido (catch nao engole)'
    }
    Assert-That (-not [string]::IsNullOrWhiteSpace($rThrow.ErrorFileText)) 'throw: detached-payload-error.log presente com a excecao'

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
