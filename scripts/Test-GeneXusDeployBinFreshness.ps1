#requires -Version 7.4
<#
.SYNOPSIS
    Diagnostico somente leitura de frescor de web\bin do environment de deploy.

.DESCRIPTION
    Complementa Test-GeneXusRuntimeFreshness.ps1 (CSharpModel compartilhado) verificando
    artefatos em <KbNative>\<EnvDeploy>\web\bin conforme deployment_hosting_kind no metadata.

.PARAMETER KbPath
    Caminho da KB GeneXus nativa.

.PARAMETER EnvironmentName
    Nome do environment de deploy. Se omitido, usa deployment_environment_name do metadata.

.PARAMETER BuildStartedAt
    Timestamp ISO de inicio do build usado como linha de corte.

.PARAMETER ParallelKbRoot
    Raiz da pasta paralela para resolver kb-source-metadata.md.

.PARAMETER KbMetadataPath
    Caminho explicito para kb-source-metadata.md.

.PARAMETER DeploymentHostingKind
    Quando informado, prevalece sobre o valor do metadata.

.PARAMETER AsJson
    Emite JSON estruturado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [string]$EnvironmentName,

    [Parameter(Mandatory = $true)]
    [string]$BuildStartedAt,

    [string]$ParallelKbRoot,

    [string]$KbMetadataPath,

    [string]$DeploymentHostingKind,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbDeployBinSupport.ps1')

$kbPathResolved = [System.IO.Path]::GetFullPath($KbPath)
if (-not (Test-Path -LiteralPath $kbPathResolved -PathType Container)) {
    throw "KbPath invalido: $kbPathResolved"
}

$metadataPathResolved = Resolve-GeneXusKbSourceMetadataPath -KbMetadataPath $KbMetadataPath -ParallelKbRoot $ParallelKbRoot
$fields = $null
if ($metadataPathResolved) {
    $fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $metadataPathResolved
}

$validationEnvironment = $EnvironmentName
if ([string]::IsNullOrWhiteSpace($validationEnvironment) -and $null -ne $fields) {
    $validationEnvironment = $fields.deployment_environment_name
}

$hostingKind = $DeploymentHostingKind
if ([string]::IsNullOrWhiteSpace($hostingKind) -and $null -ne $fields) {
    $hostingKind = $fields.deployment_hosting_kind
}

try {
    $buildStartedAtDt = [DateTimeOffset]::Parse($BuildStartedAt)
}
catch {
    throw "BuildStartedAt nao e timestamp valido: '$BuildStartedAt'"
}

$result = [ordered]@{
    status                    = 'skipped'
    validationEnvironmentName = $validationEnvironment
    deploymentHostingKind     = $hostingKind
    metadataPath              = $metadataPathResolved
    buildStartedAt            = $buildStartedAtDt.ToString('o')
    deployBinCheck            = $null
    summary                   = ''
}

if ([string]::IsNullOrWhiteSpace($validationEnvironment)) {
    $result.summary = 'Environment de deploy nao informado e deployment_environment_name ausente no metadata.'
}
elseif ([string]::IsNullOrWhiteSpace($hostingKind)) {
    $result.summary = 'deployment_hosting_kind ausente; gravar via xpz-kb-parallel-setup.'
}
elseif ($hostingKind -notin @('dotnet-core-self-host', 'dotnet-framework-iis')) {
    $result.summary = "deployment_hosting_kind invalido: $hostingKind"
}
else {
    $freshness = Test-GeneXusKbDeployBinFreshnessCore `
        -KbPath $kbPathResolved `
        -EnvironmentName $validationEnvironment `
        -DeploymentHostingKind $hostingKind `
        -BuildStartedAt $buildStartedAtDt `
        -MetadataPath $metadataPathResolved

    $result.status = $freshness.status
    $result.deployBinCheck = [ordered]@{
        paths           = $freshness.paths
        binCheck        = $freshness.binCheck
        diagnosticLayer = $freshness.diagnosticLayer
        interpretation  = $freshness.interpretation
        thresholdAt     = $freshness.thresholdAt
    }
    $result.summary = $freshness.interpretation
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
}
else {
    Write-Output ("deploy-bin-{0}: env={1} hosting={2} — {3}" -f $result.status, $validationEnvironment, $hostingKind, $result.summary)
}
