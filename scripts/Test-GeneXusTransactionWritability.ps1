[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TransactionPath,

    [Parameter(Mandatory = $true)]
    [string]$CorpusFolder,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Catalogo canonico de tipos
$CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
if (-not (Test-Path -LiteralPath $CatalogPath)) {
    throw "Catalogo de tipos nao encontrado: $CatalogPath"
}
$Catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$TransactionTypeGuid = $Catalog.types.Transaction.objectTypeGuid

# Regex
$LevelOpenRegex = [regex]::new('<Level\s+[^>]*name="(?<name>[^"]+)"[^>]*>',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$AttributeRegex = [regex]::new(
    '<Attribute\s+(?<attrs>[^>]*?)>(?<name>[^<]+)</Attribute>',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$KeyAttrRegex        = [regex]::new('\bkey\s*=\s*"(?<v>[^"]*)"',          [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$IsRedundantRegex    = [regex]::new('\bisRedundant\s*=\s*"(?<v>[^"]*)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$FormulaPropertyRegex = [regex]::new(
    '<Property>\s*<Name>Formula</Name>\s*<Value>(?<v>.*?)</Value>\s*</Property>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function New-AttributeResult {
    param(
        [string]$LevelName,
        [string]$AttributeName,
        [bool]$Key,
        [bool]$IsRedundant,
        [string]$Classification,
        [object]$Writable,
        [string]$Evidence
    )
    return [pscustomobject]@{
        levelName       = $LevelName
        attributeName   = $AttributeName
        key             = $Key
        isRedundant     = $IsRedundant
        classification  = $Classification
        writable        = $Writable
        evidence        = $Evidence
    }
}

function Get-TransactionMetadata {
    param([string]$XmlPath)
    try {
        [xml]$doc = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    } catch {
        return $null
    }
    $root = $doc.DocumentElement
    if ($null -eq $root -or $root.LocalName -ne 'Object') { return $null }
    if ($root.GetAttribute('type') -ne $TransactionTypeGuid) { return $null }
    $name = ''
    foreach ($prop in $doc.SelectNodes('/Object/Properties/Property')) {
        if ($prop.Name -eq 'Name') { $name = $prop.Value; break }
    }
    return [pscustomobject]@{
        Path = $XmlPath
        Name = $name
    }
}

# Localiza Attribute standalone XML por nome em CorpusFolder/Attribute/<Nome>.xml
function Find-AttributeXmlPath {
    param(
        [string]$AttributeName,
        [string]$CorpusFolder
    )
    $candidate = Join-Path $CorpusFolder (Join-Path 'Attribute' "$AttributeName.xml")
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    return $null
}

function Test-AttributeHasFormula {
    param([string]$AttributeXmlPath)
    $text = Get-Content -LiteralPath $AttributeXmlPath -Raw -Encoding UTF8
    return $FormulaPropertyRegex.IsMatch($text)
}

# Extrai Levels e seus atributos do Transaction XML
function Get-LevelsAndAttributes {
    param([string]$TransactionXml)
    $results = @()
    # Encontrar inicio de cada Level
    $levelMatches = $LevelOpenRegex.Matches($TransactionXml)
    if ($levelMatches.Count -eq 0) { return ,@() }
    # Para cada Level, capturar atributos ate o proximo <Level ou ate o fim
    for ($i = 0; $i -lt $levelMatches.Count; $i++) {
        $start = $levelMatches[$i].Index + $levelMatches[$i].Length
        if ($i + 1 -lt $levelMatches.Count) {
            $end = $levelMatches[$i + 1].Index
        } else {
            $end = $TransactionXml.Length
        }
        $chunk = $TransactionXml.Substring($start, $end - $start)
        $levelName = $levelMatches[$i].Groups['name'].Value
        foreach ($am in $AttributeRegex.Matches($chunk)) {
            $attrsStr = $am.Groups['attrs'].Value
            $name = $am.Groups['name'].Value.Trim()
            if ([string]::IsNullOrEmpty($name)) { continue }
            $keyMatch = $KeyAttrRegex.Match($attrsStr)
            $key = ($keyMatch.Success -and $keyMatch.Groups['v'].Value -eq 'True')
            $isRedMatch = $IsRedundantRegex.Match($attrsStr)
            $isRedundant = ($isRedMatch.Success -and $isRedMatch.Groups['v'].Value -eq 'True')
            $results += [pscustomobject]@{
                LevelName    = $levelName
                AttributeName= $name
                Key          = $key
                IsRedundant  = $isRedundant
            }
        }
    }
    return ,@($results)
}

# Validar parametros
if (-not (Test-Path -LiteralPath $TransactionPath -PathType Leaf)) {
    throw "TransactionPath nao encontrado ou nao e arquivo: $TransactionPath"
}
if (-not (Test-Path -LiteralPath $CorpusFolder -PathType Container)) {
    throw "CorpusFolder nao encontrado ou nao e diretorio: $CorpusFolder"
}
$TransactionPath = (Resolve-Path -LiteralPath $TransactionPath).Path
$CorpusFolder    = (Resolve-Path -LiteralPath $CorpusFolder).Path

$txMeta = Get-TransactionMetadata $TransactionPath
if ($null -eq $txMeta) {
    throw "TransactionPath nao parece ser uma Transaction GeneXus valida: $TransactionPath"
}

$txText = Get-Content -LiteralPath $TransactionPath -Raw -Encoding UTF8
$levelAttrs = Get-LevelsAndAttributes $txText

$levelAttributes = @()
foreach ($la in $levelAttrs) {
    if ($la.Key) {
        $levelAttributes += New-AttributeResult `
            -LevelName $la.LevelName -AttributeName $la.AttributeName `
            -Key $true -IsRedundant $la.IsRedundant `
            -Classification 'key-attribute' -Writable $true `
            -Evidence "key=`"True`" no Level '$($la.LevelName)'"
        continue
    }
    # key="False" - aplicar sinais ordenados (1.5.a cobre 2 sinais)
    if ($la.IsRedundant) {
        $levelAttributes += New-AttributeResult `
            -LevelName $la.LevelName -AttributeName $la.AttributeName `
            -Key $false -IsRedundant $true `
            -Classification 'extended-parent-fk' -Writable $false `
            -Evidence "isRedundant=`"True`" no Level '$($la.LevelName)'"
        continue
    }
    # Buscar Attribute XML standalone para verificar Formula
    $attrPath = Find-AttributeXmlPath -AttributeName $la.AttributeName -CorpusFolder $CorpusFolder
    if ($null -eq $attrPath) {
        $levelAttributes += New-AttributeResult `
            -LevelName $la.LevelName -AttributeName $la.AttributeName `
            -Key $false -IsRedundant $false `
            -Classification 'unclassified-attribute-not-found' -Writable $null `
            -Evidence "Attribute XML '$($la.AttributeName).xml' nao encontrado em CorpusFolder/Attribute/"
        continue
    }
    if (Test-AttributeHasFormula $attrPath) {
        $levelAttributes += New-AttributeResult `
            -LevelName $la.LevelName -AttributeName $la.AttributeName `
            -Key $false -IsRedundant $false `
            -Classification 'formula' -Writable $false `
            -Evidence "Property Formula presente em $attrPath"
        continue
    }
    # Demais sinais (SubTypeGroup, FK recursivo) ficam para 1.5.b/c
    $levelAttributes += New-AttributeResult `
        -LevelName $la.LevelName -AttributeName $la.AttributeName `
        -Key $false -IsRedundant $false `
        -Classification 'unclassified-pending-higher-signals' -Writable $null `
        -Evidence "1.5.a nao cobre sinais SubTypeGroup, naked-FK ou FK recursivo; classificacao final requer revisao manual ou conclusao das sub-sub-fases 1.5.b e 1.5.c"
}

$result = [pscustomobject]@{
    status           = 'ok'
    transactionName  = $txMeta.Name
    transactionPath  = $TransactionPath
    coverage         = 'partial-1.5.a'
    levelAttributes  = @($levelAttributes)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $($result.status)"
    Write-Output "transactionName: $($result.transactionName)"
    Write-Output "coverage: $($result.coverage)"
    Write-Output "levelAttributes: $($levelAttributes.Count)"
    foreach ($a in $levelAttributes) {
        $w = if ($null -eq $a.writable) { 'null' } else { $a.writable }
        Write-Output "  [$($a.levelName)] $($a.attributeName) key=$($a.key) -> $($a.classification) (writable=$w)"
    }
}
