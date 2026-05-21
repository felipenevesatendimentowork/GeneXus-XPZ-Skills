#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para obter timestamp GeneXus lastUpdate.

.DESCRIPTION
Delega ao motor compartilhado `Get-GeneXusXpzLastUpdate.ps1`, retornando o
instante UTC corrente no formato usado por `Object/@lastUpdate`.

.PARAMETER Count
Quantidade de timestamps a devolver. Default: 1.

.PARAMETER AsJson
Retorna saida JSON estruturada.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.
#>

param(
    [ValidateRange(1, 1000)]
    [int]$Count = 1,

    [switch]$AsJson,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$enginePath = Join-Path $SharedSkillsRoot "scripts\Get-GeneXusXpzLastUpdate.ps1"

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared lastUpdate script not found: $enginePath"
}

$argsForEngine = @{
    Count = $Count
}

if ($AsJson) {
    $argsForEngine.AsJson = $true
}

& $enginePath @argsForEngine
