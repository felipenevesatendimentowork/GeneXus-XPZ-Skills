#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para criar pacote import_file.xml de uma frente da KB.

.DESCRIPTION
Executa o wrapper compartilhado `New-XpzImportPackage.ps1`, que chama o motor Python,
le
`kb-source-metadata.md`, coleta os XMLs de
`ObjetosGeradosParaImportacaoNaKbNoGenexus\<FrontName>` e grava o pacote em
`PacotesGeradosParaImportacaoNaKbNoGenexus`.

Este wrapper e recomendado quando a pasta paralela adota empacotamento local
recorrente e precisa de comando curto, auditavel e aderente a allowlist.

Quando -AcervoPath e fornecido, o gate de drift frente-vs-acervo
(Test-GeneXusFrontAcervoDrift.ps1) executa antes do empacotamento para detectar
XMLs na frente com lastUpdate mais antigo que o homonimo no acervo.

.PARAMETER FrontName
Nome da subpasta da frente no formato `NomeCurto_GUID_YYYYMMDD`.

.PARAMETER NN
Rodada curta pretendida para o pacote. Default: 01.

.PARAMETER AsJson
Retorna saida JSON estruturada.

.PARAMETER TemplatePackagePath
Pacote import_file.xml ou XPZ real comparavel para clonar KMW, Source,
Dependencies e ObjectsIdentityMapping. Quando o template trouxer Attributes de
topo e a frente nao trouxer atributos explicitos, o motor preserva esses
Attributes. Quando omitido, o motor usa envelope minimo derivado de
kb-source-metadata.md.

.PARAMETER AcervoPath
Caminho para a pasta do acervo oficial (ObjetosDaKbEmXml). Quando fornecido,
executa o gate de drift frente-vs-acervo antes do empacotamento. Se o gate
detectar que um XML da frente esta mais antigo que o homonimo no acervo,
o empacotamento e abortado.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
.\New-KbImportPackage.ps1 -FrontName MinhaFrente_12345678-1234-1234-1234-1234567890ab_20260429 -NN 01
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

    [string]$TemplatePackagePath,

    [string]$AcervoPath,

    [switch]$AsJson,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $SharedSkillsRoot "scripts\New-XpzImportPackage.ps1"

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared import package script not found: $enginePath"
}

$argsForEngine = @{
    RepoRoot = $repoRoot
    FrontName = $FrontName
    NN = $NN
}

if ($AsJson) {
    $argsForEngine.AsJson = $true
}

if (-not [string]::IsNullOrWhiteSpace($TemplatePackagePath)) {
    $argsForEngine.TemplatePackagePath = $TemplatePackagePath
}

if (-not [string]::IsNullOrWhiteSpace($AcervoPath)) {
    $argsForEngine.AcervoPath = $AcervoPath
}

& $enginePath @argsForEngine
