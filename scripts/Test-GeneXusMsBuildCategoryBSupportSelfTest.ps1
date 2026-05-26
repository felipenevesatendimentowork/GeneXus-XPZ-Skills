#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusMsBuildCategoryBSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusMsBuildCategoryBSupport.ps1 nao encontrado: $supportPath"
}
. $supportPath

if (-not (Test-GeneXusMsBuildCategoryBPresent -MsBuildErrors @('error : test') -InvalidTypesRejected @())) {
    throw 'Test-GeneXusMsBuildCategoryBPresent deveria ser true com exportErrors'
}

if (Test-GeneXusMsBuildCategoryBPresent -MsBuildErrors @() -InvalidTypesRejected @()) {
    throw 'Test-GeneXusMsBuildCategoryBPresent deveria ser false sem sinais'
}

$downgraded = Resolve-GeneXusMsBuildCategoryBExitCode `
    -BaseExitCode 0 `
    -MsBuildExitCode 0 `
    -MsBuildErrors @('error : WorkWithForWeb is not a valid type.') `
    -InvalidTypesRejected @('WorkWithForWeb')

if ($downgraded -ne 48) {
    throw "Esperava exit 48; obtido: $downgraded"
}

$unchanged = Resolve-GeneXusMsBuildCategoryBExitCode `
    -BaseExitCode 41 `
    -MsBuildExitCode 1 `
    -MsBuildErrors @('error : x') `
    -InvalidTypesRejected @()

if ($unchanged -ne 41) {
    throw "BaseExitCode 41 deveria ser preservado; obtido: $unchanged"
}

$reasons = @(Get-GeneXusMsBuildCategoryBBlockingReasons -MsBuildErrors @('error : a') -InvalidTypesRejected @('TipoX') -StageLabel 'Export')
if ($reasons.Count -lt 2) {
    throw "Esperava pelo menos 2 blocking reasons; obtido: $($reasons.Count)"
}

Write-Output 'MSBUILD_CATEGORY_B_SUPPORT_SELFTEST_OK'
