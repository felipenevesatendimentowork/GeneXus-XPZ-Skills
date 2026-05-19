#requires -Version 7.4
<#
.SYNOPSIS
Audita o naming dos diretorios imediatos de ObjetosDaKbEmXml.

.DESCRIPTION
Para cada diretorio imediato em ObjetosDaKbEmXml, le o primeiro XML classificavel,
extrai o tipo canonico pelo elemento raiz Attribute ou por Object/@type, compara
com o nome do diretorio e emite resultado estruturado. O script e somente leitura.

.PARAMETER ParallelKbRoot
Raiz da pasta paralela da KB.

.PARAMETER CatalogPath
Caminho opcional para gx-object-type-catalog.json.

.PARAMETER AsJson
Emite JSON estruturado em vez da tabela textual.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ParallelKbRoot,

    [string]$CatalogPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-StructuredError {
    param([string]$Message)

    if ($AsJson) {
        [pscustomobject]@{
            status    = 'STRUCTURAL_ERROR'
            divergent = @()
            all       = @()
            error     = $Message
        } | ConvertTo-Json -Depth 8
    } else {
        Write-Output "STRUCTURAL_ERROR: $Message"
    }
}

function Get-CatalogMap {
    param([string]$Path)

    $rawCatalog = Get-Content -LiteralPath $Path -Raw
    $catalog = $rawCatalog | ConvertFrom-Json
    $map = @{}

    foreach ($property in $catalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.objectTypeGuid -or [string]::IsNullOrWhiteSpace([string]$entry.objectTypeGuid)) {
            continue
        }

        $folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
            [string]$entry.folderName
        } else {
            [string]$property.Name
        }

        $map[[string]$entry.objectTypeGuid.ToLowerInvariant()] = [pscustomobject]@{
            TypeName   = [string]$property.Name
            FolderName = $folderName
        }
    }

    return $map
}

function Try-ClassifyXml {
    param(
        [string]$Path,
        [hashtable]$GuidMap
    )

    $document = [xml](Get-Content -LiteralPath $Path -Raw)
    $root = $document.DocumentElement
    if ($null -eq $root) {
        throw "XML sem elemento raiz"
    }

    $rootName = $root.LocalName
    if ($rootName -eq 'Attribute' -or $rootName -eq 'Attributes') {
        return [pscustomobject]@{
            Root                 = $rootName
            TypeGuid             = $null
            TipoReal             = 'Attribute'
            NomeCanonicoEsperado = 'Attribute'
            StatusNaming         = $null
            SourceFile           = $Path
        }
    }

    if ($rootName -ne 'Object') {
        return [pscustomobject]@{
            Root                 = $rootName
            TypeGuid             = $null
            TipoReal             = 'DESCONHECIDO'
            NomeCanonicoEsperado = $null
            StatusNaming         = 'TIPO_DESCONHECIDO'
            SourceFile           = $Path
        }
    }

    $typeGuid = $root.GetAttribute('type')
    if ([string]::IsNullOrWhiteSpace($typeGuid)) {
        return [pscustomobject]@{
            Root                 = $rootName
            TypeGuid             = $null
            TipoReal             = 'DESCONHECIDO'
            NomeCanonicoEsperado = $null
            StatusNaming         = 'TIPO_DESCONHECIDO'
            SourceFile           = $Path
        }
    }

    $guidKey = $typeGuid.ToLowerInvariant()
    if (-not $GuidMap.ContainsKey($guidKey)) {
        return [pscustomobject]@{
            Root                 = $rootName
            TypeGuid             = $typeGuid
            TipoReal             = 'TIPO_DESCONHECIDO'
            NomeCanonicoEsperado = $null
            StatusNaming         = 'TIPO_DESCONHECIDO'
            SourceFile           = $Path
        }
    }

    $mapped = $GuidMap[$guidKey]
    return [pscustomobject]@{
        Root                 = $rootName
        TypeGuid             = $typeGuid
        TipoReal             = $mapped.TypeName
        NomeCanonicoEsperado = $mapped.FolderName
        StatusNaming         = $null
        SourceFile           = $Path
    }
}

try {
    $resolvedKbRoot = (Resolve-Path -LiteralPath $ParallelKbRoot).Path
    $objetosPath = Join-Path $resolvedKbRoot 'ObjetosDaKbEmXml'
    if (-not (Test-Path -LiteralPath $objetosPath -PathType Container)) {
        throw "ObjetosDaKbEmXml nao encontrado: $objetosPath"
    }

    if (-not $CatalogPath) {
        $CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
    }
    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
        throw "Catalogo de tipos nao encontrado: $CatalogPath"
    }

    $guidMap = Get-CatalogMap -Path $CatalogPath
    $rows = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($dir in Get-ChildItem -LiteralPath $objetosPath -Directory | Sort-Object Name) {
        $xmlFiles = @(Get-ChildItem -LiteralPath $dir.FullName -Filter '*.xml' -File | Sort-Object Name)
        if ($xmlFiles.Count -eq 0) {
            $rows.Add([pscustomobject]@{
                Diretorio             = $dir.Name
                Root                  = $null
                TypeGuid              = $null
                TipoReal              = 'INDETERMINADO'
                StatusNaming          = 'INDETERMINADO'
                NomeCanonicoEsperado  = $null
                SourceFile            = $null
                Observacao            = 'diretorio sem XML legivel'
            })
            continue
        }

        $classified = $null
        $lastError = $null
        foreach ($xmlFile in $xmlFiles) {
            try {
                $classified = Try-ClassifyXml -Path $xmlFile.FullName -GuidMap $guidMap
                break
            } catch {
                $lastError = $_.Exception.Message
            }
        }

        if ($null -eq $classified) {
            $rows.Add([pscustomobject]@{
                Diretorio             = $dir.Name
                Root                  = $null
                TypeGuid              = $null
                TipoReal              = 'INDETERMINADO'
                StatusNaming          = 'INDETERMINADO'
                NomeCanonicoEsperado  = $null
                SourceFile            = $null
                Observacao            = "nenhum XML classificavel: $lastError"
            })
            continue
        }

        $status = $classified.StatusNaming
        if ($null -eq $status) {
            $status = if ($dir.Name -eq $classified.NomeCanonicoEsperado) { 'OK' } else { 'DIVERGENTE' }
        }

        $rows.Add([pscustomobject]@{
            Diretorio             = $dir.Name
            Root                  = $classified.Root
            TypeGuid              = $classified.TypeGuid
            TipoReal              = $classified.TipoReal
            StatusNaming          = $status
            NomeCanonicoEsperado  = if ($status -eq 'DIVERGENTE') { $classified.NomeCanonicoEsperado } else { $null }
            SourceFile            = $classified.SourceFile
            Observacao            = if ($status -eq 'TIPO_DESCONHECIDO') { 'GUID nao mapeado; atualizar scripts/gx-object-type-catalog.json' } else { $null }
        })
    }

    $divergentRows = @($rows | Where-Object { $_.StatusNaming -eq 'DIVERGENTE' })
    $indeterminedRows = @($rows | Where-Object { $_.StatusNaming -in @('INDETERMINADO', 'TIPO_DESCONHECIDO') })
    $statusText = if ($divergentRows.Count -gt 0) {
        'NAMING_DIVERGENT'
    } elseif ($indeterminedRows.Count -gt 0) {
        'NAMING_INDETERMINADO'
    } else {
        'NAMING_OK'
    }

    if ($AsJson) {
        [pscustomobject]@{
            status    = $statusText
            divergent = @($divergentRows | ForEach-Object { $_.Diretorio })
            all       = @($rows)
        } | ConvertTo-Json -Depth 8
    } else {
        $rows |
            Select-Object Diretorio, Root, TypeGuid, TipoReal, StatusNaming, NomeCanonicoEsperado |
            Format-Table -AutoSize

        if ($divergentRows.Count -gt 0) {
            Write-Output ("NAMING_DIVERGENT: {0}" -f (($divergentRows | ForEach-Object { $_.Diretorio }) -join ','))
        } elseif ($indeterminedRows.Count -gt 0) {
            Write-Output ("NAMING_INDETERMINADO: {0}" -f (($indeterminedRows | ForEach-Object { $_.Diretorio }) -join ','))
        } else {
            Write-Output 'NAMING_OK'
        }
    }

    if ($divergentRows.Count -gt 0) {
        exit 1
    }

    exit 0
} catch {
    Write-StructuredError -Message $_.Exception.Message
    exit 2
}
