[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$ObjectXmlPaths,

    [Parameter(Mandatory = $true)]
    [string]$TemplatePackagePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string[]]$TopLevelAttributesXmlPaths,

    [Parameter(Mandatory = $true)]
    [string]$AcervoPath,

    [string[]]$ModifiedObjectNames,

    [string[]]$ModifiedObjectGuids,

    [ValidateRange(1, 3600)]
    [int]$FreshnessMarginSeconds = 60,

    [ValidateRange(0, 3600)]
    [int]$FutureToleranceSeconds = 120,

    [ValidateSet("pass", "warn", "block")]
    [string]$NewObjectPolicy = "warn",

    [switch]$SkipGate,

    [switch]$Force,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PanelObjectTypeGuid = "d82625fd-5892-40b0-99c9-5c8559c197fc"

function Resolve-NextRejectedPath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath
    )
    $letters = [char[]](65..90)
    foreach ($letter in $letters) {
        $candidate = "$BasePath.rejected.$letter"
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }
    throw "Limite de rejeicoes atingido: '$BasePath.rejected.A'..'.Z' ja existem. Limpar rejeicoes anteriores antes de tentar novamente."
}

function Assert-XmlWellFormed {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Role
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Role nao encontrado: $Path"
    }
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        $doc.LoadXml($raw)
    } catch {
        throw "$Role nao e XML bem-formado ('$Path'): $($_.Exception.Message)"
    }
    return $doc
}

function Format-GeneXusLastUpdate {
    param([Parameter(Mandatory = $true)][DateTime]$Value)

    return $Value.ToUniversalTime().ToString(
        "yyyy-MM-dd'T'HH:mm:ss'.0000000Z'",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Read-ObjectLastUpdate {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Root,
        [Parameter(Mandatory = $true)][string]$SourceLabel
    )

    $raw = $Root.GetAttribute("lastUpdate")
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "$SourceLabel sem Object/@lastUpdate."
    }

    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $raw,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed
    )
    if (-not $ok) {
        throw "$SourceLabel com Object/@lastUpdate invalido: '$raw'."
    }

    return $parsed.UtcDateTime
}

function Test-ObjectIdentityMatch {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Candidate,
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Baseline
    )

    $candidateGuid = $Candidate.GetAttribute("guid")
    $baselineGuid = $Baseline.GetAttribute("guid")
    if (-not [string]::IsNullOrWhiteSpace($candidateGuid) -and $candidateGuid -eq $baselineGuid) {
        return $true
    }

    $candidateFqn = $Candidate.GetAttribute("fullyQualifiedName")
    $baselineFqn = $Baseline.GetAttribute("fullyQualifiedName")
    if (-not [string]::IsNullOrWhiteSpace($candidateFqn) -and $candidateFqn -eq $baselineFqn) {
        return $true
    }

    $candidateName = $Candidate.GetAttribute("name")
    $baselineName = $Baseline.GetAttribute("name")
    if (-not [string]::IsNullOrWhiteSpace($candidateName) -and $candidateName -eq $baselineName) {
        return $true
    }

    return $false
}

function Find-BaselineObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$CandidateRoot
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        throw "AcervoPath nao encontrado ou nao e pasta: $RootPath"
    }

    $candidateNames = [System.Collections.Generic.List[string]]::new()
    foreach ($attrName in @("fullyQualifiedName", "name")) {
        $value = $CandidateRoot.GetAttribute($attrName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $candidateNames.Add($value) | Out-Null
        }
    }

    $candidateFiles = @()
    foreach ($candidateName in @($candidateNames | Select-Object -Unique)) {
        $leaf = "$candidateName.xml"
        $candidateFiles += @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue)
    }

    if ($candidateFiles.Count -eq 0) {
        $guid = $CandidateRoot.GetAttribute("guid")
        if (-not [string]::IsNullOrWhiteSpace($guid)) {
            $candidateFiles += @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter "*.xml" -ErrorAction SilentlyContinue | Select-String -SimpleMatch $guid | ForEach-Object { $_.Path } | Sort-Object -Unique | ForEach-Object { Get-Item -LiteralPath $_ })
        }
    }

    foreach ($file in @($candidateFiles | Sort-Object FullName -Unique)) {
        try {
            $doc = Assert-XmlWellFormed -Path $file.FullName -Role "BaselineObjectXml"
        } catch {
            continue
        }
        if ($doc.DocumentElement.LocalName -eq "Object" -and (Test-ObjectIdentityMatch -Candidate $CandidateRoot -Baseline $doc.DocumentElement)) {
            return $doc
        }
    }

    return $null
}

function Test-LastUpdateFreshness {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlDocument[]]$Docs,
        [Parameter(Mandatory = $true)][string]$BaselineRootPath
    )

    $checks = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $blockingReasons = [System.Collections.Generic.List[string]]::new()
    $nowUtc = [DateTime]::UtcNow
    $maxFuture = $nowUtc.AddSeconds($FutureToleranceSeconds)
    $modifiedNamesSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $modifiedGuidsSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($name in @($ModifiedObjectNames)) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            [void]$modifiedNamesSet.Add($name)
        }
    }
    foreach ($guid in @($ModifiedObjectGuids)) {
        if (-not [string]::IsNullOrWhiteSpace($guid)) {
            [void]$modifiedGuidsSet.Add($guid)
        }
    }

    foreach ($doc in $Docs) {
        $root = $doc.DocumentElement
        $name = $root.GetAttribute("name")
        $fqn = $root.GetAttribute("fullyQualifiedName")
        $guid = $root.GetAttribute("guid")
        $label = if (-not [string]::IsNullOrWhiteSpace($fqn)) { $fqn } elseif (-not [string]::IsNullOrWhiteSpace($name)) { $name } else { $guid }
        $candidateLastUpdate = Read-ObjectLastUpdate -Root $root -SourceLabel "ObjectXml '$label'"
        $isDeclaredModified = $modifiedNamesSet.Contains($name) -or $modifiedNamesSet.Contains($fqn) -or $modifiedGuidsSet.Contains($guid)
        $baselineDoc = Find-BaselineObjectXml -RootPath $BaselineRootPath -CandidateRoot $root

        if ($null -eq $baselineDoc) {
            $message = "last-update-baseline-missing: '$label' nao foi encontrado em AcervoPath; NewObjectPolicy=$NewObjectPolicy."
            if ($NewObjectPolicy -eq "block") {
                $blockingReasons.Add($message) | Out-Null
                $status = "fail"
            } elseif ($NewObjectPolicy -eq "warn") {
                $warnings.Add($message) | Out-Null
                $status = "warn"
            } else {
                $status = "pass"
            }
            $checks.Add([pscustomobject]@{
                objectName       = $name
                fullyQualifiedName = $fqn
                guid             = $guid
                role             = if ($isDeclaredModified) { "declared-modified" } else { "unclassified-or-new" }
                candidateLastUpdate = Format-GeneXusLastUpdate -Value $candidateLastUpdate
                baselineLastUpdate  = $null
                status           = $status
                code             = "baseline-missing"
            }) | Out-Null
            continue
        }

        $baselineLastUpdate = Read-ObjectLastUpdate -Root $baselineDoc.DocumentElement -SourceLabel "BaselineObjectXml '$label'"
        $minimumFreshLastUpdate = $baselineLastUpdate.AddSeconds($FreshnessMarginSeconds)
        $maxAllowedFuture = $maxFuture
        if ($minimumFreshLastUpdate -gt $maxAllowedFuture) {
            $maxAllowedFuture = $minimumFreshLastUpdate
        }
        $statusCode = "pass"
        $status = "pass"

        if ($candidateLastUpdate -lt $baselineLastUpdate) {
            $status = "fail"
            $statusCode = "older-than-baseline"
            $blockingReasons.Add("last-update-older-than-baseline: '$label' tem lastUpdate $(Format-GeneXusLastUpdate -Value $candidateLastUpdate), anterior ao acervo $(Format-GeneXusLastUpdate -Value $baselineLastUpdate).") | Out-Null
        } elseif ($candidateLastUpdate -eq $baselineLastUpdate) {
            if ($isDeclaredModified) {
                $status = "fail"
                $statusCode = "declared-modified-equals-baseline"
                $blockingReasons.Add("last-update-not-fresh: '$label' foi declarado como modificado, mas preserva lastUpdate igual ao acervo $(Format-GeneXusLastUpdate -Value $baselineLastUpdate).") | Out-Null
            } else {
                $status = "warn"
                $statusCode = "equals-baseline-presumed-preserved"
                $warnings.Add("last-update-preserved: '$label' preserva lastUpdate igual ao acervo; aceito apenas se for dependencia/objeto reenviado sem mudanca.") | Out-Null
            }
        } elseif ($isDeclaredModified -and $candidateLastUpdate -lt $minimumFreshLastUpdate) {
            $status = "fail"
            $statusCode = "declared-modified-below-freshness-margin"
            $blockingReasons.Add("last-update-margin-too-small: '$label' foi declarado como modificado, mas lastUpdate $(Format-GeneXusLastUpdate -Value $candidateLastUpdate) e menor que acervo + $FreshnessMarginSeconds segundos ($(Format-GeneXusLastUpdate -Value $minimumFreshLastUpdate)).") | Out-Null
        } elseif ((-not $isDeclaredModified) -and $candidateLastUpdate -gt $baselineLastUpdate -and $candidateLastUpdate -lt $minimumFreshLastUpdate) {
            $status = "warn"
            $statusCode = "freshness-margin-small-unclassified"
            $warnings.Add("last-update-margin-small: '$label' esta acima do acervo, mas abaixo de acervo + $FreshnessMarginSeconds segundos; se for objeto alterado, recalcular lastUpdate.") | Out-Null
        } elseif ($candidateLastUpdate -gt $maxAllowedFuture) {
            $status = "fail"
            $statusCode = "too-far-in-future"
            $blockingReasons.Add("last-update-too-far-in-future: '$label' tem lastUpdate $(Format-GeneXusLastUpdate -Value $candidateLastUpdate), maior que UtcNow + $FutureToleranceSeconds segundos e sem justificativa pelo acervo + margem.") | Out-Null
        }

        $checks.Add([pscustomobject]@{
            objectName       = $name
            fullyQualifiedName = $fqn
            guid             = $guid
            role             = if ($isDeclaredModified) { "declared-modified" } else { "unclassified-or-preserved" }
            candidateLastUpdate = Format-GeneXusLastUpdate -Value $candidateLastUpdate
            baselineLastUpdate  = Format-GeneXusLastUpdate -Value $baselineLastUpdate
            freshnessMarginSeconds = $FreshnessMarginSeconds
            futureToleranceSeconds = $FutureToleranceSeconds
            status           = $status
            code             = $statusCode
        }) | Out-Null
    }

    return [pscustomobject]@{
        checks          = $checks.ToArray()
        warnings        = $warnings.ToArray()
        blockingReasons = $blockingReasons.ToArray()
    }
}

function Read-TemplatePackage {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "TemplatePackage nao encontrado: $Path"
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -ne ".xpz" -and $extension -ne ".zip") {
        return (Assert-XmlWellFormed -Path $Path -Role "TemplatePackage")
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
    try {
        foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '\.xml$' } | Sort-Object FullName)) {
            $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
            try {
                $text = $reader.ReadToEnd()
            } finally {
                $reader.Dispose()
            }
            $doc = New-Object System.Xml.XmlDocument
            $doc.PreserveWhitespace = $true
            try {
                $doc.LoadXml($text)
            } catch {
                continue
            }
            if ($doc.DocumentElement.LocalName -eq "ExportFile") {
                return $doc
            }
        }
    } finally {
        $zip.Dispose()
    }

    throw "TemplatePackage XPZ nao contem XML com raiz 'ExportFile': $Path"
}

# 1 - validacao de entradas
if (-not $ObjectXmlPaths -or $ObjectXmlPaths.Count -eq 0) {
    throw "ObjectXmlPaths vazio: nenhum XML de objeto informado."
}

# 1a - gate de colisao de pacote (antes de qualquer escrita)
# Garante reserva determinista do _nn: se houver colisao, o script aborta sem
# materializar nada. Bypass intencional via -Force, alinhado a semantica ja
# existente de sobrescrita explicita.
if (-not $Force) {
    $collisionScript = Join-Path $PSScriptRoot "Test-XpzPackageCollision.ps1"
    if (-not (Test-Path -LiteralPath $collisionScript)) {
        throw "Gate de colisao nao encontrado em '$collisionScript'."
    }
    $absOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $leafName = Split-Path -Leaf $absOutputPath
    $nameMatch = [regex]::Match(
        $leafName,
        '^(?<front>.+)_(?<nn>\d+)\.import_file\.xml$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $nameMatch.Success) {
        throw "BLOCK: nome de OutputPath fora do padrao '<FrontPrefix>_<nn>.import_file.xml': $leafName"
    }
    $collisionFront = $nameMatch.Groups['front'].Value
    $collisionNN    = $nameMatch.Groups['nn'].Value
    $collisionDir   = Split-Path -Parent $absOutputPath
    if (-not (Test-Path -LiteralPath $collisionDir -PathType Container)) {
        New-Item -ItemType Directory -Path $collisionDir -Force | Out-Null
    }
    & $collisionScript -FrontPrefix $collisionFront -NN $collisionNN -OutputDir $collisionDir | Out-Null
}

if (Test-Path -LiteralPath $OutputPath) {
    if (-not $Force) {
        throw "OutputPath ja existe: '$OutputPath'. Use -Force para sobrescrever."
    }
    Remove-Item -LiteralPath $OutputPath -Force
}

$templateDoc = Read-TemplatePackage -Path $TemplatePackagePath
if ($templateDoc.DocumentElement.LocalName -ne "ExportFile") {
    throw "TemplatePackage nao tem raiz 'ExportFile': raiz encontrada '$($templateDoc.DocumentElement.LocalName)'."
}

$templateRoot = $templateDoc.DocumentElement
$templateBlocks = @{}
foreach ($name in @("KMW", "Source", "Attributes", "Dependencies", "ObjectsIdentityMapping")) {
    $node = $templateRoot.SelectSingleNode("./$name")
    if ($null -ne $node) {
        $templateBlocks[$name] = $node
    }
}
foreach ($required in @("KMW", "Source")) {
    if (-not $templateBlocks.ContainsKey($required)) {
        throw "TemplatePackage nao contem bloco obrigatorio '<$required>'."
    }
}

# 2 - validacao previa dos XMLs de objeto (cada um deve carregar isoladamente)
$objectDocs = @()
foreach ($path in $ObjectXmlPaths) {
    $objectDocs += (Assert-XmlWellFormed -Path $path -Role "ObjectXml")
}

$lastUpdateFreshness = Test-LastUpdateFreshness -Docs $objectDocs -BaselineRootPath $AcervoPath
if (@($lastUpdateFreshness.blockingReasons).Count -gt 0) {
    throw "BLOCK: lastUpdate invalido antes do empacotamento. $(@($lastUpdateFreshness.blockingReasons) -join ' | ')"
}

$panelObjectNames = @(
    $objectDocs |
        Where-Object { $_.DocumentElement.GetAttribute("type").ToLowerInvariant() -eq $PanelObjectTypeGuid } |
        ForEach-Object { $_.DocumentElement.GetAttribute("name") }
)

$attributeDocs = @()
if ($TopLevelAttributesXmlPaths -and $TopLevelAttributesXmlPaths.Count -gt 0) {
    foreach ($path in $TopLevelAttributesXmlPaths) {
        $attributeDocs += (Assert-XmlWellFormed -Path $path -Role "TopLevelAttributeXml")
    }
}

# 3 - montagem do novo documento
$outDoc = New-Object System.Xml.XmlDocument
$outDoc.PreserveWhitespace = $false

$xmlDecl = $outDoc.CreateXmlDeclaration("1.0", "UTF-8", $null)
[void]$outDoc.AppendChild($xmlDecl)

$newRoot = $outDoc.CreateElement("ExportFile")
foreach ($attr in $templateRoot.Attributes) {
    $copiedAttr = $outDoc.CreateAttribute($attr.Name)
    $copiedAttr.Value = $attr.Value
    [void]$newRoot.Attributes.Append($copiedAttr)
}
[void]$outDoc.AppendChild($newRoot)

# 3a - KMW e Source clonados do template
foreach ($name in @("KMW", "Source")) {
    $imported = $outDoc.ImportNode($templateBlocks[$name], $true)
    [void]$newRoot.AppendChild($imported)
}

# 3b - <Objects> com cada objeto via ImportNode(DocumentElement) — sem prologo interno
$objectsElement = $outDoc.CreateElement("Objects")
[void]$newRoot.AppendChild($objectsElement)
foreach ($doc in $objectDocs) {
    $imported = $outDoc.ImportNode($doc.DocumentElement, $true)
    [void]$objectsElement.AppendChild($imported)
}

# 3c - <Attributes> top-level: explicito vence; senao, clonar do template quando existir
$topLevelAttrSource = "none"
if ($attributeDocs.Count -gt 0) {
    $attributesElement = $outDoc.CreateElement("Attributes")
    [void]$newRoot.AppendChild($attributesElement)
    foreach ($doc in $attributeDocs) {
        $imported = $outDoc.ImportNode($doc.DocumentElement, $true)
        [void]$attributesElement.AppendChild($imported)
    }
    $topLevelAttrSource = "explicit"
} elseif ($templateBlocks.ContainsKey("Attributes")) {
    $imported = $outDoc.ImportNode($templateBlocks["Attributes"], $true)
    [void]$newRoot.AppendChild($imported)
    $topLevelAttrSource = "template"
}

# 3d - Dependencies clonado (ou vazio se template nao tiver)
if ($templateBlocks.ContainsKey("Dependencies")) {
    $imported = $outDoc.ImportNode($templateBlocks["Dependencies"], $true)
    [void]$newRoot.AppendChild($imported)
} else {
    $depElement = $outDoc.CreateElement("Dependencies")
    [void]$newRoot.AppendChild($depElement)
}

# 3e - ObjectsIdentityMapping clonado (warn-only quando template nao tem)
if ($templateBlocks.ContainsKey("ObjectsIdentityMapping")) {
    $imported = $outDoc.ImportNode($templateBlocks["ObjectsIdentityMapping"], $true)
    [void]$newRoot.AppendChild($imported)
}

# 4 - serializacao para arquivo
$outputDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrEmpty($outputDir) -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$writerSettings = New-Object System.Xml.XmlWriterSettings
$writerSettings.Encoding = New-Object System.Text.UTF8Encoding($false)
$writerSettings.Indent = $true
$writerSettings.IndentChars = "  "
$writerSettings.OmitXmlDeclaration = $false
$writerSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

$writer = [System.Xml.XmlWriter]::Create($OutputPath, $writerSettings)
try {
    $outDoc.Save($writer)
} finally {
    $writer.Close()
}

$buildResult = [ordered]@{
    outputPath        = (Resolve-Path -LiteralPath $OutputPath).Path
    templatePackage   = (Resolve-Path -LiteralPath $TemplatePackagePath).Path
    objectCount       = $objectDocs.Count
    topLevelAttrCount = $attributeDocs.Count
    topLevelAttrSource = $topLevelAttrSource
    lastUpdateFreshness = $lastUpdateFreshness
    gateStatus        = $null
    gateInvoked       = (-not $SkipGate.IsPresent)
    blockingReasons   = @()
    warnings          = @(
        @($lastUpdateFreshness.warnings)
        if ($panelObjectNames.Count -gt 0) {
            "panel-level-layout-coupling: Panel detectado no pacote ($((@($panelObjectNames) | Sort-Object -Unique) -join ', ')); para Panel SD, nao gerar level id e layout id como GUIDs independentes. Usar par coerente vindo de template real exportado pela IDE da mesma KB quando a regra de derivacao nao estiver provada."
        }
    )
    rejectedPath      = $null
    status            = "apto para prosseguir"
}

# 5 - gate final (default)
if (-not $SkipGate) {
    $gateScript = Join-Path $PSScriptRoot "Test-GeneXusImportFileEnvelope.ps1"
    if (-not (Test-Path -LiteralPath $gateScript)) {
        throw "Gate nao encontrado em '$gateScript'. Use -SkipGate apenas se souber o que esta fazendo."
    }
    $gateResult = & $gateScript -InputPath $OutputPath
    $buildResult.gateStatus      = $gateResult.status
    $buildResult.blockingReasons = @($gateResult.blockingReasons)
    $buildResult.warnings        = @($buildResult.warnings + $gateResult.warnings | Sort-Object -Unique)
    $buildResult.status          = $gateResult.status

    if ($gateResult.status -eq "não apto para prosseguir") {
        $rejected = Resolve-NextRejectedPath -BasePath $OutputPath
        Move-Item -LiteralPath $OutputPath -Destination $rejected -Force
        $buildResult.rejectedPath = $rejected
        $buildResult.outputPath   = $null
    }
}

if ($AsJson) {
    $buildResult | ConvertTo-Json -Depth 6
} else {
    [pscustomobject]$buildResult
}
