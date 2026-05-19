#requires -Version 7.4
<#
.SYNOPSIS
Inventaria objetos efetivamente presentes em um import_file.xml GeneXus.

.DESCRIPTION
Le um envelope GeneXus com raiz <ExportFile>, lista os objetos sob <Objects>
e atributos top-level sob <Attributes>, mapeia GUIDs de tipo pelo catalogo
compartilhado quando possivel e, opcionalmente, confronta o inventario com um
delta declarado em arquivo texto.

Escopo inicial: import_file.xml/XML com raiz <ExportFile>. Pacotes .xpz ficam
fora desta primeira implementacao para preservar o fluxo cotidiano focado em
import_file.xml.

.PARAMETER InputPath
Caminho do import_file.xml ou XML equivalente com raiz <ExportFile>.

.PARAMETER DeclaredDeltaPath
Arquivo texto opcional com o delta esperado, uma entrada por linha no formato
Tipo:Nome. Linhas vazias e iniciadas por # sao ignoradas.

.PARAMETER CatalogPath
Caminho opcional para gx-object-type-catalog.json.

.PARAMETER FailOnDeltaMismatch
Quando informado junto com DeclaredDeltaPath, retorna exit code 2 se houver
objetos extras ou ausentes.

.PARAMETER AsJson
Emite JSON estruturado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$DeclaredDeltaPath,

    [string]$CatalogPath,

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

function Read-DeclaredDelta {
    param([string]$Path)

    $items = [System.Collections.Generic.List[pscustomobject]]::new()
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $lineNumber += 1
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $parts = @($trimmed -split '[:|	]', 2)
        if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
            throw ("BLOCK: linha {0} de DeclaredDeltaPath fora do formato Tipo:Nome: {1}" -f $lineNumber, $line)
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

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "BLOCK: InputPath nao encontrado: $InputPath"
}

$resolvedInputPath = (Resolve-Path -LiteralPath $InputPath).Path
if ([System.IO.Path]::GetExtension($resolvedInputPath).Equals('.xpz', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "BLOCK: .xpz ainda nao e suportado por este inventario inicial; informe o import_file.xml/XML com raiz <ExportFile>."
}

if (-not $CatalogPath) {
    $CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
}
if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
    throw "BLOCK: CatalogPath nao encontrado: $CatalogPath"
}

$guidMap = Get-CatalogMap -Path $CatalogPath

$document = New-Object System.Xml.XmlDocument
$document.PreserveWhitespace = $true
$document.Load($resolvedInputPath)
$root = $document.DocumentElement
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

$warnings = [System.Collections.Generic.List[string]]::new()
$unknownTypeItems = @($inventory | Where-Object { $_.typeStatus -eq 'unknown' })
foreach ($item in $unknownTypeItems) {
    $warnings.Add(("tipo nao mapeado no item {0}[{1}] name='{2}' typeGuid='{3}'" -f $item.sourceBlock, $item.index, $item.name, $item.typeGuid)) | Out-Null
}

$deltaComparison = $null
$status = 'INVENTORY_OK'
$exitCode = 0

if (-not [string]::IsNullOrWhiteSpace($DeclaredDeltaPath)) {
    if (-not (Test-Path -LiteralPath $DeclaredDeltaPath -PathType Leaf)) {
        throw "BLOCK: DeclaredDeltaPath nao encontrado: $DeclaredDeltaPath"
    }

    $declaredItems = @(Read-DeclaredDelta -Path $DeclaredDeltaPath)
    $declaredKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $declaredItems) {
        if (-not [string]::IsNullOrWhiteSpace($item.key)) {
            [void]$declaredKeys.Add($item.key)
        }
    }

    $inventoryKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $inventory) {
        if (-not [string]::IsNullOrWhiteSpace($item.identityKey)) {
            [void]$inventoryKeys.Add($item.identityKey)
        }
    }

    $extraKeys = @($inventoryKeys | Where-Object { -not $declaredKeys.Contains($_) } | Sort-Object)
    $missingKeys = @($declaredKeys | Where-Object { -not $inventoryKeys.Contains($_) } | Sort-Object)
    $extraObjects = @($inventory | Where-Object { -not [string]::IsNullOrWhiteSpace($_.identityKey) -and $extraKeys -contains $_.identityKey })
    $uncomparableObjects = @($inventory | Where-Object { [string]::IsNullOrWhiteSpace($_.identityKey) })
    $missingObjects = @($declaredItems | Where-Object { $missingKeys -contains $_.key })

    $deltaStatus = if ($extraKeys.Count -eq 0 -and $missingKeys.Count -eq 0 -and $uncomparableObjects.Count -eq 0) { 'MATCH' } else { 'MISMATCH' }
    if ($deltaStatus -eq 'MISMATCH') {
        $status = 'DELTA_MISMATCH'
        if ($FailOnDeltaMismatch) {
            $exitCode = 2
        }
    }

    $deltaComparison = [ordered]@{
        status         = $deltaStatus
        declaredCount  = $declaredItems.Count
        matchedCount   = $declaredKeys.Count - $missingKeys.Count
        extraCount     = $extraKeys.Count
        missingCount   = $missingKeys.Count
        uncomparableCount = $uncomparableObjects.Count
        extraObjects   = @($extraObjects)
        missingObjects = @($missingObjects)
        uncomparableObjects = @($uncomparableObjects)
    }
}

$result = [ordered]@{
    status            = $status
    exitCode          = $exitCode
    inputPath         = $resolvedInputPath
    rootElement       = $root.LocalName
    totalItemCount    = $inventory.Count
    objectCount       = @($inventory | Where-Object { $_.sourceBlock -eq 'Objects' }).Count
    attributeCount    = @($inventory | Where-Object { $_.sourceBlock -eq 'Attributes' }).Count
    unknownTypeCount  = $unknownTypeItems.Count
    inventory         = @($inventory)
    deltaComparison   = $deltaComparison
    warnings          = @($warnings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 8
} else {
    [pscustomobject]$result
}

exit $exitCode
