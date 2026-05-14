#requires -version 5.1
<#
.SYNOPSIS
    Cria um import_file.xml a partir de uma frente local da pasta paralela da KB.

.DESCRIPTION
    Lê os XMLs de ObjetosGeradosParaImportacaoNaKbNoGenexus\<FrontName>,
    lê KMW/Source/Source Version de kb-source-metadata.md e delega a montagem
    final para Build-GeneXusImportFileEnvelope.ps1.

.PARAMETER RepoRoot
    Raiz da pasta paralela da KB.

.PARAMETER FrontName
    Nome da subpasta da frente no formato NomeCurto_GUID_YYYYMMDD.

.PARAMETER NN
    Rodada curta do pacote. Default: 01.

.PARAMETER AsJson
    Retorna saída JSON estruturada.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-MarkdownTableValue {
    param(
        [string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$SectionName,
        [Parameter(Mandatory = $true)][string]$FieldName
    )

    $inSection = $false
    $sectionPattern = '^\s*##\s+{0}\s*$' -f [regex]::Escape($SectionName)

    foreach ($line in $Lines) {
        if ([regex]::IsMatch($line, '^\s*##\s+')) {
            $inSection = [regex]::IsMatch($line, $sectionPattern)
            continue
        }

        if (-not $inSection) {
            continue
        }

        $cells = $line -split '\|'
        if ($cells.Count -lt 4) {
            continue
        }

        $name = $cells[1].Trim()
        $value = $cells[2].Trim()
        if ($name -ieq $FieldName -and $name -notmatch '^-+$') {
            return $value
        }
    }

    return $null
}

function Assert-RequiredValue {
    param(
        [AllowNull()][string]$Value,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $trimmed = if ($null -eq $Value) { $null } else { $Value.Trim() }
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed -eq '(ausente)' -or $trimmed -match '^-+$') {
        throw "BLOCK: campo obrigatorio ausente em kb-source-metadata.md: $Label"
    }

    return $trimmed
}

function New-EnvelopeTemplate {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Metadata
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $false
    [void]$doc.AppendChild($doc.CreateXmlDeclaration('1.0', 'UTF-8', $null))

    $root = $doc.CreateElement('ExportFile')
    [void]$doc.AppendChild($root)

    $kmw = $doc.CreateElement('KMW')
    foreach ($name in @('MajorVersion', 'MinorVersion', 'Build')) {
        $child = $doc.CreateElement($name)
        $child.InnerText = $Metadata[$name]
        [void]$kmw.AppendChild($child)
    }
    [void]$root.AppendChild($kmw)

    $source = $doc.CreateElement('Source')
    $source.SetAttribute('kb', $Metadata['KbGuid'])
    $source.SetAttribute('username', $Metadata['Username'])
    $source.SetAttribute('UNCPath', $Metadata['UNCPath'])

    $version = $doc.CreateElement('Version')
    $version.SetAttribute('guid', $Metadata['VersionGuid'])
    $version.SetAttribute('name', $Metadata['VersionName'])
    [void]$source.AppendChild($version)
    [void]$root.AppendChild($source)

    [void]$root.AppendChild($doc.CreateElement('Objects'))
    [void]$root.AppendChild($doc.CreateElement('Dependencies'))
    [void]$root.AppendChild($doc.CreateElement('ObjectsIdentityMapping'))

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $settings.IndentChars = '  '
    $settings.OmitXmlDeclaration = $false
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $doc.Save($writer)
    } finally {
        $writer.Close()
    }
}

if ($FrontName -match '[\\/]') {
    throw 'BLOCK: FrontName invalido; informe apenas o nome da subpasta da frente.'
}

if ($NN -notmatch '^\d+$') {
    throw 'BLOCK: NN invalido; use apenas digitos.'
}

$repo = [System.IO.Path]::GetFullPath($RepoRoot)
if (-not (Test-Path -LiteralPath $repo -PathType Container)) {
    throw "BLOCK: RepoRoot inexistente: $repo"
}

$roundWidth = [Math]::Max($NN.Length, 2)
$round = ([int]$NN).ToString(('D{0}' -f $roundWidth))

$frontDir = Join-Path (Join-Path $repo 'ObjetosGeradosParaImportacaoNaKbNoGenexus') $FrontName
$packagesDir = Join-Path $repo 'PacotesGeradosParaImportacaoNaKbNoGenexus'
$metadataPath = Join-Path $repo 'kb-source-metadata.md'
$tempDir = Join-Path $repo 'Temp'
$outputPath = Join-Path $packagesDir ('{0}_{1}.import_file.xml' -f $FrontName, $round)

if (-not (Test-Path -LiteralPath $frontDir -PathType Container)) {
    throw "BLOCK: pasta da frente nao encontrada: $frontDir"
}

if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    throw "BLOCK: kb-source-metadata.md nao encontrado: $metadataPath"
}

if (-not (Test-Path -LiteralPath $packagesDir -PathType Container)) {
    New-Item -ItemType Directory -Path $packagesDir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $tempDir -PathType Container)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

$objectXmlPaths = @(Get-ChildItem -LiteralPath $frontDir -Filter '*.xml' -File | Sort-Object Name | ForEach-Object { $_.FullName })
if ($objectXmlPaths.Count -eq 0) {
    throw "BLOCK: nenhum XML encontrado na pasta da frente: $frontDir"
}

$metadataLines = [System.IO.File]::ReadAllLines($metadataPath)
$metadata = @{
    MajorVersion = Assert-RequiredValue -Value (Get-MarkdownTableValue -Lines $metadataLines -SectionName 'KMW' -FieldName 'MajorVersion') -Label 'KMW/MajorVersion'
    MinorVersion = Assert-RequiredValue -Value (Get-MarkdownTableValue -Lines $metadataLines -SectionName 'KMW' -FieldName 'MinorVersion') -Label 'KMW/MinorVersion'
    Build = Assert-RequiredValue -Value (Get-MarkdownTableValue -Lines $metadataLines -SectionName 'KMW' -FieldName 'Build') -Label 'KMW/Build'
    KbGuid = Assert-RequiredValue -Value (Get-MarkdownTableValue -Lines $metadataLines -SectionName 'Source' -FieldName 'kb (GUID)') -Label 'Source/kb (GUID)'
    Username = Assert-RequiredValue -Value (Get-MarkdownTableValue -Lines $metadataLines -SectionName 'Source' -FieldName 'username') -Label 'Source/username'
    UNCPath = Assert-RequiredValue -Value (Get-MarkdownTableValue -Lines $metadataLines -SectionName 'Source' -FieldName 'UNCPath') -Label 'Source/UNCPath'
    VersionGuid = Assert-RequiredValue -Value (Get-MarkdownTableValue -Lines $metadataLines -SectionName 'Source/Version' -FieldName 'guid') -Label 'Source/Version/guid'
    VersionName = Assert-RequiredValue -Value (Get-MarkdownTableValue -Lines $metadataLines -SectionName 'Source/Version' -FieldName 'name') -Label 'Source/Version/name'
}

$templatePath = Join-Path $tempDir ('New-XpzImportPackage_{0}.template.import_file.xml' -f ([guid]::NewGuid().ToString('N')))
$builderPath = Join-Path $PSScriptRoot 'Build-GeneXusImportFileEnvelope.ps1'
if (-not (Test-Path -LiteralPath $builderPath -PathType Leaf)) {
    throw "BLOCK: motor de envelope nao encontrado: $builderPath"
}

try {
    New-EnvelopeTemplate -Path $templatePath -Metadata $metadata
    $buildResult = & $builderPath -ObjectXmlPaths $objectXmlPaths -TemplatePackagePath $templatePath -OutputPath $outputPath

    $result = [ordered]@{
        status = $buildResult.status
        outputPath = $buildResult.outputPath
        rejectedPath = $buildResult.rejectedPath
        repoRoot = $repo
        frontName = $FrontName
        nn = $round
        sourceFolder = $frontDir
        metadataPath = $metadataPath
        objectCount = $buildResult.objectCount
        gateStatus = $buildResult.gateStatus
        blockingReasons = @($buildResult.blockingReasons)
        warnings = @($buildResult.warnings)
    }

    if ($AsJson) {
        [pscustomobject]$result | ConvertTo-Json -Depth 6
    } else {
        [pscustomobject]$result
    }
} finally {
    if (Test-Path -LiteralPath $templatePath -PathType Leaf) {
        Remove-Item -LiteralPath $templatePath -Force
    }
}
