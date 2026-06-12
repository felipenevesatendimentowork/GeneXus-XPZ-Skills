#requires -Version 7.4

<#
.SYNOPSIS
Bateria mínima do catalogo de descoberta de MSBuild (vswhere + caminhos estaticos).

.DESCRIPTION
Valida que o catalogo estatico cobre Visual Studio 18, VS 2022 em Program Files e
Program Files (x86), variantes BuildTools/Community e binarios amd64, sem depender
de instalacao local. Não substitui probe real com Test-GeneXusMsBuildSetup.ps1.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$contractPath = Join-Path $PSScriptRoot 'GeneXusMsBuildPathContract.ps1'
if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    throw "GeneXusMsBuildPathContract.ps1 nao encontrado: $contractPath"
}

. $contractPath

$staticPaths = @(Get-MsBuildStaticCandidatePaths)
if ($staticPaths.Count -lt 32) {
    throw "Catalogo estatico menor que o esperado (32 entradas minimas); obtido: $($staticPaths.Count)"
}

$requiredFragments = @(
    'Microsoft Visual Studio\18\BuildTools\MSBuild\Current\Bin\MSBuild.exe',
    'Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe',
    'Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe',
    'Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\amd64\MSBuild.exe',
    'Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe'
)

foreach ($fragment in $requiredFragments) {
    $hit = @($staticPaths | Where-Object { $_ -like "*$fragment*" })
    if ($hit.Count -eq 0) {
        throw "Catalogo estatico sem fragmento obrigatorio: $fragment"
    }
}

$catalogPlan = Get-MsBuildCandidateCatalog
$catalog = @($catalogPlan.catalog)
if ($catalog.Count -lt $staticPaths.Count) {
    throw "Catalogo unificado menor que o estatico; obtido: $($catalog.Count)"
}

$sources = @($catalog | ForEach-Object { $_.source } | Select-Object -Unique)
if (-not ($sources -contains 'static')) {
    throw 'Catalogo unificado sem entradas static.'
}

$vswherePath = Get-VsWhereExecutablePath
if (-not [string]::IsNullOrWhiteSpace($vswherePath)) {
    $vsDiag = $null
    $vsPaths = @(Get-VsWhereMsBuildCandidatePaths -VsWhereDiagnostics ([ref]$vsDiag))
    if ($null -eq $vsDiag -or -not $vsDiag.invoked) {
        throw 'vswhere presente mas diagnostico nao marcou invoked=true.'
    }

    if ($vsPaths.Count -gt 0) {
        $merged = @($catalogPlan.catalog)
        if ($merged[0].source -ne 'vswhere') {
            throw 'Com vswhere retornando caminhos, a primeira entrada do catalogo deveria ser vswhere.'
        }
    }
}

Write-Output 'MSBUILD_DISCOVERY_CONTRACT_OK'
exit 0
