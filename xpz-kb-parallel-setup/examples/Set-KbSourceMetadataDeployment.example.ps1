#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local para gravar campos de environment/deploy em kb-source-metadata.md.

.DESCRIPTION
Delega a scripts/Set-XpzKbSourceMetadataDeployment.ps1 no repositorio GeneXus-XPZ-Skills.
A lista kb_environment_names vem SOMENTE de -KbEnvironmentNames confirmada pelo usuario.
O mapeamento de output por environment vem SOMENTE de -KbEnvironmentOutputDirs confirmado
pelo usuario; nao fazer scan de pastas da KB nativa.
Por padrao valida cada nome via SetActiveEnvironment headless (MSBuild).

.EXAMPLE
.\Set-KbSourceMetadataDeployment.ps1 `
    -KbParallelRoot "C:\Dev\Prod\Gx_FabricaBrasil" `
    -DeploymentEnvironmentName "NETPostgreSQL" `
    -DeploymentHostingKind "dotnet-core-self-host" `
    -KbEnvironmentNames @("NETPostgreSQL", ".Net Environment") `
    -KbEnvironmentOutputDirs @("NETPostgreSQL=NETPostgreSQL", ".Net Environment=NETFrameworkPostgreSQL") `
    -KbNativePath "C:\GxModels\FabricaBrasil18" `
    -InventoryWorkingDirectory "C:\Dev\Prod\Gx_FabricaBrasil\Temp\msbuild-inventory"
#>

param(
    [string]$KbParallelRoot,

    [string]$MetadataPath,

    [Parameter(Mandatory = $true)]
    [string]$DeploymentEnvironmentName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('dotnet-core-self-host', 'dotnet-framework-iis')]
    [string]$DeploymentHostingKind,

    [Parameter(Mandatory = $true)]
    [string[]]$KbEnvironmentNames,

    [Parameter(Mandatory = $true)]
    [string[]]$KbEnvironmentOutputDirs,

    [string[]]$KbEnvironmentWebDirs,

    [string]$KbNativePath,

    [string]$InventoryWorkingDirectory,

    [string]$InventoryLogPath,

    [switch]$SkipEnvironmentNamesMsBuildValidation,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string]$DatabaseUser,

    [string]$DatabasePassword,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$skillsRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$engineScript = Join-Path $skillsRoot 'scripts\Set-XpzKbSourceMetadataDeployment.ps1'

if (-not (Test-Path -LiteralPath $engineScript -PathType Leaf)) {
    throw "Motor compartilhado ausente: $engineScript"
}

$invokeArgs = @{
    DeploymentEnvironmentName = $DeploymentEnvironmentName
    DeploymentHostingKind     = $DeploymentHostingKind
    KbEnvironmentNames        = $KbEnvironmentNames
    KbEnvironmentOutputDirs   = $KbEnvironmentOutputDirs
}
if ($KbParallelRoot) { $invokeArgs['KbParallelRoot'] = $KbParallelRoot }
if ($MetadataPath) { $invokeArgs['MetadataPath'] = $MetadataPath }
if ($KbEnvironmentWebDirs) { $invokeArgs['KbEnvironmentWebDirs'] = $KbEnvironmentWebDirs }
if ($KbNativePath) { $invokeArgs['KbNativePath'] = $KbNativePath }
if ($InventoryWorkingDirectory) { $invokeArgs['InventoryWorkingDirectory'] = $InventoryWorkingDirectory }
if ($InventoryLogPath) { $invokeArgs['InventoryLogPath'] = $InventoryLogPath }
if ($SkipEnvironmentNamesMsBuildValidation.IsPresent) { $invokeArgs['SkipEnvironmentNamesMsBuildValidation'] = $true }
if ($GeneXusDir) { $invokeArgs['GeneXusDir'] = $GeneXusDir }
if ($MsBuildPath) { $invokeArgs['MsBuildPath'] = $MsBuildPath }
if ($DatabaseUser) { $invokeArgs['DatabaseUser'] = $DatabaseUser }
if ($DatabasePassword) { $invokeArgs['DatabasePassword'] = $DatabasePassword }
if ($AsJson.IsPresent) { $invokeArgs['AsJson'] = $true }

& $engineScript @invokeArgs
exit $LASTEXITCODE
