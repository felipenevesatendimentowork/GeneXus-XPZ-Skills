#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$readerPath = Join-Path $PSScriptRoot 'Read-MsBuildImportSignals.ps1'
if (-not (Test-Path -LiteralPath $readerPath -PathType Leaf)) {
    throw "Read-MsBuildImportSignals.ps1 nao encontrado: $readerPath"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-msbuild-signals-classifier-" + [guid]::NewGuid().ToString('N'))
try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)

    $stdoutPath = Join-Path $tempRoot 'msbuild.stdout.log'
    $stderrPath = Join-Path $tempRoot 'msbuild.stderr.log'

    $stdoutText = @(
        "O acesso ao caminho 'C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json' foi negado."
        'Import Task Success'
    ) -join [Environment]::NewLine

    [System.IO.File]::WriteAllText($stdoutPath, $stdoutText, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($stderrPath, '', [System.Text.UTF8Encoding]::new($false))

    $jsonText = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -Stage 'classifier-self-test' -AsJson) -join [Environment]::NewLine
    $signals = $jsonText | ConvertFrom-Json
    $knownNoise = @($signals.knownStdOutNoise)

    if ($knownNoise.Count -ne 1) {
        throw "Esperava 1 knownStdOutNoise; obtido: $($knownNoise.Count)"
    }

    if ($knownNoise[0].code -ne 'cssproperties-access-denied') {
        throw "Codigo inesperado para knownStdOutNoise: $($knownNoise[0].code)"
    }

    if ($knownNoise[0].classification -ne 'known-environment-noise') {
        throw "Classificacao inesperada para knownStdOutNoise: $($knownNoise[0].classification)"
    }

    if ($signals.counts.knownStdOutNoise -ne 1) {
        throw "Contador knownStdOutNoise inesperado: $($signals.counts.knownStdOutNoise)"
    }

    $lockedStdoutText = @(
        "The process cannot access the file 'C:\Models\GX\GxImport.log' because it is being used by another process."
        'Import Task Success'
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($stdoutPath, $lockedStdoutText, [System.Text.UTF8Encoding]::new($false))

    $lockedJsonText = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -Stage 'classifier-self-test' -AsJson) -join [Environment]::NewLine
    $lockedSignals = $lockedJsonText | ConvertFrom-Json

    if ($lockedSignals.gxImportLogReadStatus -ne 'locked') {
        throw "Status gxImportLogReadStatus inesperado: $($lockedSignals.gxImportLogReadStatus)"
    }

    if (-not $lockedSignals.diagnosticDegraded) {
        throw 'Esperava diagnosticDegraded=true para lock de GxImport.log.'
    }

    if ([string]::IsNullOrWhiteSpace($lockedSignals.gxImportLogReadError)) {
        throw 'Esperava gxImportLogReadError preenchido para lock de GxImport.log.'
    }

    $aliasStdoutText = @(
        '__IMPORTED_ITEM__=SDPanel:SDVendaIncluir'
        'Import Task Success'
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($stdoutPath, $aliasStdoutText, [System.Text.UTF8Encoding]::new($false))

    $aliasJsonText = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -ExpectedItems 'Panel:SDVendaIncluir' -Stage 'classifier-self-test' -AsJson) -join [Environment]::NewLine
    $aliasSignals = $aliasJsonText | ConvertFrom-Json
    $aliasMatches = @($aliasSignals.itemAliasMatches)

    if ($aliasMatches.Count -ne 1) {
        throw "Esperava 1 itemAliasMatches; obtido: $($aliasMatches.Count)"
    }

    if ($aliasMatches[0].canonical -ne 'Panel:SDVendaIncluir') {
        throw "Canonical inesperado para alias Panel/SDPanel: $($aliasMatches[0].canonical)"
    }

    if (@($aliasSignals.expectedItemsCanonical)[0] -ne @($aliasSignals.importedItemsCanonical)[0]) {
        throw 'Esperava expectedItemsCanonical e importedItemsCanonical equivalentes para Panel/SDPanel.'
    }

    'TEST_MsBuildImportSignalsClassifier=PASS'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
