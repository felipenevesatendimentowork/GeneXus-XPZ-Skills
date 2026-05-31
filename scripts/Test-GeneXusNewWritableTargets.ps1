#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$FrontFolder,

    [string]$ProcedurePath,

    [Parameter(Mandatory = $true)]
    [string]$CorpusFolder,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FrontFolder) -and [string]::IsNullOrWhiteSpace($ProcedurePath)) {
    throw "Informe FrontFolder ou ProcedurePath."
}

$CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
    throw "Catalogo de tipos nao encontrado: $CatalogPath"
}
$Catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$ProcedureTypeGuid   = $Catalog.types.Procedure.objectTypeGuid
$TransactionTypeGuid = $Catalog.types.Transaction.objectTypeGuid

$SourcePartTypeGuid = '528d1c06-a9c2-420d-bd35-21dca83f12ff'

$RxSourcePart = [regex]::new(
    "<Part type=`"$([regex]::Escape($SourcePartTypeGuid))`">\s*<Source><!\[CDATA\[(?<src>.*?)\]\]></Source>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$RxBlockComment = [regex]::new('/\*.*?\*/', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$RxLineComment = [regex]::new('//[^\r\n]*')
$RxNewBlock = [regex]::new('\bNew\b(?<body>.*?)\bEndNew\b',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$RxAssignment = [regex]::new('(?m)^\s*(?<lhs>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?)\s*=',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

. (Join-Path $PSScriptRoot 'GeneXusTransactionWritabilitySupport.ps1')

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$ProcedureName,
        [string]$ProcedureFile,
        [int]$NewBlockIndex,
        [string]$AttributeName,
        [string]$TransactionName,
        [string]$Classification,
        [object]$Writable,
        [string]$Evidence
    )
    return [pscustomobject]@{
        severity       = $Severity
        code           = $Code
        message        = $Message
        procedureName  = $ProcedureName
        procedureFile  = $ProcedureFile
        newBlockIndex  = $NewBlockIndex
        attributeName  = $AttributeName
        transactionName = $TransactionName
        classification = $Classification
        writable       = $Writable
        evidence       = $Evidence
    }
}

function Get-RelativePathSafe {
    param([string]$BasePath, [string]$ChildPath)
    $baseUriText = ([System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar)
    $childFull = [System.IO.Path]::GetFullPath($ChildPath)
    $baseUri = [System.Uri]::new($baseUriText)
    $childUri = [System.Uri]::new($childFull)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($childUri).ToString()).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Strip-Comments {
    param([string]$Source)
    if ([string]::IsNullOrEmpty($Source)) { return '' }
    $withoutBlock = $RxBlockComment.Replace($Source, '')
    return $RxLineComment.Replace($withoutBlock, '')
}

function Get-ObjectMetadata {
    param([string]$XmlPath)
    try {
        [xml]$doc = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    } catch {
        return $null
    }
    $root = $doc.DocumentElement
    if ($null -eq $root -or $root.LocalName -ne 'Object') { return $null }
    $objName = ''
    foreach ($prop in $doc.SelectNodes('/Object/Properties/Property')) {
        if ($prop.Name -eq 'Name') {
            $objName = $prop.Value
            break
        }
    }
    return [pscustomobject]@{
        Path     = $XmlPath
        Name     = $objName
        TypeGuid = $root.GetAttribute('type')
    }
}

function Get-ProcedureSource {
    param([string]$XmlPath)
    $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    $match = $RxSourcePart.Match($text)
    if (-not $match.Success) { return '' }
    return $match.Groups['src'].Value
}

function Get-NewBlockAssignments {
    param([string]$Source)
    $clean = Strip-Comments -Source $Source
    $blocks = @()
    $index = 0
    foreach ($m in $RxNewBlock.Matches($clean)) {
        $index++
        $attrs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($am in $RxAssignment.Matches($m.Groups['body'].Value)) {
            $lhs = $am.Groups['lhs'].Value
            if ($lhs.StartsWith('&')) { continue }
            $firstSegment = @($lhs -split '\.')[0]
            if ([string]::IsNullOrWhiteSpace($firstSegment)) { continue }
            [void]$attrs.Add($firstSegment)
        }
        $blocks += [pscustomobject]@{
            Index = $index
            Attributes = @($attrs)
        }
    }
    return ,@($blocks)
}

if (-not [string]::IsNullOrWhiteSpace($FrontFolder)) {
    if (-not (Test-Path -LiteralPath $FrontFolder -PathType Container)) {
        throw "FrontFolder nao encontrado ou nao e diretorio: $FrontFolder"
    }
    $FrontFolder = (Resolve-Path -LiteralPath $FrontFolder).Path
}
if (-not [string]::IsNullOrWhiteSpace($ProcedurePath)) {
    if (-not (Test-Path -LiteralPath $ProcedurePath -PathType Leaf)) {
        throw "ProcedurePath nao encontrado ou nao e arquivo: $ProcedurePath"
    }
    $ProcedurePath = (Resolve-Path -LiteralPath $ProcedurePath).Path
}
if (-not (Test-Path -LiteralPath $CorpusFolder -PathType Container)) {
    throw "CorpusFolder nao encontrado ou nao e diretorio: $CorpusFolder"
}
$CorpusFolder = (Resolve-Path -LiteralPath $CorpusFolder).Path

$procedureMetas = @()
if (-not [string]::IsNullOrWhiteSpace($ProcedurePath)) {
    $meta = Get-ObjectMetadata -XmlPath $ProcedurePath
    if ($null -eq $meta -or $meta.TypeGuid -ne $ProcedureTypeGuid -or [string]::IsNullOrEmpty($meta.Name)) {
        throw "ProcedurePath nao parece ser uma Procedure GeneXus valida: $ProcedurePath"
    }
    $procedureMetas += $meta
}
if (-not [string]::IsNullOrWhiteSpace($FrontFolder)) {
    foreach ($xml in (Get-ChildItem -LiteralPath $FrontFolder -Recurse -Filter *.xml -File)) {
        $meta = Get-ObjectMetadata -XmlPath $xml.FullName
        if ($null -eq $meta -or $meta.TypeGuid -ne $ProcedureTypeGuid -or [string]::IsNullOrEmpty($meta.Name)) { continue }
        $alreadyListed = $false
        foreach ($listedProcedure in $procedureMetas) {
            if ($listedProcedure.Path -eq $meta.Path) {
                $alreadyListed = $true
                break
            }
        }
        if ($alreadyListed) { continue }
        $procedureMetas += $meta
    }
}

$frontTransactionMetas = @()
if (-not [string]::IsNullOrWhiteSpace($FrontFolder)) {
    foreach ($xml in (Get-ChildItem -LiteralPath $FrontFolder -Recurse -Filter *.xml -File)) {
        $meta = Get-ObjectMetadata -XmlPath $xml.FullName
        if ($null -eq $meta -or $meta.TypeGuid -ne $TransactionTypeGuid -or [string]::IsNullOrEmpty($meta.Name)) { continue }
        $frontTransactionMetas += $meta
    }
}

$corpusTransactionFolder = Join-Path $CorpusFolder 'Transaction'
if (-not (Test-Path -LiteralPath $corpusTransactionFolder -PathType Container)) {
    throw "Layout do CorpusFolder inesperado: subpasta 'Transaction' nao encontrada em $CorpusFolder"
}

$transactionMetasByName = @{}
foreach ($xml in (Get-ChildItem -LiteralPath $corpusTransactionFolder -Recurse -Filter *.xml -File)) {
    $meta = Get-ObjectMetadata -XmlPath $xml.FullName
    if ($null -eq $meta -or $meta.TypeGuid -ne $TransactionTypeGuid -or [string]::IsNullOrEmpty($meta.Name)) { continue }
    $transactionMetasByName[$meta.Name.ToLowerInvariant()] = $meta
}
foreach ($meta in $frontTransactionMetas) {
    $transactionMetasByName[$meta.Name.ToLowerInvariant()] = $meta
}

$transactionPaths = @($transactionMetasByName.Values | ForEach-Object { $_.Path })
$catalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
$batchPayload = Invoke-GeneXusTransactionWritabilityBatch `
    -TransactionPaths $transactionPaths `
    -CorpusFolder $CorpusFolder `
    -CatalogPath $catalogPath
$transactionWritableMaps = ConvertFrom-GeneXusWritabilityBatchPayload -Payload $batchPayload

$findings = @()
$newBlocksScanned = 0
$assignmentsScanned = 0

if ($procedureMetas.Count -eq 0) {
    $status = 'not-applicable'
} else {
    foreach ($proc in $procedureMetas) {
        $procFile = $proc.Path
        if (-not [string]::IsNullOrWhiteSpace($FrontFolder)) {
            $procFile = Get-RelativePathSafe -BasePath $FrontFolder -ChildPath $proc.Path
        }
        $source = Get-ProcedureSource -XmlPath $proc.Path
        $blocks = Get-NewBlockAssignments -Source $source
        if ($blocks.Count -eq 0) {
            $findings += New-Finding -Severity 'info' -Code 'new-no-blocks' `
                -Message "Procedure '$($proc.Name)' nao contem bloco New detectavel no Source" `
                -ProcedureName $proc.Name -ProcedureFile $procFile -NewBlockIndex 0
            continue
        }
        foreach ($block in $blocks) {
            $newBlocksScanned++
            $attrs = @($block.Attributes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $assignmentsScanned += $attrs.Count
            if ($attrs.Count -eq 0) {
                $findings += New-Finding -Severity 'info' -Code 'new-no-attribute-assignments' `
                    -Message "Procedure '$($proc.Name)' contem New #$($block.Index), mas sem atribuicoes diretas a atributos detectaveis" `
                    -ProcedureName $proc.Name -ProcedureFile $procFile -NewBlockIndex $block.Index
                continue
            }

            $candidateKeys = @()
            foreach ($txKey in $transactionWritableMaps.Keys) {
                $map = $transactionWritableMaps[$txKey]
                $allKnown = $true
                foreach ($attr in $attrs) {
                    if (-not $map.ContainsKey($attr.ToLowerInvariant())) {
                        $allKnown = $false
                        break
                    }
                }
                if ($allKnown) { $candidateKeys += $txKey }
            }

            if ($candidateKeys.Count -eq 0) {
                foreach ($attr in $attrs) {
                    $findings += New-Finding -Severity 'fail' -Code 'new-target-unresolved' `
                        -Message "Nao foi possivel resolver uma Transaction candidata para o New #$($block.Index) contendo '$attr'; nao entregar enquanto a tabela base do New nao estiver comprovada" `
                        -ProcedureName $proc.Name -ProcedureFile $procFile -NewBlockIndex $block.Index `
                        -AttributeName $attr -Writable $null -Classification 'unresolved-new-target'
                }
                continue
            }

            $passingCandidates = @()
            foreach ($txKey in $candidateKeys) {
                $map = $transactionWritableMaps[$txKey]
                $allWritable = $true
                foreach ($attr in $attrs) {
                    $info = $map[$attr.ToLowerInvariant()]
                    if ($info.writable -ne $true) {
                        $allWritable = $false
                        break
                    }
                }
                if ($allWritable) { $passingCandidates += $txKey }
            }

            if ($passingCandidates.Count -gt 0) {
                $txNames = @($passingCandidates | ForEach-Object { $transactionMetasByName[$_].Name })
                $severity = 'info'
                $code = 'new-assignments-writable'
                $message = "New #$($block.Index) atribui apenas atributos gravaveis em candidata(s): $($txNames -join ', ')"
                if ($txNames.Count -gt 1) {
                    $severity = 'warn'
                    $code = 'new-target-ambiguous'
                    $message = "New #$($block.Index) tem mais de uma Transaction candidata com atributos gravaveis: $($txNames -join ', '); confirmar tabela base inferida pelo GeneXus"
                }
                $findings += New-Finding -Severity $severity -Code $code -Message $message `
                    -ProcedureName $proc.Name -ProcedureFile $procFile -NewBlockIndex $block.Index `
                    -TransactionName ($txNames -join ', ')
                continue
            }

            foreach ($txKey in $candidateKeys) {
                $txName = $transactionMetasByName[$txKey].Name
                $map = $transactionWritableMaps[$txKey]
                foreach ($attr in $attrs) {
                    $info = $map[$attr.ToLowerInvariant()]
                    if ($info.writable -eq $true) { continue }
                    $severity = 'fail'
                    $code = 'new-assignment-non-writable'
                    if ($null -eq $info.writable) {
                        $code = 'new-assignment-unclassified'
                    }
                    $findings += New-Finding -Severity $severity -Code $code `
                        -Message "Atributo '$attr' no New #$($block.Index) nao foi confirmado como gravavel para Transaction '$txName' ($($info.classification)); nao entregar esta atribuicao" `
                        -ProcedureName $proc.Name -ProcedureFile $procFile -NewBlockIndex $block.Index `
                        -AttributeName $attr -TransactionName $txName -Classification $info.classification `
                        -Writable $info.writable -Evidence $info.evidence
                }
            }
        }
    }
    $hasFail = $findings | Where-Object { $_.severity -eq 'fail' } | Select-Object -First 1
    $hasWarn = $findings | Where-Object { $_.severity -eq 'warn' } | Select-Object -First 1
    if ($hasFail) {
        $status = 'fail'
    } elseif ($hasWarn) {
        $status = 'alert'
    } else {
        $status = 'pass'
    }
}

$result = [pscustomobject]@{
    status = $status
    frontFolder = $FrontFolder
    procedurePath = $ProcedurePath
    corpusFolder = $CorpusFolder
    proceduresScanned = $procedureMetas.Count
    transactionsIndexed = $transactionMetasByName.Count
    newBlocksScanned = $newBlocksScanned
    assignmentsScanned = $assignmentsScanned
    findings = @($findings)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    Write-Output "status: $status"
    Write-Output "proceduresScanned: $($procedureMetas.Count)"
    Write-Output "transactionsIndexed: $($transactionMetasByName.Count)"
    Write-Output "newBlocksScanned: $newBlocksScanned"
    Write-Output "assignmentsScanned: $assignmentsScanned"
    if ($findings.Count -eq 0) {
        Write-Output "findings: (none)"
    } else {
        Write-Output "findings:"
        foreach ($f in $findings) {
            Write-Output "  - [$($f.severity)] $($f.code): $($f.message)"
            if (-not [string]::IsNullOrWhiteSpace($f.evidence)) {
                Write-Output "    evidence: $($f.evidence)"
            }
        }
    }
}
