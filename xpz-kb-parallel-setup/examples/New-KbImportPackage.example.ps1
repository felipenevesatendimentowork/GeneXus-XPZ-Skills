#requires -version 5.1
<#
.SYNOPSIS
Wrapper local sanitizado para criar pacote import_file.xml de uma frente da KB.

.DESCRIPTION
Executa o motor compartilhado `New-XpzImportPackage.ps1`, que lê
`kb-source-metadata.md`, coleta os XMLs de
`ObjetosGeradosParaImportacaoNaKbNoGenexus\<FrontName>` e grava o pacote em
`PacotesGeradosParaImportacaoNaKbNoGenexus`.

Este wrapper é recomendado quando a pasta paralela adota empacotamento local
recorrente e precisa de comando curto, auditável e aderente a allowlist.

.PARAMETER FrontName
Nome da subpasta da frente no formato `NomeCurto_GUID_YYYYMMDD`.

.PARAMETER NN
Rodada curta pretendida para o pacote. Default: 01.

.PARAMETER AsJson
Retorna saída JSON estruturada.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
.\New-KbImportPackage.ps1 -FrontName MinhaFrente_12345678-1234-1234-1234-1234567890ab_20260429 -NN 01
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

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

& $enginePath @argsForEngine
