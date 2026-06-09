#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico de Initialize-XpzSkillsRepoGit.ps1.

.DESCRIPTION
    Valida a classificacao de estado do script de bootstrap Git SEM acesso a rede
    e SEM tocar no repositorio real. Cada caso monta um repositorio Git temporario
    local e confere o "label" produzido. Os caminhos que exigiriam fetch do remoto
    oficial (GIT_LINKED_CLEAN / GIT_LINKED_WITH_DRIFT) sao exercitados via -WhatIf,
    que para antes de qualquer operacao de rede ou escrita.

    Requer o executavel Git disponivel (o proprio recurso depende dele).
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptUnderTest = Join-Path $PSScriptRoot 'Initialize-XpzSkillsRepoGit.ps1'
if (-not (Test-Path -LiteralPath $scriptUnderTest -PathType Leaf)) {
    throw "BLOCK: script alvo nao encontrado: $scriptUnderTest"
}

$official = 'https://github.com/GxBrasilNOficial/GeneXus-XPZ-Skills.git'
$git = (Get-Command git -ErrorAction SilentlyContinue)
if (-not $git) {
    throw 'BLOCK: git ausente; este self-test requer o executavel git.'
}

$failures = 0
$cases = 0

function New-TempDir {
    $path = Join-Path $env:TEMP ('xpz-gitselftest-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Remove-TempDir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Attributes = 'Normal' }
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Assert-Label {
    param(
        [string]$CaseName,
        [string]$ExpectedLabel,
        [string]$Output
    )
    $script:cases++
    if ($Output -match ('"label":\s*"' + [regex]::Escape($ExpectedLabel) + '"')) {
        Write-Output ("PASS: {0} -> {1}" -f $CaseName, $ExpectedLabel)
    }
    else {
        $script:failures++
        Write-Output ("FAIL: {0} -> esperado {1}" -f $CaseName, $ExpectedLabel)
        Write-Output ("      saida: {0}" -f ($Output -replace "`r?`n", ' '))
    }
}

# Caso A: repositorio ja ligado ao oficial -> GIT_ALREADY_LINKED (sem rede)
$tmp = New-TempDir
try {
    & git -C $tmp init -b main *> $null
    & git -C $tmp remote add origin $official *> $null
    $out = & $scriptUnderTest -RepoRoot $tmp -AsJson | Out-String
    Assert-Label -CaseName 'already-linked' -ExpectedLabel 'GIT_ALREADY_LINKED' -Output $out
}
finally { Remove-TempDir -Path $tmp }

# Caso B: repositorio com origin divergente -> REMOTE_MISMATCH (sem rede)
$tmp = New-TempDir
try {
    & git -C $tmp init -b main *> $null
    & git -C $tmp remote add origin 'https://example.com/outro/repo.git' *> $null
    $out = & $scriptUnderTest -RepoRoot $tmp -AsJson | Out-String
    Assert-Label -CaseName 'remote-mismatch' -ExpectedLabel 'REMOTE_MISMATCH' -Output $out
}
finally { Remove-TempDir -Path $tmp }

# Caso C: repositorio sem origin + WhatIf -> ORIGIN_ADD_SKIPPED (sem rede/escrita)
$tmp = New-TempDir
try {
    & git -C $tmp init -b main *> $null
    $out = & $scriptUnderTest -RepoRoot $tmp -AsJson -WhatIf | Out-String
    Assert-Label -CaseName 'origin-missing-whatif' -ExpectedLabel 'ORIGIN_ADD_SKIPPED' -Output $out
}
finally { Remove-TempDir -Path $tmp }

# Caso D: pasta com conteudo, sem .git + WhatIf -> BOOTSTRAP_SKIPPED (sem rede/escrita)
$tmp = New-TempDir
try {
    Set-Content -LiteralPath (Join-Path $tmp 'README.md') -Value '# zip extraido' -Encoding utf8
    $out = & $scriptUnderTest -RepoRoot $tmp -AsJson -WhatIf | Out-String
    Assert-Label -CaseName 'not-a-repo-whatif' -ExpectedLabel 'BOOTSTRAP_SKIPPED' -Output $out
}
finally { Remove-TempDir -Path $tmp }

Write-Output ('---')
if ($failures -eq 0) {
    Write-Output ("SELFTEST_OK: {0}/{0} casos passaram" -f $cases)
    exit 0
}
else {
    Write-Output ("SELFTEST_FAIL: {0} de {1} casos falharam" -f $failures, $cases)
    exit 1
}
