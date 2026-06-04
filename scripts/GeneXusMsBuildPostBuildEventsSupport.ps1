#requires -Version 7.4
<#
.SYNOPSIS
    Extracao de eventos pos-build do stdout MSBuild GeneXus.

.DESCRIPTION
    Prefere a janela delimitada pelo marcador "Executando eventos pos-construcao"
    e pelo proximo separador "==========". Mantem a regex historica como fallback
    para logs antigos ou variantes sem marcador de fase.
#>

Set-StrictMode -Version Latest

function Convert-GeneXusPostBuildEventLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $value = $Line.Trim()
    if ($value -match '^(?i)REM\s+') {
        return "(commented) $value"
    }
    return $value
}

function Test-GeneXusPostBuildPhaseStartLine {
    param(
        [AllowNull()]
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }
    return ($Line -match '(?i)Executando\s+eventos\s+p[oó]s-constru[cç][aã]o')
}

function Test-GeneXusMsBuildPhaseBoundaryLine {
    param(
        [AllowNull()]
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }
    return ($Line -match '^\s*=+\s*.*=+\s*$')
}

function Test-GeneXusPostBuildWindowDiagnosticLine {
    param(
        [AllowNull()]
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $true
    }
    if (Test-GeneXusPostBuildPhaseStartLine -Line $Line) {
        return $true
    }
    if (Test-GeneXusMsBuildPhaseBoundaryLine -Line $Line) {
        return $true
    }
    if ($Line -match '(?i)\(\d+,\d+\)\s*:\s*(warning|error)\s*:') {
        return $true
    }
    if ($Line -match '(?i)^\s*(Build succeeded|Build FAILED|Compilaci[oó]n|Compila[cç][aã]o)\b') {
        return $true
    }
    return $false
}

function Get-GeneXusMsBuildPostBuildEventLines {
    param(
        [AllowNull()]
        [string[]]$StdOutLines
    )

    $lines = @($StdOutLines)
    $windowEvents = [System.Collections.Generic.List[string]]::new()
    $insidePostBuildWindow = $false

    foreach ($line in $lines) {
        if (-not $insidePostBuildWindow) {
            if (Test-GeneXusPostBuildPhaseStartLine -Line $line) {
                $insidePostBuildWindow = $true
            }
            continue
        }

        if (Test-GeneXusMsBuildPhaseBoundaryLine -Line $line) {
            break
        }
        if (Test-GeneXusPostBuildWindowDiagnosticLine -Line $line) {
            continue
        }

        [void]$windowEvents.Add((Convert-GeneXusPostBuildEventLine -Line $line))
    }

    if ($windowEvents.Count -gt 0) {
        return @($windowEvents)
    }

    $fallbackText = ($lines -join "`n")
    return @([regex]::Matches($fallbackText, '(?im)^\s*(REM\s+)?(start\s+c:|start\s+cmd)[^\r\n]*') |
             ForEach-Object { Convert-GeneXusPostBuildEventLine -Line $_.Value })
}
