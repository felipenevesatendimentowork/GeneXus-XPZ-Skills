#requires -Version 7.4
<#
.SYNOPSIS
    Registra entrada paliativa em gx-object-type-catalog.override.json (com upstream pendente).

.DESCRIPTION
    Grava ou atualiza o override local na pasta paralela. Exige consentimento explicito
    registrado em -UserApproved. Não altera o catalogo compartilhado GeneXus-XPZ-Skills.

.PARAMETER ParallelKbRoot
    Raiz da pasta paralela da KB.

.PARAMETER TypeName
    Nome canonico do tipo (chave no JSON, ex.: DataView).

.PARAMETER ObjectTypeGuid
    GUID de Object/@type no XPZ/XML.

.PARAMETER FolderName
    Nome da subpasta em ObjetosDaKbEmXml (padrão: TypeName).

.PARAMETER UserApproved
    Obrigatório. Confirma consentimento explicito do usuário para registro local.

.PARAMETER EvidenceSummary
    Resumo curto da evidencia (XML, nexa, wiki).

.PARAMETER WikiLinks
    Links oficiais GeneXus consultados.

.PARAMETER NexaFindings
    Achados da skill nexa quando aplicavel.

.PARAMETER CatalogOverridePath
    Caminho alternativo ao arquivo override.

.PARAMETER AsJson
    Emite JSON com o resultado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ParallelKbRoot,

    [Parameter(Mandatory = $true)]
    [string]$TypeName,

    [Parameter(Mandatory = $true)]
    [string]$ObjectTypeGuid,

    [string]$FolderName,

    [switch]$UserApproved,

    [string]$EvidenceSummary,

    [string[]]$WikiLinks = @(),

    [string]$NexaFindings,

    [string]$CatalogOverridePath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

if (-not $UserApproved) {
    throw 'BLOCK: registro local exige -UserApproved apos consentimento explicito do usuario.'
}

$supportScript = Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1'
. $supportScript

$resolvedKbRoot = (Resolve-Path -LiteralPath $ParallelKbRoot).Path
if (-not $CatalogOverridePath) {
    $CatalogOverridePath = Get-GeneXusObjectTypeCatalogDefaultOverridePath -ParallelKbRoot $resolvedKbRoot
}

if ([string]::IsNullOrWhiteSpace($CatalogOverridePath)) {
    throw 'BLOCK: CatalogOverridePath nao resolvido.'
}

$scriptsDir = Split-Path -Parent $CatalogOverridePath
if (-not (Test-Path -LiteralPath $scriptsDir)) {
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($FolderName)) {
    $FolderName = $TypeName.Trim()
}

$typeNameKey = $TypeName.Trim()
$guidValue = $ObjectTypeGuid.Trim().ToLowerInvariant()

$overrideObject = $null
if (Test-Path -LiteralPath $CatalogOverridePath -PathType Leaf) {
    $overrideObject = Read-GeneXusObjectTypeCatalogFile -Path $CatalogOverridePath
} else {
    $overrideObject = [pscustomobject]@{
        schemaVersion       = 1
        upstreamPending     = $true
        lastLocalRegistrationAt = (Get-Date).ToString('o')
        types               = [pscustomobject]@{}
    }
}

$typeEntry = [ordered]@{
    objectTypeGuid  = $guidValue
    rootKind        = 'Object'
    folderName      = $FolderName
    inventoryEligible = $true
    queryableByKbIntelligence = $true
    containerType   = $false
    evidenceSummary = $EvidenceSummary
    wikiLinks       = @($WikiLinks)
    nexaFindings    = $NexaFindings
    notes           = 'Entrada paliativa local; upstreamPending na base GeneXus-XPZ-Skills.'
}

$typesTable = [ordered]@{}
if ($null -ne $overrideObject.types) {
    foreach ($property in $overrideObject.types.PSObject.Properties) {
        $typesTable[$property.Name] = $property.Value
    }
}
$typesTable[$typeNameKey] = [pscustomobject]$typeEntry

$payload = [ordered]@{
    schemaVersion             = 1
    upstreamPending           = $true
    lastLocalRegistrationAt   = (Get-Date).ToString('o')
    registrationRequiresUpstreamSync = $true
    types                     = [pscustomobject]$typesTable
}

$json = ($payload | ConvertTo-Json -Depth 8)
[System.IO.File]::WriteAllText($CatalogOverridePath, $json, (Get-Utf8NoBomEncoding))

$reminder = Get-GeneXusCatalogOverrideSessionReminder -ParallelKbRoot $resolvedKbRoot -CatalogOverridePath $CatalogOverridePath

$result = [pscustomobject]@{
    status            = 'LOCAL_OVERRIDE_REGISTERED'
    overridePath      = (Resolve-Path -LiteralPath $CatalogOverridePath).Path
    typeName          = $typeNameKey
    objectTypeGuid    = $guidValue
    folderName        = $FolderName
    upstreamPending   = $true
    reminder          = $reminder
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    $result | Format-List
}

exit 0
