#requires -Version 7.4
<#
.SYNOPSIS
  Self-test do orquestrador Invoke-XpzKbParallelPrePushPhase1.ps1 (Fase 1 mecanica
  da rotina pre-push de pasta paralela de KB). Sentinela:
  XPZ_KB_PREPUSH_PHASE1_SELFTEST_OK.

.DESCRIPTION
  Monta repos git de fixture com wrappers locais STUB de K8/K9 e exercita a
  consolidacao pushReadiness e os caminhos de contrato:
    1. READY        - repo limpo + stubs verdes + -SkipFetch -> ready (exit 0).
    2. K8 red       - estado bloqueante do setup-audit -> blocked.
    3. K9 block     - status BLOCK do index gate -> blocked.
    4. wrapper none - sem wrapper de setup-audit -> K8 block (resolvedBy none).
    5. ambiguous    - 2 wrappers de setup-audit sem config -> K8 block.
    6. BaseRef inv. - ref inexistente -> unknown -> blocked.
    7. commitsBehind- BaseRef a frente do HEAD -> G1 block -> blocked.
    8. fetch fail   - sem -SkipFetch e sem remote -> G0 unknown -> blocked.
    9. G5 broken    - .ps1 local com erro de parse -> G5 block -> blocked.
   10. K11 fires    - acervo com antipattern not-not no diff -> blocked.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'XpzKbPrePushSelfTestSupport.ps1')

$orch = Join-Path $PSScriptRoot 'Invoke-XpzKbParallelPrePushPhase1.ps1'
$repos = [System.Collections.Generic.List[string]]::new()

$stubGreenAudit = @'
param([switch]$AsJson)
'{"estado_operacional_sugerido":"materializado_e_indice_validado"}'
'@
$stubRedAudit = @'
param([switch]$AsJson)
'{"estado_operacional_sugerido":"auditoria_incompleta"}'
'@
$stubOkIndex = @'
param([switch]$AsJson)
'{"status":"OK"}'
'@
$stubBlockIndex = @'
param([switch]$AsJson)
'{"status":"BLOCK","reason":"fixture block"}'
'@

function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw "FALHA: $Message" }
}

function New-OrchBase {
  # Repo com stubs verdes de K8/K9 commitados; retorna { Root, Base }.
  $root = New-XpzPrePushSelfTestRepo -Slug 'orch'; $repos.Add($root)
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'scripts/Test-FixKbSetupAudit.ps1' -Content $stubGreenAudit
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'scripts/Test-FixKbIndexGate.ps1'  -Content $stubOkIndex
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'README.md' -Content "fixture`n"
  $base = New-XpzPrePushSelfTestCommit -Root $root -Message 'base + stubs verdes'
  return [pscustomobject]@{ Root = $root; Base = $base }
}

function Invoke-Orch {
  param([string]$Root, [string]$BaseRef, [switch]$NoSkipFetch)
  $a = @('-RepoRoot', $Root, '-BaseRef', $BaseRef)
  if (-not $NoSkipFetch) { $a += '-SkipFetch' }
  return Invoke-XpzSelfTestScript -ScriptPath $orch -ScriptArgs $a
}

try {
  # --- 1: READY ---
  $r1 = New-OrchBase
  Set-XpzPrePushSelfTestFile -Root $r1.Root -RelPath 'README.md' -Content "fixture v2`n"
  [void](New-XpzPrePushSelfTestCommit -Root $r1.Root -Message '1: neutro')
  $o1 = Invoke-Orch -Root $r1.Root -BaseRef $r1.Base
  Assert-True ($o1.exit -eq 0) "1: exit 0 esperado; obtido $($o1.exit). stdout=$($o1.stdout)"
  Assert-True ($o1.json.pushReadiness -eq 'ready') "1: pushReadiness ready esperado; obtido $($o1.json.pushReadiness)"

  # --- 2: K8 red -> blocked ---
  $r2 = New-OrchBase
  Set-XpzPrePushSelfTestFile -Root $r2.Root -RelPath 'scripts/Test-FixKbSetupAudit.ps1' -Content $stubRedAudit
  [void](New-XpzPrePushSelfTestCommit -Root $r2.Root -Message '2: setup-audit vermelho')
  $o2 = Invoke-Orch -Root $r2.Root -BaseRef $r2.Base
  Assert-True ($o2.json.pushReadiness -eq 'blocked') "2: blocked esperado; obtido $($o2.json.pushReadiness)"
  Assert-True ((@($o2.json.gates | Where-Object { $_.id -eq 'K8' })[0]).status -eq 'block') "2: K8 block esperado"

  # --- 3: K9 block -> blocked ---
  $r3 = New-OrchBase
  Set-XpzPrePushSelfTestFile -Root $r3.Root -RelPath 'scripts/Test-FixKbIndexGate.ps1' -Content $stubBlockIndex
  [void](New-XpzPrePushSelfTestCommit -Root $r3.Root -Message '3: index gate block')
  $o3 = Invoke-Orch -Root $r3.Root -BaseRef $r3.Base
  Assert-True ($o3.json.pushReadiness -eq 'blocked') "3: blocked esperado; obtido $($o3.json.pushReadiness)"
  Assert-True ((@($o3.json.gates | Where-Object { $_.id -eq 'K9' })[0]).status -eq 'block') "3: K9 block esperado"

  # --- 4: wrapper none -> K8 block ---
  $r4 = New-OrchBase
  Remove-XpzPrePushSelfTestPath -Root $r4.Root -RelPath 'scripts/Test-FixKbSetupAudit.ps1'
  [void](New-XpzPrePushSelfTestCommit -Root $r4.Root -Message '4: sem setup-audit')
  $o4 = Invoke-Orch -Root $r4.Root -BaseRef $r4.Base
  Assert-True ($o4.json.pushReadiness -eq 'blocked') "4: blocked esperado; obtido $($o4.json.pushReadiness)"
  Assert-True ((@($o4.json.gates | Where-Object { $_.id -eq 'K8' })[0]).status -eq 'block') "4: K8 block (none) esperado"

  # --- 5: ambiguous -> K8 block ---
  $r5 = New-OrchBase
  Set-XpzPrePushSelfTestFile -Root $r5.Root -RelPath 'scripts/Test-OutroKbSetupAudit.ps1' -Content $stubGreenAudit
  [void](New-XpzPrePushSelfTestCommit -Root $r5.Root -Message '5: dois setup-audit')
  $o5 = Invoke-Orch -Root $r5.Root -BaseRef $r5.Base
  Assert-True ($o5.json.pushReadiness -eq 'blocked') "5: blocked esperado; obtido $($o5.json.pushReadiness)"
  Assert-True ((@($o5.json.gates | Where-Object { $_.id -eq 'K8' })[0]).status -eq 'block') "5: K8 block (ambiguous) esperado"

  # --- 6: BaseRef inexistente -> blocked (unknown) ---
  $r6 = New-OrchBase
  $o6 = Invoke-Orch -Root $r6.Root -BaseRef 'ref-que-nao-existe'
  Assert-True ($o6.json.pushReadiness -eq 'blocked') "6: blocked esperado; obtido $($o6.json.pushReadiness)"
  Assert-True (@($o6.json.gates | Where-Object { $_.status -eq 'unknown' }).Count -gt 0) "6: ao menos um gate unknown esperado"

  # --- 7: commitsBehind -> G1 block ---
  $r7 = New-OrchBase
  & git -C $r7.Root checkout -q -b ahead 2>$null
  Set-XpzPrePushSelfTestFile -Root $r7.Root -RelPath 'README.md' -Content "ahead`n"
  $aheadSha = New-XpzPrePushSelfTestCommit -Root $r7.Root -Message '7: commit a frente'
  & git -C $r7.Root checkout -q main 2>$null
  $o7 = Invoke-Orch -Root $r7.Root -BaseRef $aheadSha
  Assert-True ($o7.json.pushReadiness -eq 'blocked') "7: blocked esperado; obtido $($o7.json.pushReadiness)"
  Assert-True ((@($o7.json.gates | Where-Object { $_.id -eq 'G1' })[0]).status -eq 'block') "7: G1 block (commitsBehind) esperado"

  # --- 8: fetch fail (sem -SkipFetch, sem remote) -> G0 unknown ---
  $r8 = New-OrchBase
  $o8 = Invoke-Orch -Root $r8.Root -BaseRef $r8.Base -NoSkipFetch
  Assert-True ($o8.json.pushReadiness -eq 'blocked') "8: blocked esperado; obtido $($o8.json.pushReadiness)"
  Assert-True ((@($o8.json.gates | Where-Object { $_.id -eq 'G0' })[0]).status -eq 'unknown') "8: G0 unknown (fetch fail) esperado"

  # --- 9: G5 broken -> block ---
  $r9 = New-OrchBase
  Set-XpzPrePushSelfTestFile -Root $r9.Root -RelPath 'scripts/Quebrado.ps1' -Content "function {`n"
  [void](New-XpzPrePushSelfTestCommit -Root $r9.Root -Message '9: ps1 quebrado')
  $o9 = Invoke-Orch -Root $r9.Root -BaseRef $r9.Base
  Assert-True ($o9.json.pushReadiness -eq 'blocked') "9: blocked esperado; obtido $($o9.json.pushReadiness)"
  Assert-True ((@($o9.json.gates | Where-Object { $_.id -eq 'G5' })[0]).status -eq 'block') "9: G5 block esperado"

  # --- 10: K11 fires -> blocked ---
  $r10 = New-OrchBase
  Set-XpzPrePushSelfTestFile -Root $r10.Root -RelPath 'ObjetosDaKbEmXml/Procedure/Bug.xml' -Content '<Object type="Procedure" name="Bug"><Source>if (not not Cliente.IsNull()) msg(1) endif</Source></Object>'
  [void](New-XpzPrePushSelfTestCommit -Root $r10.Root -Message '10: antipattern')
  $o10 = Invoke-Orch -Root $r10.Root -BaseRef $r10.Base
  Assert-True ($o10.json.pushReadiness -eq 'blocked') "10: blocked esperado; obtido $($o10.json.pushReadiness)"
  Assert-True ((@($o10.json.gates | Where-Object { $_.id -eq 'K11' })[0]).status -eq 'block') "10: K11 block esperado"

  'XPZ_KB_PREPUSH_PHASE1_SELFTEST_OK'
}
finally {
  foreach ($r in $repos) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
