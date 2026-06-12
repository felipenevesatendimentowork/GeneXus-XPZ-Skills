#requires -Version 7.4
<#
.SYNOPSIS
    Regressao mínima do resolvedor de .cs gerado via kb-source-metadata.md.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$setMetadataScript = Join-Path $scriptDir 'Set-XpzKbSourceMetadataDeployment.ps1'
$resolveScript = Join-Path $scriptDir 'Resolve-GeneXusGeneratedCsPath.ps1'

if (-not (Test-Path -LiteralPath $setMetadataScript -PathType Leaf)) {
    throw "Set-XpzKbSourceMetadataDeployment.ps1 nao encontrado: $setMetadataScript"
}

if (-not (Test-Path -LiteralPath $resolveScript -PathType Leaf)) {
    throw "Resolve-GeneXusGeneratedCsPath.ps1 nao encontrado: $resolveScript"
}

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-resolve-cs-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $parallelRoot = Join-Path $tempRoot 'parallel'
    $kbNativePath = Join-Path $tempRoot 'KbNative'
    $webDir = Join-Path (Join-Path $kbNativePath 'NETPostgreSQL') 'web'
    New-Item -ItemType Directory -Path $parallelRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $webDir -Force | Out-Null

    $metadataPath = Join-Path $parallelRoot 'kb-source-metadata.md'
    $metadata = @(
        '---'
        'last_xpz_materialization_run_at: 2026-06-04T10:00:00.0000000+00:00'
        '---'
        ''
        '## Source'
        ''
        '| field | value |'
        '| --- | --- |'
        '| kb (GUID) | 11111111-1111-1111-1111-111111111111 |'
        ''
        '## Source/Version'
        ''
        '| field | value |'
        '| --- | --- |'
        '| name | MinhaKb |'
        '| guid | 22222222-2222-2222-2222-222222222222 |'
    ) -join "`n"
    [System.IO.File]::WriteAllText($metadataPath, $metadata + "`n", (Get-Utf8NoBomEncoding))

    & $setMetadataScript `
        -KbParallelRoot $parallelRoot `
        -DeploymentEnvironmentName 'NETPostgreSQL' `
        -DeploymentHostingKind 'dotnet-core-self-host' `
        -KbEnvironmentNames 'NETPostgreSQL' `
        -KbEnvironmentOutputDirs 'NETPostgreSQL=NETPostgreSQL' `
        -KbNativePath $kbNativePath `
        -SkipEnvironmentNamesMsBuildValidation `
        -AsJson | Out-Null

    $csPath = Join-Path $webDir 'wpprocessaarquivo.cs'
    [System.IO.File]::WriteAllText($csPath, 'public class wpprocessaarquivo {}', (Get-Utf8NoBomEncoding))

    $json = & $resolveScript `
        -KbPath $kbNativePath `
        -ParallelKbRoot $parallelRoot `
        -ObjectName 'WpProcessaArquivo' `
        -ObjectType 'WebPanel' `
        -AsJson

    $result = $json | ConvertFrom-Json
    if ($result.status -ne 'CS_PATH_RESOLVED') {
        throw "ASSERT_FAILED: status inesperado: $($result.status)"
    }
    if (-not $result.exists) {
        throw 'ASSERT_FAILED: resolvedor deveria encontrar o .cs criado.'
    }
    if ($result.csPath -ne $csPath) {
        throw "ASSERT_FAILED: csPath divergente. esperado=$csPath atual=$($result.csPath)"
    }
    if ($result.resolutionSource -ne 'kb-source-metadata.kb_environment_web_dirs') {
        throw "ASSERT_FAILED: resolutionSource divergente: $($result.resolutionSource)"
    }

    'RESOLVE_GENEXUS_GENERATED_CS_PATH_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
