#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusMsBuildConcurrencySupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusMsBuildConcurrencySupport.ps1 nao encontrado: $supportPath"
}
. $supportPath

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [object]$Expected,
        [object]$Actual,
        [string]$Message
    )

    if ($Expected -ne $Actual) {
        throw ("{0} Esperado: {1}; obtido: {2}" -f $Message, $Expected, $Actual)
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-msbuild-concurrency-selftest-' + [System.Guid]::NewGuid().ToString('N'))

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

    $kbPath = Join-Path $tempRoot 'Kb Principal'
    $otherKbPath = Join-Path $tempRoot 'Kb Outra'
    [System.IO.Directory]::CreateDirectory($kbPath) | Out-Null
    [System.IO.Directory]::CreateDirectory($otherKbPath) | Out-Null

    $projectPath = Join-Path $tempRoot 'import real.msbuild'
    $plainProjectPath = Join-Path $tempRoot 'plain.msbuild'
    $otherProjectPath = Join-Path $tempRoot 'other.msbuild'
    $withoutKbPath = Join-Path $tempRoot 'without-kbpath.msbuild'
    $invalidProjectPath = Join-Path $tempRoot 'invalid.msbuild'

    [System.IO.File]::WriteAllText(
        $projectPath,
        "<Project><PropertyGroup><KBPath>$kbPath</KBPath></PropertyGroup></Project>",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        $plainProjectPath,
        "<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><PropertyGroup><KBPath>$kbPath</KBPath></PropertyGroup></Project>",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        $otherProjectPath,
        "<Project><PropertyGroup><KBPath>$otherKbPath</KBPath></PropertyGroup></Project>",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        $withoutKbPath,
        '<Project><PropertyGroup><Other>value</Other></PropertyGroup></Project>',
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        $invalidProjectPath,
        '<Project><PropertyGroup>',
        [System.Text.UTF8Encoding]::new($false)
    )

    $quotedPaths = @(Get-GeneXusMsBuildProjectPathFromCommandLine -CommandLine ('"C:\MSBuild.exe" "{0}" /t:Run "{1}"' -f $projectPath, $projectPath))
    Assert-Equal -Expected 1 -Actual $quotedPaths.Count -Message 'Caminhos .msbuild duplicados deveriam ser deduplicados.'
    Assert-Equal -Expected ([System.IO.Path]::GetFullPath($projectPath)) -Actual $quotedPaths[0] -Message 'Parser deveria extrair .msbuild quoted.'

    $unquotedPaths = @(Get-GeneXusMsBuildProjectPathFromCommandLine -CommandLine ('C:\MSBuild.exe {0} /t:Run' -f $plainProjectPath))
    Assert-Equal -Expected 1 -Actual $unquotedPaths.Count -Message 'Parser deveria extrair .msbuild unquoted.'
    Assert-Equal -Expected ([System.IO.Path]::GetFullPath($plainProjectPath)) -Actual $unquotedPaths[0] -Message 'Parser deveria normalizar .msbuild unquoted.'

    $emptyPaths = @(Get-GeneXusMsBuildProjectPathFromCommandLine -CommandLine '')
    Assert-Equal -Expected 0 -Actual $emptyPaths.Count -Message 'CommandLine vazia nao deveria produzir caminhos.'

    $projectDiagnostic = Get-GeneXusKbPathFromMsBuildProject -ProjectPath $projectPath
    Assert-Equal -Expected 'ok' -Actual $projectDiagnostic.readStatus -Message 'Projeto com KBPath deveria retornar ok.'
    Assert-Equal -Expected 1 -Actual @($projectDiagnostic.kbPaths).Count -Message 'Projeto com um KBPath deveria retornar uma KB.'
    Assert-Equal -Expected ([System.IO.Path]::GetFullPath($kbPath)) -Actual @($projectDiagnostic.kbPaths)[0] -Message 'KBPath deveria ser normalizado.'

    $missingDiagnostic = Get-GeneXusKbPathFromMsBuildProject -ProjectPath (Join-Path $tempRoot 'missing.msbuild')
    Assert-Equal -Expected 'project-file-not-found' -Actual $missingDiagnostic.readStatus -Message 'Projeto inexistente deveria ser classificado.'

    $withoutKbDiagnostic = Get-GeneXusKbPathFromMsBuildProject -ProjectPath $withoutKbPath
    Assert-Equal -Expected 'kbpath-not-found' -Actual $withoutKbDiagnostic.readStatus -Message 'Projeto sem KBPath deveria ser classificado.'

    $invalidDiagnostic = Get-GeneXusKbPathFromMsBuildProject -ProjectPath $invalidProjectPath
    Assert-Equal -Expected 'read-error' -Actual $invalidDiagnostic.readStatus -Message 'XML invalido deveria ser classificado como read-error.'
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($invalidDiagnostic.readError)) -Message 'read-error deveria trazer mensagem.'

    function Get-GeneXusMsBuildRunningProcesses {
        param([int]$ExcludeProcessId)

        return [ordered]@{
            status = 'ok'
            error = $null
            processes = @(
                [ordered]@{
                    processId = 101
                    processName = 'MSBuild.exe'
                    executablePath = 'C:\MSBuild.exe'
                    commandLine = ('"C:\MSBuild.exe" "{0}" /t:Run' -f $projectPath)
                },
                [ordered]@{
                    processId = 102
                    processName = 'MSBuild.exe'
                    executablePath = 'C:\MSBuild.exe'
                    commandLine = ('"C:\MSBuild.exe" "{0}" /t:Run' -f $otherProjectPath)
                },
                [ordered]@{
                    processId = 103
                    processName = 'MSBuild.exe'
                    executablePath = 'C:\MSBuild.exe'
                    commandLine = '"C:\MSBuild.exe" /t:Run'
                },
                [ordered]@{
                    processId = $ExcludeProcessId
                    processName = 'MSBuild.exe'
                    executablePath = 'C:\MSBuild.exe'
                    commandLine = ('"C:\MSBuild.exe" "{0}" /t:Run' -f $projectPath)
                }
            ) | Where-Object { [int]$_.processId -ne $ExcludeProcessId }
        }
    }

    $blocked = Invoke-GeneXusMsBuildKbConcurrencyCheck -KbPath $kbPath -ExcludeProcessId 999
    Assert-Equal -Expected 'blocked' -Actual $blocked.status -Message 'Mesma KB deveria bloquear.'
    Assert-Equal -Expected 46 -Actual $blocked.exitCode -Message 'Bloqueio de concorrencia deveria retornar exit 46.'
    Assert-Equal -Expected 1 -Actual @($blocked.matchedKbProcesses).Count -Message 'Deveria haver um processo reconciliado com a mesma KB.'
    Assert-Equal -Expected 1 -Actual @($blocked.unreconciledMsBuildProcesses).Count -Message 'Processo sem .msbuild deveria ficar unreconciled.'
    Assert-True -Condition (@($blocked.blockingReasons) -contains 'MSBUILD_CONCORRENTE_MESMA_KB') -Message 'Blocking reason esperada ausente.'

    $ok = Invoke-GeneXusMsBuildKbConcurrencyCheck -KbPath (Join-Path $tempRoot 'Kb Sem Processo') -ExcludeProcessId 999
    Assert-Equal -Expected 'ok' -Actual $ok.status -Message 'KB sem processo reconciliado nao deveria bloquear.'
    Assert-Equal -Expected 0 -Actual $ok.exitCode -Message 'KB sem processo reconciliado deveria retornar exit 0.'
    Assert-Equal -Expected 0 -Actual @($ok.matchedKbProcesses).Count -Message 'KB sem processo reconciliado nao deveria ter matches.'

    Write-Output 'GENEXUS_MSBUILD_CONCURRENCY_SUPPORT_SELFTEST_OK'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
