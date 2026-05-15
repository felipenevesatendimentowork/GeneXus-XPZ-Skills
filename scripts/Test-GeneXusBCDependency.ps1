[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FrontFolder,

    [Parameter(Mandatory = $true)]
    [string]$CorpusFolder,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolver catalogo de tipos canonico (gx-object-type-catalog.json fica em scripts/ da base compartilhada)
$CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
if (-not (Test-Path -LiteralPath $CatalogPath)) {
    throw "Catalogo de tipos nao encontrado: $CatalogPath"
}
$Catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$ProcedureTypeGuid   = $Catalog.types.Procedure.objectTypeGuid
$TransactionTypeGuid = $Catalog.types.Transaction.objectTypeGuid

# Regex compativel com Build-KbIntelligenceIndex.py (paridade com o indice)
$VariableRegex      = [regex]::new('<Variable\b(?<attrs>[^>]*)>(?<body>.*?)</Variable>',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                                   [System.Text.RegularExpressions.RegexOptions]::Singleline)
$AttCustomTypeRegex = [regex]::new('<Property>\s*<Name>ATTCUSTOMTYPE</Name>\s*<Value>(?<value>.*?)</Value>\s*</Property>',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                                   [System.Text.RegularExpressions.RegexOptions]::Singleline)
$VariableNameRegex  = [regex]::new('Name="(?<name>[^"]*)"',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function Normalize-CustomType {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return '' }
    $unescaped = [System.Net.WebUtility]::HtmlDecode($Value).Trim()
    $stripped  = ($unescaped -split '//', 2)[0].Trim()
    return ($stripped -split '\s+' -join ' ')
}

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$ProcedureName,
        [string]$ProcedureFile,
        [string]$TransactionName,
        [string]$Location
    )
    return [pscustomobject]@{
        severity        = $Severity
        code            = $Code
        message         = $Message
        procedureName   = $ProcedureName
        procedureFile   = $ProcedureFile
        transactionName = $TransactionName
        location        = $Location
    }
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
    $objType = $root.GetAttribute('type')
    $objName = ''
    foreach ($prop in $doc.SelectNodes('/Object/Properties/Property')) {
        if ($prop.Name -eq 'Name') { $objName = $prop.Value; break }
    }
    $isBC = $null  # null = property absent
    foreach ($prop in $doc.SelectNodes('/Object/Properties/Property')) {
        if ($prop.Name -eq 'idISBUSINESSCOMPONENT') {
            $isBC = ($prop.Value -eq 'True')
            break
        }
    }
    return [pscustomobject]@{
        Path     = $XmlPath
        Name     = $objName
        TypeGuid = $objType
        IsBC     = $isBC  # $true / $false / $null
    }
}

function Get-BCDependencies {
    param([string]$XmlPath)
    $deps = @()
    $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    foreach ($varMatch in $VariableRegex.Matches($text)) {
        $varName = ''
        $nameMatch = $VariableNameRegex.Match($varMatch.Groups['attrs'].Value)
        if ($nameMatch.Success) { $varName = $nameMatch.Groups['name'].Value }
        $body = $varMatch.Groups['body'].Value
        $ctMatch = $AttCustomTypeRegex.Match($body)
        if (-not $ctMatch.Success) { continue }
        $ct = Normalize-CustomType $ctMatch.Groups['value'].Value
        if (-not $ct.ToLowerInvariant().StartsWith('bc:')) { continue }
        $txName = ($ct.Substring(3)).Trim()
        if ([string]::IsNullOrEmpty($txName)) { continue }
        $deps += [pscustomobject]@{
            VariableName    = $varName
            TransactionName = $txName
        }
    }
    return $deps
}

# Validar parametros
if (-not (Test-Path -LiteralPath $FrontFolder -PathType Container)) {
    throw "FrontFolder nao encontrado ou nao e diretorio: $FrontFolder"
}
if (-not (Test-Path -LiteralPath $CorpusFolder -PathType Container)) {
    throw "CorpusFolder nao encontrado ou nao e diretorio: $CorpusFolder"
}
$FrontFolder  = (Resolve-Path -LiteralPath $FrontFolder).Path
$CorpusFolder = (Resolve-Path -LiteralPath $CorpusFolder).Path

# 1. Enumerar XMLs no FrontFolder e classificar
$batchProcedures = @()
$batchTransactions = @{}  # name (lower) -> ObjectMetadata
$batchXmls = Get-ChildItem -LiteralPath $FrontFolder -Recurse -Filter *.xml -File
foreach ($xml in $batchXmls) {
    $meta = Get-ObjectMetadata $xml.FullName
    if ($null -eq $meta -or [string]::IsNullOrEmpty($meta.Name)) { continue }
    if ($meta.TypeGuid -eq $ProcedureTypeGuid) {
        $batchProcedures += $meta
    } elseif ($meta.TypeGuid -eq $TransactionTypeGuid) {
        $batchTransactions[$meta.Name.ToLowerInvariant()] = $meta
    }
}

# 2. Se nenhum Procedure no batch -> not-applicable
$findings = @()
$bcDependenciesFound = 0
if ($batchProcedures.Count -eq 0) {
    $status = 'not-applicable'
} else {
    # 3. Coletar BC dependencies por Procedure
    $procDeps = @{}  # ProcedurePath -> @(BCDep)
    $pendingCorpusLookup = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($proc in $batchProcedures) {
        $deps = Get-BCDependencies $proc.Path
        $procDeps[$proc.Path] = $deps
        $bcDependenciesFound += $deps.Count
        foreach ($d in $deps) {
            if (-not $batchTransactions.ContainsKey($d.TransactionName.ToLowerInvariant())) {
                [void]$pendingCorpusLookup.Add($d.TransactionName)
            }
        }
    }
    # 4. Varrer corpus uma unica vez por TX pendentes
    $corpusTransactions = @{}  # name (lower) -> ObjectMetadata
    if ($pendingCorpusLookup.Count -gt 0) {
        $corpusXmls = Get-ChildItem -LiteralPath $CorpusFolder -Recurse -Filter *.xml -File
        foreach ($xml in $corpusXmls) {
            $meta = Get-ObjectMetadata $xml.FullName
            if ($null -eq $meta -or [string]::IsNullOrEmpty($meta.Name)) { continue }
            if ($meta.TypeGuid -ne $TransactionTypeGuid) { continue }
            if ($pendingCorpusLookup.Contains($meta.Name)) {
                $corpusTransactions[$meta.Name.ToLowerInvariant()] = $meta
            }
        }
    }
    # 5. Gerar findings
    foreach ($proc in $batchProcedures) {
        $procRel = [System.IO.Path]::GetRelativePath($FrontFolder, $proc.Path)
        foreach ($dep in $procDeps[$proc.Path]) {
            $txKey = $dep.TransactionName.ToLowerInvariant()
            if ($batchTransactions.ContainsKey($txKey)) {
                $tx = $batchTransactions[$txKey]
                if ($null -eq $tx.IsBC) {
                    $findings += New-Finding -Severity 'fail' -Code 'bc-isbc-property-absent-batch' `
                        -Message "Transaction '$($tx.Name)' no batch nao tem a propriedade idISBUSINESSCOMPONENT; corrigir antes de empacotar" `
                        -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $tx.Name -Location 'batch'
                } elseif ($tx.IsBC -eq $false) {
                    $findings += New-Finding -Severity 'fail' -Code 'bc-isbc-false-batch' `
                        -Message "Transaction '$($tx.Name)' no batch tem idISBUSINESSCOMPONENT=False; corrigir antes de empacotar" `
                        -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $tx.Name -Location 'batch'
                } else {
                    $findings += New-Finding -Severity 'warn' -Code 'bc-isbc-true-same-batch-ordering-risk' `
                        -Message "Transaction '$($tx.Name)' e o Procedure '$($proc.Name)' estao no mesmo batch; risco de ordenacao na importacao" `
                        -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $tx.Name -Location 'batch'
                }
            } elseif ($corpusTransactions.ContainsKey($txKey)) {
                $tx = $corpusTransactions[$txKey]
                if ($null -eq $tx.IsBC) {
                    $findings += New-Finding -Severity 'fail' -Code 'bc-isbc-property-absent-corpus' `
                        -Message "Transaction '$($tx.Name)' no corpus nao tem a propriedade idISBUSINESSCOMPONENT; dependencia bc: nao pode ser satisfeita" `
                        -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $tx.Name -Location 'corpus'
                } elseif ($tx.IsBC -eq $false) {
                    $findings += New-Finding -Severity 'fail' -Code 'bc-isbc-false-corpus' `
                        -Message "Transaction '$($tx.Name)' no corpus tem idISBUSINESSCOMPONENT=False; dependencia bc: nao pode ser satisfeita" `
                        -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $tx.Name -Location 'corpus'
                } else {
                    $findings += New-Finding -Severity 'info' -Code 'bc-isbc-true-corpus' `
                        -Message "Transaction '$($tx.Name)' ja existe como BC no corpus" `
                        -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $tx.Name -Location 'corpus'
                }
            } else {
                $findings += New-Finding -Severity 'fail' -Code 'bc-missing-everywhere' `
                    -Message "Transaction '$($dep.TransactionName)' nao encontrada nem no batch nem no corpus" `
                    -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $dep.TransactionName -Location 'absent'
            }
        }
    }
    # 6. Status agregado
    $hasFail = $findings | Where-Object { $_.severity -eq 'fail' } | Select-Object -First 1
    $hasWarn = $findings | Where-Object { $_.severity -eq 'warn' } | Select-Object -First 1
    if ($hasFail) { $status = 'fail' }
    elseif ($hasWarn) { $status = 'alert' }
    else { $status = 'pass' }
}

# 7. Emitir
$result = [pscustomobject]@{
    status              = $status
    frontFolder         = $FrontFolder
    corpusFolder        = $CorpusFolder
    proceduresScanned   = $batchProcedures.Count
    bcDependenciesFound = $bcDependenciesFound
    findings            = $findings
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $status"
    Write-Output "frontFolder: $FrontFolder"
    Write-Output "corpusFolder: $CorpusFolder"
    Write-Output "proceduresScanned: $($batchProcedures.Count)"
    Write-Output "bcDependenciesFound: $bcDependenciesFound"
    if ($findings.Count -eq 0) {
        Write-Output "findings: (none)"
    } else {
        Write-Output "findings:"
        foreach ($f in $findings) {
            Write-Output "  - [$($f.severity)] $($f.code): $($f.message)"
            Write-Output "    procedure: $($f.procedureName) ($($f.procedureFile))"
            Write-Output "    transaction: $($f.transactionName) [$($f.location)]"
        }
    }
}
