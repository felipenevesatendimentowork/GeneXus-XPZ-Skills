#requires -Version 7.4
<#
.SYNOPSIS
    Grava campos de environment/deploy em kb-source-metadata.md (autoridade: xpz-kb-parallel-setup).

.DESCRIPTION
    Atualiza ou insere deployment_environment_name, deployment_hosting_kind,
    kb_environment_count e kb_environment_names no frontmatter, preservando o restante do arquivo.

    Inventario de environments ocorre somente no setup via -InventoryFromGeneXusMsBuild
    (validacao SetActiveEnvironment) ou -KbEnvironmentNames explicito — nunca por pastas com web\.

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB.

.PARAMETER MetadataPath
    Caminho explicito para kb-source-metadata.md (prevalece sobre KbParallelRoot).

.PARAMETER DeploymentEnvironmentName
    Identificador MSBuild do environment de validacao/deploy (ex.: NETPostgreSQL).

.PARAMETER DeploymentHostingKind
    Tipo de hospedagem do environment de deploy: dotnet-core-self-host ou dotnet-framework-iis.

.PARAMETER KbEnvironmentNames
    Lista explicita de environments (excecao quando MSBuild indisponivel no setup).

.PARAMETER InventoryFromGeneXusMsBuild
    Inventaria environments registrados na KB via SetActiveEnvironment headless.

.PARAMETER InventoryFromKbNativePath
    REMOVIDO — emite BLOCK (heuristica web\ incluia CSharpModel, Data* e pastas legadas).

.PARAMETER KbNativePath
    Caminho da KB nativa GeneXus. Obrigatorio com -InventoryFromGeneXusMsBuild.

.PARAMETER InventoryWorkingDirectory
    Diretorio de trabalho para probe/inventario MSBuild. Obrigatorio com -InventoryFromGeneXusMsBuild.

.PARAMETER InventoryLogPath
    Log JSON opcional do probe MSBuild do inventario.

.PARAMETER GeneXusDir
    Instalacao GeneXus (opcional — resolvida pelo probe).

.PARAMETER MsBuildPath
    Caminho do MSBuild.exe (opcional — resolvido pelo probe).

.PARAMETER DatabaseUser
    Usuario de banco para abertura headless do inventario (opcional).

.PARAMETER DatabasePassword
    Senha de banco para abertura headless do inventario (opcional).

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

    [switch]$InventoryFromGeneXusMsBuild,

    [switch]$InventoryFromKbNativePath,

    [string]$KbNativePath,

    [string]$InventoryWorkingDirectory,

    [string]$InventoryLogPath,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string]$DatabaseUser,

    [string]$DatabasePassword,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($InventoryFromKbNativePath.IsPresent) {
    throw @'
BLOCK: -InventoryFromKbNativePath foi removido. Pastas com web\ na KB nativa incluem legado (CSharpModel, Data*, backups de environment) e nao representam a lista de environments GeneXus. Use -InventoryFromGeneXusMsBuild com -KbNativePath e -InventoryWorkingDirectory, ou -KbEnvironmentNames explicito como excecao documentada.
'@
}

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
$inventoryFromGeneXusMsBuild = $false
$inventoryExcludedNativeFolders = @()

if ($InventoryFromGeneXusMsBuild.IsPresent) {
    if ([string]::IsNullOrWhiteSpace($KbNativePath)) {
        throw 'BLOCK: -InventoryFromGeneXusMsBuild exige -KbNativePath.'
    }
    if ([string]::IsNullOrWhiteSpace($InventoryWorkingDirectory)) {
        throw 'BLOCK: -InventoryFromGeneXusMsBuild exige -InventoryWorkingDirectory.'
    }

    . (Join-Path $PSScriptRoot 'GeneXusKbEnvironmentInventorySupport.ps1')

    $inventoryResult = Get-GeneXusKbRegisteredEnvironmentNamesFromMsBuild `
        -KbNativePath $KbNativePath `
        -WorkingDirectory $InventoryWorkingDirectory `
        -LogPath $InventoryLogPath `
        -GeneXusDir $GeneXusDir `
        -MsBuildPath $MsBuildPath `
        -DatabaseUser $DatabaseUser `
        -DatabasePassword $DatabasePassword

    foreach ($name in $inventoryResult.kb_environment_names) {
        $environmentNames.Add($name) | Out-Null
    }

    $inventoryFromGeneXusMsBuild = $true
    $inventoryExcludedNativeFolders = @($inventoryResult.excludedNativeFolders)
} elseif ($KbEnvironmentNames -and $KbEnvironmentNames.Count -gt 0) {
    foreach ($name in $KbEnvironmentNames) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $environmentNames.Add($name.Trim()) | Out-Null
        }
    }
} else {
    throw 'BLOCK: informe -InventoryFromGeneXusMsBuild (-KbNativePath e -InventoryWorkingDirectory) ou -KbEnvironmentNames explicito.'
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
$fileLines = $fileContext.Lines

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
        $frontmatterClose = -1
        $hasFrontmatter = ($fileLines.Count -gt 0 -and $fileLines[0].Trim() -eq '---')

        if ($hasFrontmatter) {
            for ($i = 1; $i -lt $fileLines.Count; $i++) {
                if ($fileLines[$i].Trim() -eq '---') {
                    $frontmatterClose = $i
                    break
                }
            }

            if ($frontmatterClose -gt 0) {
                $insertAt = $frontmatterClose
            }
        } else {
            for ($i = 0; $i -lt $fileLines.Count; $i++) {
                if ($fileLines[$i] -match '^\s*##\s+') {
                    $insertAt = $i
                    break
                }
            }

            if ($insertAt -lt 0) {
                $insertAt = $fileLines.Count
            }
        }

        if ($insertAt -lt 0) {
            $insertAt = 0
        }

        $fileLines.Insert($insertAt, $newLine)
    }
}

Write-TextFilePreservingEol -Path $MetadataPath -FileContext $fileContext

$result = [ordered]@{
    status                        = 'KB_DEPLOYMENT_METADATA_OK'
    metadataPath                  = $MetadataPath
    deployment_environment_name   = $deploymentName
    deployment_hosting_kind       = $hostingKind
    kb_environment_count          = $count
    kb_environment_names          = @($environmentNames | Sort-Object)
    inventoryFromGeneXusMsBuild   = $inventoryFromGeneXusMsBuild
    inventoryExcludedNativeFolders = $inventoryExcludedNativeFolders
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "KB_DEPLOYMENT_METADATA_OK: deployment=$deploymentName count=$count names=$namesJoined"
}
