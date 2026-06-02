#requires -Version 7.4

Set-StrictMode -Version Latest

function Get-GeneXusMsBuildConcurrencyFullPath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    try {
        return [System.IO.Path]::GetFullPath($PathValue)
    } catch {
        return $PathValue
    }
}

function Get-GeneXusMsBuildConcurrencyComparablePath {
    param([string]$PathValue)

    $fullPath = Get-GeneXusMsBuildConcurrencyFullPath -PathValue $PathValue
    if ([string]::IsNullOrWhiteSpace($fullPath)) {
        return $null
    }

    return $fullPath.TrimEnd([char[]]@('\', '/')).ToLowerInvariant()
}

function Get-GeneXusMsBuildProjectPathFromCommandLine {
    param([string]$CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return @()
    }

    $matches = [regex]::Matches(
        $CommandLine,
        '(?:"([^"]+?\.msbuild)"|([^\s"]+?\.msbuild))',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    $paths = @()
    foreach ($match in $matches) {
        $value = $null
        if ($match.Groups[1].Success) {
            $value = $match.Groups[1].Value
        } elseif ($match.Groups[2].Success) {
            $value = $match.Groups[2].Value
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $paths += (Get-GeneXusMsBuildConcurrencyFullPath -PathValue $value)
        }
    }

    return @($paths | Select-Object -Unique)
}

function Get-GeneXusKbPathFromMsBuildProject {
    param([string]$ProjectPath)

    $result = [ordered]@{
        projectPath = $ProjectPath
        projectPathExists = $false
        kbPaths = @()
        readStatus = 'not-read'
        readError = $null
    }

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $result.readStatus = 'missing-project-path'
        return $result
    }

    if (-not (Test-Path -LiteralPath $ProjectPath -PathType Leaf)) {
        $result.readStatus = 'project-file-not-found'
        return $result
    }

    $result.projectPathExists = $true

    try {
        [xml]$projectXml = [System.IO.File]::ReadAllText($ProjectPath)
        $kbPathNodes = @($projectXml.SelectNodes("//*[local-name()='KBPath']"))
        $kbPaths = @()
        foreach ($node in $kbPathNodes) {
            $value = [string]$node.InnerText
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $kbPaths += (Get-GeneXusMsBuildConcurrencyFullPath -PathValue $value)
            }
        }

        $result.kbPaths = @($kbPaths | Select-Object -Unique)
        $result.readStatus = if ($result.kbPaths.Count -gt 0) { 'ok' } else { 'kbpath-not-found' }
    } catch {
        $result.readStatus = 'read-error'
        $result.readError = $_.Exception.Message
    }

    return $result
}

function Get-GeneXusMsBuildRunningProcesses {
    param([int]$ExcludeProcessId)

    $query = [ordered]@{
        status = 'ok'
        error = $null
        processes = @()
    }

    try {
        $items = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'MSBuild.exe'")
        $query.processes = @(
            $items |
                Where-Object { [int]$_.ProcessId -ne $ExcludeProcessId } |
                ForEach-Object {
                    [ordered]@{
                        processId = [int]$_.ProcessId
                        processName = [string]$_.Name
                        executablePath = [string]$_.ExecutablePath
                        commandLine = [string]$_.CommandLine
                    }
                }
        )
    } catch {
        $query.status = 'diagnostic-unavailable'
        $query.error = $_.Exception.Message
        $query.processes = @()
    }

    return $query
}

function Invoke-GeneXusMsBuildKbConcurrencyCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$KbPath,

        [int]$ExcludeProcessId = $PID
    )

    $resolvedKbPath = Get-GeneXusMsBuildConcurrencyFullPath -PathValue $KbPath
    $targetComparablePath = Get-GeneXusMsBuildConcurrencyComparablePath -PathValue $resolvedKbPath
    $processQuery = Get-GeneXusMsBuildRunningProcesses -ExcludeProcessId $ExcludeProcessId

    $runningProcesses = @()
    $matchedProcesses = @()
    $unreconciledProcesses = @()

    foreach ($process in @($processQuery.processes)) {
        $projectPaths = @(Get-GeneXusMsBuildProjectPathFromCommandLine -CommandLine ([string]$process.commandLine))
        $projectDiagnostics = @()
        $kbPaths = @()

        foreach ($projectPath in $projectPaths) {
            $projectDiagnostic = Get-GeneXusKbPathFromMsBuildProject -ProjectPath $projectPath
            $projectDiagnostics += $projectDiagnostic
            foreach ($kbPath in @($projectDiagnostic.kbPaths)) {
                $kbPaths += $kbPath
            }
        }

        $kbComparablePaths = @($kbPaths | ForEach-Object { Get-GeneXusMsBuildConcurrencyComparablePath -PathValue $_ })
        $matchesRequestedKb = $false
        foreach ($candidate in $kbComparablePaths) {
            if (-not [string]::IsNullOrWhiteSpace($candidate) -and $candidate -eq $targetComparablePath) {
                $matchesRequestedKb = $true
                break
            }
        }

        $processDiagnostic = [ordered]@{
            processId = $process.processId
            processName = $process.processName
            executablePath = $process.executablePath
            commandLine = $process.commandLine
            msBuildProjectPaths = @($projectPaths)
            msBuildProjectDiagnostics = @($projectDiagnostics)
            kbPaths = @($kbPaths | Select-Object -Unique)
            matchesRequestedKb = $matchesRequestedKb
        }

        $runningProcesses += $processDiagnostic
        if ($matchesRequestedKb) {
            $matchedProcesses += $processDiagnostic
        } elseif ($projectPaths.Count -eq 0 -or $kbPaths.Count -eq 0) {
            $unreconciledProcesses += $processDiagnostic
        }
    }

    $blockingReasons = @()
    $warnings = @()
    $status = 'ok'
    $exitCode = 0
    $summary = 'Nenhum MSBuild.exe em execução foi reconciliado com a mesma KB.'

    if ($matchedProcesses.Count -gt 0) {
        $status = 'blocked'
        $exitCode = 46
        $blockingReasons += 'MSBUILD_CONCORRENTE_MESMA_KB'
        $summary = 'Bloqueio preventivo: ja existe MSBuild.exe em execucao para a mesma KB.'
    }

    if ($processQuery.status -ne 'ok') {
        $warnings += ('Diagnostico de processos MSBuild indisponivel: {0}' -f $processQuery.error)
    }

    if ($unreconciledProcesses.Count -gt 0) {
        $warnings += 'Ha MSBuild.exe em execucao sem projeto .msbuild/KBPath reconciliavel; nao bloqueado por nao confirmar mesma KB.'
    }

    return [ordered]@{
        status = $status
        summary = $summary
        exitCode = $exitCode
        blockingReasons = @($blockingReasons)
        warnings = @($warnings)
        requestedContext = [ordered]@{
            kbPath = $KbPath
            resolvedKbPath = $resolvedKbPath
            comparableKbPath = $targetComparablePath
            excludeProcessId = $ExcludeProcessId
        }
        runningMsBuildProcesses = @($runningProcesses)
        matchedKbProcesses = @($matchedProcesses)
        unreconciledMsBuildProcesses = @($unreconciledProcesses)
        processQuery = [ordered]@{
            status = $processQuery.status
            error = $processQuery.error
        }
    }
}
