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

# Catalogo canonico de tipos
$CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
if (-not (Test-Path -LiteralPath $CatalogPath)) {
    throw "Catalogo de tipos nao encontrado: $CatalogPath"
}
$Catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$ProcedureTypeGuid       = $Catalog.types.Procedure.objectTypeGuid
$TransactionTypeGuid     = $Catalog.types.Transaction.objectTypeGuid
$WorkWithForWebTypeGuid  = $Catalog.types.WorkWithForWeb.objectTypeGuid

# Part type do Source principal de Procedure (confirmado em sub-fase 1.3)
$SourcePartTypeGuid = '528d1c06-a9c2-420d-bd35-21dca83f12ff'

# Regex
$VariableRegex      = [regex]::new('<Variable\b(?<attrs>[^>]*)>(?<body>.*?)</Variable>',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                                   [System.Text.RegularExpressions.RegexOptions]::Singleline)
$AttCustomTypeRegex = [regex]::new('<Property>\s*<Name>ATTCUSTOMTYPE</Name>\s*<Value>(?<value>.*?)</Value>\s*</Property>',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                                   [System.Text.RegularExpressions.RegexOptions]::Singleline)
$SourcePartRegex    = [regex]::new(
    "<Part type=`"$([regex]::Escape($SourcePartTypeGuid))`">\s*<Source><!\[CDATA\[(?<src>.*?)\]\]></Source>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$LineCommentRegex   = [regex]::new('//[^\r\n]*')
$BlockCommentRegex  = [regex]::new('/\*.*?\*/',
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
$CallExplicitRegex  = [regex]::new('\bCall\s*\(\s*(?<name>[A-Za-z_][A-Za-z0-9_]*)',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$CallDirectRegex    = [regex]::new('(?<![A-Za-z0-9_\.])(?<name>[A-Za-z_][A-Za-z0-9_]+)\s*\(',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

# Palavras-chave GeneXus que NAO sao procedures (filtro de falso-positivo do CallDirectRegex)
$GxKeywords = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($kw in @('if','else','elseif','endif','for','each','endfor','do','case','endcase',
                  'when','where','not','and','or','new','true','false','null','return',
                  'call','commit','rollback','sub','endsub','event','endevent',
                  'defined','is','in','like','between','order','print','exit',
                  'while','endwhile','repeat','until','then','endsub',
                  'iif','format','str','val','trim','upper','lower','left','right',
                  'isempty','isnull','today','now','min','max','round','int','dec',
                  'count','sum','avg','find','update','insert','delete','load','save','check')) {
    [void]$GxKeywords.Add($kw)
}

function Normalize-CustomType {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return '' }
    $unescaped = [System.Net.WebUtility]::HtmlDecode($Value).Trim()
    $stripped  = ($unescaped -split '//', 2)[0].Trim()
    return ($stripped -split '\s+' -join ' ')
}

function Strip-Comments {
    param([string]$Source)
    if ([string]::IsNullOrEmpty($Source)) { return '' }
    $stripped = $BlockCommentRegex.Replace($Source, '')
    return $LineCommentRegex.Replace($stripped, '')
}

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string[]]$InvolvedObjects
    )
    return [pscustomobject]@{
        severity        = $Severity
        code            = $Code
        message         = $Message
        involvedObjects = @($InvolvedObjects)
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

function Get-BCDependencies {
    param([string]$XmlPath)
    $deps = @()
    $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    foreach ($varMatch in $VariableRegex.Matches($text)) {
        $body = $varMatch.Groups['body'].Value
        $ctMatch = $AttCustomTypeRegex.Match($body)
        if (-not $ctMatch.Success) { continue }
        $ct = Normalize-CustomType $ctMatch.Groups['value'].Value
        if (-not $ct.ToLowerInvariant().StartsWith('bc:')) { continue }
        $fullName = ($ct.Substring(3)).Trim()
        if ([string]::IsNullOrEmpty($fullName)) { continue }
        # Para 9-IDO, so a Transaction principal interessa
        $mainTxName = (@($fullName -split '\.'))[0]
        $deps += $mainTxName
    }
    return ,@($deps)
}

function Get-ProcedureCalls {
    param(
        [string]$XmlPath,
        [System.Collections.Generic.HashSet[string]]$BatchProcedureNames
    )
    $callees = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    $sourceMatch = $SourcePartRegex.Match($text)
    if (-not $sourceMatch.Success) { return ,@() }
    $source = Strip-Comments $sourceMatch.Groups['src'].Value
    # Call() explicito
    foreach ($m in $CallExplicitRegex.Matches($source)) {
        $name = $m.Groups['name'].Value
        if ($BatchProcedureNames.Contains($name)) { [void]$callees.Add($name) }
    }
    # Chamada direta Nome(args) - filtrar keywords e os do batch
    foreach ($m in $CallDirectRegex.Matches($source)) {
        $name = $m.Groups['name'].Value
        if ($GxKeywords.Contains($name)) { continue }
        if ($BatchProcedureNames.Contains($name)) { [void]$callees.Add($name) }
    }
    return ,@($callees)
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

# 1. Enumerar objetos no batch
$batchObjects = @()  # lista de meta
$batchByName  = @{}  # name (lower) -> meta
foreach ($xml in (Get-ChildItem -LiteralPath $FrontFolder -Recurse -Filter *.xml -File)) {
    $meta = Get-ObjectMetadata $xml.FullName
    if ($null -eq $meta -or [string]::IsNullOrEmpty($meta.Name)) { continue }
    $batchObjects += $meta
    $batchByName[$meta.Name.ToLowerInvariant()] = $meta
}

# 2. Status not-applicable se menos de 2 objetos distintos
$findings = @()
$edges = @()
$layers = $null
$cycle = $null
if ($batchObjects.Count -lt 2) {
    $status = 'not-applicable'
} else {
    # 3. Identificar Procedures no batch e Procedures no corpus (para distinguir "novas")
    $batchProcedureNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $batchTransactionNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $batchWorkWithForWeb = @()
    foreach ($obj in $batchObjects) {
        if ($obj.TypeGuid -eq $ProcedureTypeGuid)   { [void]$batchProcedureNames.Add($obj.Name) }
        elseif ($obj.TypeGuid -eq $TransactionTypeGuid) { [void]$batchTransactionNames.Add($obj.Name) }
        elseif ($obj.TypeGuid -eq $WorkWithForWebTypeGuid) { $batchWorkWithForWeb += $obj }
    }
    # Procedures que existem no corpus (necessario para distinguir "Procedure nova") — restringe a subpasta canonica Procedure/
    $corpusProcedureFolder = Join-Path $CorpusFolder 'Procedure'
    if (-not (Test-Path -LiteralPath $corpusProcedureFolder -PathType Container)) {
        throw "Layout do CorpusFolder inesperado: subpasta 'Procedure' nao encontrada em $CorpusFolder; gate exige layout canonico <Type>/<Name>.xml gerado por Sync-GeneXusXpzToXml.ps1"
    }
    $corpusProcedureNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($xml in (Get-ChildItem -LiteralPath $corpusProcedureFolder -Recurse -Filter *.xml -File)) {
        $meta = Get-ObjectMetadata $xml.FullName
        if ($null -eq $meta) { continue }
        if ($meta.TypeGuid -ne $ProcedureTypeGuid) { continue }
        if ([string]::IsNullOrEmpty($meta.Name)) { continue }
        [void]$corpusProcedureNames.Add($meta.Name)
    }

    # 4. Construir grafo
    # Cada no = nome do objeto (case-insensitive lookup)
    # edges: lista de @{ From=...; To=...; Kind=... }
    foreach ($obj in $batchObjects) {
        if ($obj.TypeGuid -eq $ProcedureTypeGuid) {
            # 4a. BC dependencies
            $bcDeps = Get-BCDependencies $obj.Path
            foreach ($bcTx in $bcDeps) {
                if ($batchTransactionNames.Contains($bcTx)) {
                    $edges += [pscustomobject]@{ From = $bcTx; To = $obj.Name; Kind = 'bc-dependency' }
                }
            }
            # 4b. Procedure -> Procedure calls
            $calls = Get-ProcedureCalls -XmlPath $obj.Path -BatchProcedureNames $batchProcedureNames
            foreach ($callee in $calls) {
                if ([string]::Equals($callee, $obj.Name, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                # So gera edge se callee e nova no batch (nao existe no corpus)
                if ($corpusProcedureNames.Contains($callee)) { continue }
                $edges += [pscustomobject]@{ From = $callee; To = $obj.Name; Kind = 'procedure-call' }
            }
        }
        # 4c. WorkWithForWeb -> Transaction: TODO 9-WW
    }
    # Deduplicar edges
    $seenEdges = @{}
    $dedupedEdges = @()
    foreach ($e in $edges) {
        $key = "$($e.From.ToLowerInvariant())|$($e.To.ToLowerInvariant())|$($e.Kind)"
        if (-not $seenEdges.ContainsKey($key)) {
            $seenEdges[$key] = $true
            $dedupedEdges += $e
        }
    }
    $edges = $dedupedEdges

    # 5. Construir adjacency list e in-degree
    $nodeKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($obj in $batchObjects) { [void]$nodeKeys.Add($obj.Name) }
    $adj = @{}    # nodeKey (lower) -> list of nodeKey (original-case)
    $inDeg = @{}  # nodeKey (lower) -> int
    foreach ($n in $nodeKeys) {
        $adj[$n.ToLowerInvariant()] = @()
        $inDeg[$n.ToLowerInvariant()] = 0
    }
    foreach ($e in $edges) {
        $fromKey = $e.From.ToLowerInvariant()
        $toKey = $e.To.ToLowerInvariant()
        if (-not $adj.ContainsKey($fromKey)) { continue }
        if (-not $adj.ContainsKey($toKey)) { continue }
        $adj[$fromKey] = @($adj[$fromKey]) + $e.To
        $inDeg[$toKey] = $inDeg[$toKey] + 1
    }

    # 6. Deteccao de ciclo via DFS
    $visited = @{}
    $stack = @{}
    $cycleFound = $null
    function Find-Cycle {
        param([string]$NodeKey, [System.Collections.Generic.List[string]]$Path)
        if ($script:cycleFound) { return }
        $script:stack[$NodeKey] = $true
        $Path.Add($NodeKey)
        foreach ($neighborName in $script:adj[$NodeKey]) {
            $neighborKey = $neighborName.ToLowerInvariant()
            if ($script:stack.ContainsKey($neighborKey) -and $script:stack[$neighborKey]) {
                $idx = $Path.IndexOf($neighborKey)
                if ($idx -ge 0) {
                    $script:cycleFound = @($Path.GetRange($idx, $Path.Count - $idx).ToArray()) + @($neighborKey)
                } else {
                    $script:cycleFound = @($neighborKey, $NodeKey, $neighborKey)
                }
                return
            }
            if (-not $script:visited.ContainsKey($neighborKey) -or -not $script:visited[$neighborKey]) {
                Find-Cycle -NodeKey $neighborKey -Path $Path
                if ($script:cycleFound) { return }
            }
        }
        $Path.RemoveAt($Path.Count - 1)
        $script:stack[$NodeKey] = $false
        $script:visited[$NodeKey] = $true
    }
    $script:adj = $adj
    $script:visited = $visited
    $script:stack = $stack
    $script:cycleFound = $null
    foreach ($key in $adj.Keys) {
        if ($script:visited.ContainsKey($key) -and $script:visited[$key]) { continue }
        Find-Cycle -NodeKey $key -Path ([System.Collections.Generic.List[string]]::new())
        if ($script:cycleFound) { break }
    }
    $cycle = $script:cycleFound

    if ($null -ne $cycle) {
        $cycleNames = @($cycle | ForEach-Object { if ($batchByName.ContainsKey($_)) { $batchByName[$_].Name } else { $_ } })
        $findings += New-Finding -Severity 'fail' -Code 'ido-cycle-detected' `
            -Message ("Ciclo detectado no grafo de dependencias do batch: " + ($cycleNames -join ' -> ')) `
            -InvolvedObjects $cycleNames
        $status = 'fail'
    } else {
        # 7. Topological sort (Kahn's)
        $layersWork = @()
        $remainingInDeg = @{}
        foreach ($k in $inDeg.Keys) { $remainingInDeg[$k] = $inDeg[$k] }
        $remainingNodes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($k in $adj.Keys) { [void]$remainingNodes.Add($k) }
        while ($remainingNodes.Count -gt 0) {
            $thisLayerKeys = @()
            foreach ($k in @($remainingNodes)) {
                if ($remainingInDeg[$k] -eq 0) { $thisLayerKeys += $k }
            }
            if ($thisLayerKeys.Count -eq 0) { break }  # nao deveria acontecer se sem ciclo
            $thisLayerNames = @($thisLayerKeys | ForEach-Object { if ($batchByName.ContainsKey($_)) { $batchByName[$_].Name } else { $_ } })
            $layersWork += ,$thisLayerNames
            foreach ($k in $thisLayerKeys) {
                foreach ($neighborName in $adj[$k]) {
                    $neighborKey = $neighborName.ToLowerInvariant()
                    if ($remainingInDeg.ContainsKey($neighborKey)) {
                        $remainingInDeg[$neighborKey] = $remainingInDeg[$neighborKey] - 1
                    }
                }
                [void]$remainingNodes.Remove($k)
            }
        }
        $layers = $layersWork

        if ($layers.Count -le 1) {
            $allNames = @($batchObjects | ForEach-Object { $_.Name })
            $findings += New-Finding -Severity 'info' -Code 'ido-single-layer-no-ordering-risk' `
                -Message "Nenhuma dependencia de ordenacao detectada entre os $($batchObjects.Count) objetos do batch" `
                -InvolvedObjects $allNames
            $status = 'pass'
        } else {
            $layersDesc = @()
            for ($i = 0; $i -lt $layers.Count; $i++) {
                $layersDesc += "Layer $($i + 1): " + (($layers[$i]) -join ', ')
            }
            $allNames = @($batchObjects | ForEach-Object { $_.Name })
            $findings += New-Finding -Severity 'warn' -Code 'ido-multiple-layers' `
                -Message ("Batch tem $($layers.Count) camadas topologicas; risco de ordenacao na importacao. Staging sugerido: " + ($layersDesc -join ' | ')) `
                -InvolvedObjects $allNames
            $status = 'alert'
        }
    }

    # 8. TODO 9-WW: aviso quando ha WorkWithForWeb no batch
    if ($batchWorkWithForWeb.Count -gt 0) {
        $wwNames = @($batchWorkWithForWeb | ForEach-Object { $_.Name })
        $findings += New-Finding -Severity 'info' -Code 'ido-ww-detection-pending' `
            -Message "Batch contem $($batchWorkWithForWeb.Count) WorkWithForWeb; a integracao da deteccao WorkWithForWeb -> Transaction neste script ainda nao foi feita. O gate 9-WW (Test-GeneXusWorkWithWebApply.ps1) ja cobre a verificacao Apply, mas a ordenacao topologica desta dependencia precisa ser adicionada aqui reusando Get-WorkWithForWebDetails. Dependencias dessa categoria nao foram avaliadas nesta execucao." `
            -InvolvedObjects $wwNames
    }
}

# 9. Emitir
$result = [pscustomobject]@{
    status         = $status
    frontFolder    = $FrontFolder
    corpusFolder   = $CorpusFolder
    objectsScanned = $batchObjects.Count
    edges          = @($edges)
    layers         = $layers
    cycle          = $cycle
    findings       = @($findings)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    Write-Output "status: $status"
    Write-Output "frontFolder: $FrontFolder"
    Write-Output "corpusFolder: $CorpusFolder"
    Write-Output "objectsScanned: $($batchObjects.Count)"
    Write-Output "edges: $($edges.Count)"
    if ($null -ne $layers) {
        Write-Output "layers: $($layers.Count)"
        for ($i = 0; $i -lt $layers.Count; $i++) {
            Write-Output ("  Layer $($i + 1): " + (($layers[$i]) -join ', '))
        }
    }
    if ($null -ne $cycle) {
        Write-Output "cycle: $($cycle -join ' -> ')"
    }
    if ($findings.Count -eq 0) {
        Write-Output "findings: (none)"
    } else {
        Write-Output "findings:"
        foreach ($f in $findings) {
            Write-Output "  - [$($f.severity)] $($f.code): $($f.message)"
            if ($f.involvedObjects.Count -gt 0) {
                Write-Output "    involved: $($f.involvedObjects -join ', ')"
            }
        }
    }
}
