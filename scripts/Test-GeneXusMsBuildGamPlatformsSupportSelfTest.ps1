#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusMsBuildGamPlatformsSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusMsBuildGamPlatformsSupport.ps1 nao encontrado: $supportPath"
}
. $supportPath

$geneXusDir = 'C:\Program Files (x86)\GeneXus\GeneXus18'
$platformsSegment = '\Library\GAM\Platforms\NetCore\PublishOutputs.deadbeef.txt'

$noiseLineMsb = ('C:\Program Files (x86)\GeneXus\GeneXus18{0} : error MSB3491: Could not write lines to file. Access to the path is denied.' -f $platformsSegment)
$noiseLineNuGet = ('C:\Program Files (x86)\Microsoft SDKs\NuGet\17.0\NuGet.targets(198,5): error : Access to the path ''C:\Program Files (x86)\GeneXus\GeneXus18{0}'' is denied.' -f $platformsSegment)
$cleanLine = 'Build All Task Sucesso'

try {
    $null = New-GamPlatformsEnvironmentRemediationHints -ResolvedGeneXusDir $geneXusDir -FilteredNoiseLines @()
    Write-Output 'EMPTY_HINTS_NO_THROW'
}
catch {
    throw "New-GamPlatformsEnvironmentRemediationHints com array vazio nao deveria lancar: $($_.Exception.Message)"
}

$hintsFromEmpty = New-GamPlatformsEnvironmentRemediationHints -ResolvedGeneXusDir $geneXusDir -FilteredNoiseLines @()
if ($null -ne $hintsFromEmpty) {
    throw 'Esperava null para FilteredNoiseLines vazio.'
}

$cleanSplit = Split-StdoutByGamPlatformsNoise -Lines @($cleanLine)
if (@($cleanSplit.NoiseLines).Count -ne 0) {
    throw 'Stdout limpo nao deveria produzir linhas de ruido GAM.'
}

$cleanPostFilter = Get-GamPlatformsStdoutPostFilterResult -StdOutLines @($cleanLine) -ResolvedGeneXusDir $geneXusDir
if (@($cleanPostFilter.NoiseLines).Count -ne 0) {
    throw 'Post-filter limpo deveria ter NoiseLines vazio.'
}
if ($null -ne $cleanPostFilter.EnvironmentRemediationHints) {
    throw 'Post-filter limpo nao deveria emitir environmentRemediationHints.'
}
if (-not [string]::IsNullOrWhiteSpace($cleanPostFilter.RemediationHintWarning)) {
    throw 'Post-filter limpo nao deveria registrar RemediationHintWarning.'
}

$noisySplit = Split-StdoutByGamPlatformsNoise -Lines @($cleanLine, $noiseLineMsb)
if (@($noisySplit.NoiseLines).Count -ne 1) {
    throw "Esperava 1 linha de ruido; obtido: $(@($noisySplit.NoiseLines).Count)"
}
if (@($noisySplit.NonNoiseLines).Count -ne 1) {
    throw "Esperava 1 linha util; obtido: $(@($noisySplit.NonNoiseLines).Count)"
}

$noisyPostFilter = Get-GamPlatformsStdoutPostFilterResult -StdOutLines @($noiseLineMsb, $noiseLineNuGet) -ResolvedGeneXusDir $geneXusDir
if ($null -eq $noisyPostFilter.EnvironmentRemediationHints) {
    throw 'Com ruido GAM filtrado, environmentRemediationHints deveria estar presente.'
}
$filteredBlock = $noisyPostFilter.EnvironmentRemediationHints.gamPlatformsWriteDeniedFiltered
if ($filteredBlock.filteredLineCount -ne 2) {
    throw "Esperava filteredLineCount=2; obtido: $($filteredBlock.filteredLineCount)"
}

Write-Output 'GENEXUS_MSBUILD_GAM_PLATFORMS_SUPPORT_SELFTEST_OK'
