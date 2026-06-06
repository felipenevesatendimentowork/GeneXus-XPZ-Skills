#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para copiar XMLs do acervo para a frente, com bump de lastUpdate.

.DESCRIPTION
Chama o script compartilhado Copy-GeneXusAcervoToFront.ps1 para copiar XMLs de
ObjetosDaKbEmXml para a pasta da frente, com bump automatico de lastUpdate.
Resolve o anti-padrao "editar acervo esperando que o pacote pegue": em vez de
editar o acervo, copia a versao mais recente para a frente e bumpa o lastUpdate.
Quando ObjectNames ou ObjectGuids e informado e o objeto ainda nao existe na frente,
faz seed inicial desse objeto a partir do acervo. Seed nunca ocorre sem alvo explicito.

.PARAMETER FrontName
Nome da subpasta da frente no formato NomeCurto_GUID_YYYYMMDD.

.PARAMETER ObjectNames
Nomes de objetos a copiar (opcional). Quando omitido, copia todos com drift.
Para seed inicial, deve identificar um unico XML no acervo.

.PARAMETER ObjectList
Alias operacional para selecao de objetos. Aceita nomes simples ou entradas
`Tipo:Nome`; o wrapper repassa apenas o nome ao motor de copia.

.PARAMETER ObjectGuids
GUIDs de objetos a copiar (opcional). Quando omitido, copia todos com drift.
Para seed inicial, deve identificar um unico XML no acervo.

.PARAMETER DryRun
Mostra o que seria copiado sem gravar.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada GeneXus-XPZ-Skills.

.EXAMPLE
.\Copy-KbAcervoToFront.ps1 -FrontName GtaP3_c34f_20260528
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string[]]$ObjectNames,

    [string[]]$ObjectList,

    [string[]]$ObjectGuids,

    [switch]$DryRun,

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

if ($null -ne $ObjectNames -and $ObjectNames.Count -gt 0) {
    $argsForScript.ObjectNames = $ObjectNames
}

if ($null -ne $ObjectList -and $ObjectList.Count -gt 0) {
    $objectListNames = @($ObjectList | ForEach-Object {
        $item = [string]$_
        if ($item -match '^[^:]+:(?<name>.+)$') { $Matches['name'] } else { $item }
    })
    $argsForScript.ObjectNames = @($argsForScript.ObjectNames) + $objectListNames
}

if ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0) {
    $argsForScript.ObjectGuids = $ObjectGuids
}

& $scriptPath @argsForScript
