[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$ObjectXmlPaths,

    [Parameter(Mandatory = $true)]
    [string]$TemplatePackagePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string[]]$TopLevelAttributesXmlPaths,

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
    gateStatus        = $null
    gateInvoked       = (-not $SkipGate.IsPresent)
    blockingReasons   = @()
    warnings          = @(
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
