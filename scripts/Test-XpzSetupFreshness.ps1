#requires -Version 7.4
<#
.SYNOPSIS
    Verifica se o setup da pasta paralela da KB esta fresco em relacao ao repositorio de skills XPZ.

.DESCRIPTION
    Le last_setup_audit_run_at de kb-source-metadata.md da pasta paralela, determina a data de
    ultima modificacao do repositorio de skills XPZ e compara os dois timestamps.
    Retorna GATE_ONLY quando o repositorio nao foi atualizado desde o ultimo audit concluido
    com sucesso; retorna AUDIT_REQUIRED com motivo nos demais casos.

    Projetado para ser chamado pelo wrapper local Test-*KbSetupFreshness.ps1 como primeira acao
    da PRE-CONDICAO obrigatoria em xpz-kb-parallel-setup.

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB (deve conter kb-source-metadata.md).

.PARAMETER SkillsRoot
    Raiz do repositorio de skills XPZ (GeneXus-XPZ-Skills).

.OUTPUTS
    String: "GATE_ONLY" ou "AUDIT_REQUIRED: <motivo>"

.EXAMPLE
    .\Test-XpzSetupFreshness.ps1 -KbParallelRoot "C:\DevTests\Gx_MyCinema" -SkillsRoot "C:\Dev\Knowledge\GeneXus-XPZ-Skills"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbParallelRoot,

    [Parameter(Mandatory = $true)]
    [string]$SkillsRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$metadataPath = Join-Path $KbParallelRoot 'kb-source-metadata.md'

if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    Write-Output "AUDIT_REQUIRED: kb-source-metadata.md ausente em $KbParallelRoot"
    exit 0
}

$content = Get-Content -LiteralPath $metadataPath -Raw

if ($content -notmatch '(?m)^last_setup_audit_run_at:\s*(.+)$') {
    Write-Output 'AUDIT_REQUIRED: campo last_setup_audit_run_at ausente em kb-source-metadata.md'
    exit 0
}

$rawTimestamp = $Matches[1].Trim()

if ([string]::IsNullOrWhiteSpace($rawTimestamp)) {
    Write-Output 'AUDIT_REQUIRED: campo last_setup_audit_run_at vazio em kb-source-metadata.md'
    exit 0
}

$lastAudit = $null
try {
    $lastAudit = [DateTimeOffset]::Parse($rawTimestamp)
} catch {
    Write-Output "AUDIT_REQUIRED: last_setup_audit_run_at nao e timestamp valido: '$rawTimestamp'"
    exit 0
}

# Determinar data de ultima modificacao do repositorio de skills
$skillsLastChange = $null
$gitDir = Join-Path $SkillsRoot '.git'

if (Test-Path -LiteralPath $gitDir -PathType Container) {
    try {
        $gitOutput = & git -C $SkillsRoot log -1 --format="%cI" 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitOutput)) {
            $skillsLastChange = [DateTimeOffset]::Parse($gitOutput.Trim())
        }
    } catch {
        $skillsLastChange = $null
    }
}

if ($null -eq $skillsLastChange) {
    # Fallback: arquivo mais recentemente modificado na pasta de skills (ignora .git)
    $mostRecent = Get-ChildItem -LiteralPath $SkillsRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "*\.git\*" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $mostRecent) {
        Write-Output "AUDIT_REQUIRED: nao foi possivel determinar data de modificacao do repositorio de skills em $SkillsRoot"
        exit 0
    }

    $skillsLastChange = [DateTimeOffset]::new($mostRecent.LastWriteTime)
}

if ($skillsLastChange -gt $lastAudit) {
    Write-Output "AUDIT_REQUIRED: skills atualizados em $($skillsLastChange.ToString('o')); ultimo audit em $($lastAudit.ToString('o'))"
    exit 0
}

Write-Output 'GATE_ONLY'
exit 0
