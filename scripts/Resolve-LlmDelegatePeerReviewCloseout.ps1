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

    Este script NAO grava preferred-reviewers.json, NAO decide autorizacao por KB e NAO
    recalcula diversidade. Ele so emite JSON de maquina para o orquestrador:
    pronto/bloqueado, razoes, prompt obrigatorio e adendo de recibo. A gravacao continua
    sendo de Set-LlmDelegatePreferredReviewers.ps1.

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

    Quando preferred-reviewers.json existia, a lista preferida nao e autorizacao nem obriga
    parecer util de todos, mas tambem nao pode virar pool opcional silencioso. O fechamento
    exige estado auditavel para cada revisor preferido da rodada. Estados incompletos
    (`gateAllow`, `dispatched`, `enqueued`) bloqueiam o recibo final; estados finais como
    `responded`, `noResponse`, `timeout`, `error`, `gateAsk`, `gateDeny`, `unavailable`,
    `skippedByHumanDecision` e `stoppedOnGap` liberam, desde que o piso de diversidade ja tenha
    sido tratado pelo motor proprio.
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
.PARAMETER PreferredReviewerStatesJson
    JSON opcional com o estado final de cada revisor preferido da rodada:
    [{ "targetModelKey": "...", "backend": "...", "state": "responded|noResponse|timeout|error|gateAsk|gateDeny|unavailable|skippedByHumanDecision|stoppedOnGap|gateAllow|dispatched|enqueued", "family": "..." }].
    Quando HadPreferredReviewers=true, deve conter todos os preferidos resolvidos.
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
    [string] $PreferredReviewerStatesJson = '[]',
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

$preferredReviewerStates = @()
try {
    $parsedStates = $PreferredReviewerStatesJson | ConvertFrom-Json
    $preferredReviewerStates = @($parsedStates)
} catch {
    throw "BLOCK: -PreferredReviewerStatesJson nao e JSON valido: $($_.Exception.Message)"
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

$validFinalStates = @(
    'responded',
    'noResponse',
    'timeout',
    'error',
    'gateAsk',
    'gateDeny',
    'unavailable',
    'skippedByHumanDecision',
    'stoppedOnGap'
)
$incompleteStates = @('gateAllow', 'dispatched', 'enqueued')
$allKnownStates = @($validFinalStates + $incompleteStates)
$preferredStateRows = [System.Collections.Generic.List[object]]::new()

foreach ($st in $preferredReviewerStates) {
    $target = [string](Get-Prop $st 'targetModelKey')
    $state = [string](Get-Prop $st 'state')
    $backend = [string](Get-Prop $st 'backend')
    $family = [string](Get-Prop $st 'family')

    if ([string]::IsNullOrWhiteSpace($target)) {
        $blockingReasons.Add('preferred-reviewer-state-missing-target')
        continue
    }
    if ([string]::IsNullOrWhiteSpace($state)) {
        $blockingReasons.Add("preferred-reviewer-state-missing-state:$target")
        continue
    }
    if ($allKnownStates -notcontains $state) {
        $blockingReasons.Add("preferred-reviewer-state-invalid:${target}:${state}")
        continue
    }
    if ($incompleteStates -contains $state) {
        $blockingReasons.Add("preferred-reviewer-state-incomplete:${target}:${state}")
    }

    $preferredStateRows.Add([pscustomobject]@{
            targetModelKey = $target
            backend        = $backend
            family         = $family
            state          = $state
        })
}

if ($HadPreferredReviewers -and $preferredStateRows.Count -eq 0) {
    $blockingReasons.Add('preferred-reviewer-states-missing')
}

$labels = @($selectedReviewers | ForEach-Object { Get-ReviewerLabel $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$selectedText = if ($labels.Count -gt 0) { ($labels -join ', ') } else { 'os revisores escolhidos nesta rodada' }

$preferredPath = '%LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json'
$requiredPrompt = $null
if ($requiresOffer -and ($blockingReasons -contains 'preferred-reviewers-offer-missing' -or $blockingReasons -contains 'preferred-reviewers-offer-state-invalid-for-manual-selection')) {
    $requiredPrompt = "Antes de encerrar a revisão por pares: você quer salvar $selectedText como revisores preferidos desta máquina em ${preferredPath}? Se responder sim, vou usar Set-LlmDelegatePreferredReviewers.ps1; se preferir não salvar ou adiar, sigo sem bloquear esta rodada."
} elseif ($blockingReasons.Count -gt 0) {
    $requiredPrompt = 'Antes de encerrar a revisão por pares: registre no recibo o estado final de cada revisor preferido da rodada, sem omitir preferidos não consultados. Se algum ficou fora, informe o motivo auditável.'
}

$closeoutReady = ($blockingReasons.Count -eq 0)
$curationReceipt = if ($requiresOffer) {
    "Curadoria de revisores preferidos: oferta=$PreferredReviewersOfferState; destino=$preferredPath."
} else {
    "Curadoria de revisores preferidos: not_applicable; motivo=" + ($(if ($HadPreferredReviewers) { 'preferred-reviewers.json ja existia' } else { 'sem selecao manual de revisores' }))
}
$stateReceipt = if ($HadPreferredReviewers) {
    "Estados dos revisores preferidos: registrados=$($preferredStateRows.Count)."
} else {
    'Estados dos revisores preferidos: not_applicable.'
}
$receiptAddendum = "$curationReceipt $stateReceipt"

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
    preferredReviewerStates      = @($preferredStateRows)
    requiredUserPrompt           = $requiredPrompt
    receiptAddendum              = $receiptAddendum
    note                         = 'Fechamento consultivo/deterministico da revisao por pares; nao grava preferencia, nao decide autorizacao e nao recalcula diversidade. Se closeoutReady=false, nao encerrar a rodada nem emitir recibo final sem antes apresentar requiredUserPrompt.'
} | ConvertTo-Json -Depth 8
