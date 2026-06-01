#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para copiar XMLs do acervo para a frente quando o acervo e mais recente.

.DESCRIPTION
Chama o script compartilhado Copy-GeneXusAcervoToFront.ps1 para copiar XMLs de
ObjetosDaKbEmXml para a pasta da frente, com bump automatico de lastUpdate.
Resolve o anti-padrao "editar acervo esperando que o pacote pegue": em vez de
editar o acervo, copia a versao mais recente para a frente e bumpa o lastUpdate.

.PARAMETER FrontName
Nome da subpasta da frente no formato NomeCurto_GUID_YYYYMMDD.

.PARAMETER ObjectNames
Nomes de objetos a copiar (opcional). Quando omitido, copia todos com drift.

.PARAMETER ObjectGuids
GUIDs de objetos a copiar (opcional). Quando omitido, copia todos com drift.

.PARAMETER DryRun
Mostra o que seria copiado sem gravar.

.PARAMETER AsJson
Retorna saida JSON estruturada.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada GeneXus-XPZ-Skills.

.EXAMPLE
.\Copy-KbAcervoToFront.ps1 -FrontName GtaP3_c34f_20260528 -AsJson
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string[]]$ObjectNames,

    [string[]]$ObjectGuids,

    [switch]$DryRun,

    [switch]$AsJson,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $SharedSkillsRoot "scripts\Copy-GeneXusAcervoToFront.ps1"

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Shared script not found: $scriptPath"
}

$frontFolder = Join-Path $repoRoot "ObjetosGeradosParaImportacaoNaKbNoGenexus" $FrontName
$acervoFolder = Join-Path $repoRoot "ObjetosDaKbEmXml"

$argsForScript = @{
    FrontFolder = $frontFolder
    AcervoFolder = $acervoFolder
}

if ($DryRun) {
    $argsForScript.DryRun = $true
}

if ($AsJson) {
    $argsForScript.AsJson = $true
}

if ($null -ne $ObjectNames -and $ObjectNames.Count -gt 0) {
    $argsForScript.ObjectNames = $ObjectNames
}

if ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0) {
    $argsForScript.ObjectGuids = $ObjectGuids
}

& $scriptPath @argsForScript
