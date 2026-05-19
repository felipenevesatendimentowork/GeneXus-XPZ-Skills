<#
.SYNOPSIS
    Verifica se o runtime PowerShell minimo da base XPZ esta disponivel.

.DESCRIPTION
    Gate consultivo para pastas paralelas de KB. Ele deve ser chamado antes
    dos demais wrappers locais para garantir que `pwsh` existe e atende ao
    contrato minimo da base: PowerShell 7.4 LTS ou superior.
#>

[CmdletBinding()]
param(
    [version]$MinimumVersion = [version]'7.4'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($null -eq $pwsh) {
    Write-Output "BLOCK: pwsh nao encontrado no PATH; instale PowerShell $MinimumVersion ou superior antes de usar esta pasta paralela"
    exit 1
}

$versionText = $null
try {
    $versionText = (& $pwsh.Source -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>&1 |
        ForEach-Object { $_.ToString() }) -join ''
} catch {
    Write-Output "BLOCK: falha ao executar pwsh: $($_.Exception.Message)"
    exit 1
}

$actualVersion = $null
if (-not [version]::TryParse($versionText.Trim(), [ref]$actualVersion)) {
    Write-Output "BLOCK: nao foi possivel determinar versao do pwsh: '$versionText'"
    exit 1
}

if ($actualVersion -lt $MinimumVersion) {
    Write-Output "BLOCK: PowerShell $MinimumVersion ou superior requerido; encontrado $actualVersion em $($pwsh.Source)"
    exit 1
}

Write-Output "POWERSHELL_RUNTIME_OK: pwsh $actualVersion em $($pwsh.Source)"
exit 0
