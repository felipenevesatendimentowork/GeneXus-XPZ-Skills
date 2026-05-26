#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$governancePath = Join-Path $PSScriptRoot 'GeneXusXpzExportInventoryGovernance.ps1'
$supportPath = Join-Path $PSScriptRoot 'GeneXusMsBuildCategoryBSupport.ps1'
. $governancePath
. $supportPath

$expectedSubState = 'exportação parcial com errors do MSBuild — artefato não confiável'
$actualSubState = Resolve-ExportOperationalSubState -InventoryBlock $null -ExportErrors @('error : demo')
if ($actualSubState -ne $expectedSubState) {
    throw "Sub-estado inesperado: [$actualSubState]"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-export-error-barring-' + [guid]::NewGuid().ToString('N'))
try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)
    $stdoutPath = Join-Path $tempRoot 'msbuild.stdout.log'
    $stderrPath = Join-Path $tempRoot 'msbuild.stderr.log'
    $stdoutText = @(
        'Export Sucesso'
        '__EXPORTED_FILE__=C:\Temp\demo.xpz'
        'error : WorkWithForWeb is not a valid type.'
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($stdoutPath, $stdoutText, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($stderrPath, '', [System.Text.UTF8Encoding]::new($false))

    $readerPath = Join-Path $PSScriptRoot 'Read-MsBuildImportSignals.ps1'
    $signalsJson = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -Stage 'export' -AsJson) | Out-String
    $signals = $signalsJson | ConvertFrom-Json

    if (@($signals.exportErrors).Count -lt 1) {
        throw 'Esperava exportErrors no signals.json sintetico'
    }
    if (@($signals.invalidTypesRejected).Count -lt 1) {
        throw 'Esperava invalidTypesRejected no signals.json sintetico'
    }

    $exitCode = Resolve-GeneXusMsBuildCategoryBExitCode `
        -BaseExitCode 0 `
        -MsBuildExitCode 0 `
        -MsBuildErrors @($signals.exportErrors) `
        -InvalidTypesRejected @($signals.invalidTypesRejected)

    if ($exitCode -ne 48) {
        throw "Cenario Export Sucesso + error: deveria rebaixar para 48; obtido: $exitCode"
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output 'EXPORT_ERROR_BARRING_SELFTEST_OK'
