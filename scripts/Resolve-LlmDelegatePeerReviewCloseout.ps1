#requires -Version 7.4
<#
.SYNOPSIS
    Verifica, de forma deterministica, se uma rodada de revisao por pares pode ser encerrada
    sem omitir a oferta de salvar revisores preferidos.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.

    Por que existe: em teste real, o agente consumidor leu a regra de persistencia de
    preferred-reviewers.json, pediu os revisores, executou o painel e encerrou a rodada sem
    oferecer salvar a curadoria. Este resolvedor torna esse ponto de fechamento mecanico:
    quando a rodada comeca sem preferred-reviewers.json e o usuario escolhe revisores
    manualmente, o encerramento so fica pronto se a oferta foi feita ou se houve decisao
    explicita equivalente.

    Este script NAO grava preferred-reviewers.json e NAO decide autorizacao por KB. Ele so
    emite JSON de maquina para o orquestrador: pronto/bloqueado, razoes, prompt obrigatorio
    e adendo de recibo. A gravacao continua sendo de Set-LlmDelegatePreferredReviewers.ps1.

    Estados de oferta:
      not_made       -> oferta obrigatoria ainda nao feita
      offered        -> oferta apresentada ao usuario; a rodada pode seguir sem resposta
      accepted       -> usuario aceitou salvar curadoria
      declined       -> usuario recusou salvar curadoria
      deferred       -> usuario adiou salvar curadoria
      not_applicable -> nao havia obrigacao de ofertar nesta rodada

    Regra fail-closed: se nao havia preferred-reviewers.json, houve selecao manual, e o estado
    vier not_applicable ou ausente, o fechamento bloqueia. not_applicable so e valido quando
    ja havia preferencias ou quando a rodada nao usou selecao manual de revisores.
.PARAMETER HadPreferredReviewers
    Indica se Resolve-LlmDelegatePreferredReviewers.ps1 devolveu hasPreferences=true no inicio
    da montagem do painel.
.PARAMETER ManualReviewerSelection
    Indica se o usuario escolheu revisores manualmente para esta rodada.
.PARAMETER PreferredReviewersOfferState
    Estado da oferta de salvar a selecao em preferred-reviewers.json.
.PARAMETER RoundId
    Identificador opcional da rodada, usado apenas para recibo e auditoria.
.PARAMETER SelectedReviewersJson
    JSON opcional com os revisores escolhidos. Usado para ecoar a selecao no prompt.
.PARAMETER DiversityState
    Estado opcional ja calculado por Resolve-LlmDelegatePanelDiversity.ps1. Este script nao
    recalcula diversidade; apenas ecoa o valor no recibo.
.EXAMPLE
    .\Resolve-LlmDelegatePeerReviewCloseout.ps1 -HadPreferredReviewers:$false -ManualReviewerSelection:$true -PreferredReviewersOfferState not_made
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [bool] $HadPreferredReviewers,
    [Parameter(Mandatory)] [bool] $ManualReviewerSelection,
    [ValidateSet('not_made', 'offered', 'accepted', 'declined', 'deferred', 'not_applicable')]
    [string] $PreferredReviewersOfferState = 'not_applicable',
    [string] $RoundId,
    [string] $SelectedReviewersJson = '[]',
    [string] $DiversityState
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) { return $Obj.PSObject.Properties[$Name].Value }
    return $null
}

function Get-ReviewerLabel {
    param($Reviewer)
    $backend = [string](Get-Prop $Reviewer 'backend')
    $target = [string](Get-Prop $Reviewer 'targetModelKey')
    if ([string]::IsNullOrWhiteSpace($target)) { $target = [string](Get-Prop $Reviewer 'model') }
    if ([string]::IsNullOrWhiteSpace($backend)) { return $target }
    if ([string]::IsNullOrWhiteSpace($target)) { return $backend }
    return "$backend -> $target"
}

$selectedReviewers = @()
try {
    $parsed = $SelectedReviewersJson | ConvertFrom-Json
    $selectedReviewers = @($parsed)
} catch {
    throw "BLOCK: -SelectedReviewersJson nao e JSON valido: $($_.Exception.Message)"
}

$requiresOffer = (-not $HadPreferredReviewers) -and $ManualReviewerSelection
$blockingReasons = [System.Collections.Generic.List[string]]::new()

if ($requiresOffer -and $PreferredReviewersOfferState -eq 'not_made') {
    $blockingReasons.Add('preferred-reviewers-offer-missing')
}

if ($requiresOffer -and $PreferredReviewersOfferState -eq 'not_applicable') {
    $blockingReasons.Add('preferred-reviewers-offer-state-invalid-for-manual-selection')
}

if (-not $requiresOffer -and $PreferredReviewersOfferState -ne 'not_applicable' -and -not $ManualReviewerSelection) {
    $blockingReasons.Add('preferred-reviewers-offer-state-unexpected-without-manual-selection')
}

$labels = @($selectedReviewers | ForEach-Object { Get-ReviewerLabel $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$selectedText = if ($labels.Count -gt 0) { ($labels -join ', ') } else { 'os revisores escolhidos nesta rodada' }

$preferredPath = '%LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json'
$requiredPrompt = $null
if ($blockingReasons.Count -gt 0) {
    $requiredPrompt = "Antes de encerrar a revisão por pares: você quer salvar $selectedText como revisores preferidos desta máquina em ${preferredPath}? Se responder sim, vou usar Set-LlmDelegatePreferredReviewers.ps1; se preferir não salvar ou adiar, sigo sem bloquear esta rodada."
}

$closeoutReady = ($blockingReasons.Count -eq 0)
$receiptAddendum = if ($requiresOffer) {
    "Curadoria de revisores preferidos: oferta=$PreferredReviewersOfferState; destino=$preferredPath."
} else {
    "Curadoria de revisores preferidos: not_applicable; motivo=" + ($(if ($HadPreferredReviewers) { 'preferred-reviewers.json ja existia' } else { 'sem selecao manual de revisores' }))
}

[pscustomobject]@{
    closeoutReady                = $closeoutReady
    blockingReasons             = @($blockingReasons)
    requiresPreferredOffer       = $requiresOffer
    hadPreferredReviewers        = $HadPreferredReviewers
    manualReviewerSelection      = $ManualReviewerSelection
    preferredReviewersOfferState = $PreferredReviewersOfferState
    roundId                      = $RoundId
    diversityState               = $DiversityState
    selectedReviewers            = @($labels)
    requiredUserPrompt           = $requiredPrompt
    receiptAddendum              = $receiptAddendum
    note                         = 'Fechamento consultivo/deterministico da revisao por pares; nao grava preferencia e nao decide autorizacao. Se closeoutReady=false, nao encerrar a rodada nem emitir recibo final sem antes apresentar requiredUserPrompt.'
} | ConvertTo-Json -Depth 8
