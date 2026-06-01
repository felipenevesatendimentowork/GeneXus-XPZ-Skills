#requires -Version 7.4

<#
.SYNOPSIS
    Detecta caracteres Unicode inesperados em .md e .ps1 do diff pre-push.

.DESCRIPTION
    Varre linhas adicionadas (ou modificadas) no intervalo BaseRef..HEAD em
    arquivos .md e .ps1 (excluindo historico/), procurando caracteres que nao
    pertencem aos alfabetos de pt-BR, es e en (CJK, Cirilico, Arabic, etc.).
    Para .md, linhas dentro de code blocks cercados (``` ... ```) sao ignoradas.

    O gate e consultivo: emite findings com severity='warn' e sempre exita 0.
    O agente revisa os findings e decide se sao falsos positivos.

.PARAMETER RootPath
    Raiz do repositorio. Default: pai de scripts/.

.PARAMETER BaseRef
    Referencia base do intervalo (default: origin/main).

.PARAMETER ChangedFiles
    Lista pre-computada de arquivos alterados (paths relativos a RootPath).
    Se omitida, o script executa git diff --name-only para obter a lista.

.PARAMETER AsJson
    Emite resultado estruturado em JSON.

.EXAMPLE
    .\Test-GeneXusUnexpectedCharacter.ps1 -RootPath C:\Dev\GeneXus-XPZ-Skills -AsJson
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath,

    [string]$BaseRef = 'origin/main',

    [AllowEmptyCollection()]
    [string[]]$ChangedFiles = @(),

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BlockedRanges = @(
    @{ Min = 0x0400; Max = 0x04FF; Name = 'Cyrillic' }
    @{ Min = 0x0500; Max = 0x052F; Name = 'Cyrillic Supplement' }
    @{ Min = 0x0590; Max = 0x05FF; Name = 'Hebrew' }
    @{ Min = 0x0600; Max = 0x06FF; Name = 'Arabic' }
    @{ Min = 0x0900; Max = 0x097F; Name = 'Devanagari' }
    @{ Min = 0x3000; Max = 0x303F; Name = 'CJK Symbols and Punctuation' }
    @{ Min = 0x3040; Max = 0x309F; Name = 'Hiragana' }
    @{ Min = 0x30A0; Max = 0x30FF; Name = 'Katakana' }
    @{ Min = 0x3400; Max = 0x4DBF; Name = 'CJK Unified Ideographs Extension A' }
    @{ Min = 0x4E00; Max = 0x9FFF; Name = 'CJK Unified Ideographs' }
    @{ Min = 0xAC00; Max = 0xD7AF; Name = 'Hangul Syllables' }
    @{ Min = 0x0E00; Max = 0x0E7F; Name = 'Thai' }
    @{ Min = 0x0E80; Max = 0x0EFF; Name = 'Lao' }
    @{ Min = 0x1F600; Max = 0x1F64F; Name = 'Emoticons' }
    @{ Min = 0x1F300; Max = 0x1F5FF; Name = 'Misc Symbols and Pictographs' }
    @{ Min = 0x1F680; Max = 0x1F6FF; Name = 'Transport and Map Symbols' }
    @{ Min = 0x1F900; Max = 0x1F9FF; Name = 'Supplemental Symbols and Pictographs' }
    @{ Min = 0x1FA00; Max = 0x1FA6F; Name = 'Chess Symbols' }
    @{ Min = 0x1FA70; Max = 0x1FAFF; Name = 'Symbols and Pictographs Extended-A' }
)

$BlockedIndividualChars = @(
    @{ Code = 0xFEFF; Name = 'BOM / ZERO WIDTH NO-BREAK SPACE' }
    @{ Code = 0x200B; Name = 'ZERO WIDTH SPACE' }
)

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path

function Get-BlockedRangeName {
    param([int]$CodePoint)
    foreach ($range in $BlockedRanges) {
        if ($CodePoint -ge $range.Min -and $CodePoint -le $range.Max) {
            return $range.Name
        }
    }
    foreach ($blocked in $BlockedIndividualChars) {
        if ($CodePoint -eq $blocked.Code) {
            return $blocked.Name
        }
    }
    return $null
}

function Invoke-RepoGit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & git -C $RepositoryRoot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @()
    if ($null -ne $output) {
        $lines = @($output | ForEach-Object { $_.ToString() })
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines    = $lines
        Text     = ($lines -join [Environment]::NewLine)
    }
}

function Get-AddedLinesFromDiff {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$BaseRef,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $diffResult = Invoke-RepoGit -RepositoryRoot $RepositoryRoot -Arguments @('diff', '--unified=0', "$BaseRef..HEAD", '--', $RelativePath)
    if ($diffResult.ExitCode -ne 0) {
        return ,[string[]]@()
    }

    $addedLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $diffResult.Lines) {
        if ($line.StartsWith('+') -and -not $line.StartsWith('+++')) {
            $addedLines.Add($line.Substring(1))
        }
    }

    return ,[string[]]@($addedLines)
}

function Remove-CodeBlocksFromMd {
    param([string[]]$Lines)

    $result = [System.Collections.Generic.List[string]]::new()
    $inCodeBlock = $false

    foreach ($line in $Lines) {
        $trimmed = $line.TrimStart()
        if ($trimmed.StartsWith('```')) {
            $inCodeBlock = -not $inCodeBlock
            continue
        }
        if (-not $inCodeBlock) {
            $result.Add($line)
        }
    }

    return ,[string[]]@($result)
}

function Find-UnexpectedCharacters {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line,

        [Parameter(Mandatory = $true)]
        [int]$LineNumber,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $findings = [System.Collections.Generic.List[pscustomobject]]::new()

    for ($i = 0; $i -lt $Line.Length; $i++) {
        $cp = [int][char]$Line[$i]

        if ($cp -le 0x007E) {
            continue
        }

        $rangeName = Get-BlockedRangeName -CodePoint $cp
        if ($null -ne $rangeName) {
            $start = [Math]::Max(0, $i - 30)
            $end = [Math]::Min($Line.Length, $i + 31)
            $context = $Line.Substring($start, $end - $start)
            $msg = "Caractere U+{0:X4} ({1}) na linha {2} de {3} pertence ao bloco '{4}', inesperado em conteudo pt-BR/es/en." -f $cp, $Line[$i], $LineNumber, $RelativePath, $rangeName
            $cpStr = 'U+{0:X4}' -f $cp

            $findings.Add([pscustomobject]@{
                severity  = 'warn'
                code      = 'UNEXPECTED_CHARACTER'
                message   = $msg
                file      = $RelativePath
                line      = $LineNumber
                codepoint = $cpStr
                character = $Line[$i]
                blockName = $rangeName
                context   = $context
            })
        }
    }

    return ,[pscustomobject[]]@($findings)
}

$relevantFiles = [System.Collections.Generic.List[string]]::new()

if ($ChangedFiles.Count -gt 0) {
    foreach ($f in @($ChangedFiles)) {
        $normalized = ($f -replace '\\', '/').Trim()
        if ($normalized -match '\.(md|ps1)$' -and $normalized -notmatch '^historico/') {
            $relevantFiles.Add($normalized)
        }
    }
} else {
    $nameOnlyResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--name-only', "$BaseRef..HEAD")
    if ($nameOnlyResult.ExitCode -ne 0) {
        $result = [pscustomobject]@{
            status         = 'warn'
            totalFilesScanned = 0
            totalUnexpectedChars = 0
            findings       = @([pscustomobject]@{
                severity  = 'warn'
                code      = 'GIT_DIFF_FAILED'
                message   = "Falha ao listar arquivos alterados: $($nameOnlyResult.Text)"
                file      = ''
                line      = 0
                codepoint = ''
                character = ''
                blockName = ''
                context   = ''
            })
        }
        if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { Write-Output "status: warn"; Write-Output "findings: 1 (git diff failed)" }
        exit 0
    }

    foreach ($f in @($nameOnlyResult.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $normalized = ($f -replace '\\', '/').Trim()
        if ($normalized -match '\.(md|ps1)$' -and $normalized -notmatch '^historico/') {
            $relevantFiles.Add($normalized)
        }
    }
}

$allFindings = [System.Collections.Generic.List[pscustomobject]]::new()
$filesScanned = 0

foreach ($relPath in @($relevantFiles)) {
    $addedLines = Get-AddedLinesFromDiff -RepositoryRoot $resolvedRoot -BaseRef $BaseRef -RelativePath $relPath
    if ($addedLines.Count -eq 0) {
        continue
    }

    $filesScanned++

    $linesToScan = @($addedLines)
    if ($relPath -match '\.md$') {
        $linesToScan = Remove-CodeBlocksFromMd -Lines $addedLines
    }

    for ($lineIdx = 0; $lineIdx -lt $linesToScan.Count; $lineIdx++) {
        $lineContent = $linesToScan[$lineIdx]
        if ([string]::IsNullOrWhiteSpace($lineContent)) {
            continue
        }
        $lineNumber = $lineIdx + 1

        $charFindings = Find-UnexpectedCharacters -Line $lineContent -LineNumber $lineNumber -RelativePath $relPath
        foreach ($f in $charFindings) {
            [void]$allFindings.Add($f)
        }
    }
}

$status = if ($allFindings.Count -eq 0) { 'pass' } else { 'warn' }
$uniqueChars = @($allFindings | Select-Object -Property codepoint, character, blockName -Unique)

$result = [pscustomobject]@{
    status                = $status
    totalFilesScanned     = $filesScanned
    totalUnexpectedChars   = $allFindings.Count
    uniqueUnexpectedChars  = $uniqueChars.Count
    findings               = @($allFindings)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $status"
    Write-Output "totalFilesScanned: $filesScanned"
    Write-Output "totalUnexpectedChars: $($allFindings.Count)"
    if ($allFindings.Count -eq 0) {
        Write-Output "findings: (none)"
    } else {
        Write-Output "findings:"
        foreach ($f in $allFindings) {
            Write-Output "  - [$($f.severity)] $($f.code): $($f.message)"
            Write-Output "    context: $($f.context)"
        }
    }
}

exit 0