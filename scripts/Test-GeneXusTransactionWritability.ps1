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
$SubtypeBlockRegex = [regex]::new(
    '<Subtype\b[^>]*>\s*<Name>(?<sub>[^<]+)</Name>\s*<Supertype\b[^>]*>(?<sup>[^<]+)</Supertype>\s*</Subtype>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$DuplicateIndexRegex = [regex]::new(
    '<Index\b[^>]*\bType\s*=\s*"Duplicate"[^>]*>(?<body>.*?)</Index>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$MemberRegex = [regex]::new(
    '<Member\b[^>]*>(?<n>[^<]+)</Member>',
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

# Pre-indice: subtypeName -> supertypeName extraido de todos SubTypeGroup XMLs
function Build-SubtypeIndex {
    param([string]$CorpusFolder)
    $idx = @{}
    $stgFolder = Join-Path $CorpusFolder 'SubTypeGroup'
    if (-not (Test-Path -LiteralPath $stgFolder -PathType Container)) { return $idx }
    foreach ($xml in (Get-ChildItem -LiteralPath $stgFolder -Filter *.xml -File)) {
        $text = Get-Content -LiteralPath $xml.FullName -Raw -Encoding UTF8
        foreach ($m in $SubtypeBlockRegex.Matches($text)) {
            $subName = $m.Groups['sub'].Value.Trim()
            $supName = $m.Groups['sup'].Value.Trim()
            if ([string]::IsNullOrEmpty($subName) -or [string]::IsNullOrEmpty($supName)) { continue }
            $key = $subName.ToLowerInvariant()
            if (-not $idx.ContainsKey($key)) { $idx[$key] = $supName }
        }
    }
    return $idx
}

# Pre-indice 1.5.c: para cada Transaction, lista de PK attrs (ordenada) e set de non-key attrs no Level principal
# Resultado: hashtable { txNameLower -> @{ pkAttrs=[..]; nonKeyAttrs=HashSet } }
function Build-TransactionLevelIndex {
    param([string]$CorpusFolder)
    $idx = @{}
    $txFolder = Join-Path $CorpusFolder 'Transaction'
    if (-not (Test-Path -LiteralPath $txFolder -PathType Container)) { return $idx }
    foreach ($xml in (Get-ChildItem -LiteralPath $txFolder -Filter *.xml -File)) {
        $meta = Get-TransactionMetadata $xml.FullName
        if ($null -eq $meta -or [string]::IsNullOrEmpty($meta.Name)) { continue }
        $text = Get-Content -LiteralPath $xml.FullName -Raw -Encoding UTF8
        # Levels e atributos do Level principal (primeiro Level)
        $levelMatches = $LevelOpenRegex.Matches($text)
        if ($levelMatches.Count -eq 0) { continue }
        $firstStart = $levelMatches[0].Index + $levelMatches[0].Length
        if ($levelMatches.Count -ge 2) {
            $firstEnd = $levelMatches[1].Index
        } else {
            $firstEnd = $text.Length
        }
        $chunk = $text.Substring($firstStart, $firstEnd - $firstStart)
        $pkAttrs = @()
        $nonKeyAttrs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($am in $AttributeRegex.Matches($chunk)) {
            $attrsStr = $am.Groups['attrs'].Value
            $name = $am.Groups['name'].Value.Trim()
            if ([string]::IsNullOrEmpty($name)) { continue }
            $keyMatch = $KeyAttrRegex.Match($attrsStr)
            if ($keyMatch.Success -and $keyMatch.Groups['v'].Value -eq 'True') {
                $pkAttrs += $name
            } else {
                [void]$nonKeyAttrs.Add($name)
            }
        }
        $idx[$meta.Name.ToLowerInvariant()] = @{
            Name        = $meta.Name
            PKAttrs     = $pkAttrs
            NonKeyAttrs = $nonKeyAttrs
        }
    }
    return $idx
}

# Localiza Table XML correspondente a uma Transaction (heuristica: mesmo nome)
function Find-TableXmlPath {
    param([string]$TransactionName, [string]$CorpusFolder)
    $candidate = Join-Path $CorpusFolder (Join-Path 'Table' "$TransactionName.xml")
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    return $null
}

# Extrai os Duplicate indexes de uma Table XML como lista de @{ Members=[..] }
function Get-DuplicateIndexesFromTable {
    param([string]$TableXmlPath)
    $result = @()
    $text = Get-Content -LiteralPath $TableXmlPath -Raw -Encoding UTF8
    foreach ($idxMatch in $DuplicateIndexRegex.Matches($text)) {
        $members = @()
        foreach ($mm in $MemberRegex.Matches($idxMatch.Groups['body'].Value)) {
            $members += $mm.Groups['n'].Value.Trim()
        }
        if ($members.Count -gt 0) {
            $result += [pscustomobject]@{ Members = $members }
        }
    }
    return ,@($result)
}

# Identifica FK entity para um Duplicate index: Transaction cuja PK e exatamente os members do index
function Find-FKEntityForIndex {
    param(
        [string[]]$Members,
        [hashtable]$TransactionLevelIndex
    )
    foreach ($k in $TransactionLevelIndex.Keys) {
        $entry = $TransactionLevelIndex[$k]
        $pk = $entry.PKAttrs
        if ($pk.Count -ne $Members.Count) { continue }
        $allMatch = $true
        for ($i = 0; $i -lt $pk.Count; $i++) {
            if (-not [string]::Equals($pk[$i], $Members[$i], [System.StringComparison]::OrdinalIgnoreCase)) {
                $allMatch = $false
                break
            }
        }
        if ($allMatch) { return $entry }
    }
    return $null
}

# Recursao: dado o atributo candidato e a Table-alvo, procura por FK entities cuja non-key attrs contenha o candidato.
# Retorna $true se encontrou (extended-fk-descriptive), $false caso contrario (own-physical).
# MaxDepth previne loops patologicos.
function Test-AttributeInFKEntityRecursive {
    param(
        [string]$AttributeName,
        [string]$TableXmlPath,
        [hashtable]$TransactionLevelIndex,
        [string]$CorpusFolder,
        [int]$MaxDepth,
        [System.Collections.Generic.HashSet[string]]$VisitedTables
    )
    if ($MaxDepth -le 0) { return $false }
    if ($VisitedTables.Contains($TableXmlPath)) { return $false }
    [void]$VisitedTables.Add($TableXmlPath)
    $dupIndexes = Get-DuplicateIndexesFromTable $TableXmlPath
    foreach ($dup in $dupIndexes) {
        $fkEntity = Find-FKEntityForIndex -Members $dup.Members -TransactionLevelIndex $TransactionLevelIndex
        if ($null -eq $fkEntity) { continue }
        if ($fkEntity.NonKeyAttrs.Contains($AttributeName)) { return $true }
        # Recursao: ler Table da FK entity
        $fkTablePath = Find-TableXmlPath -TransactionName $fkEntity.Name -CorpusFolder $CorpusFolder
        if ($null -eq $fkTablePath) { continue }
        if (Test-AttributeInFKEntityRecursive -AttributeName $AttributeName -TableXmlPath $fkTablePath `
            -TransactionLevelIndex $TransactionLevelIndex -CorpusFolder $CorpusFolder `
            -MaxDepth ($MaxDepth - 1) -VisitedTables $VisitedTables) {
            return $true
        }
    }
    return $false
}

# Pre-indice: conjunto de nomes de atributos que aparecem como key="True" em alguma Transaction Level
function Build-PrimaryKeyAttributeSet {
    param([string]$CorpusFolder)
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $txFolder = Join-Path $CorpusFolder 'Transaction'
    if (-not (Test-Path -LiteralPath $txFolder -PathType Container)) { return ,$set }
    foreach ($xml in (Get-ChildItem -LiteralPath $txFolder -Filter *.xml -File)) {
        $text = Get-Content -LiteralPath $xml.FullName -Raw -Encoding UTF8
        # Mesma regex do main para extrair Attribute name + key
        foreach ($am in $AttributeRegex.Matches($text)) {
            $attrsStr = $am.Groups['attrs'].Value
            $name = $am.Groups['name'].Value.Trim()
            if ([string]::IsNullOrEmpty($name)) { continue }
            $keyMatch = $KeyAttrRegex.Match($attrsStr)
            if ($keyMatch.Success -and $keyMatch.Groups['v'].Value -eq 'True') {
                [void]$set.Add($name)
            }
        }
    }
    return ,$set
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

# Pre-indices para 1.5.b/1.5.c (build sob demanda - so se houver atributo unclassified)
$subtypeIndex = $null
$pkAttrSet = $null
$txLevelIndex = $null
$tableXmlPath = $null
$dupIndexes = $null
$indicesBuilt = $false
function Ensure-Indices {
    if (-not $script:indicesBuilt) {
        $script:subtypeIndex = Build-SubtypeIndex -CorpusFolder $script:CorpusFolder
        $script:pkAttrSet    = Build-PrimaryKeyAttributeSet -CorpusFolder $script:CorpusFolder
        $script:txLevelIndex = Build-TransactionLevelIndex -CorpusFolder $script:CorpusFolder
        $script:tableXmlPath = Find-TableXmlPath -TransactionName $script:TxName -CorpusFolder $script:CorpusFolder
        if ($null -ne $script:tableXmlPath) {
            $script:dupIndexes = Get-DuplicateIndexesFromTable $script:tableXmlPath
        } else {
            $script:dupIndexes = @()
        }
        $script:indicesBuilt = $true
    }
}
$script:CorpusFolder = $CorpusFolder
$script:TxName       = $txMeta.Name
$script:subtypeIndex = $subtypeIndex
$script:pkAttrSet    = $pkAttrSet
$script:txLevelIndex = $txLevelIndex
$script:tableXmlPath = $tableXmlPath
$script:dupIndexes   = $dupIndexes
$script:indicesBuilt = $indicesBuilt

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
    # 1.5.b: SubTypeGroup membership
    Ensure-Indices
    $key = $la.AttributeName.ToLowerInvariant()
    if ($script:subtypeIndex.ContainsKey($key)) {
        $supertypeName = $script:subtypeIndex[$key]
        if ($script:pkAttrSet.Contains($supertypeName)) {
            $levelAttributes += New-AttributeResult `
                -LevelName $la.LevelName -AttributeName $la.AttributeName `
                -Key $false -IsRedundant $false `
                -Classification 'extended-subtype-key' -Writable $true `
                -Evidence "membro de SubTypeGroup com Supertype '$supertypeName' que e PK em alguma Transaction"
        } else {
            $levelAttributes += New-AttributeResult `
                -LevelName $la.LevelName -AttributeName $la.AttributeName `
                -Key $false -IsRedundant $false `
                -Classification 'extended-subtype-descriptive' -Writable $false `
                -Evidence "membro de SubTypeGroup com Supertype '$supertypeName' que nao e PK em nenhuma Transaction"
        }
        continue
    }
    # 1.5.c: naked-FK test e FK-entity recursivo
    if ($null -eq $script:tableXmlPath) {
        $levelAttributes += New-AttributeResult `
            -LevelName $la.LevelName -AttributeName $la.AttributeName `
            -Key $false -IsRedundant $false `
            -Classification 'unclassified-table-not-found' -Writable $null `
            -Evidence "Table XML correspondente ('$($script:TxName).xml') nao encontrado em CorpusFolder/Table/; sinais 5/6/7 nao podem ser avaliados"
        continue
    }
    # Sinal 5: aparece em algum Duplicate index Members? -> extended-fk-key
    $foundInDuplicate = $false
    foreach ($dup in $script:dupIndexes) {
        foreach ($m in $dup.Members) {
            if ([string]::Equals($m, $la.AttributeName, [System.StringComparison]::OrdinalIgnoreCase)) {
                $foundInDuplicate = $true
                break
            }
        }
        if ($foundInDuplicate) { break }
    }
    if ($foundInDuplicate) {
        $levelAttributes += New-AttributeResult `
            -LevelName $la.LevelName -AttributeName $la.AttributeName `
            -Key $false -IsRedundant $false `
            -Classification 'extended-fk-key' -Writable $true `
            -Evidence "atributo aparece como Member em Duplicate index da Table '$($script:TxName)'; FK column armazenada nesta table"
        continue
    }
    # Sinal 6: atributo aparece em key=False de alguma FK entity (recursivo)?
    $visitedTables = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $isFkDescriptive = Test-AttributeInFKEntityRecursive -AttributeName $la.AttributeName `
        -TableXmlPath $script:tableXmlPath -TransactionLevelIndex $script:txLevelIndex `
        -CorpusFolder $script:CorpusFolder -MaxDepth 10 -VisitedTables $visitedTables
    if ($isFkDescriptive) {
        $levelAttributes += New-AttributeResult `
            -LevelName $la.LevelName -AttributeName $la.AttributeName `
            -Key $false -IsRedundant $false `
            -Classification 'extended-fk-descriptive' -Writable $false `
            -Evidence "atributo aparece como key=False em alguma FK entity (resolucao recursiva ate profundidade 10 a partir da Table '$($script:TxName)')"
        continue
    }
    # Sinal 7: ausente em todas FK entities -> own-physical
    $levelAttributes += New-AttributeResult `
        -LevelName $la.LevelName -AttributeName $la.AttributeName `
        -Key $false -IsRedundant $false `
        -Classification 'own-physical' -Writable $true `
        -Evidence "atributo ausente em FK entities em todas as profundidades exploradas (max 10); proprio da tabela fisica desta Transaction"
}

$result = [pscustomobject]@{
    status           = 'pass'
    transactionName  = $txMeta.Name
    transactionPath  = $TransactionPath
    coverage         = 'complete-1.5.a-1.5.b-1.5.c'
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
