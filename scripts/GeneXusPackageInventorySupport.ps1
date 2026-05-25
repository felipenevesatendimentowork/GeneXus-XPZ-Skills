#requires -Version 7.4
<#
.SYNOPSIS
    Funcoes compartilhadas para inventario de pacote import_file.xml / .xpz.

.DESCRIPTION
    Produz packageInventory resumido e sidecar JSON a partir de
    Get-GeneXusImportPackageObjectInventory.ps1. Consumido por
    Build-GeneXusImportFileEnvelope.ps1, New-XpzImportPackage.ps1 e pelo export
    MSBuild via GeneXusXpzExportInventoryGovernance.ps1 (governanca de sub-estado
    permanece no modulo de export, nao neste arquivo).
#>

Set-StrictMode -Version Latest

function Get-GeneXusCatalogMap {
    param([string]$CatalogPath)

    if (-not $CatalogPath) {
        $CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
    }
    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
        throw "BLOCK: CatalogPath nao encontrado: $CatalogPath"
    }

    $rawCatalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8
    $catalog = $rawCatalog | ConvertFrom-Json
    $map = @{}
    foreach ($property in $catalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.objectTypeGuid -or [string]::IsNullOrWhiteSpace([string]$entry.objectTypeGuid)) {
            continue
        }
        $map[[string]$entry.objectTypeGuid.ToLowerInvariant()] = [string]$property.Name
    }
    return $map
}

function Get-TypeNameFromObjectElement {
    param(
        [System.Xml.XmlElement]$ObjectElement,
        [hashtable]$GuidMap
    )

    $rawTypeGuid = $ObjectElement.GetAttribute('type')
    if (-not [string]::IsNullOrWhiteSpace($rawTypeGuid)) {
        $typeKey = $rawTypeGuid.ToLowerInvariant()
        if ($GuidMap.ContainsKey($typeKey)) {
            return $GuidMap[$typeKey]
        }
    }
    return $null
}

function Test-ObjectMatchesModifiedFilter {
    param(
        [System.Xml.XmlElement]$ObjectElement,
        [System.Collections.Generic.HashSet[string]]$ModifiedNames,
        [System.Collections.Generic.HashSet[string]]$ModifiedGuids
    )

    if ($ModifiedNames.Count -eq 0 -and $ModifiedGuids.Count -eq 0) {
        return $true
    }

    $name = $ObjectElement.GetAttribute('name')
    $fqn = $ObjectElement.GetAttribute('fullyQualifiedName')
    $guid = $ObjectElement.GetAttribute('guid')
    if (-not [string]::IsNullOrWhiteSpace($name) -and $ModifiedNames.Contains($name)) {
        return $true
    }
    if (-not [string]::IsNullOrWhiteSpace($fqn) -and $ModifiedNames.Contains($fqn)) {
        return $true
    }
    if (-not [string]::IsNullOrWhiteSpace($guid) -and $ModifiedGuids.Contains($guid)) {
        return $true
    }
    return $false
}

function ConvertTo-DeclaredDeltaItemsFromObjectDocuments {
    param(
        [System.Xml.XmlDocument[]]$ObjectDocuments,
        [string[]]$ModifiedObjectNames,
        [string[]]$ModifiedObjectGuids,
        [string]$CatalogPath
    )

    $guidMap = Get-GeneXusCatalogMap -CatalogPath $CatalogPath
    $modifiedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $modifiedGuids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($ModifiedObjectNames)) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            [void]$modifiedNames.Add($entry.Trim())
        }
    }
    foreach ($entry in @($ModifiedObjectGuids)) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            [void]$modifiedGuids.Add($entry.Trim())
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($doc in @($ObjectDocuments)) {
        $root = $doc.DocumentElement
        if ($null -eq $root -or $root.LocalName -ne 'Object') {
            continue
        }
        if (-not (Test-ObjectMatchesModifiedFilter -ObjectElement $root -ModifiedNames $modifiedNames -ModifiedGuids $modifiedGuids)) {
            continue
        }
        $typeName = Get-TypeNameFromObjectElement -ObjectElement $root -GuidMap $guidMap
        $name = $root.GetAttribute('name')
        if ([string]::IsNullOrWhiteSpace($typeName) -or [string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        $lines.Add(('{0}:{1}' -f $typeName, $name)) | Out-Null
    }

    return ($lines | Sort-Object -Unique) -join ';'
}

function Get-DeclaredDeltaItemsFromFrontObjectXmls {
    param(
        [Parameter(Mandatory = $true)][string]$FrontDir,
        [string]$CatalogPath
    )

    $guidMap = Get-GeneXusCatalogMap -CatalogPath $CatalogPath
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $FrontDir -Filter '*.xml' -File -ErrorAction SilentlyContinue)) {
        $doc = New-Object System.Xml.XmlDocument
        $doc.PreserveWhitespace = $true
        try {
            $doc.Load($file.FullName)
        } catch {
            continue
        }
        if ($doc.DocumentElement.LocalName -ne 'Object') {
            continue
        }
        $typeName = Get-TypeNameFromObjectElement -ObjectElement $doc.DocumentElement -GuidMap $guidMap
        $name = $doc.DocumentElement.GetAttribute('name')
        if ([string]::IsNullOrWhiteSpace($typeName) -or [string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        $lines.Add(('{0}:{1}' -f $typeName, $name)) | Out-Null
    }
    return ($lines | Sort-Object -Unique) -join ';'
}

function New-PackageInventoryResult {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [string]$DeclaredDeltaItems,
        [string]$SidecarInventoryPath
    )

    $inventoryScriptPath = Join-Path $PSScriptRoot 'Get-GeneXusImportPackageObjectInventory.ps1'
    $result = [ordered]@{
        inventoryDegraded    = $true
        inventoryError       = $null
        packageInventory     = $null
        packageInventoryPath = $SidecarInventoryPath
    }

    if (-not (Test-Path -LiteralPath $inventoryScriptPath -PathType Leaf)) {
        $result.inventoryError = "Script de inventario nao encontrado: $inventoryScriptPath"
        return [pscustomobject]$result
    }
    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        $result.inventoryError = "Pacote nao encontrado para inventario: $InputPath"
        return [pscustomobject]$result
    }

    try {
        $invokeParams = @{
            InputPath = $InputPath
            AsJson    = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($DeclaredDeltaItems)) {
            $invokeParams['DeclaredDeltaItems'] = $DeclaredDeltaItems
        }

        $inventory = (& $inventoryScriptPath @invokeParams | ConvertFrom-Json)
        $namedItems = [System.Collections.Generic.List[pscustomobject]]::new()
        foreach ($item in @($inventory.inventory)) {
            $namedItems.Add([pscustomobject]@{
                sourceBlock = $item.sourceBlock
                typeName    = $item.typeName
                name        = $item.name
                guid        = $item.guid
            }) | Out-Null
        }

        if (-not [string]::IsNullOrWhiteSpace($SidecarInventoryPath)) {
            $sidecarDir = Split-Path -Parent $SidecarInventoryPath
            if (-not [string]::IsNullOrWhiteSpace($sidecarDir) -and -not (Test-Path -LiteralPath $sidecarDir)) {
                [void](New-Item -ItemType Directory -Path $sidecarDir -Force)
            }
            $fullInventoryDoc = [ordered]@{
                inputPath      = $inventory.inputPath
                inputKind      = $inventory.inputKind
                innerXmlEntry  = $inventory.innerXmlEntry
                objectCount    = $inventory.objectCount
                attributeCount = $inventory.attributeCount
                items          = @($namedItems)
            }
            $encoding = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText(
                $SidecarInventoryPath,
                (($fullInventoryDoc | ConvertTo-Json -Depth 6) + [Environment]::NewLine),
                $encoding)
            $result.packageInventoryPath = $SidecarInventoryPath
        }

        $objectsByType = @{}
        if ($null -ne $inventory.objectsByType) {
            foreach ($prop in $inventory.objectsByType.PSObject.Properties) {
                $objectsByType[$prop.Name] = [int]$prop.Value
            }
        }

        $summary = [ordered]@{
            inventoryStatus                = $inventory.status
            selectiveExport                = [bool]$inventory.selectiveExport
            totalObjects                   = [int]$inventory.objectCount
            totalAttributes                = [int]$inventory.attributeCount
            objectsByType                  = $objectsByType
            systemModulesPresent           = @($inventory.systemModulesPresent)
            systemExternalObjectsPresent   = @($inventory.systemExternalObjectsPresent)
            declaredIncludesTransaction    = [bool]$inventory.declaredIncludesTransaction
            attributesTopLevelUnreconciled = [bool]$inventory.attributesTopLevelUnreconciled
            packageInventoryPath           = $result.packageInventoryPath
        }
        if (@($inventory.warnings).Count -gt 0) {
            $summary.inventoryWarnings = @($inventory.warnings)
        }

        if ($summary.selectiveExport -and $null -ne $inventory.deltaComparison) {
            $delta = $inventory.deltaComparison
            $summary.requestedItemsFound = @($delta.requestedItemsFound | ForEach-Object {
                if ($null -ne $_.typeName -and $null -ne $_.name) { '{0}:{1}' -f $_.typeName, $_.name }
            })
            $summary.requestedItemsMissing = @($delta.requestedItemsMissing | ForEach-Object {
                if ($null -ne $_.typeName -and $null -ne $_.name) { '{0}:{1}' -f $_.typeName, $_.name }
            })
            $summary.extrasCount = [int]$delta.extraCount
            $summary.deltaStatus = [string]$delta.status
            $extrasLines = @($delta.extraObjects | ForEach-Object {
                if ($null -ne $_.typeName -and $null -ne $_.name) { '{0}:{1}' -f $_.typeName, $_.name }
            })
            if ($summary.extrasCount -le 50) {
                $summary.extrasSample = @($extrasLines)
            } else {
                $summary.extrasSample = @()
                $summary.extrasSampleTruncated = $true
                $summary.extrasFullListAt = $result.packageInventoryPath
            }
        }

        $result.inventoryDegraded = $false
        $result.inventoryError = $null
        $result.packageInventory = [pscustomobject]$summary
        return [pscustomobject]$result
    } catch {
        $result.inventoryError = $_.Exception.Message
        return [pscustomobject]$result
    }
}
