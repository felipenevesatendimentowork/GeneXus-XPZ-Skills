#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string]$PanelReferencePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap {
    [ordered]@{
        inputPath = $InputPath
        status = 'não apto para prosseguir'
        exitCode = 20
        xmlWellFormed = $false
        rootElement = $null
        checks = [ordered]@{}
        blockingReasons = @($_.Exception.Message)
        warnings = @()
        information = @()
    } | ConvertTo-Json -Depth 6
    exit 20
}

$GuidPattern        = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
$PlaceholderPattern = '(?i)(YOUR[-_]GUID|GUID[-_]HERE|PLACEHOLDER|TODO[-_]GUID|INSERT[-_]HERE|OBJECT[-_]HERE)'
$PanelObjectTypeGuid = 'd82625fd-5892-40b0-99c9-5c8559c197fc'

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message
    )
    return [pscustomobject]@{
        severity = $Severity
        code     = $Code
        message  = $Message
    }
}

function Get-PanelLevelLayoutPairs {
    param([System.Xml.XmlElement]$ObjectNode)

    $pairs = [System.Collections.Generic.List[string]]::new()
    foreach ($payloadNode in @($ObjectNode.SelectNodes(".//Data|.//Source"))) {
        $payload = $payloadNode.InnerText
        foreach ($match in [regex]::Matches(
            $payload,
            '<(?:level|Level)\b[^>]*(?:id|guid)="(?<level>[^"]+)"[\s\S]*?<(?:layout|Layout)\b[^>]*(?:id|guid)="(?<layout>[^"]+)"',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )) {
            [void]$pairs.Add(("{0}|{1}" -f $match.Groups["level"].Value, $match.Groups["layout"].Value))
        }
    }
    return @($pairs | Sort-Object -Unique)
}

function Get-PanelReferencePairs {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @()
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "PanelReferencePath not found: $Path"
    }
    $referenceDoc = $null
    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -eq ".xpz" -or $extension -eq ".zip") {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
        try {
            foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '\.xml$' } | Sort-Object FullName)) {
                $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
                try { $referenceText = $reader.ReadToEnd() } finally { $reader.Dispose() }
                $candidateDoc = New-Object System.Xml.XmlDocument
                try { $candidateDoc.LoadXml($referenceText) } catch { continue }
                if ($candidateDoc.DocumentElement.LocalName -eq "ExportFile") {
                    $referenceDoc = $candidateDoc
                    break
                }
            }
        } finally {
            $zip.Dispose()
        }
        if ($null -eq $referenceDoc) {
            throw "PanelReferencePath XPZ does not contain an ExportFile XML: $Path"
        }
    } else {
        $referenceText = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        $referenceDoc = New-Object System.Xml.XmlDocument
        $referenceDoc.PreserveWhitespace = $true
        $referenceDoc.LoadXml($referenceText)
    }
    $referenceObjects = @()
    if ($referenceDoc.DocumentElement.LocalName -eq "Object") {
        $referenceObjects = @($referenceDoc.DocumentElement)
    } elseif ($referenceDoc.DocumentElement.LocalName -eq "ExportFile") {
        $referenceObjects = @($referenceDoc.DocumentElement.SelectNodes("./Objects/Object"))
    }
    $referencePairs = [System.Collections.Generic.List[string]]::new()
    foreach ($referenceObject in $referenceObjects) {
        if ($referenceObject.GetAttribute("type").ToLowerInvariant() -eq $PanelObjectTypeGuid) {
            foreach ($pair in @(Get-PanelLevelLayoutPairs -ObjectNode $referenceObject)) {
                [void]$referencePairs.Add($pair)
            }
        }
    }
    return @($referencePairs | Sort-Object -Unique)
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "InputPath not found: $InputPath"
}

$rawXml = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8

$result = [ordered]@{
    inputPath       = (Resolve-Path -LiteralPath $InputPath).Path
    status          = "não apto para prosseguir"
    xmlWellFormed   = $false
    rootElement     = $null
    checks          = [ordered]@{
        xmlWellFormed             = $false
        rootIsExportFile          = $false
        requiredBlocksPresent     = $false
        noEmbeddedXmlDeclaration  = $false
        noTextContentInObjects    = $false
        objectsNotEmpty           = $false
        noPlaceholderContent      = $false
        objectGuidsValid          = $false
        sourceGuidsPresent        = $false
    }
    objectCount     = 0
    blockingReasons = @()
    warnings        = @()
    information     = @()
}

$allFindings = [System.Collections.Generic.List[object]]::new()

# Camada 1 - XML bem-formado
try {
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.PreserveWhitespace = $true
    $xmlDoc.LoadXml($rawXml)
    $result.xmlWellFormed = $true
    $result.checks.xmlWellFormed = $true
    $result.rootElement = $xmlDoc.DocumentElement.LocalName
} catch {
    $allFindings.Add((New-Finding -Severity "fail" -Code "xml-parse" `
        -Message "XML malformado: $($_.Exception.Message)")) | Out-Null
    $result.blockingReasons = @($allFindings | Where-Object { $_.severity -eq "fail" } |
        ForEach-Object { "$($_.code): $($_.message)" })
    $result | ConvertTo-Json -Depth 6
    return
}

$root = $xmlDoc.DocumentElement

# Camada 2 - raiz ExportFile
if ($root.LocalName -ne "ExportFile") {
    $allFindings.Add((New-Finding -Severity "fail" -Code "root-not-export-file" `
        -Message "Raiz esperada 'ExportFile'; encontrada '$($root.LocalName)'.")) | Out-Null
} else {
    $result.checks.rootIsExportFile = $true
}

# Camada 3 - blocos obrigatórios
$missingBlocks = [System.Collections.Generic.List[string]]::new()
foreach ($block in @("KMW", "Source", "Objects", "Dependencies")) {
    if ($null -eq $root.SelectSingleNode("./$block")) {
        $missingBlocks.Add($block) | Out-Null
        $allFindings.Add((New-Finding -Severity "fail" -Code "missing-$($block.ToLower())" `
            -Message "Bloco obrigatorio '<$block>' ausente no envelope.")) | Out-Null
    }
}
if ($missingBlocks.Count -eq 0) {
    $result.checks.requiredBlocksPresent = $true
}

if ($null -eq $root.SelectSingleNode("./ObjectsIdentityMapping")) {
    $allFindings.Add((New-Finding -Severity "warn" -Code "missing-identity-mapping" `
        -Message "'<ObjectsIdentityMapping>' ausente — verificar se o padrao local da KB exige este bloco.")) | Out-Null
}

# Camada 4 - Source/@kb e Source/Version/@guid
$sourceNode = $root.SelectSingleNode("./Source")
if ($null -ne $sourceNode) {
    $kbGuid      = $sourceNode.GetAttribute("kb")
    $versionNode = $sourceNode.SelectSingleNode("./Version")
    $versionGuid = if ($null -ne $versionNode) { $versionNode.GetAttribute("guid") } else { $null }

    $sourceGuidsOk = $true

    if ([string]::IsNullOrEmpty($kbGuid)) {
        $allFindings.Add((New-Finding -Severity "fail" -Code "source-kb-missing" `
            -Message "'Source/@kb' ausente ou vazio.")) | Out-Null
        $sourceGuidsOk = $false
    } elseif ($kbGuid -notmatch $GuidPattern) {
        $allFindings.Add((New-Finding -Severity "fail" -Code "source-kb-not-guid" `
            -Message "'Source/@kb' presente mas nao esta em formato GUID: '$kbGuid'.")) | Out-Null
        $sourceGuidsOk = $false
    }

    if ($null -eq $versionNode) {
        $allFindings.Add((New-Finding -Severity "fail" -Code "source-version-missing" `
            -Message "'Source/Version' ausente.")) | Out-Null
        $sourceGuidsOk = $false
    } elseif ([string]::IsNullOrEmpty($versionGuid)) {
        $allFindings.Add((New-Finding -Severity "fail" -Code "source-version-guid-missing" `
            -Message "'Source/Version/@guid' ausente ou vazio.")) | Out-Null
        $sourceGuidsOk = $false
    } elseif ($versionGuid -notmatch $GuidPattern) {
        $allFindings.Add((New-Finding -Severity "fail" -Code "source-version-guid-not-guid" `
            -Message "'Source/Version/@guid' presente mas nao esta em formato GUID: '$versionGuid'.")) | Out-Null
        $sourceGuidsOk = $false
    }

    if ($sourceGuidsOk) {
        $result.checks.sourceGuidsPresent = $true
    }
}

# Camada 5 - conteúdo de Objects
$objectsNode = $root.SelectSingleNode("./Objects")
if ($null -ne $objectsNode) {

    $childElements = @($objectsNode.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] })
    $textNodes     = @($objectsNode.ChildNodes | Where-Object {
        $_ -is [System.Xml.XmlText] -and -not [string]::IsNullOrWhiteSpace($_.Value)
    })
    $piNodes       = @($objectsNode.ChildNodes | Where-Object { $_ -is [System.Xml.XmlProcessingInstruction] })

    # 5a - Objects não vazio
    if ($childElements.Count -eq 0 -and $textNodes.Count -eq 0) {
        $allFindings.Add((New-Finding -Severity "fail" -Code "objects-empty" `
            -Message "'<Objects>' nao contem nenhum objeto; verificar se o XML do objeto foi embutido corretamente.")) | Out-Null
    } else {
        $result.checks.objectsNotEmpty = $true
    }

    # 5b - sem texto solto (objeto embutido como string em vez de XML)
    if ($textNodes.Count -gt 0) {
        $preview = $textNodes[0].Value.Trim()
        if ($preview.Length -gt 120) { $preview = $preview.Substring(0, 120) + "..." }
        $allFindings.Add((New-Finding -Severity "fail" -Code "objects-text-content" `
            -Message "'<Objects>' contem texto solto em vez de elemento XML — o objeto pode ter sido embutido como string. Preview: $preview")) | Out-Null
    } else {
        $result.checks.noTextContentInObjects = $true
    }

    # 5c - sem processing instruction de declaracao XML dentro de Objects
    if ($piNodes.Count -gt 0) {
        foreach ($pi in $piNodes) {
            $allFindings.Add((New-Finding -Severity "fail" -Code "objects-xml-declaration" `
                -Message "'<Objects>' contem declaracao XML interna '<?$($pi.Target) ...' — remover antes de empacotar.")) | Out-Null
        }
    } else {
        $result.checks.noEmbeddedXmlDeclaration = $true
    }

    # 5d - GUIDs e placeholders nos elementos de objeto.
    # Nomes de objetos GeneXus podem conter "PlaceHolder" legitimamente; apenas GUID placeholder bloqueia.
    $result.objectCount = $childElements.Count
    $allGuidsValid  = $true
    $noPlaceholder  = $true
    $panelNames      = [System.Collections.Generic.List[string]]::new()
    $panelPairs      = [System.Collections.Generic.List[string]]::new()

    foreach ($objNode in $childElements) {
        $objGuid = $objNode.GetAttribute("guid")
        $objName = $objNode.GetAttribute("name")
        $nodeTag = $objNode.LocalName
        $objType = $objNode.GetAttribute("type")

        if ($nodeTag -ne "Object") {
            $allFindings.Add((New-Finding -Severity "fail" -Code "objects-invalid-child-element" `
                -Message "'<Objects>' deve conter apenas elementos '<Object>'; encontrado '<$nodeTag>' (name='$objName').")) | Out-Null
            $allGuidsValid = $false
        }

        if ([string]::IsNullOrEmpty($objGuid)) {
            $allFindings.Add((New-Finding -Severity "fail" -Code "object-guid-missing" `
                -Message "Elemento '<$nodeTag>' (name='$objName') sem atributo 'guid'.")) | Out-Null
            $allGuidsValid = $false
        } elseif ($objGuid -match $PlaceholderPattern) {
            $allFindings.Add((New-Finding -Severity "fail" -Code "object-guid-placeholder" `
                -Message "Elemento '<$nodeTag>' (name='$objName'): guid='$objGuid' parece ser texto de placeholder.")) | Out-Null
            $allGuidsValid = $false
            $noPlaceholder = $false
        } elseif ($objGuid -notmatch $GuidPattern) {
            $allFindings.Add((New-Finding -Severity "fail" -Code "object-guid-invalid" `
                -Message "Elemento '<$nodeTag>' (name='$objName'): guid='$objGuid' nao esta em formato GUID valido.")) | Out-Null
            $allGuidsValid = $false
        }

        if (-not [string]::IsNullOrEmpty($objName) -and $objName -match $PlaceholderPattern) {
            $allFindings.Add((New-Finding -Severity "warn" -Code "object-name-placeholder" `
                -Message "Elemento '<$nodeTag>': name='$objName' parece ser texto de placeholder.")) | Out-Null
        }

        if ([string]::IsNullOrEmpty($objName)) {
            $allFindings.Add((New-Finding -Severity "warn" -Code "object-name-missing" `
                -Message "Elemento '<$nodeTag>' sem atributo 'name'.")) | Out-Null
        }

        if ($objType.ToLowerInvariant() -eq $PanelObjectTypeGuid) {
            [void]$panelNames.Add($objName)
            foreach ($pair in @(Get-PanelLevelLayoutPairs -ObjectNode $objNode)) {
                [void]$panelPairs.Add($pair)
            }
        }
    }

    if ($panelNames.Count -gt 0) {
        $referencePairs = @(Get-PanelReferencePairs -Path $PanelReferencePath)
        $confirmedPairs = @($panelPairs | Sort-Object -Unique | Where-Object { $referencePairs -contains $_ })
        if ($confirmedPairs.Count -gt 0) {
            $allFindings.Add((New-Finding -Severity "info" -Code "panel-level-layout-confirmed" `
                -Message ("Panel detectado no pacote ({0}); par level/layout confirmado em referencia comparavel informada." -f (($panelNames | Sort-Object -Unique) -join ", ")))) | Out-Null
        } elseif (-not [string]::IsNullOrWhiteSpace($PanelReferencePath)) {
            $allFindings.Add((New-Finding -Severity "warn" -Code "panel-level-layout-suspicious" `
                -Message ("Panel detectado no pacote ({0}); nenhum par level/layout do pacote foi localizado na referencia comparavel informada. Revisar contra Panel SD exportado pela IDE da mesma KB." -f (($panelNames | Sort-Object -Unique) -join ", ")))) | Out-Null
        } else {
            $allFindings.Add((New-Finding -Severity "warn" -Code "panel-level-layout-unverified" `
                -Message ("Panel detectado no pacote ({0}); sem referencia comparavel para confirmar o par level/layout. Para Panel SD, nao gerar GUIDs independentes; preservar par de template real exportado pela IDE da mesma KB." -f (($panelNames | Sort-Object -Unique) -join ", ")))) | Out-Null
        }
    }

    if ($allGuidsValid) {
        $result.checks.objectGuidsValid = $true
    }
    if ($noPlaceholder -and $textNodes.Count -eq 0) {
        $result.checks.noPlaceholderContent = $true
    }
}

# Resultado final
$failFindings = @($allFindings | Where-Object { $_.severity -eq "fail" })
$warnFindings = @($allFindings | Where-Object { $_.severity -eq "warn" })
$infoFindings = @($allFindings | Where-Object { $_.severity -eq "info" })

$result.blockingReasons = @($failFindings | ForEach-Object { "$($_.code): $($_.message)" })
$result.warnings        = @($warnFindings | ForEach-Object { "$($_.code): $($_.message)" })
$result.information     = @($infoFindings | ForEach-Object { "$($_.code): $($_.message)" })

if ($failFindings.Count -eq 0 -and $warnFindings.Count -eq 0) {
    $result.status = "apto para prosseguir"
} elseif ($failFindings.Count -eq 0) {
    $result.status = "apto com ressalvas"
} else {
    $result.status = "não apto para prosseguir"
}

$result | ConvertTo-Json -Depth 6
