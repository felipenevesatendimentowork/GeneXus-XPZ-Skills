#requires -Version 7.4
<#
.SYNOPSIS
    Resolve um executavel Python utilizavel para motores GeneXus-XPZ-Skills (ex.: KbIntelligence).
#>

Set-StrictMode -Version Latest

function Test-GeneXusPythonCandidateExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath
    )

    if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
        return $false
    }

    try {
        $length = (Get-Item -LiteralPath $ExecutablePath).Length
        if ($length -eq 0) {
            return $false
        }
    } catch {
        return $false
    }

    if ($ExecutablePath -match '\\WindowsApps\\') {
        return $false
    }

    $versionOutput = @(& $ExecutablePath --version 2>&1)
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return -not [string]::IsNullOrWhiteSpace(($versionOutput | Out-String).Trim())
}

function Get-GeneXusPythonExecutable {
    <#
    .OUTPUTS
        PSCustom1 with Source and VersionLine, or $null when nenhum Python utilizavel foi encontrado.
    #>
    $candidates = @(
        @{ Name = 'python'; Arguments = @('--version') },
        @{ Name = 'py'; Arguments = @('-3', '--version') }
    )

    foreach ($candidate in $candidates) {
        $command = Get-Command $candidate.Name -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            continue
        }

        $executablePath = $command.Source
        if (-not (Test-GeneXusPythonCandidateExecutable -ExecutablePath $executablePath)) {
            continue
        }

        $versionOutput = @(& $executablePath @($candidate.Arguments) 2>&1)
        if ($LASTEXITCODE -ne 0) {
            continue
        }

        return [pscustomobject]@{
            Source      = $executablePath
            VersionLine = (($versionOutput | ForEach-Object { $_.ToString() }) -join ' ').Trim()
            Launcher    = $candidate.Name
        }
    }

    return $null
}

function Get-GeneXusPythonPrerequisiteErrorMessage {
    return @(
        'PREREQUISITO AUSENTE: Python 3 utilizavel nao encontrado no PATH.'
        'Instale Python 3.x (https://www.python.org/downloads/) e adicione ao PATH.'
        'No Windows, ignore o stub em Microsoft Store (WindowsApps) se ele nao executar de verdade.'
        'A materializacao XPZ/XML pode ter concluido; apenas o indice KbIntelligence nao foi gerado.'
    ) -join ' '
}
