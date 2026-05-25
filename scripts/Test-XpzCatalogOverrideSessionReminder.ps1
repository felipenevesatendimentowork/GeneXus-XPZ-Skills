#requires -Version 7.4
<#
.SYNOPSIS
    Emite lembrete de sessao quando gx-object-type-catalog.override.json estiver ativo.

.PARAMETER ParallelKbRoot
    Raiz da pasta paralela da KB.

.PARAMETER CatalogOverridePath
    Caminho opcional do override.

.PARAMETER AsJson
    Saida JSON (recomendado para agentes).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ParallelKbRoot,

    [string]$CatalogOverridePath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1')

$resolvedKbRoot = (Resolve-Path -LiteralPath $ParallelKbRoot).Path
$reminder = Get-GeneXusCatalogOverrideSessionReminder -ParallelKbRoot $resolvedKbRoot -CatalogOverridePath $CatalogOverridePath

$result = [pscustomobject]@{
    status           = if ($reminder.reminderRequired) { 'REMINDER_REQUIRED' } else { 'OK' }
    parallelKbRoot   = $resolvedKbRoot
    reminderRequired = $reminder.reminderRequired
    overrideActive   = $reminder.overrideActive
    upstreamPending  = $reminder.upstreamPending
    overridePath     = $reminder.overridePath
    pendingTypeNames = $reminder.pendingTypeNames
    pendingTypeGuids = $reminder.pendingTypeGuids
    message          = $reminder.message
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    if ($reminder.reminderRequired) {
        Write-Output $reminder.message
    } else {
        Write-Output 'OK: nenhum override local de catalogo ativo.'
    }
}

exit $(if ($reminder.reminderRequired) { 2 } else { 0 })
