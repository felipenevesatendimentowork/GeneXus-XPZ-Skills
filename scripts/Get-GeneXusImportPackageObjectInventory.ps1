#requires -Version 7.4
<#
.SYNOPSIS
Inventaria objetos efetivamente presentes em import_file.xml ou pacote .xpz GeneXus.

.DESCRIPTION
Le um envelope GeneXus com raiz <ExportFile> (XML direto ou XML interno em .xpz),
lista os objetos sob <Objects> e atributos top-level sob <Attributes>, mapeia GUIDs
de tipo pelo catalogo compartilhado quando possivel e, opcionalmente, confronta o
inventario de objetos com um delta declarado em texto Tipo:Nome.

.PARAMETER InputPath
Caminho do import_file.xml, XML equivalente com raiz <ExportFile> ou pacote .xpz.

.PARAMETER DeclaredDeltaPath
Arquivo texto opcional com o delta esperado, uma entrada por linha no formato Tipo:Nome.

.PARAMETER DeclaredDeltaItems
Lista inline opcional no formato Tipo:Nome separada por ponto-e-virgula (;) ou quebra
de linha. Ignorada quando DeclaredDeltaPath estiver informado.

.PARAMETER CatalogPath
Caminho opcional para gx-object-type-catalog.json.

.PARAMETER SystemModulesCatalogPath
Caminho opcional para gx-system-modules.txt (modulos de plataforma/SDK).

.PARAMETER SystemExternalObjectsCatalogPath
Caminho opcional para gx-system-external-objects.txt (ExternalObjects de plataforma/SDK).

.PARAMETER FailOnDeltaMismatch
Quando informado junto com delta declarado, retorna exit code 2 se houver objetos
extras ou ausentes na comparacao seletiva (somente bloco Objects).

.PARAMETER AsJson
Emite JSON estruturado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$DeclaredDeltaPath,

    [string]$DeclaredDeltaItems,

    [string]$CatalogPath,

    [string]$SystemModulesCatalogPath,

    [string]$SystemExternalObjectsCatalogPath,

    [switch]$FailOnDeltaMismatch,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CatalogMap {
    param([string]$Path)

    $rawCatalog = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $catalog = $rawCatalog | ConvertFrom-Json
    $map = @{}

    foreach ($property in $catalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.objectTypeGuid -or [string]::IsNullOrWhiteSpace([string]$entry.objectTypeGuid)) {
            continue
        }

        $map[[string]$entry.objectTypeGuid.ToLowerInvariant()] = [pscustomobject]@{
            typeName   = [string]$property.Name
            folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
                [string]$entry.folderName
            } else {
                [string]$property.Name
            }
        }
    }

    return $map
}

function Get-SystemModuleNameSet {
    param([string]$Path)

    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }
        [void]$set.Add($trimmed)
    }
    return $set
}

function Get-IdentityKey {
    param(
        [string]$TypeName,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($TypeName) -or [string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    return ('{0}:{1}' -f $TypeName.Trim(), $Name.Trim()).ToLowerInvariant()
}

function Read-DeclaredDeltaLines {
    param([string[]]$Lines)

    $items = [System.Collections.Generic.List[pscustomobject]]::new()
    $lineNumber = 0
    foreach ($line in $Lines) {
        $lineNumber += 1
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $parts = @($trimmed -split '[:|	]', 2)
        if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
            throw ("BLOCK: entrada fora do formato Tipo:Nome (linha {0}): {1}" -f $lineNumber, $trimmed)
        }

        $typeName = $parts[0].Trim()
        $name = $parts[1].Trim()
        $items.Add([pscustomobject]@{
            typeName = $typeName
            name     = $name
            key      = Get-IdentityKey -TypeName $typeName -Name $name
            source   = ('line {0}' -f $lineNumber)
        }) | Out-Null
    }

    return @($items)
}

function Read-DeclaredDeltaFromPath {
    param([string]$Path)
    return @(Read-DeclaredDeltaLines -Lines @(Get-Content -LiteralPath $Path -Encoding UTF8))
}

function Read-DeclaredDeltaFromItems {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $normalized = $Text -replace ';', "`n"
    $lines = @($normalized -split "`r?`n")
    return @(Read-DeclaredDeltaLines -Lines $lines)
}

function Get-ExportFileXmlDocument {
    param([string]$Path)

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()

    if ($extension -eq '.xpz' -or $extension -eq '.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $candidates = [System.Collections.Generic.List[System.Xml.XmlDocument]]::new()
        $candidateNames = [System.Collections.Generic.List[string]]::new()
        $zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedPath)
        try {
            foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '\.xml$' } | Sort-Object FullName)) {
                $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
                try {
                    $entryText = $reader.ReadToEnd()
                } finally {
                    $reader.Dispose()
                }

                $candidateDoc = New-Object System.Xml.XmlDocument
                try {
                    $candidateDoc.PreserveWhitespace = $true
                    $candidateDoc.LoadXml($entryText)
                } catch {
                    continue
                }

                if ($candidateDoc.DocumentElement.LocalName -eq 'ExportFile') {
                    $candidates.Add($candidateDoc) | Out-Null
                    $candidateNames.Add($entry.FullName) | Out-Null
                }
            }
        } finally {
            $zip.Dispose()
        }

        if ($candidates.Count -eq 0) {
            throw "BLOCK: pacote .xpz nao contem XML com raiz ExportFile: $resolvedPath"
        }
        if ($candidates.Count -gt 1) {
            $names = ($candidateNames -join ', ')
            throw ("BLOCK: pacote .xpz contem {0} candidatos ExportFile ambiguos ({1}); informe XML descompactado." -f $candidates.Count, $names)
        }

        return [pscustomobject]@{
            Document     = $candidates[0]
            ResolvedPath = $resolvedPath
            InputKind    = 'xpz'
            InnerXmlName = $candidateNames[0]
        }
    }

    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.Load($resolvedPath)
    return [pscustomobject]@{
        Document     = $document
        ResolvedPath = $resolvedPath
        InputKind    = 'xml'
        InnerXmlName = $null
    }
}

function New-InventoryItem {
    param(
        [System.Xml.XmlElement]$Node,
        [hashtable]$GuidMap,
        [string]$SourceBlock,
        [int]$Index
    )

    $rootKind = $Node.LocalName
    $rawTypeGuid = $Node.GetAttribute('type')
    $name = $Node.GetAttribute('name')
    $guid = $Node.GetAttribute('guid')
    $typeName = $null
    $typeStatus = 'unknown'

    if ($rootKind -eq 'Attribute') {
        $typeName = 'Attribute'
        $typeStatus = 'root-kind'
    } elseif (-not [string]::IsNullOrWhiteSpace($rawTypeGuid)) {
        $typeKey = $rawTypeGuid.ToLowerInvariant()
        if ($GuidMap.ContainsKey($typeKey)) {
            $typeName = $GuidMap[$typeKey].typeName
            $typeStatus = 'mapped'
        }
    }

    $identityKey = Get-IdentityKey -TypeName $typeName -Name $name

    return [pscustomobject]@{
        index       = $Index
        sourceBlock = $SourceBlock
        rootKind    = $rootKind
        type        = $typeName
        typeName    = $typeName
        typeGuid    = if ([string]::IsNullOrWhiteSpace($rawTypeGuid)) { $null } else { $rawTypeGuid }
        typeStatus  = $typeStatus
        name        = if ([string]::IsNullOrWhiteSpace($name)) { $null } else { $name }
        guid        = if ([string]::IsNullOrWhiteSpace($guid)) { $null } else { $guid }
        identityKey = $identityKey
    }
}

function Get-ObjectsByTypeMap {
    param($InventoryItems)

    $map = [ordered]@{}
    foreach ($item in @($InventoryItems | Where-Object { $_.sourceBlock -eq 'Objects' -and -not [string]::IsNullOrWhiteSpace($_.typeName) })) {
        $key = [string]$item.typeName
        if ($map.Contains($key)) {
            $map[$key] = [int]$map[$key] + 1
        } else {
            $map[$key] = 1
        }
    }
    return $map
}

function Test-IsPlatformModuleInventoryItem {
    param($Item)

    if ($Item.sourceBlock -ne 'Objects' -or [string]::IsNullOrWhiteSpace($Item.name)) {
        return $false
    }

    # Export real GeneXus 18 traz SDK/plataforma como PackagedModule (GUID c88fffcd-...).
    # Module (GUID 00000000-...-000006) e container de KB do usuario.
    return $Item.typeName -eq 'Module' -or $Item.typeName -eq 'PackagedModule'
}

function Get-SystemModulesPresent {
    param(
        $InventoryItems,
        [System.Collections.Generic.HashSet[string]]$SystemModuleNames
    )

    $found = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($InventoryItems | Where-Object { Test-IsPlatformModuleInventoryItem -Item $_ })) {
        if ($SystemModuleNames.Contains($item.name)) {
            if (-not $found.Contains($item.name)) {
                $found.Add($item.name) | Out-Null
            }
        }
    }
    return @($found | Sort-Object)
}

function Get-SystemExternalObjectsPresent {
    param(
        $InventoryItems,
        [System.Collections.Generic.HashSet[string]]$SystemExternalObjectNames
    )

    $found = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($InventoryItems | Where-Object {
            $_.sourceBlock -eq 'Objects' -and
            $_.typeName -eq 'ExternalObject' -and
            -not [string]::IsNullOrWhiteSpace($_.name)
        })) {
        if ($SystemExternalObjectNames.Contains($item.name)) {
            if (-not $found.Contains($item.name)) {
                $found.Add($item.name) | Out-Null
            }
        }
    }
    return @($found | Sort-Object)
}

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "BLOCK: InputPath nao encontrado: $InputPath"
}

if (-not $CatalogPath) {
    $CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
}
if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
    throw "BLOCK: CatalogPath nao encontrado: $CatalogPath"
}

if (-not $SystemModulesCatalogPath) {
    $SystemModulesCatalogPath = Join-Path $PSScriptRoot 'gx-system-modules.txt'
}
if (-not (Test-Path -LiteralPath $SystemModulesCatalogPath -PathType Leaf)) {
    throw "BLOCK: SystemModulesCatalogPath nao encontrado: $SystemModulesCatalogPath"
}

if (-not $SystemExternalObjectsCatalogPath) {
    $SystemExternalObjectsCatalogPath = Join-Path $PSScriptRoot 'gx-system-external-objects.txt'
}
if (-not (Test-Path -LiteralPath $SystemExternalObjectsCatalogPath -PathType Leaf)) {
    throw "BLOCK: SystemExternalObjectsCatalogPath nao encontrado: $SystemExternalObjectsCatalogPath"
}

$guidMap = Get-CatalogMap -Path $CatalogPath
$systemModuleNames = Get-SystemModuleNameSet -Path $SystemModulesCatalogPath
$systemExternalObjectNames = Get-SystemModuleNameSet -Path $SystemExternalObjectsCatalogPath

$package = Get-ExportFileXmlDocument -Path $InputPath
$root = $package.Document.DocumentElement
if ($null -eq $root -or $root.LocalName -ne 'ExportFile') {
    $found = if ($null -eq $root) { '<null>' } else { $root.LocalName }
    throw ("BLOCK: raiz esperada 'ExportFile'; encontrada '{0}'." -f $found)
}

$inventory = [System.Collections.Generic.List[pscustomObject]]::new()
$objectsNode = $root.SelectSingleNode('./Objects')
if ($null -ne $objectsNode) {
    $index = 0
    foreach ($child in @($objectsNode.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] })) {
        $index += 1
        $inventory.Add((New-InventoryItem -Node $child -GuidMap $guidMap -SourceBlock 'Objects' -Index $index)) | Out-Null
    }
}

$attributesNode = $root.SelectSingleNode('./Attributes')
if ($null -ne $attributesNode) {
    $index = 0
    foreach ($child in @($attributesNode.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] })) {
        $index += 1
        $inventory.Add((New-InventoryItem -Node $child -GuidMap $guidMap -SourceBlock 'Attributes' -Index $index)) | Out-Null
    }
}

$inventoryArray = @($inventory)
$objectItems = @($inventoryArray | Where-Object { $_.sourceBlock -eq 'Objects' })
$attributeItems = @($inventoryArray | Where-Object { $_.sourceBlock -eq 'Attributes' })

$warnings = [System.Collections.Generic.List[string]]::new()
$unknownTypeItems = @($inventoryArray | Where-Object { $_.typeStatus -eq 'unknown' })
foreach ($item in $unknownTypeItems) {
    $warnings.Add(("tipo nao mapeado no item {0}[{1}] name='{2}' typeGuid='{3}'" -f $item.sourceBlock, $item.index, $item.name, $item.typeGuid)) | Out-Null
}

$objectsByType = Get-ObjectsByTypeMap -InventoryItems $inventoryArray
$systemModulesPresent = Get-SystemModulesPresent -InventoryItems $inventoryArray -SystemModuleNames $systemModuleNames
$systemExternalObjectsPresent = Get-SystemExternalObjectsPresent -InventoryItems $inventoryArray -SystemExternalObjectNames $systemExternalObjectNames

$deltaComparison = $null
$selectiveExport = $false
$status = 'INVENTORY_OK'
$exitCode = 0
$declaredIncludesTransaction = $false
$attributesTopLevelUnreconciled = $false

$declaredItems = @()
if (-not [string]::IsNullOrWhiteSpace($DeclaredDeltaPath)) {
    if (-not (Test-Path -LiteralPath $DeclaredDeltaPath -PathType Leaf)) {
        throw "BLOCK: DeclaredDeltaPath nao encontrado: $DeclaredDeltaPath"
    }
    $declaredItems = @(Read-DeclaredDeltaFromPath -Path $DeclaredDeltaPath)
} elseif (-not [string]::IsNullOrWhiteSpace($DeclaredDeltaItems)) {
    $declaredItems = @(Read-DeclaredDeltaFromItems -Text $DeclaredDeltaItems)
}

if ($declaredItems.Count -gt 0) {
    $selectiveExport = $true
    $declaredKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $declaredItems) {
        if (-not [string]::IsNullOrWhiteSpace($item.key)) {
            [void]$declaredKeys.Add($item.key)
        }
    }

    $inventoryKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $objectItems) {
        if (-not [string]::IsNullOrWhiteSpace($item.identityKey)) {
            [void]$inventoryKeys.Add($item.identityKey)
        }
    }

    $extraKeys = @($inventoryKeys | Where-Object { -not $declaredKeys.Contains($_) } | Sort-Object)
    $missingKeys = @($declaredKeys | Where-Object { -not $inventoryKeys.Contains($_) } | Sort-Object)
    $extraObjects = @($objectItems | Where-Object { -not [string]::IsNullOrWhiteSpace($_.identityKey) -and $extraKeys -contains $_.identityKey })
    $uncomparableObjects = @($objectItems | Where-Object { [string]::IsNullOrWhiteSpace($_.identityKey) })
    $missingObjects = @($declaredItems | Where-Object { $missingKeys -contains $_.key })
    $requestedItemsFound = @($declaredItems | Where-Object { -not [string]::IsNullOrWhiteSpace($_.key) -and $inventoryKeys.Contains($_.key) })

    $deltaStatus = if ($extraKeys.Count -eq 0 -and $missingKeys.Count -eq 0 -and $uncomparableObjects.Count -eq 0) { 'MATCH' } else { 'MISMATCH' }
    if ($deltaStatus -eq 'MISMATCH') {
        $status = 'DELTA_MISMATCH'
        if ($FailOnDeltaMismatch) {
            $exitCode = 2
        }
    }

    $deltaComparison = [ordered]@{
        status              = $deltaStatus
        selectiveExport     = $true
        declaredCount       = $declaredItems.Count
        requestedItemsFound = @($requestedItemsFound)
        requestedItemsMissing = @($missingObjects)
        matchedCount        = $requestedItemsFound.Count
        extraCount          = $extraKeys.Count
        missingCount        = $missingKeys.Count
        uncomparableCount   = $uncomparableObjects.Count
        extraObjects        = @($extraObjects)
        missingObjects      = @($missingObjects)
        uncomparableObjects = @($uncomparableObjects)
        systemModulesPresent = @($systemModulesPresent)
        systemExternalObjectsPresent = @($systemExternalObjectsPresent)
    }
}

if ($declaredItems.Count -gt 0) {
    $declaredIncludesTransaction = @($declaredItems | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.typeName) -and
            $_.typeName.Equals('Transaction', [System.StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0
}

if ($selectiveExport -and $attributeItems.Count -gt 0 -and -not $declaredIncludesTransaction) {
    $warnings.Add(('attributes-top-level-em-export-cirurgico: {0} atributo(s) top-level em export seletiva sem Transaction na lista declarada' -f $attributeItems.Count)) | Out-Null
    $attributesTopLevelUnreconciled = $true
}

$result = [ordered]@{
    status               = $status
    exitCode             = $exitCode
    inputPath            = $package.ResolvedPath
    inputKind            = $package.InputKind
    innerXmlEntry        = $package.InnerXmlName
    rootElement          = $root.LocalName
    selectiveExport      = $selectiveExport
    totalItemCount       = $inventoryArray.Count
    objectCount          = $objectItems.Count
    attributeCount       = $attributeItems.Count
    objectsByType                 = $objectsByType
    systemModulesPresent          = @($systemModulesPresent)
    systemExternalObjectsPresent  = @($systemExternalObjectsPresent)
    declaredIncludesTransaction   = $declaredIncludesTransaction
    attributesTopLevelUnreconciled = $attributesTopLevelUnreconciled
    unknownTypeCount              = $unknownTypeItems.Count
    inventory            = $inventoryArray
    deltaComparison      = $deltaComparison
    warnings             = @($warnings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 10
} else {
    [pscustomobject]$result
}

exit $exitCode
