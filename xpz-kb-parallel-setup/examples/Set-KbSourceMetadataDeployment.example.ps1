#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local para gravar campos de environment/deploy em kb-source-metadata.md.

.DESCRIPTION
Delega a scripts/Set-XpzKbSourceMetadataDeployment.ps1 no repositorio GeneXus-XPZ-Skills.
Inventario de environments na KB nativa (-InventoryFromKbNativePath) ocorre somente nesta
rotina de setup — nao em build/import.

.EXAMPLE
.\Set-KbSourceMetadataDeployment.ps1 `
    -KbParallelRoot "C:\Dev\Prod\Gx_FabricaBrasil" `
    -DeploymentEnvironmentName "NETPostgreSQL" `
    -InventoryFromKbNativePath `
    -KbNativePath "C:\GxModels\FabricaBrasil18"
#>

param(
    [string]$KbParallelRoot,

    [string]$MetadataPath,

    [Parameter(Mandatory = $true)]
    [string]$DeploymentEnvironmentName,

    [string[]]$KbEnvironmentNames,

    [switch]$InventoryFromKbNativePath,

    [string]$KbNativePath,

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
}
if ($KbParallelRoot) { $invokeArgs['KbParallelRoot'] = $KbParallelRoot }
if ($MetadataPath) { $invokeArgs['MetadataPath'] = $MetadataPath }
if ($KbEnvironmentNames) { $invokeArgs['KbEnvironmentNames'] = $KbEnvironmentNames }
if ($InventoryFromKbNativePath.IsPresent) { $invokeArgs['InventoryFromKbNativePath'] = $true }
if ($KbNativePath) { $invokeArgs['KbNativePath'] = $KbNativePath }
if ($AsJson.IsPresent) { $invokeArgs['AsJson'] = $true }

& $engineScript @invokeArgs
