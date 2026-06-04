#requires -Version 7.4
<#
.SYNOPSIS
    Funções compartilhadas para catálogo de tipos GeneXus (base + override local).
#>

Set-StrictMode -Version Latest

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

function Get-GeneXusObjectTypeCatalogDefaultBasePath {
    return (Join-Path $PSScriptRoot 'gx-object-type-catalog.json')
}

function Get-GeneXusObjectTypeCatalogDefaultOverridePath {
    param([string]$ParallelKbRoot)

    if ([string]::IsNullOrWhiteSpace($ParallelKbRoot)) {
        return $null
    }

    return (Join-Path $ParallelKbRoot 'scripts/gx-object-type-catalog.override.json')
}

function Read-GeneXusObjectTypeCatalogFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Object type catalog not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
}

function Merge-GeneXusObjectTypeCatalog {
    param(
        [object]$BaseCatalog,
        [object]$OverrideCatalog
    )

    if ($null -eq $OverrideCatalog -or $null -eq $OverrideCatalog.types) {
        return $BaseCatalog
    }

    $mergedTypes = [ordered]@{}
    foreach ($property in $BaseCatalog.types.PSObject.Properties) {
        $mergedTypes[$property.Name] = $property.Value
    }

    foreach ($property in $OverrideCatalog.types.PSObject.Properties) {
        $mergedTypes[$property.Name] = $property.Value
    }

    $merged = [pscustomobject]@{
        version = if ($null -ne $BaseCatalog.version) { $BaseCatalog.version } else { 1 }
        types   = [pscustomobject]$mergedTypes
    }

    if ($null -ne $OverrideCatalog.PSObject.Properties['schemaVersion']) {
        $merged | Add-Member -NotePropertyName schemaVersion -NotePropertyValue $OverrideCatalog.schemaVersion -Force
    }

    return $merged
}

function Resolve-GeneXusObjectTypeCatalogPaths {
    param(
        [string]$BaseCatalogPath,
        [string]$CatalogOverridePath,
        [string]$ParallelKbRoot
    )

    if ([string]::IsNullOrWhiteSpace($BaseCatalogPath)) {
        $BaseCatalogPath = Get-GeneXusObjectTypeCatalogDefaultBasePath
    }

    $resolvedOverridePath = $CatalogOverridePath
    if ([string]::IsNullOrWhiteSpace($resolvedOverridePath) -and -not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) {
        $resolvedOverridePath = Get-GeneXusObjectTypeCatalogDefaultOverridePath -ParallelKbRoot $ParallelKbRoot
    }

    $overrideCatalog = $null
    $overrideActive = $false
    if (-not [string]::IsNullOrWhiteSpace($resolvedOverridePath) -and (Test-Path -LiteralPath $resolvedOverridePath -PathType Leaf)) {
        $overrideCatalog = Read-GeneXusObjectTypeCatalogFile -Path $resolvedOverridePath
        $overrideActive = $true
    }

    $baseCatalog = Read-GeneXusObjectTypeCatalogFile -Path $BaseCatalogPath
    $mergedCatalog = Merge-GeneXusObjectTypeCatalog -BaseCatalog $baseCatalog -OverrideCatalog $overrideCatalog

    $upstreamPending = $false
    if ($overrideActive -and $null -ne $overrideCatalog.PSObject.Properties['upstreamPending']) {
        $upstreamPending = [bool]$overrideCatalog.upstreamPending
    }

    return [pscustomobject]@{
        BaseCatalogPath      = $BaseCatalogPath
        OverridePath         = if ($overrideActive) { (Resolve-Path -LiteralPath $resolvedOverridePath).Path } else { $null }
        OverrideActive       = $overrideActive
        UpstreamPending      = $upstreamPending
        MergedCatalog        = $mergedCatalog
        OverrideCatalog      = $overrideCatalog
    }
}

function Get-GeneXusCatalogGuidToFolderMap {
    param([object]$MergedCatalog)

    $map = @{}
    foreach ($property in $MergedCatalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.objectTypeGuid -or [string]::IsNullOrWhiteSpace([string]$entry.objectTypeGuid)) {
            continue
        }

        $folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
            [string]$entry.folderName
        } else {
            [string]$property.Name
        }

        $map[[string]$entry.objectTypeGuid.ToLowerInvariant()] = $folderName
    }

    return $map
}

function Get-GeneXusCatalogGuidToTypeMap {
    param([object]$MergedCatalog)

    $map = @{}
    foreach ($property in $MergedCatalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.objectTypeGuid -or [string]::IsNullOrWhiteSpace([string]$entry.objectTypeGuid)) {
            continue
        }

        $folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
            [string]$entry.folderName
        } else {
            [string]$property.Name
        }

        $map[[string]$entry.objectTypeGuid.ToLowerInvariant()] = [pscustomobject]@{
            TypeName   = [string]$property.Name
            FolderName = $folderName
        }
    }

    return $map
}

function Get-GeneXusExportTaskLabelAliasRules {
    param([object]$MergedCatalog)

    $rules = [System.Collections.Generic.List[object]]::new()
    foreach ($property in $MergedCatalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.PSObject.Properties['exportTaskLabel']) {
            continue
        }

        $exportTaskLabel = [string]$entry.exportTaskLabel
        if ([string]::IsNullOrWhiteSpace($exportTaskLabel)) {
            continue
        }

        $folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
            [string]$entry.folderName
        } else {
            [string]$property.Name
        }

        [void]$rules.Add([ordered]@{
            exportTaskLabel = $exportTaskLabel.Trim()
            catalogTypeName = [string]$property.Name
            catalogTypeGuid = if ($null -ne $entry.objectTypeGuid) { [string]$entry.objectTypeGuid } else { $null }
            folderName      = $folderName
        })
    }

    return @($rules)
}

function Get-GeneXusCatalogOverrideSessionReminder {
    param(
        [string]$ParallelKbRoot,
        [string]$CatalogOverridePath
    )

    $resolution = Resolve-GeneXusObjectTypeCatalogPaths -CatalogOverridePath $CatalogOverridePath -ParallelKbRoot $ParallelKbRoot
    if (-not $resolution.OverrideActive) {
        return [pscustomobject]@{
            reminderRequired = $false
            overrideActive   = $false
            upstreamPending  = $false
            message          = $null
            overridePath     = $null
            pendingTypeNames = @()
            pendingTypeGuids = @()
        }
    }

    $pendingNames = [System.Collections.Generic.List[string]]::new()
    $pendingGuids = [System.Collections.Generic.List[string]]::new()
    if ($null -ne $resolution.OverrideCatalog -and $null -ne $resolution.OverrideCatalog.types) {
        foreach ($property in $resolution.OverrideCatalog.types.PSObject.Properties) {
            $entry = $property.Value
            $pendingNames.Add([string]$property.Name) | Out-Null
            if ($null -ne $entry.objectTypeGuid -and -not [string]::IsNullOrWhiteSpace([string]$entry.objectTypeGuid)) {
                $pendingGuids.Add([string]$entry.objectTypeGuid) | Out-Null
            }
        }
    }

    $reminderRequired = $resolution.UpstreamPending -or $pendingNames.Count -gt 0
    $message = $null
    if ($reminderRequired) {
        $typeList = ($pendingNames | Sort-Object) -join ', '
        $message = @(
            'CATÁLOGO_LOCAL_OVERRIDE_ATIVO: esta pasta paralela usa gx-object-type-catalog.override.json (paliativo).'
            "Tipos no override local: $typeList."
            'Ainda falta registrar o(s) mesmo(s) tipo(s) na base compartilhada GeneXus-XPZ-Skills (scripts/gx-object-type-catalog.json e 01a-catalogo-e-padroes-empiricos.md).'
            'Nao trate o override como catálogo definitivo; encaminhe evidencia ao mantenedor da base XPZ quando possivel.'
        ) -join ' '
    }

    return [pscustomobject]@{
        reminderRequired = $reminderRequired
        overrideActive     = $true
        upstreamPending    = $resolution.UpstreamPending
        message            = $message
        overridePath       = $resolution.OverridePath
        pendingTypeNames   = @($pendingNames | Sort-Object)
        pendingTypeGuids   = @($pendingGuids)
    }
}

function Get-GeneXusXmlObjectOuterSnippet {
    param(
        [System.Xml.XmlNode]$Node,
        [int]$MaxLength = 480
    )

    if ($null -eq $Node) {
        return $null
    }

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.OmitXmlDeclaration = $true
    $settings.Indent = $false
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::None

    $builder = New-Object System.Text.StringBuilder
    $writer = [System.Xml.XmlWriter]::Create($builder, $settings)
    try {
        $Node.WriteTo($writer)
    } finally {
        $writer.Dispose()
    }

    $text = $builder.ToString() -replace '\s+', ' '
    if ($text.Length -le $MaxLength) {
        return $text
    }

    return $text.Substring(0, $MaxLength) + '…'
}

function Get-GeneXusUnknownObjectTypesFromExportFile {
    param(
        [xml]$XmlDocument,
        [hashtable]$GuidToFolderMap,
        [int]$MaxSampleNamesPerGuid = 5,
        [int]$MaxXmlSnippetLength = 480
    )

    $aggregates = @{}

    $objectsNode = $XmlDocument.SelectSingleNode('/ExportFile/Objects')
    if ($null -eq $objectsNode) {
        return @()
    }

    foreach ($node in $objectsNode.SelectNodes('./Object')) {
        $typeGuid = $node.GetAttribute('type')
        if ([string]::IsNullOrWhiteSpace($typeGuid)) {
            continue
        }

        $typeKey = $typeGuid.ToLowerInvariant()
        if ($GuidToFolderMap.ContainsKey($typeKey)) {
            continue
        }

        if (-not $aggregates.ContainsKey($typeKey)) {
            $aggregates[$typeKey] = [pscustomobject]@{
                unknownObjectTypeGuid = $typeGuid
                count                   = 0
                sampleNames             = [System.Collections.Generic.List[string]]::new()
                sampleParents           = [System.Collections.Generic.List[string]]::new()
                sampleParentTypes       = [System.Collections.Generic.List[string]]::new()
                sampleXmlSnippets       = [System.Collections.Generic.List[string]]::new()
                suggestedFolderName     = ('Unknown_{0}' -f $typeKey.Split('-')[0])
            }
        }

        $bucket = $aggregates[$typeKey]
        $bucket.count += 1

        $logicalName = $node.GetAttribute('name')
        if (-not [string]::IsNullOrWhiteSpace($logicalName) -and $bucket.sampleNames.Count -lt $MaxSampleNamesPerGuid) {
            if (-not $bucket.sampleNames.Contains($logicalName)) {
                $bucket.sampleNames.Add($logicalName) | Out-Null
            }
        }

        $parent = $node.GetAttribute('parent')
        if (-not [string]::IsNullOrWhiteSpace($parent) -and $bucket.sampleParents.Count -lt $MaxSampleNamesPerGuid) {
            if (-not $bucket.sampleParents.Contains($parent)) {
                $bucket.sampleParents.Add($parent) | Out-Null
            }
        }

        $parentType = $node.GetAttribute('parentType')
        if (-not [string]::IsNullOrWhiteSpace($parentType) -and $bucket.sampleParentTypes.Count -lt $MaxSampleNamesPerGuid) {
            if (-not $bucket.sampleParentTypes.Contains($parentType)) {
                $bucket.sampleParentTypes.Add($parentType) | Out-Null
            }
        }

        if ($bucket.sampleXmlSnippets.Count -lt 2) {
            $snippet = Get-GeneXusXmlObjectOuterSnippet -Node $node -MaxLength $MaxXmlSnippetLength
            if (-not [string]::IsNullOrWhiteSpace($snippet) -and -not $bucket.sampleXmlSnippets.Contains($snippet)) {
                $bucket.sampleXmlSnippets.Add($snippet) | Out-Null
            }
        }
    }

    return @(
        $aggregates.GetEnumerator() |
            Sort-Object Name |
            ForEach-Object {
                [pscustomobject]@{
                    unknownObjectTypeGuid = $_.Value.unknownObjectTypeGuid
                    count                   = $_.Value.count
                    sampleNames             = @($_.Value.sampleNames)
                    sampleParents           = @($_.Value.sampleParents)
                    sampleParentTypes       = @($_.Value.sampleParentTypes)
                    sampleXmlSnippets       = @($_.Value.sampleXmlSnippets)
                    suggestedFolderName     = $_.Value.suggestedFolderName
                }
            }
    )
}

function Format-GeneXusUnknownObjectTypesErrorMessage {
    param(
        [object[]]$UnknownTypes,
        [bool]$OverrideActive
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $UnknownTypes) {
        $namePart = if ($entry.sampleNames.Count -gt 0) {
            (' names={0}' -f (($entry.sampleNames | Select-Object -First 3) -join ', '))
        } else {
            ''
        }
        $parentPart = if ($entry.sampleParents.Count -gt 0) {
            (' parent={0}' -f (($entry.sampleParents | Select-Object -First 2) -join ', '))
        } else {
            ''
        }
        $parentTypePart = if ($entry.sampleParentTypes.Count -gt 0) {
            (' parentType={0}' -f (($entry.sampleParentTypes | Select-Object -First 2) -join ', '))
        } else {
            ''
        }
        $lines.Add(('{0} [{1}]{2}{3}{4}' -f $entry.unknownObjectTypeGuid, $entry.count, $namePart, $parentPart, $parentTypePart)) | Out-Null
    }

    $suffix = 'Update scripts\gx-object-type-catalog.json and 01a-catalogo-e-padroes-empiricos.md in GeneXus-XPZ-Skills, or register an approved local override (gx-object-type-catalog.override.json) after explicit user consent.'
    if ($OverrideActive) {
        $suffix = 'Some types may still be missing from the merged catalog. Review gx-object-type-catalog.override.json and upstream GeneXus-XPZ-Skills catalog alignment.'
    }

    return ('Package contains object type GUIDs not mapped to destination folders: {0}. {1}' -f (($lines -join '; ')), $suffix)
}

function Write-GeneXusUnknownTypeDiscoveryReport {
    param(
        [string]$Path,
        [object[]]$UnknownTypes,
        [object]$CatalogResolution,
        [string]$InputPath
    )

    $payload = [ordered]@{
        generatedAt          = (Get-Date).ToString('o')
        inputPath            = $InputPath
        catalogBasePath      = $CatalogResolution.BaseCatalogPath
        catalogOverridePath  = $CatalogResolution.OverridePath
        catalogOverrideActive = $CatalogResolution.OverrideActive
        upstreamPending      = $CatalogResolution.UpstreamPending
        unknownTypes         = $UnknownTypes
        resolutionHints      = [ordered]@{
            recommendedSources = @('XPZ/XML evidence', 'nexa skill (with user consent)', 'docs.genexus.com / wiki.genexus.com official documentation')
            localOverrideFile  = 'scripts/gx-object-type-catalog.override.json under parallel KB root'
            upstreamCatalog    = 'GeneXus-XPZ-Skills scripts/gx-object-type-catalog.json + 01a-catalogo-e-padroes-empiricos.md'
        }
    }

    $json = ($payload | ConvertTo-Json -Depth 10)
    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $json, (Get-Utf8NoBomEncoding))
}

function New-GeneXusUnknownTypeMaintainerPromptText {
    param(
        [object[]]$UnknownTypes,
        [string]$KbName = $null,
        [string]$GeneXusVersion = $null,
        [string[]]$WikiLinks = @(),
        [string]$NexaFindings = $null
    )

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine('## Pedido: registrar tipo(s) no catálogo GeneXus-XPZ-Skills')
    [void]$builder.AppendLine()
    [void]$builder.AppendLine('Contexto: sync XPZ/XML bloqueado por GUID de tipo não mapeado no catálogo compartilhado.')
    if (-not [string]::IsNullOrWhiteSpace($KbName)) {
        [void]$builder.AppendLine("- KB: $KbName")
    }
    if (-not [string]::IsNullOrWhiteSpace($GeneXusVersion)) {
        [void]$builder.AppendLine("- GeneXus: $GeneXusVersion")
    }
    [void]$builder.AppendLine()

    foreach ($entry in $UnknownTypes) {
        [void]$builder.AppendLine("### Tipo desconhecido: $($entry.unknownObjectTypeGuid)")
        [void]$builder.AppendLine("- Contagem no pacote: $($entry.count)")
        if ($entry.sampleNames.Count -gt 0) {
            [void]$builder.AppendLine(('- Amostra de nomes: {0}' -f (($entry.sampleNames -join ', '))))
        }
        if ($entry.sampleParents.Count -gt 0) {
            [void]$builder.AppendLine(('- parent: {0}' -f (($entry.sampleParents -join ', '))))
        }
        if ($entry.sampleParentTypes.Count -gt 0) {
            [void]$builder.AppendLine(('- parentType: {0}' -f (($entry.sampleParentTypes -join ', '))))
        }
        [void]$builder.AppendLine(('- folderName sugerido (provisório): {0}' -f $entry.suggestedFolderName))
        if ($entry.sampleXmlSnippets.Count -gt 0) {
            [void]$builder.AppendLine('- Snippet XML (evidência):')
            [void]$builder.AppendLine('```xml')
            [void]$builder.AppendLine($entry.sampleXmlSnippets[0])
            [void]$builder.AppendLine('```')
        }
        [void]$builder.AppendLine()
    }

    if ($WikiLinks.Count -gt 0) {
        [void]$builder.AppendLine('### Referências wiki/docs')
        foreach ($link in $WikiLinks) {
            [void]$builder.AppendLine("- $link")
        }
        [void]$builder.AppendLine()
    }

    if (-not [string]::IsNullOrWhiteSpace($NexaFindings)) {
        [void]$builder.AppendLine('### Achados nexa (com consentimento do usuário)')
        [void]$builder.AppendLine($NexaFindings)
        [void]$builder.AppendLine()
    }

    [void]$builder.AppendLine('### Ação solicitada no repositório GeneXus-XPZ-Skills')
    [void]$builder.AppendLine('- Entrada em `scripts/gx-object-type-catalog.json` (`objectTypeGuid`, `folderName`, flags alinhadas aos tipos vizinhos).')
    [void]$builder.AppendLine('- Linha correspondente em `01a-catalogo-e-padroes-empiricos.md`.')
    [void]$builder.AppendLine('- Self-test / regressão de descoberta de tipo desconhecido, se aplicável.')
    [void]$builder.AppendLine()
    [void]$builder.AppendLine('FIM DO PROMPT')

    return $builder.ToString()
}
