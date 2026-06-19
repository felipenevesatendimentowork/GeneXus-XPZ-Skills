#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test de Resolve-LlmDelegatePeerReviewCloseout.ps1 (skill xpz-llm-delegate).
# Cobre o bug real: sem preferred-reviewers.json + selecao manual + oferta omitida
# deve bloquear o fechamento da revisao por pares.

$target = Join-Path $PSScriptRoot 'Resolve-LlmDelegatePeerReviewCloseout.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $target -PathType Leaf) "Script ausente: $target"

function Invoke-Closeout {
    param(
        [bool] $HadPreferredReviewers,
        [bool] $ManualReviewerSelection,
        [string] $OfferState,
        [string] $SelectedReviewersJson = '[]',
        [string] $PreferredReviewerStatesJson = '[]'
    )
    return (& $target `
            -HadPreferredReviewers:$HadPreferredReviewers `
            -ManualReviewerSelection:$ManualReviewerSelection `
            -PreferredReviewersOfferState $OfferState `
            -SelectedReviewersJson $SelectedReviewersJson `
            -PreferredReviewerStatesJson $PreferredReviewerStatesJson | ConvertFrom-Json)
}

# (1) Caso do bug: sem preferencias previas, escolha manual, oferta omitida -> bloqueia.
$r1 = Invoke-Closeout $false $true 'not_made' '[{"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro"}]'
Assert-True ($r1.closeoutReady -eq $false) 'Caso 1: fechamento deveria bloquear.'
Assert-True (@($r1.blockingReasons) -contains 'preferred-reviewers-offer-missing') 'Caso 1: razao de bloqueio ausente.'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$r1.requiredUserPrompt)) 'Caso 1: prompt obrigatorio ausente.'

# (2) Oferta apresentada, mesmo sem resposta final, libera a rodada.
$r2 = Invoke-Closeout $false $true 'offered'
Assert-True ($r2.closeoutReady -eq $true) 'Caso 2: oferta apresentada deveria liberar fechamento.'

# (3) Usuario recusou salvar curadoria -> libera e registra no recibo.
$r3 = Invoke-Closeout $false $true 'declined'
Assert-True ($r3.closeoutReady -eq $true) 'Caso 3: recusa deveria liberar fechamento.'
Assert-True ([string]$r3.receiptAddendum -match 'oferta=declined') 'Caso 3: recibo deveria registrar declined.'

# (4) Usuario adiou salvar curadoria -> libera e registra no recibo.
$r4 = Invoke-Closeout $false $true 'deferred'
Assert-True ($r4.closeoutReady -eq $true) 'Caso 4: adiamento deveria liberar fechamento.'
Assert-True ([string]$r4.receiptAddendum -match 'oferta=deferred') 'Caso 4: recibo deveria registrar deferred.'

# (5) Ja havia preferred-reviewers.json -> exige estados dos preferidos para fechar.
$r5 = Invoke-Closeout $true $false 'not_applicable'
Assert-True ($r5.closeoutReady -eq $false) 'Caso 5: preferencias existentes sem estados deveriam bloquear.'
Assert-True (@($r5.blockingReasons) -contains 'preferred-reviewer-states-missing') 'Caso 5: razao preferred-reviewer-states-missing ausente.'

# (6) Ja havia preferred-reviewers.json + estados finais -> not_applicable e valido.
$statesOk = @'
[
  {"backend":"claude-code","targetModelKey":"anthropic/claude-opus-4-8","family":"anthropic","state":"responded"},
  {"backend":"codex","targetModelKey":"openai/gpt-5.5","family":"openai","state":"responded"},
  {"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro","family":"ollama-cloud","state":"noResponse"},
  {"backend":"opencode","targetModelKey":"ollama-cloud/glm-5.2","family":"ollama-cloud","state":"stoppedOnGap"}
]
'@
$r6 = Invoke-Closeout $true $false 'not_applicable' '[]' $statesOk
Assert-True ($r6.closeoutReady -eq $true) 'Caso 6: preferencias existentes com estados finais deveriam liberar.'
Assert-True ($r6.requiresPreferredOffer -eq $false) 'Caso 6: requiresPreferredOffer deveria ser false.'
Assert-True (@($r6.preferredReviewerStates).Count -eq 4) 'Caso 6: deveria ecoar 4 estados de revisores preferidos.'
Assert-True ([string]$r6.receiptAddendum -match 'registrados=4') 'Caso 6: recibo deveria registrar quantidade de estados.'

# (7) Estado incompleto em revisor preferido -> bloqueia.
$statesIncomplete = '[{"backend":"opencode","targetModelKey":"ollama-cloud/kimi-k2.7-code","family":"ollama-cloud","state":"gateAllow"}]'
$r7 = Invoke-Closeout $true $false 'not_applicable' '[]' $statesIncomplete
Assert-True ($r7.closeoutReady -eq $false) 'Caso 7: estado incompleto gateAllow deveria bloquear.'
Assert-True (@($r7.blockingReasons) -contains 'preferred-reviewer-state-incomplete:ollama-cloud/kimi-k2.7-code:gateAllow') 'Caso 7: razao de estado incompleto ausente.'

# (8) not_applicable indevido com selecao manual sem preferencias previas -> fail-closed.
$r8 = Invoke-Closeout $false $true 'not_applicable'
Assert-True ($r8.closeoutReady -eq $false) 'Caso 8: not_applicable indevido deveria bloquear.'
Assert-True (@($r8.blockingReasons) -contains 'preferred-reviewers-offer-state-invalid-for-manual-selection') 'Caso 8: razao fail-closed ausente.'

# (9) JSON invalido deve falhar de forma explicita.
$failed = $false
try {
    [void](Invoke-Closeout $false $true 'not_made' '{')
} catch {
    $failed = ($_.Exception.Message -match 'SelectedReviewersJson')
}
Assert-True $failed 'Caso 9: JSON invalido deveria falhar citando SelectedReviewersJson.'

# (10) JSON invalido de estados deve falhar de forma explicita.
$failedStates = $false
try {
    [void](Invoke-Closeout $true $false 'not_applicable' '[]' '{')
} catch {
    $failedStates = ($_.Exception.Message -match 'PreferredReviewerStatesJson')
}
Assert-True $failedStates 'Caso 10: JSON invalido deveria falhar citando PreferredReviewerStatesJson.'

<#
Casos antigos mantidos por cobertura historica:
  - sem preferencias previas + escolha manual + oferta omitida -> bloqueia;
  - oferta apresentada/recusada/adiada -> libera a rodada ad-hoc;
  - estados de preferidos existentes agora sao obrigatorios no fechamento.
#>

Write-Output 'OK: Test-LlmDelegatePeerReviewCloseoutSelfTest.ps1'
