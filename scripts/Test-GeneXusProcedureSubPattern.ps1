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

# Catalogo de tipos canonico
$CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
if (-not (Test-Path -LiteralPath $CatalogPath)) {
    throw "Catalogo de tipos nao encontrado: $CatalogPath"
}
$Catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$ProcedureTypeGuid = $Catalog.types.Procedure.objectTypeGuid

# Source principal da Procedure (Part type confirmado empiricamente)
$SourcePartTypeGuid = '528d1c06-a9c2-420d-bd35-21dca83f12ff'

# Regex GeneXus (case-insensitive)
$RxSourcePart = [regex]::new(
    "<Part type=`"$([regex]::Escape($SourcePartTypeGuid))`">\s*<Source><!\[CDATA\[(?<src>.*?)\]\]></Source>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$RxSubBlock = [regex]::new(
    "\bSub\s+'(?<name>[^']+)'(?<body>.*?)\bEndSub\b",
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$RxForEach = [regex]::new('\bFor\s+each\b',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$RxDoCall  = [regex]::new("\bDo\s+'(?<name>[^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$RxLineComment  = [regex]::new('//[^\r\n]*')
$RxBlockComment = [regex]::new('/\*.*?\*/',
    [System.Text.RegularExpressions.RegexOptions]::Singleline)

function Strip-Comments {
    param([string]$Source)
    if ([string]::IsNullOrEmpty($Source)) { return '' }
    $stripped = $RxBlockComment.Replace($Source, '')
    return $RxLineComment.Replace($stripped, '')
}

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$ProcedureName,
        [string]$ProcedureFile,
        $DominantPattern,
        [string]$NewSubName,
        [string]$NewSubClass
    )
    return [pscustomobject]@{
        severity         = $Severity
        code             = $Code
        message          = $Message
        procedureName    = $ProcedureName
        procedureFile    = $ProcedureFile
        dominantPattern  = $DominantPattern
        newSubName       = $NewSubName
        newSubClass      = $NewSubClass
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

function Get-ProcedureSource {
    param([string]$XmlPath)
    $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    $match = $RxSourcePart.Match($text)
    if (-not $match.Success) { return '' }
    return $match.Groups['src'].Value
}

function Get-SubBlocks {
    param([string]$Source)
    $blocks = @()
    if ([string]::IsNullOrEmpty($Source)) { return ,$blocks }
    $clean = Strip-Comments $Source
    foreach ($m in $RxSubBlock.Matches($clean)) {
        $blocks += [pscustomobject]@{
            Name = $m.Groups['name'].Value
            Body = $m.Groups['body'].Value
        }
    }
    return ,$blocks
}

function Classify-Sub {
    param(
        [string]$Body,
        [string]$Name,
        [System.Collections.Generic.HashSet[string]]$NamesCalledByOthers
    )
    $hasForEach = $RxForEach.IsMatch($Body)
    $callsAnother = $false
    foreach ($call in $RxDoCall.Matches($Body)) {
        $callsAnother = $true
        break
    }
    if ($hasForEach -and $callsAnother) { return 'iteration-sub' }
    if (-not $hasForEach -and $NamesCalledByOthers.Contains($Name)) { return 'unit-sub' }
    return 'mixed'
}

function Identify-DominantPattern {
    param($Subs)
    if ($Subs.Count -lt 2) { return $null }

    # Mapear chamadas: NomeCallee -> chamado por alguem
    $calledByOthers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $Subs) {
        foreach ($call in $RxDoCall.Matches($s.Body)) {
            [void]$calledByOthers.Add($call.Groups['name'].Value)
        }
    }
    # Classificar cada Sub
    $classified = @()
    foreach ($s in $Subs) {
        $cls = Classify-Sub -Body $s.Body -Name $s.Name -NamesCalledByOthers $calledByOthers
        $classified += [pscustomobject]@{ Name = $s.Name; Class = $cls }
    }
    # Mapear pares iteration -> unit
    $pairs = @()
    foreach ($s in $Subs) {
        $thisClass = ($classified | Where-Object { $_.Name -eq $s.Name }).Class
        if ($thisClass -ne 'iteration-sub') { continue }
        foreach ($call in $RxDoCall.Matches($s.Body)) {
            $calleeName = $call.Groups['name'].Value
            $calleeClass = ($classified | Where-Object { $_.Name -eq $calleeName }).Class
            if ($calleeClass -eq 'unit-sub') {
                $pairs += [pscustomobject]@{ IterationSub = $s.Name; UnitSub = $calleeName }
            }
        }
    }
    if ($pairs.Count -eq 0) { return $null }
    # Conta quantas Subs distintas participam em pelo menos um par
    $participating = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $pairs) {
        [void]$participating.Add($p.IterationSub)
        [void]$participating.Add($p.UnitSub)
    }
    if ($participating.Count -lt [Math]::Ceiling($Subs.Count / 2.0)) { return $null }
    return [pscustomobject]@{
        IterationSub = $pairs[0].IterationSub
        UnitSub      = $pairs[0].UnitSub
        Classified   = $classified
        CalledByOthers = $calledByOthers
    }
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

# 1. Enumerar Procedures no FrontFolder
$batchProcedures = @()
foreach ($xml in (Get-ChildItem -LiteralPath $FrontFolder -Recurse -Filter *.xml -File)) {
    $meta = Get-ObjectMetadata $xml.FullName
    if ($null -eq $meta) { continue }
    if ($meta.TypeGuid -ne $ProcedureTypeGuid) { continue }
    if ([string]::IsNullOrEmpty($meta.Name)) { continue }
    $batchProcedures += $meta
}

$findings = @()
if ($batchProcedures.Count -eq 0) {
    $status = 'not-applicable'
} else {
    # 2. Indexar Procedures no corpus por nome (restringe a subpasta canonica Procedure/)
    $corpusProcedureFolder = Join-Path $CorpusFolder 'Procedure'
    if (-not (Test-Path -LiteralPath $corpusProcedureFolder -PathType Container)) {
        throw "Layout do CorpusFolder inesperado: subpasta 'Procedure' nao encontrada em $CorpusFolder; gate exige layout canonico <Type>/<Name>.xml gerado por Sync-GeneXusXpzToXml.ps1"
    }
    $corpusIndex = @{}
    $corpusXmls = @(Get-ChildItem -LiteralPath $corpusProcedureFolder -Recurse -Filter *.xml -File)
    $corpusTotal = $corpusXmls.Count
    $corpusSeen = 0
    foreach ($xml in $corpusXmls) {
        $corpusSeen++
        if (($corpusSeen % 250) -eq 0 -or $corpusSeen -eq $corpusTotal) {
            Write-Progress -Activity 'Test-GeneXusProcedureSubPattern' `
                -Status ('Indexando Procedures no corpus ({0}/{1})' -f $corpusSeen, $corpusTotal) `
                -PercentComplete ([int](100 * $corpusSeen / [Math]::Max($corpusTotal,1)))
        }
        $meta = Get-ObjectMetadata $xml.FullName
        if ($null -eq $meta) { continue }
        if ($meta.TypeGuid -ne $ProcedureTypeGuid) { continue }
        if ([string]::IsNullOrEmpty($meta.Name)) { continue }
        $corpusIndex[$meta.Name.ToLowerInvariant()] = $meta
    }
    Write-Progress -Activity 'Test-GeneXusProcedureSubPattern' -Status 'Indexacao corpus concluida' -Completed
    # 3. Avaliar cada Procedure no batch
    $procTotal = $batchProcedures.Count
    $procSeen = 0
    foreach ($proc in $batchProcedures) {
        $procSeen++
        Write-Progress -Activity 'Test-GeneXusProcedureSubPattern' `
            -Status ('Avaliando Procedure {0}/{1}: {2}' -f $procSeen, $procTotal, $proc.Name) `
            -PercentComplete ([int](100 * $procSeen / [Math]::Max($procTotal,1)))
        $procRel = [System.IO.Path]::GetRelativePath($FrontFolder, $proc.Path)
        $corpusMatch = $corpusIndex[$proc.Name.ToLowerInvariant()]
        if ($null -eq $corpusMatch) {
            $findings += New-Finding -Severity 'info' -Code 'psm-skip-procedure-new' `
                -Message "Procedure '$($proc.Name)' nao existe no corpus; sem baseline pre-delta para comparar" `
                -ProcedureName $proc.Name -ProcedureFile $procRel
            continue
        }
        $preSource  = Get-ProcedureSource $corpusMatch.Path
        $postSource = Get-ProcedureSource $proc.Path
        $preSubs  = Get-SubBlocks $preSource
        $postSubs = Get-SubBlocks $postSource
        if ($preSubs.Count -lt 2) {
            $findings += New-Finding -Severity 'info' -Code 'psm-skip-too-few-subs' `
                -Message "Procedure '$($proc.Name)' tem menos de 2 Subs no pre-delta; padrao dominante nao pode ser estabelecido" `
                -ProcedureName $proc.Name -ProcedureFile $procRel
            continue
        }
        $dominant = Identify-DominantPattern $preSubs
        if ($null -eq $dominant) {
            $findings += New-Finding -Severity 'info' -Code 'psm-skip-no-dominant-pattern' `
                -Message "Procedure '$($proc.Name)' nao tem padrao dominante iteration->unit no pre-delta" `
                -ProcedureName $proc.Name -ProcedureFile $procRel
            continue
        }
        $domSummary = [pscustomobject]@{
            iterationSub = $dominant.IterationSub
            unitSub      = $dominant.UnitSub
        }
        # Detectar novas Subs (presentes no batch, ausentes no pre-delta)
        $preNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($s in $preSubs) { [void]$preNames.Add($s.Name) }
        $postCalledByOthers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($s in $postSubs) {
            foreach ($call in $RxDoCall.Matches($s.Body)) {
                [void]$postCalledByOthers.Add($call.Groups['name'].Value)
            }
        }
        $procFindingsBefore = $findings.Count
        foreach ($newSub in $postSubs) {
            if ($preNames.Contains($newSub.Name)) { continue }
            $newClass = Classify-Sub -Body $newSub.Body -Name $newSub.Name -NamesCalledByOthers $postCalledByOthers
            if ($newClass -eq 'mixed') {
                $msg = "a procedure ja usa fluxo do tipo '$($dominant.IterationSub)' -> '$($dominant.UnitSub)'; a nova sub '$($newSub.Name)' mistura varredura e persistencia sem delegar para uma sub unitaria; considere espelhar o padrao dominante"
                $findings += New-Finding -Severity 'warn' -Code 'psm-new-sub-mixed-diverges' `
                    -Message $msg `
                    -ProcedureName $proc.Name -ProcedureFile $procRel `
                    -DominantPattern $domSummary -NewSubName $newSub.Name -NewSubClass $newClass
            } else {
                $findings += New-Finding -Severity 'info' -Code 'psm-new-sub-mirrors-pattern' `
                    -Message "Procedure '$($proc.Name)' introduz a Sub '$($newSub.Name)' classificada como $newClass, coerente com o padrao dominante" `
                    -ProcedureName $proc.Name -ProcedureFile $procRel `
                    -DominantPattern $domSummary -NewSubName $newSub.Name -NewSubClass $newClass
            }
        }
        if ($findings.Count -eq $procFindingsBefore) {
            $findings += New-Finding -Severity 'info' -Code 'psm-no-new-subs-detected' `
                -Message "Procedure '$($proc.Name)' tem padrao dominante '$($dominant.IterationSub)' -> '$($dominant.UnitSub)' identificado no pre-delta e nenhuma Sub nova foi introduzida no batch" `
                -ProcedureName $proc.Name -ProcedureFile $procRel `
                -DominantPattern $domSummary
        }
    }
    Write-Progress -Activity 'Test-GeneXusProcedureSubPattern' -Status 'Avaliacao concluida' -Completed
    # 4. Status agregado (gate advisory: nunca fail)
    $hasWarn = $findings | Where-Object { $_.severity -eq 'warn' } | Select-Object -First 1
    if ($hasWarn) { $status = 'alert' } else { $status = 'pass' }
}

# 5. Emitir
$result = [pscustomobject]@{
    status            = $status
    frontFolder       = $FrontFolder
    corpusFolder      = $CorpusFolder
    proceduresScanned = $batchProcedures.Count
    findings          = $findings
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    Write-Output "status: $status"
    Write-Output "frontFolder: $FrontFolder"
    Write-Output "corpusFolder: $CorpusFolder"
    Write-Output "proceduresScanned: $($batchProcedures.Count)"
    if ($findings.Count -eq 0) {
        Write-Output "findings: (none)"
    } else {
        Write-Output "findings:"
        foreach ($f in $findings) {
            Write-Output "  - [$($f.severity)] $($f.code): $($f.message)"
            Write-Output "    procedure: $($f.procedureName) ($($f.procedureFile))"
            if ($null -ne $f.dominantPattern) {
                Write-Output "    dominant pattern: $($f.dominantPattern.iterationSub) -> $($f.dominantPattern.unitSub)"
            }
            if (-not [string]::IsNullOrEmpty($f.newSubName)) {
                Write-Output "    new sub: $($f.newSubName) [$($f.newSubClass)]"
            }
        }
    }
}
