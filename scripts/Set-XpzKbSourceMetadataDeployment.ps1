#requires -Version 7.4
<#
.SYNOPSIS
    Grava campos de environment/deploy em kb-source-metadata.md (autoridade: xpz-kb-parallel-setup).

.DESCRIPTION
    Atualiza ou insere deployment_environment_name, deployment_hosting_kind,
    kb_environment_count e kb_environment_names no frontmatter, preservando o restante do arquivo.

    Inventario da KB nativa (pastas com web\) so ocorre quando -InventoryFromKbNativePath
    for passado explicitamente nesta rotina de setup — nunca em build/import.

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB.

.PARAMETER MetadataPath
    Caminho explicito para kb-source-metadata.md (prevalece sobre KbParallelRoot).

.PARAMETER DeploymentEnvironmentName
    Identificador MSBuild do environment de validacao/deploy (ex.: NETPostgreSQL).

.PARAMETER DeploymentHostingKind
    Tipo de hospedagem do environment de deploy: dotnet-core-self-host ou dotnet-framework-iis.

.PARAMETER KbEnvironmentNames
    Lista de nomes de environments conhecidos na KB.

.PARAMETER InventoryFromKbNativePath
    Quando presente, enumera subpastas de KbNativePath que contem web\ e usa como KbEnvironmentNames.

.PARAMETER KbNativePath
    Caminho da KB nativa GeneXus (ex.: C:\GxModels\FabricaBrasil18). Obrigatorio com -InventoryFromKbNativePath.

.PARAMETER AsJson
    Emite JSON em vez de texto simples.
#>

[CmdletBinding()]
param(
    [string]$KbParallelRoot,

    [string]$MetadataPath,

    [Parameter(Mandatory = $true)]
    [string]$DeploymentEnvironmentName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('dotnet-core-self-host', 'dotnet-framework-iis')]
    [string]$DeploymentHostingKind,

    [string[]]$KbEnvironmentNames,

    [switch]$InventoryFromKbNativePath,

    [string]$KbNativePath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($MetadataPath)) {
    if ([string]::IsNullOrWhiteSpace($KbParallelRoot)) {
        throw 'BLOCK: informe -KbParallelRoot ou -MetadataPath.'
    }
    $MetadataPath = Join-Path $KbParallelRoot 'kb-source-metadata.md'
}

$MetadataPath = [System.IO.Path]::GetFullPath($MetadataPath)

if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
    throw "BLOCK: kb-source-metadata.md ausente: $MetadataPath"
}

$deploymentName = $DeploymentEnvironmentName.Trim()
if ($deploymentName.Length -eq 0) {
    throw 'BLOCK: DeploymentEnvironmentName vazio.'
}

$hostingKind = $DeploymentHostingKind.Trim()
if ($hostingKind.Length -eq 0) {
    throw 'BLOCK: DeploymentHostingKind vazio.'
}

$environmentNames = New-Object System.Collections.Generic.List[string]

if ($InventoryFromKbNativePath.IsPresent) {
    if ([string]::IsNullOrWhiteSpace($KbNativePath)) {
        throw 'BLOCK: -InventoryFromKbNativePath exige -KbNativePath.'
    }

    $nativeRoot = [System.IO.Path]::GetFullPath($KbNativePath)
    if (-not (Test-Path -LiteralPath $nativeRoot -PathType Container)) {
        throw "BLOCK: KbNativePath invalido: $nativeRoot"
    }

    foreach ($child in Get-ChildItem -LiteralPath $nativeRoot -Directory) {
        $webPath = Join-Path $child.FullName 'web'
        if (Test-Path -LiteralPath $webPath -PathType Container) {
            $environmentNames.Add($child.Name) | Out-Null
        }
    }

    if ($environmentNames.Count -eq 0) {
        throw "BLOCK: nenhum environment com pasta web\ encontrado em $nativeRoot"
    }
} elseif ($KbEnvironmentNames -and $KbEnvironmentNames.Count -gt 0) {
    foreach ($name in $KbEnvironmentNames) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $environmentNames.Add($name.Trim()) | Out-Null
        }
    }
} else {
    throw 'BLOCK: informe -KbEnvironmentNames ou -InventoryFromKbNativePath com -KbNativePath.'
}

$nameSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($name in $environmentNames) {
    [void]$nameSet.Add($name)
}

if (-not $nameSet.Contains($deploymentName)) {
    throw ("BLOCK: DeploymentEnvironmentName '{0}' nao consta na lista de environments ({1})." -f $deploymentName, ($environmentNames -join ', '))
}

$count = $environmentNames.Count
$namesJoined = ($environmentNames | Sort-Object) -join ', '

. (Join-Path $PSScriptRoot 'XpzTextFileEolSupport.ps1')

$fieldsToWrite = [ordered]@{
    deployment_environment_name = $deploymentName
    deployment_hosting_kind     = $hostingKind
    kb_environment_count        = [string]$count
    kb_environment_names        = $namesJoined
}

$fileContext = Get-TextFileLineContext -Path $MetadataPath
$fileLines = [System.Collections.Generic.List[string]]::new()
$fileLines.AddRange([string[]]$fileContext.Lines)

foreach ($fieldName in $fieldsToWrite.Keys) {
    $newLine = '{0}: {1}' -f $fieldName, $fieldsToWrite[$fieldName]
    $fieldPattern = '^\s*{0}\s*[:=]\s*.+$' -f [regex]::Escape($fieldName)
    $updated = $false
    for ($i = 0; $i -lt $fileLines.Count; $i++) {
        if ($fileLines[$i] -match $fieldPattern) {
            $fileLines[$i] = $newLine
            $updated = $true
            break
        }
    }

    if (-not $updated) {
        $insertAt = -1
        for ($i = 0; $i -lt $fileLines.Count; $i++) {
            if ($fileLines[$i] -match '^\s*---\s*$') {
                $insertAt = $i
                break
            }
        }

        if ($insertAt -ge 0) {
            $fileLines.Insert($insertAt, $newLine)
        } else {
            $fileLines.Insert(0, $newLine)
        }
    }
}

Write-TextFilePreservingEol -Path $MetadataPath -Lines $fileLines.ToArray() -DominantEol $fileContext.DominantEol -HadTrailingNewline $fileContext.HadTrailingNewline

$result = [ordered]@{
    status                        = 'KB_DEPLOYMENT_METADATA_OK'
    metadataPath                  = $MetadataPath
    deployment_environment_name   = $deploymentName
    deployment_hosting_kind       = $hostingKind
    kb_environment_count          = $count
    kb_environment_names          = @($environmentNames | Sort-Object)
    inventoryFromKbNativePath     = $InventoryFromKbNativePath.IsPresent
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 4
} else {
    Write-Output "KB_DEPLOYMENT_METADATA_OK: deployment=$deploymentName count=$count names=$namesJoined"
}
