#requires -Version 7.4

<#
.SYNOPSIS
    Copia XMLs do acervo para a frente quando o acervo e mais recente, com bump de lastUpdate.

.DESCRIPTION
    Para cada XML de objeto na pasta da frente que tem homonimo no acervo com lastUpdate
    mais recente, copia o arquivo do acervo sobre o da frente e bumpa o lastUpdate para
    garantir que o novo arquivo fique estritamente mais novo que o acervo.

    Resolve o anti-padrao "editar acervo esperando que o pacote pegue": em vez de editar
    o acervo, o agente copia a versao mais recente do acervo para a frente e depois edita
    a copia. O gate 9-FD (Test-GeneXusFrontAcervoDrift.ps1) detecta o drift; este script
    resolve o drift copiando e bumpando.

    Comportamento por finding do gate 9-FD:
      - front-older-than-acervo: copia do acervo e bumpa lastUpdate (acao primaria)
      - front-equals-acervo: copia do acervo e bumpa lastUpdate (conservative; o agente
        pode querer preservar, mas copiar e bumpar e o caminho seguro para edicoes futuras)
      - front-only-new-object: ignorado (objeto novo, sem homonimo no acervo)
      - front-newer-than-acervo: ignorado (frente ja e mais recente)
      - lastupdate-unparseable: ignorado (requer resolucao manual)

    Quando -ObjectNames ou -ObjectGuids e fornecido, so os objetos listados sao
    considerados para copia. Quando omitido, todos os objetos com drift sao copiados.

.PARAMETER FrontFolder
    Caminho da pasta da frente (ObjetosGeradosParaImportacaoNaKbNoGenexus/<NomeCurto_GUID_YYYYMMDD>).

.PARAMETER AcervoFolder
    Caminho da pasta do acervo oficial (ObjetosDaKbEmXml).

.PARAMETER ObjectNames
    Nomes de objetos a copiar (opcional). Quando omitido, copia todos com drift.

.PARAMETER ObjectGuids
    GUIDs de objetos a copiar (opcional). Quando omitido, copia todos com drift.

.PARAMETER FreshnessMarginSeconds
    Margem em segundos aplicada sobre o lastUpdate do acervo ao bumpar. Default: 60.

.PARAMETER DryRun
    Mostra o que seria copiado sem gravar. Util para preview.

.PARAMETER AsJson
    Emite resultado estruturado em JSON.

.EXAMPLE
    .\Copy-GeneXusAcervoToFront.ps1 -FrontFolder C:\Kb\ObjetosGeradosParaImportacaoNaKbNoGenexus\GtaP3_c34f_20260528 -AcervoFolder C:\Kb\ObjetosDaKbEmXml -AsJson
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FrontFolder,

    [Parameter(Mandatory = $true)]
    [string]$AcervoFolder,

    [string[]]$ObjectNames,

    [string[]]$ObjectGuids,

    [ValidateRange(1, 3600)]
    [int]$FreshnessMarginSeconds = 60,

    [switch]$DryRun,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Format-GeneXusLastUpdate {
    param([Parameter(Mandatory = $true)][DateTime]$Value)
    return $Value.ToUniversalTime().ToString(
        "yyyy-MM-dd'T'HH:mm:ss'.0000000Z'",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Read-ObjectLastUpdateSafe {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Root
    )
    $raw = $Root.GetAttribute("lastUpdate")
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $raw,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed
    )
    if (-not $ok) {
        return $null
    }
    return $parsed.UtcDateTime
}

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$ObjectName,
        [string]$ObjectGuid,
        [string]$ObjectFile,
        [string]$AcervoFile,
        [string]$Action,
        [string]$FrontLastUpdateBefore,
        [string]$AcervoLastUpdate,
        [string]$FrontLastUpdateAfter
    )
    return [pscustomobject]@{
        severity             = $Severity
        code                 = $Code
        message              = $Message
        objectName           = $ObjectName
        objectGuid           = $ObjectGuid
        objectFile           = $ObjectFile
        acervoFile           = $AcervoFile
        action               = $Action
        frontLastUpdateBefore = $FrontLastUpdateBefore
        acervoLastUpdate     = $AcervoLastUpdate
        frontLastUpdateAfter = $FrontLastUpdateAfter
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
    $objGuid = $root.GetAttribute('guid')
    $objFqn = $root.GetAttribute('fullyQualifiedName')
    $lastUpdate = Read-ObjectLastUpdateSafe $root
    return [pscustomobject]@{
        Path       = $XmlPath
        Name       = $objName
        TypeGuid   = $objType
        Guid       = $objGuid
        Fqn        = $objFqn
        LastUpdate = $lastUpdate
    }
}

function Find-AcervoObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][pscustomobject]$FrontMeta
    )
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $null
    }
    $candidateFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($attrName in @('fullyQualifiedName', 'name')) {
        $value = $null
        if ($attrName -eq 'fullyQualifiedName') { $value = $FrontMeta.Fqn }
        elseif ($attrName -eq 'name') { $value = $FrontMeta.Name }
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $leaf = "$value.xml"
        $found = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue)
        foreach ($f in $found) {
            $candidateFiles.Add($f) | Out-Null
        }
    }
    if ($candidateFiles.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($FrontMeta.Guid)) {
        $guidHits = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.xml' -ErrorAction SilentlyContinue |
            Select-String -SimpleMatch $FrontMeta.Guid |
            ForEach-Object { $_.Path } |
            Sort-Object -Unique |
            ForEach-Object { Get-Item -LiteralPath $_ })
        foreach ($f in $guidHits) {
            $candidateFiles.Add($f) | Out-Null
        }
    }
    foreach ($file in @($candidateFiles | Sort-Object FullName -Unique)) {
        try {
            [xml]$doc = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        } catch {
            continue
        }
        $baseRoot = $doc.DocumentElement
        if ($null -eq $baseRoot -or $baseRoot.LocalName -ne 'Object') { continue }
        $matched = $false
        $baseGuid = $baseRoot.GetAttribute('guid')
        if (-not [string]::IsNullOrWhiteSpace($FrontMeta.Guid) -and $FrontMeta.Guid -eq $baseGuid) {
            $matched = $true
        }
        if (-not $matched) {
            $baseFqn = $baseRoot.GetAttribute('fullyQualifiedName')
            if (-not [string]::IsNullOrWhiteSpace($FrontMeta.Fqn) -and $FrontMeta.Fqn -eq $baseFqn) {
                $matched = $true
            }
        }
        if (-not $matched) {
            $baseName = $baseRoot.GetAttribute('name')
            if (-not [string]::IsNullOrWhiteSpace($FrontMeta.Name) -and $FrontMeta.Name -eq $baseName) {
                $matched = $true
            }
        }
        if ($matched) {
            $baseMeta = Get-ObjectMetadata $file.FullName
            if ($null -ne $baseMeta) {
                return $baseMeta
            }
        }
    }
    return $null
}

# Validar parametros
if (-not (Test-Path -LiteralPath $FrontFolder -PathType Container)) {
    throw "FrontFolder nao encontrado ou nao e diretorio: $FrontFolder"
}
if (-not (Test-Path -LiteralPath $AcervoFolder -PathType Container)) {
    throw "AcervoFolder nao encontrado ou nao e diretorio: $AcervoFolder"
}
$FrontFolder  = (Resolve-Path -LiteralPath $FrontFolder).Path
$AcervoFolder = (Resolve-Path -LiteralPath $AcervoFolder).Path

# Sem dependencia de motor externo: o bump de lastUpdate e feito inline por
# Format-GeneXusLastUpdate / max(UtcNow + margin, acervoLastUpdate + margin)

# 1. Enumerar XMLs na pasta da frente
$findings = @()
$frontXmls = @(Get-ChildItem -LiteralPath $FrontFolder -File -Filter '*.xml')
$frontMetas = @()
foreach ($xml in $frontXmls) {
    $meta = Get-ObjectMetadata $xml.FullName
    if ($null -ne $meta -and -not [string]::IsNullOrWhiteSpace($meta.Name)) {
        $frontMetas += $meta
    }
}

if ($frontMetas.Count -eq 0 -and $frontXmls.Count -eq 0) {
    $status = 'not-applicable'
} else {
    $nameFilter = $null
    if ($null -ne $ObjectNames -and $ObjectNames.Count -gt 0) {
        $nameFilter = @($ObjectNames | ForEach-Object { $_.ToLowerInvariant() })
    }
    $guidFilter = $null
    if ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0) {
        $guidFilter = @($ObjectGuids | ForEach-Object { $_.ToLowerInvariant() })
    }

    # 2. Para cada objeto da frente, buscar homonimo no acervo e copiar se mais recente
    foreach ($fMeta in $frontMetas) {
        # Aplicar filtros de nome/GUID se fornecidos
        if ($null -ne $nameFilter -and -not $nameFilter.Contains($fMeta.Name.ToLowerInvariant())) {
            continue
        }
        if ($null -ne $guidFilter -and -not $guidFilter.Contains($fMeta.Guid.ToLowerInvariant())) {
            continue
        }

        $fRel = [System.IO.Path]::GetRelativePath($FrontFolder, $fMeta.Path)
        $aMeta = Find-AcervoObjectXml -RootPath $AcervoFolder -FrontMeta $fMeta

        if ($null -eq $aMeta) {
            # Objeto novo, sem homonimo no acervo
            continue
        }

        if ($null -eq $fMeta.LastUpdate -or $null -eq $aMeta.LastUpdate) {
            # lastUpdate nao parseavel em um dos lados
            $findings += New-Finding -Severity 'warn' -Code 'lastupdate-unparseable-skip' `
                -Message "Objeto '$($fMeta.Name)' com lastUpdate nao parseavel; copia manual necessaria." `
                -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                -ObjectFile $fRel -AcervoFile ([System.IO.Path]::GetRelativePath($AcervoFolder, $aMeta.Path)) `
                -Action 'skip' `
                -FrontLastUpdateBefore $(if ($null -ne $fMeta.LastUpdate) { Format-GeneXusLastUpdate $fMeta.LastUpdate } else { '' }) `
                -AcervoLastUpdate $(if ($null -ne $aMeta.LastUpdate) { Format-GeneXusLastUpdate $aMeta.LastUpdate } else { '' }) `
                -FrontLastUpdateAfter ''
            continue
        }

        if ($fMeta.LastUpdate -gt $aMeta.LastUpdate) {
            # Frente ja e mais recente
            continue
        }

        # Frente e mais antiga ou igual: copiar do acervo e bumpar lastUpdate
        $fLastStr = Format-GeneXusLastUpdate $fMeta.LastUpdate
        $aLastStr = Format-GeneXusLastUpdate $aMeta.LastUpdate
        $aRel = [System.IO.Path]::GetRelativePath($AcervoFolder, $aMeta.Path)

        # Calcular novo lastUpdate: max(UtcNow + margin, acervoLastUpdate + margin)
        $utcNow = [DateTime]::UtcNow
        $baseCandidate = $utcNow.AddSeconds($FreshnessMarginSeconds)
        $baselineCandidate = $aMeta.LastUpdate.AddSeconds($FreshnessMarginSeconds)
        if ($baselineCandidate -gt $baseCandidate) {
            $baseCandidate = $baselineCandidate
        }
        $newLastUpdate = Format-GeneXusLastUpdate -Value $baseCandidate

        if ($DryRun) {
            $findings += New-Finding -Severity 'info' -Code 'dry-run-copy' `
                -Message "DRY RUN: copiar '$($aMeta.Path)' -> '$($fMeta.Path)' e bump lastUpdate de $aLastStr para $newLastUpdate." `
                -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                -ObjectFile $fRel -AcervoFile $aRel `
                -Action 'dry-run-copy' `
                -FrontLastUpdateBefore $fLastStr -AcervoLastUpdate $aLastStr -FrontLastUpdateAfter $newLastUpdate
            continue
        }

        # Copiar do acervo para a frente
        Copy-Item -LiteralPath $aMeta.Path -Destination $fMeta.Path -Force

        # Bump lastUpdate no arquivo copiado
        $rawText = [System.IO.File]::ReadAllText($fMeta.Path)
        $pattern = [regex]::new('lastUpdate="[^"]*"')
        $newText = $pattern.Replace($rawText, "lastUpdate=""$newLastUpdate""", 1)

        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($fMeta.Path, $newText, $utf8NoBom)

        $findings += New-Finding -Severity 'info' -Code 'copied-and-bumped' `
            -Message "Objeto '$($fMeta.Name)' copiado do acervo e bumpado: lastUpdate $fLastStr -> $newLastUpdate (acervo era $aLastStr)." `
            -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
            -ObjectFile $fRel -AcervoFile $aRel `
            -Action 'copied-and-bumped' `
            -FrontLastUpdateBefore $fLastStr -AcervoLastUpdate $aLastStr -FrontLastUpdateAfter $newLastUpdate
    }

    # 3. Status agregado
    $hasFail = $findings | Where-Object { $_.severity -eq 'fail' } | Select-Object -First 1
    if ($hasFail) { $status = 'fail' } else { $status = 'pass' }
}

# 4. Emitir resultado
$result = [pscustomobject]@{
    status          = $status
    frontFolder     = $FrontFolder
    acervoFolder    = $AcervoFolder
    dryRun          = $DryRun.IsPresent
    objectsScanned  = $frontMetas.Count
    findings        = $findings
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $status"
    Write-Output "frontFolder: $FrontFolder"
    Write-Output "acervoFolder: $AcervoFolder"
    Write-Output "dryRun: $($DryRun.IsPresent)"
    Write-Output "objectsScanned: $($frontMetas.Count)"
    if ($findings.Count -eq 0) {
        Write-Output "findings: (none)"
    } else {
        Write-Output "findings:"
        foreach ($f in $findings) {
            Write-Output "  - [$($f.severity)] $($f.code): $($f.message)"
            Write-Output "    object: $($f.objectName) ($($f.objectFile))"
            Write-Output "    action: $($f.action)"
        }
    }
}
