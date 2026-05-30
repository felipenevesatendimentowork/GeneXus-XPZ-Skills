#requires -Version 7.4
<#
.SYNOPSIS
    Valida bloqueio de consultas semanticas quando queryableByKbIntelligence=false.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$buildScript = Join-Path $scriptDir 'Build-KbIntelligenceIndex.ps1'
$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.ps1'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kb-queryable-guard-selftest-{0}" -f ([guid]::NewGuid().ToString('N')))
$objetosPath = Join-Path $tempRoot 'ObjetosDaKbEmXml'
$sdpDir = Join-Path $objetosPath 'SmartDevicesPlus'
$sqlitePath = Join-Path $tempRoot 'KbIntelligence\kb-intelligence.sqlite'

[void](New-Item -ItemType Directory -Path $sdpDir -Force)
[void](New-Item -ItemType Directory -Path (Split-Path -Parent $sqlitePath) -Force)

$sdpXml = @'
<Object type="c84ec0ea-d159-46e2-a118-2108860379bb" name="SmartDevicesPlus" description="Smart Devices Plus" parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361"><Properties><Property><Name>SDPlus_Settings_Theme</Name><Value>DarkBlue</Value></Property></Properties></Object>
'@
[System.IO.File]::WriteAllText((Join-Path $sdpDir 'SmartDevicesPlus.xml'), $sdpXml, (New-Object System.Text.UTF8Encoding($false)))

& $buildScript -SourceRoot $objetosPath -OutputPath $sqlitePath
if ($LASTEXITCODE -ne 0) {
    throw "Build-KbIntelligenceIndex falhou; exit $LASTEXITCODE"
}

$blockedJson = & $queryScript `
    -IndexPath $sqlitePath `
    -Query impact-basic `
    -ObjectType SmartDevicesPlus `
    -ObjectName SmartDevicesPlus `
    -Format json 2>&1 | Out-String
$blockedExit = $LASTEXITCODE

if ($blockedExit -ne 11) {
    throw "impact-basic em SmartDevicesPlus deveria exit 11; obtido $blockedExit"
}

$blocked = $blockedJson | ConvertFrom-Json
if (-not $blocked.blocked) {
    throw 'impact-basic deveria retornar blocked=true'
}
if ($blocked.reason -ne 'QUERY_NOT_SEMANTIC_FOR_TYPE') {
    throw "reason esperado QUERY_NOT_SEMANTIC_FOR_TYPE; obtido $($blocked.reason)"
}

$infoJson = & $queryScript `
    -IndexPath $sqlitePath `
    -Query object-info `
    -ObjectType SmartDevicesPlus `
    -ObjectName SmartDevicesPlus `
    -Format json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "object-info deveria exit 0; obtido $LASTEXITCODE"
}
if ($infoJson.found -ne $true) {
    throw 'object-info deveria encontrar SmartDevicesPlus no indice'
}

Write-Output 'OK: Test-KbIntelligenceQueryableGuardSelfTest.ps1'
exit 0
