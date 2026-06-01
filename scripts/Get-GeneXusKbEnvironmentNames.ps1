#requires -Version 7.4
<#
.SYNOPSIS
    Inventaria environments GeneXus registrados na KB via MSBuild (somente leitura).

.DESCRIPTION
    Pre-filtra pastas legadas na KB nativa (CSharpModel, Data*, backups, etc.) e valida cada
    candidato restante com SetActiveEnvironment. Substitui a heuristica removida de pastas com web\.

.PARAMETER KbNativePath
    Caminho da KB nativa GeneXus (ex.: C:\GxModels\FabricaBrasil18).

.PARAMETER WorkingDirectory
    Diretorio de trabalho para artefatos temporarios e probe MSBuild.

.PARAMETER LogPath
    Caminho do log JSON do probe inicial (opcional).

.PARAMETER GeneXusDir
    Instalacao GeneXus (opcional — resolvida pelo probe).

.PARAMETER MsBuildPath
    Caminho do MSBuild.exe (opcional — resolvido pelo probe).

.PARAMETER CandidateNames
    Quando informado, pula o scan de pastas e valida apenas estes nomes via MSBuild.

.PARAMETER AdditionalCandidateNames
    Nomes extras a incluir no scan (ex.: environment ainda sem pasta na KB nativa).

.PARAMETER DatabaseUser
    Usuario de banco para abertura headless (opcional).

.PARAMETER DatabasePassword
    Senha de banco para abertura headless (opcional).

.PARAMETER AsJson
    Emite JSON em vez de texto simples.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbNativePath,

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [string]$LogPath,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string[]]$CandidateNames,

    [string[]]$AdditionalCandidateNames,

    [string]$DatabaseUser,

    [string]$DatabasePassword,

    [switch]$AsJson,

    [switch]$VerboseLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbEnvironmentInventorySupport.ps1')

$result = Get-GeneXusKbRegisteredEnvironmentNamesFromMsBuild `
    -KbNativePath $KbNativePath `
    -WorkingDirectory $WorkingDirectory `
    -LogPath $LogPath `
    -GeneXusDir $GeneXusDir `
    -MsBuildPath $MsBuildPath `
    -CandidateNames $CandidateNames `
    -AdditionalCandidateNames $AdditionalCandidateNames `
    -DatabaseUser $DatabaseUser `
    -DatabasePassword $DatabasePassword `
    -VerboseLog:$VerboseLog

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    $namesJoined = ($result.kb_environment_names -join ', ')
    Write-Output ("KB_ENVIRONMENT_INVENTORY_OK: count={0} names={1}" -f $result.kb_environment_count, $namesJoined)
}
