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

# Catalogo canonico
$CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
if (-not (Test-Path -LiteralPath $CatalogPath)) {
    throw "Catalogo de tipos nao encontrado: $CatalogPath"
}
$Catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$WorkWithForWebTypeGuid = $Catalog.types.WorkWithForWeb.objectTypeGuid
$TransactionTypeGuid    = $Catalog.types.Transaction.objectTypeGuid

# Part GUIDs
$FormAPartGuid     = 'babfa2b2-19a0-4ef1-b5f4-81b7c7be79dc'
$FormBPartGuid     = 'a51ced48-7bee-0001-ab12-04e9e32123d1'
$WWPatternGuid     = '78cecefe-be7d-4980-86ce-8d6e91fba04b'
$ApplyGuidProperty = 'Apply:78cecefe-be7d-4980-86ce-8d6e91fba04b'

# Regex
$FormAPartRegex = [regex]::new(
    "<Part type=`"$([regex]::Escape($FormAPartGuid))`">(?<body>.*?)</Part>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$FormBPartRegex = [regex]::new(
    "<Part type=`"$([regex]::Escape($FormBPartGuid))`">(?<body>.*?)</Part>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$DataPatternRegex = [regex]::new(
    "<Data\s+Pattern=`"$([regex]::Escape($WWPatternGuid))`"[^>]*>(?<cdata><!\[CDATA\[(?<inner>.*?)\]\]>)",
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$ApplyPropertyRegex = [regex]::new(
    '<Property>\s*<Name>Apply</Name>\s*<Value>(?<v>.*?)</Value>\s*</Property>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$TransactionPropertyRegex = [regex]::new(
    '<Property>\s*<Name>Transaction</Name>\s*<Value>(?<v>.*?)</Value>\s*</Property>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$TransactionElementRegex = [regex]::new(
    '<transaction\s+transaction="(?<v>[^"]+)"',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$WorkWithForWebName,
        [string]$WorkWithForWebFile,
        $TransactionName,
        $Location,
        $Form
    )
    return [pscustomobject]@{
        severity            = $Severity
        code                = $Code
        message             = $Message
        workWithForWebName  = $WorkWithForWebName
        workWithForWebFile  = $WorkWithForWebFile
        transactionName     = $TransactionName
        location            = $Location
        form                = $Form
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
    return [pscustomobject]@{
        Path     = $XmlPath
        Name     = $objName
        TypeGuid = $objType
    }
}

# Detecta forma estrutural e extrai dados relevantes
function Get-WorkWithForWebDetails {
    param([string]$XmlPath)
    $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    $hasFormA = $FormAPartRegex.IsMatch($text)
    $hasFormB = $false
    $applyValue = $null         # Form A: True/False/null (absent)
    $linkedTxName = $null
    if ($hasFormA) {
        $formAMatch = $FormAPartRegex.Match($text)
        $formABody = $formAMatch.Groups['body'].Value
        $applyMatch = $ApplyPropertyRegex.Match($formABody)
        if ($applyMatch.Success) {
            $applyValue = $applyMatch.Groups['v'].Value.Trim()
        }
        $txMatch = $TransactionPropertyRegex.Match($formABody)
        if ($txMatch.Success) {
            $linkedTxName = $txMatch.Groups['v'].Value.Trim()
        }
    }
    # Tentar Form B independente: se ambos existem, preferimos Form A no link mas registramos coexistencia
    $formBMatch = $FormBPartRegex.Match($text)
    if ($formBMatch.Success) {
        $formBBody = $formBMatch.Groups['body'].Value
        $dataPatternMatch = $DataPatternRegex.Match($formBBody)
        if ($dataPatternMatch.Success) {
            $hasFormB = $true
            if (-not $hasFormA) {
                # Em Form B isolado, extrair linked transaction do CDATA
                $cdataInner = $dataPatternMatch.Groups['inner'].Value
                $txElemMatch = $TransactionElementRegex.Match($cdataInner)
                if ($txElemMatch.Success) {
                    $raw = $txElemMatch.Groups['v'].Value
                    # Formato: "<guid>-<TransactionName>"
                    $dashIdx = $raw.LastIndexOf('-')
                    if ($dashIdx -ge 0 -and $dashIdx -lt $raw.Length - 1) {
                        $linkedTxName = $raw.Substring($dashIdx + 1).Trim()
                    }
                }
            }
        }
    }
    return [pscustomobject]@{
        HasFormA     = $hasFormA
        HasFormB     = $hasFormB
        ApplyValue   = $applyValue
        LinkedTxName = $linkedTxName
    }
}

# Le Apply:<GUID> property da Transaction
function Get-TransactionApplyGuidValue {
    param([string]$XmlPath)
    $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    $rx = [regex]::new(
        "<Property>\s*<Name>$([regex]::Escape($ApplyGuidProperty))</Name>\s*<Value>(?<v>.*?)</Value>\s*</Property>",
        [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $m = $rx.Match($text)
    if (-not $m.Success) { return $null }
    return $m.Groups['v'].Value.Trim()
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

# 1. Enumerar XMLs no FrontFolder e identificar WorkWithForWeb + Transactions
$batchWWs = @()
$batchTransactions = @{}  # name (lower) -> meta
foreach ($xml in (Get-ChildItem -LiteralPath $FrontFolder -Recurse -Filter *.xml -File)) {
    $meta = Get-ObjectMetadata $xml.FullName
    if ($null -eq $meta -or [string]::IsNullOrEmpty($meta.Name)) { continue }
    if ($meta.TypeGuid -eq $WorkWithForWebTypeGuid) {
        $batchWWs += $meta
    } elseif ($meta.TypeGuid -eq $TransactionTypeGuid) {
        $batchTransactions[$meta.Name.ToLowerInvariant()] = $meta
    }
}

$findings = @()
if ($batchWWs.Count -eq 0) {
    $status = 'not-applicable'
} else {
    # 2. Coletar TX names pendentes para lookup lazy no corpus
    $pendingCorpusTxLookup = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $wwDetailsMap = @{}
    foreach ($ww in $batchWWs) {
        $details = Get-WorkWithForWebDetails $ww.Path
        $wwDetailsMap[$ww.Path] = $details
        if (-not [string]::IsNullOrEmpty($details.LinkedTxName)) {
            if (-not $batchTransactions.ContainsKey($details.LinkedTxName.ToLowerInvariant())) {
                [void]$pendingCorpusTxLookup.Add($details.LinkedTxName)
            }
        }
    }
    # 3. Varrer corpus uma unica vez para resolver TXs pendentes (restringe a subpasta canonica Transaction/)
    $corpusTransactions = @{}
    if ($pendingCorpusTxLookup.Count -gt 0) {
        $corpusTransactionFolder = Join-Path $CorpusFolder 'Transaction'
        if (-not (Test-Path -LiteralPath $corpusTransactionFolder -PathType Container)) {
            throw "Layout do CorpusFolder inesperado: subpasta 'Transaction' nao encontrada em $CorpusFolder; gate exige layout canonico <Type>/<Name>.xml gerado por Sync-GeneXusXpzToXml.ps1"
        }
        $corpusXmls = @(Get-ChildItem -LiteralPath $corpusTransactionFolder -Recurse -Filter *.xml -File)
        $corpusTotal = $corpusXmls.Count
        $corpusSeen = 0
        foreach ($xml in $corpusXmls) {
            $corpusSeen++
            if (($corpusSeen % 250) -eq 0 -or $corpusSeen -eq $corpusTotal) {
                Write-Progress -Activity 'Test-GeneXusWorkWithWebApply' `
                    -Status ('Resolvendo Transactions linkadas no corpus ({0}/{1})' -f $corpusSeen, $corpusTotal) `
                    -PercentComplete ([int](100 * $corpusSeen / [Math]::Max($corpusTotal,1)))
            }
            $meta = Get-ObjectMetadata $xml.FullName
            if ($null -eq $meta -or [string]::IsNullOrEmpty($meta.Name)) { continue }
            if ($meta.TypeGuid -ne $TransactionTypeGuid) { continue }
            if ($pendingCorpusTxLookup.Contains($meta.Name)) {
                $corpusTransactions[$meta.Name.ToLowerInvariant()] = $meta
            }
        }
        Write-Progress -Activity 'Test-GeneXusWorkWithWebApply' -Status 'Resolucao corpus concluida' -Completed
    }
    # 4. Gerar findings por WorkWithForWeb
    $wwTotal = $batchWWs.Count
    $wwSeen = 0
    foreach ($ww in $batchWWs) {
        $wwSeen++
        Write-Progress -Activity 'Test-GeneXusWorkWithWebApply' `
            -Status ('Avaliando WorkWithForWeb {0}/{1}: {2}' -f $wwSeen, $wwTotal, $ww.Name) `
            -PercentComplete ([int](100 * $wwSeen / [Math]::Max($wwTotal,1)))
        $wwRel = [System.IO.Path]::GetRelativePath($FrontFolder, $ww.Path)
        $details = $wwDetailsMap[$ww.Path]

        # 4a. Form detection
        if (-not $details.HasFormA -and -not $details.HasFormB) {
            $findings += New-Finding -Severity 'fail' -Code 'ww-no-form-detected' `
                -Message ('WorkWithForWeb ''{0}'' nao casa com Form A (Part babfa2b2-...) nem Form B (Part a51ced48-... com <Data Pattern=...>); estrutura nao reconhecida' -f $ww.Name) `
                -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                -TransactionName $null -Location $null -Form 'none'
            continue
        }
        $form = $null
        if ($details.HasFormA -and $details.HasFormB) {
            $form = 'A+B'
            $findings += New-Finding -Severity 'info' -Code 'ww-both-forms-detected' `
                -Message ('WorkWithForWeb ''{0}'' tem ambos Form A (babfa2b2) e Form B (a51ced48 com Data Pattern); coexistencia rara — preferindo Form A para leitura do Apply' -f $ww.Name) `
                -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                -TransactionName $null -Location $null -Form 'A+B'
        } elseif ($details.HasFormA) {
            $form = 'A'
        } else {
            $form = 'B'
        }

        # 4b. Apply property (so vale para Form A; Form B trata como implicito True)
        if ($form -eq 'A' -or $form -eq 'A+B') {
            if ($null -eq $details.ApplyValue) {
                $findings += New-Finding -Severity 'fail' -Code 'ww-form-a-apply-property-absent' `
                    -Message ('WorkWithForWeb ''{0}'' em Form A nao tem a Property Apply no Part babfa2b2; a IDE nao re-aplicara o pattern. Adicionar <Name>Apply</Name><Value>True</Value> antes de empacotar' -f $ww.Name) `
                    -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                    -TransactionName $null -Location $null -Form $form
                continue
            }
            if ($details.ApplyValue -ne 'True') {
                $findings += New-Finding -Severity 'warn' -Code 'ww-form-a-apply-false' `
                    -Message ('WorkWithForWeb ''{0}'' em Form A tem Apply=''{1}''; aplicacao do pattern desabilitada explicitamente. Confirmar se intencional antes de prosseguir' -f $ww.Name, $details.ApplyValue) `
                    -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                    -TransactionName $null -Location $null -Form $form
                # Continua para verificar linked TX mesmo assim, mas sem ABORT
            }
        }

        # 4c. Linked Transaction
        if ([string]::IsNullOrEmpty($details.LinkedTxName)) {
            $findings += New-Finding -Severity 'fail' -Code 'ww-linked-transaction-missing' `
                -Message ('WorkWithForWeb ''{0}'' (Form {1}) nao expoe nome da Transaction linkada de forma extraivel; nao foi possivel verificar Apply:GUID no destino' -f $ww.Name, $form) `
                -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                -TransactionName $null -Location $null -Form $form
            continue
        }

        # 4d. Apply:<GUID> na Transaction linkada
        $txKey = $details.LinkedTxName.ToLowerInvariant()
        if ($batchTransactions.ContainsKey($txKey)) {
            $tx = $batchTransactions[$txKey]
            $applyGuidVal = Get-TransactionApplyGuidValue $tx.Path
            if ($null -eq $applyGuidVal -or $applyGuidVal -ne 'True') {
                $stateDesc = if ($null -eq $applyGuidVal) { 'ausente' } else { "='$applyGuidVal'" }
                $findings += New-Finding -Severity 'fail' -Code 'ww-applyguid-false-batch' `
                    -Message ('Transaction ''{0}'' (linkada por WorkWithForWeb ''{1}'') esta no batch mas property ''{2}'' {3}; IDE nao re-aplicara o pattern ao salvar. Adicionar com Value=True antes de empacotar' -f $tx.Name, $ww.Name, $ApplyGuidProperty, $stateDesc) `
                    -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                    -TransactionName $tx.Name -Location 'batch' -Form $form
            } else {
                $findings += New-Finding -Severity 'info' -Code 'ww-applyguid-true-batch' `
                    -Message ('Transaction ''{0}'' (linkada por WorkWithForWeb ''{1}'') esta no batch com ''{2}=True''' -f $tx.Name, $ww.Name, $ApplyGuidProperty) `
                    -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                    -TransactionName $tx.Name -Location 'batch' -Form $form
            }
        } elseif ($corpusTransactions.ContainsKey($txKey)) {
            $tx = $corpusTransactions[$txKey]
            $applyGuidVal = Get-TransactionApplyGuidValue $tx.Path
            if ($null -eq $applyGuidVal -or $applyGuidVal -ne 'True') {
                $stateDesc = if ($null -eq $applyGuidVal) { 'ausente' } else { "='$applyGuidVal'" }
                $findings += New-Finding -Severity 'warn' -Code 'ww-applyguid-absent-corpus' `
                    -Message ('Transaction ''{0}'' (linkada por WorkWithForWeb ''{1}'') esta no corpus mas property ''{2}'' {3}; verificar se a KB de destino preservara o comportamento do pattern apos import' -f $tx.Name, $ww.Name, $ApplyGuidProperty, $stateDesc) `
                    -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                    -TransactionName $tx.Name -Location 'corpus' -Form $form
            } else {
                $findings += New-Finding -Severity 'info' -Code 'ww-applyguid-true-corpus' `
                    -Message ('Transaction ''{0}'' (linkada por WorkWithForWeb ''{1}'') ja esta no corpus com ''{2}=True''' -f $tx.Name, $ww.Name, $ApplyGuidProperty) `
                    -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                    -TransactionName $tx.Name -Location 'corpus' -Form $form
            }
        } else {
            $findings += New-Finding -Severity 'warn' -Code 'ww-applyguid-tx-missing' `
                -Message ('Transaction ''{0}'' (linkada por WorkWithForWeb ''{1}'') nao encontrada nem no batch nem no corpus; nao foi possivel confirmar ''{2}=True''. Documentar o gap antes de empacotar' -f $details.LinkedTxName, $ww.Name, $ApplyGuidProperty) `
                -WorkWithForWebName $ww.Name -WorkWithForWebFile $wwRel `
                -TransactionName $details.LinkedTxName -Location 'absent' -Form $form
        }
    }

    Write-Progress -Activity 'Test-GeneXusWorkWithWebApply' -Status 'Avaliacao concluida' -Completed
    # 5. Status agregado
    $hasFail = $findings | Where-Object { $_.severity -eq 'fail' } | Select-Object -First 1
    $hasWarn = $findings | Where-Object { $_.severity -eq 'warn' } | Select-Object -First 1
    if ($hasFail) { $status = 'fail' }
    elseif ($hasWarn) { $status = 'alert' }
    else { $status = 'pass' }
}

# 6. Emitir
$result = [pscustomobject]@{
    status                  = $status
    frontFolder             = $FrontFolder
    corpusFolder            = $CorpusFolder
    workWithForWebScanned   = $batchWWs.Count
    findings                = @($findings)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $status"
    Write-Output "frontFolder: $FrontFolder"
    Write-Output "corpusFolder: $CorpusFolder"
    Write-Output "workWithForWebScanned: $($batchWWs.Count)"
    if ($findings.Count -eq 0) {
        Write-Output "findings: (none)"
    } else {
        Write-Output "findings:"
        foreach ($finding in $findings) {
            Write-Output ('  - [{0}] {1}: {2}' -f $finding.severity, $finding.code, $finding.message)
            Write-Output ('    workwithforweb: {0} ({1}) [Form {2}]' -f $finding.workWithForWebName, $finding.workWithForWebFile, $finding.form)
            if (-not [string]::IsNullOrEmpty($finding.transactionName)) {
                Write-Output ('    transaction: {0} [{1}]' -f $finding.transactionName, $finding.location)
            }
        }
    }
}
