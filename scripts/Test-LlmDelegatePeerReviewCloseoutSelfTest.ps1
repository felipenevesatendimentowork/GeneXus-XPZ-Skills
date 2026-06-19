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
        [string] $SelectedReviewersJson = '[]'
    )
    return (& $target `
            -HadPreferredReviewers:$HadPreferredReviewers `
            -ManualReviewerSelection:$ManualReviewerSelection `
            -PreferredReviewersOfferState $OfferState `
            -SelectedReviewersJson $SelectedReviewersJson | ConvertFrom-Json)
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

# (5) Ja havia preferred-reviewers.json -> not_applicable e valido.
$r5 = Invoke-Closeout $true $false 'not_applicable'
Assert-True ($r5.closeoutReady -eq $true) 'Caso 5: preferencias existentes nao exigem oferta.'
Assert-True ($r5.requiresPreferredOffer -eq $false) 'Caso 5: requiresPreferredOffer deveria ser false.'

# (6) not_applicable indevido com selecao manual sem preferencias previas -> fail-closed.
$r6 = Invoke-Closeout $false $true 'not_applicable'
Assert-True ($r6.closeoutReady -eq $false) 'Caso 6: not_applicable indevido deveria bloquear.'
Assert-True (@($r6.blockingReasons) -contains 'preferred-reviewers-offer-state-invalid-for-manual-selection') 'Caso 6: razao fail-closed ausente.'

# (7) JSON invalido deve falhar de forma explicita.
$failed = $false
try {
    [void](Invoke-Closeout $false $true 'not_made' '{')
} catch {
    $failed = ($_.Exception.Message -match 'SelectedReviewersJson')
}
Assert-True $failed 'Caso 7: JSON invalido deveria falhar citando SelectedReviewersJson.'

Write-Output 'OK: Test-LlmDelegatePeerReviewCloseoutSelfTest.ps1'
