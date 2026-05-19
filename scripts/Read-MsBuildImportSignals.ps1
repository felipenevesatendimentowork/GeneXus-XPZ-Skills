#requires -Version 7.4
<#
.SYNOPSIS
Extrai sinais compactos de logs MSBuild de preview/importacao GeneXus.

.DESCRIPTION
Le msbuild.stdout.log e msbuild.stderr.log, ou um diretorio que contenha esses
arquivos, e retorna JSON compacto para evitar colagem de logs longos na conversa.

.PARAMETER Path
Caminho de um diretorio de artefatos MSBuild ou de um arquivo stdout.log.

.PARAMETER StdOutPath
Caminho explicito para msbuild.stdout.log.

.PARAMETER StdErrPath
Caminho explicito para msbuild.stderr.log.

.PARAMETER Stage
Nome livre da etapa consumidora, por exemplo import-preview ou import-real.

.PARAMETER OutputPath
Quando informado, grava o mesmo JSON compacto nesse caminho.

.PARAMETER AsJson
Retorna JSON estruturado.
#>

[CmdletBinding()]
param(
    [string]$Path,
    [string]$StdOutPath,
    [string]$StdErrPath,
    [string]$Stage = 'import',
    [string]$OutputPath,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

function Read-TextFileSafe {
    param([string]$FilePath)

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return ''
    }
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return ''
    }
    return [System.IO.File]::ReadAllText($FilePath)
}

function Split-NonEmptyLines {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    return @($Text -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
}

function Get-MatchingLines {
    param(
        [string]$Text,
        [string]$Prefix
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    return @(
        $Text -split "\r?\n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_.StartsWith($Prefix, [System.StringComparison]::Ordinal) } |
            ForEach-Object { $_.Substring($Prefix.Length).Trim() }
    )
}

function Get-RegexValue {
    param(
        [string]$Text,
        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }
    $match = [regex]::Match($Text, $Pattern)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value
}

function Get-WarningLines {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    return @(
        [regex]::Matches($Text, '(?im)^[^\r\n]*(?:\(\d+,\d+\)\s*:\s*)?warning\s*:[^\r\n]*') |
            ForEach-Object { $_.Value.Trim() }
    )
}

function Get-ErrorLines {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    return @(
        [regex]::Matches($Text, '(?im)^[^\r\n]*(?:\(\d+,\d+\)\s*:\s*)?error\s*:[^\r\n]*') |
            ForEach-Object { $_.Value.Trim() }
    )
}

function Get-LayoutWarnings {
    param([string[]]$Warnings)

    $groups = [ordered]@{}
    $pattern = "Layout com identificador incorreto '([^']+)'\s+\(Panel '([^']+)', Layout\)"
    foreach ($warning in $Warnings) {
        $match = [regex]::Match($warning, $pattern)
        if (-not $match.Success) {
            continue
        }
        $layoutId = $match.Groups[1].Value
        $panelName = $match.Groups[2].Value
        if (-not $groups.Contains($panelName)) {
            $groups[$panelName] = [System.Collections.Generic.List[string]]::new()
        }
        if (-not $groups[$panelName].Contains($layoutId)) {
            [void]$groups[$panelName].Add($layoutId)
        }
    }

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($panelName in $groups.Keys) {
        $entry = [ordered]@{
            panelName = $panelName
            layoutIds = @($groups[$panelName])
            count = $groups[$panelName].Count
        }
        [void]$result.Add($entry)
    }
    return @($result)
}

function Get-KnownStdOutNoise {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($line in (Split-NonEmptyLines -Text $Text)) {
        if ($line -match "O acesso ao caminho 'C:\\Program Files \(x86\)\\GeneXus\\GeneXus18\\CssProperties\.json' foi negado\.") {
            [void]$result.Add([ordered]@{
                code = 'cssproperties-access-denied'
                classification = 'known-environment-noise'
                line = $line
            })
        }
    }
    return @($result)
}

if (-not [string]::IsNullOrWhiteSpace($Path)) {
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
        if ([string]::IsNullOrWhiteSpace($StdOutPath)) {
            $StdOutPath = Join-Path $resolvedPath 'msbuild.stdout.log'
        }
        if ([string]::IsNullOrWhiteSpace($StdErrPath)) {
            $StdErrPath = Join-Path $resolvedPath 'msbuild.stderr.log'
        }
    } elseif (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
        if ([string]::IsNullOrWhiteSpace($StdOutPath)) {
            $StdOutPath = $resolvedPath
        }
        if ([string]::IsNullOrWhiteSpace($StdErrPath)) {
            $candidateErr = $resolvedPath -replace 'stdout', 'stderr'
            if ($candidateErr -ne $resolvedPath -and (Test-Path -LiteralPath $candidateErr -PathType Leaf)) {
                $StdErrPath = $candidateErr
            }
        }
    } else {
        throw "Path nao encontrado: $Path"
    }
}

if ([string]::IsNullOrWhiteSpace($StdOutPath) -and [string]::IsNullOrWhiteSpace($StdErrPath)) {
    throw 'Informe -Path, -StdOutPath ou -StdErrPath.'
}

$stdOutText = Read-TextFileSafe -FilePath $StdOutPath
$stdErrText = Read-TextFileSafe -FilePath $StdErrPath
$warnings = @(Get-WarningLines -Text $stdOutText)
$errors = @()
$errors += @(Get-ErrorLines -Text $stdOutText)
$errors += @(Get-ErrorLines -Text $stdErrText)
$importedItems = @(Get-MatchingLines -Text $stdOutText -Prefix '__IMPORTED_ITEM__=')
$layoutWarnings = @(Get-LayoutWarnings -Warnings $warnings)
$knownStdOutNoise = @(Get-KnownStdOutNoise -Text $stdOutText)

$signals = [ordered]@{
    status = 'signals-read'
    stage = $Stage
    importedItems = $importedItems
    warnings = $warnings
    errors = $errors
    knownStdOutNoise = $knownStdOutNoise
    activeVersion = (Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'")
    activeEnvironment = (Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'")
    importTaskSuccess = ($stdOutText -match 'Import Task (Sucesso|Success)')
    layoutWarnings = $layoutWarnings
    counts = [ordered]@{
        importedItems = $importedItems.Count
        warnings = $warnings.Count
        errors = $errors.Count
        knownStdOutNoise = $knownStdOutNoise.Count
        layoutWarnings = $layoutWarnings.Count
    }
    artifacts = [ordered]@{
        StdOutPath = if ([string]::IsNullOrWhiteSpace($StdOutPath)) { $null } else { [System.IO.Path]::GetFullPath($StdOutPath) }
        StdErrPath = if ([string]::IsNullOrWhiteSpace($StdErrPath)) { $null } else { [System.IO.Path]::GetFullPath($StdErrPath) }
    }
}

$json = $signals | ConvertTo-Json -Depth 8
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $outputDirectory = [System.IO.Path]::GetDirectoryName($resolvedOutputPath)
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    }
    [System.IO.File]::WriteAllText($resolvedOutputPath, $json + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
}

if ($AsJson) {
    $json
} else {
    $signals
}
