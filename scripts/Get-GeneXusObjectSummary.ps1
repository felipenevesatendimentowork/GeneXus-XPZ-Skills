#requires -Version 7.4
<#
.SYNOPSIS
Resume um objeto GeneXus XML/XPZ sem despejar CDATA extenso.

.DESCRIPTION
Aceita caminho para Object XML, ExportFile XML ou XPZ. Quando o insumo contem
mais de um objeto, use -ObjectName e opcionalmente -ObjectType. Para Panel, o
resumo inclui sinais compactos de level/layout, controles, gridData, actions e
nomes de eventos extraidos de CDATA de layout/configuracao.

.PARAMETER InputPath
Caminho do XML ou XPZ.

.PARAMETER ObjectName
Nome do objeto quando InputPath contem pacote com multiplos objetos.

.PARAMETER ObjectType
Tipo canonico ou GUID de Object/@type.

.PARAMETER AsJson
Retorna JSON estruturado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$ObjectName,

    [string]$ObjectType,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PanelObjectTypeGuid = 'd82625fd-5892-40b0-99c9-5c8559c197fc'

function Read-TextFileFlexible {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    foreach ($encoding in @([System.Text.UTF8Encoding]::new($true), [System.Text.UnicodeEncoding]::new($false, $true))) {
        try { return $encoding.GetString($bytes) } catch { continue }
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-TypeGuidMap {
    $catalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
    $map = @{}
    if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $catalog.types.PSObject.Properties) {
            $guid = $prop.Value.objectTypeGuid
            if (-not [string]::IsNullOrWhiteSpace($guid)) {
                $map[$prop.Name.ToLowerInvariant()] = $guid.ToLowerInvariant()
            }
        }
    }
    return $map
}

function Resolve-ObjectTypeGuid {
    param([string]$TypeValue)

    if ([string]::IsNullOrWhiteSpace($TypeValue)) { return $null }
    if ($TypeValue -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        return $TypeValue.ToLowerInvariant()
    }
    $map = Get-TypeGuidMap
    $key = $TypeValue.ToLowerInvariant()
    if ($map.ContainsKey($key)) { return $map[$key] }
    throw "ObjectType desconhecido no catalogo local: $TypeValue"
}

function ConvertTo-XmlDocument {
    param(
        [string]$XmlText,
        [string]$SourceLabel
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    try {
        $doc.LoadXml($XmlText)
        return $doc
    } catch {
        throw "XML malformado em ${SourceLabel}: $($_.Exception.Message)"
    }
}

function Find-ObjectInXml {
    param(
        [string]$XmlText,
        [string]$SourceLabel,
        [string]$Name,
        [string]$TypeGuid
    )

    $doc = ConvertTo-XmlDocument -XmlText $XmlText -SourceLabel $SourceLabel
    $root = $doc.DocumentElement
    $candidates = @()
    if ($root.LocalName -eq 'Object') {
        $candidates = @($root)
    } elseif ($root.LocalName -eq 'ExportFile') {
        $objectsNode = $root.SelectSingleNode('./Objects')
        if ($null -ne $objectsNode) {
            $candidates = @($objectsNode.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] -and $_.LocalName -eq 'Object' })
        }
    }

    if ([string]::IsNullOrWhiteSpace($Name) -and $candidates.Count -eq 1) {
        return [pscustomobject]@{ source = $SourceLabel; node = $candidates[0] }
    }

    foreach ($candidate in $candidates) {
        $candidateName = $candidate.GetAttribute('name')
        $candidateType = $candidate.GetAttribute('type').ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($Name) -and -not $candidateName.Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($TypeGuid) -and $candidateType -ne $TypeGuid) {
            continue
        }
        return [pscustomobject]@{ source = $SourceLabel; node = $candidate }
    }
    return $null
}

function Find-Object {
    param(
        [string]$Path,
        [string]$Name,
        [string]$TypeGuid
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()
    if ($extension -ne '.xpz' -and $extension -ne '.zip') {
        return Find-ObjectInXml -XmlText (Read-TextFileFlexible -Path $resolvedPath) -SourceLabel $resolvedPath -Name $Name -TypeGuid $TypeGuid
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedPath)
    try {
        foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '\.xml$' })) {
            $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
            try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
            try {
                $found = Find-ObjectInXml -XmlText $text -SourceLabel ($resolvedPath + '!' + $entry.FullName) -Name $Name -TypeGuid $TypeGuid
                if ($null -ne $found) { return $found }
            } catch {
                continue
            }
        }
    } finally {
        $zip.Dispose()
    }
    return $null
}

function Get-CDataTexts {
    param([System.Xml.XmlElement]$ObjectNode)

    $texts = [System.Collections.Generic.List[string]]::new()
    foreach ($node in @($ObjectNode.SelectNodes('.//Source|.//Data'))) {
        if (-not [string]::IsNullOrWhiteSpace($node.InnerText)) {
            [void]$texts.Add($node.InnerText)
        }
    }
    return @($texts)
}

function Get-UniqueRegexMatches {
    param(
        [string[]]$Texts,
        [string]$Pattern,
        [string]$GroupName
    )

    $set = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($text in $Texts) {
        foreach ($match in [regex]::Matches($text, $Pattern)) {
            $value = $match.Groups[$GroupName].Value
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                [void]$set.Add($value)
            }
        }
    }
    return @($set)
}

function Convert-AttributeTextToMap {
    param([string]$AttributeText)

    $map = [ordered]@{}
    if ([string]::IsNullOrWhiteSpace($AttributeText)) {
        return $map
    }
    foreach ($match in [regex]::Matches($AttributeText, '(?<name>[A-Za-z_][A-Za-z0-9_.:-]*)="(?<value>[^"]*)"')) {
        $map[$match.Groups['name'].Value] = $match.Groups['value'].Value
    }
    return $map
}

function Get-FirstTagAttributes {
    param(
        [string[]]$Texts,
        [string]$TagName
    )

    $pattern = '<' + [regex]::Escape($TagName) + '\b(?<attrs>[^>]*)>'
    foreach ($text in $Texts) {
        $match = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            return (Convert-AttributeTextToMap -AttributeText $match.Groups['attrs'].Value)
        }
    }
    return [ordered]@{}
}

function Get-PanelSummary {
    param([System.Xml.XmlElement]$ObjectNode)

    $texts = @(Get-CDataTexts -ObjectNode $ObjectNode)
    $combined = $texts -join "`n"
    $levelIds = @(Get-UniqueRegexMatches -Texts $texts -Pattern '<(?:level|Level)\b[^>]*(?:id|guid)="(?<id>[^"]+)"' -GroupName 'id')
    $layoutIds = @(Get-UniqueRegexMatches -Texts $texts -Pattern '<(?:layout|Layout)\b[^>]*(?:id|guid)="(?<id>[^"]+)"' -GroupName 'id')
    $controlNames = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bcontrolName="(?<name>[^"]+)"' -GroupName 'name')
    $controlTypes = @(Get-UniqueRegexMatches -Texts $texts -Pattern '<(?<type>grid|Grid|action|Action|table|Table|ucw|attribute|Attribute|textblock|TextBlock)\b' -GroupName 'type')
    $gridDataNames = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bgridData(?:Name)?="(?<name>[^"]+)"' -GroupName 'name')
    $actionControls = @(Get-UniqueRegexMatches -Texts $texts -Pattern '<(?:action|Action)\b[^>]*(?:controlName|name)="(?<name>[^"]+)"' -GroupName 'name')
    $onClickEvents = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bonClickEvent="(?<name>[^"]+)"' -GroupName 'name')
    $events = @(Get-UniqueRegexMatches -Texts $texts -Pattern "(?im)^\s*(?:Event|Sub)\s+'(?<name>[^']+)'" -GroupName 'name')
    $patternGuids = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bPattern="(?<guid>[0-9a-fA-F-]{36})"' -GroupName 'guid')
    $dataVersions = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bversion="(?<version>[^"]+)"' -GroupName 'version')
    $layoutAttrs = Get-FirstTagAttributes -Texts $texts -TagName 'layout'
    $firstTableAttrs = Get-FirstTagAttributes -Texts $texts -TagName 'table'

    return [ordered]@{
        levelIds = $levelIds
        layoutIds = $layoutIds
        layoutAttrs = $layoutAttrs
        firstTableAttrs = $firstTableAttrs
        levelLayoutPairCount = [Math]::Max($levelIds.Count, $layoutIds.Count)
        patternGuids = $patternGuids
        dataVersions = $dataVersions
        hasResponsiveSizes = ($combined -match '\bresponsiveSizes=')
        hasGridData = ($combined -match '\bgridData')
        hasActions = (($combined -match '<(?:action|Action)\b') -or ($actionControls.Count -gt 0))
        hasOnClickEvent = ($onClickEvents.Count -gt 0)
        controls = [ordered]@{
            names = $controlNames
            types = $controlTypes
            count = $controlNames.Count
        }
        gridDataNames = $gridDataNames
        actionControls = $actionControls
        onClickEvents = $onClickEvents
        eventNames = $events
        cdataTextCount = $texts.Count
    }
}

function New-Summary {
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [string]$Source
    )

    $parts = @($ObjectNode.SelectNodes('./Part') | ForEach-Object {
        [ordered]@{
            type = $_.GetAttribute('type')
            hasSource = ($null -ne $_.SelectSingleNode('./Source'))
            hasData = ($null -ne $_.SelectSingleNode('./Data'))
        }
    })
    $typeGuid = $ObjectNode.GetAttribute('type')
    $summary = [ordered]@{
        source = $Source
        name = $ObjectNode.GetAttribute('name')
        typeGuid = $typeGuid
        guid = $ObjectNode.GetAttribute('guid')
        parent = $ObjectNode.GetAttribute('parent')
        parentGuid = $ObjectNode.GetAttribute('parentGuid')
        parentType = $ObjectNode.GetAttribute('parentType')
        moduleGuid = $ObjectNode.GetAttribute('moduleGuid')
        partCount = $parts.Count
        partTypes = @($parts)
        panel = $null
    }
    if ($typeGuid.ToLowerInvariant() -eq $PanelObjectTypeGuid) {
        $summary.panel = Get-PanelSummary -ObjectNode $ObjectNode
    }
    return $summary
}

$resolvedTypeGuid = Resolve-ObjectTypeGuid -TypeValue $ObjectType
$found = Find-Object -Path $InputPath -Name $ObjectName -TypeGuid $resolvedTypeGuid
if ($null -eq $found) {
    throw "Objeto nao encontrado no insumo informado."
}

$summary = New-Summary -ObjectNode $found.node -Source $found.source
if ($AsJson) {
    $summary | ConvertTo-Json -Depth 10
} else {
    [pscustomobject]$summary
}
