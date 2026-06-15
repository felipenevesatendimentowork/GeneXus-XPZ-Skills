#requires -Version 7.4
<#
.SYNOPSIS
  Self-test do CONTRATO -AsJson do motor Test-XpzKbIndexGate.ps1 (gate K9 da
  rotina pre-push de pasta paralela de KB). Sentinela:
  XPZ_KB_INDEX_GATE_CONTRACT_SELFTEST_OK.

.DESCRIPTION
  Foca o contrato consumido pelo orquestrador K9, nao o caminho verde (que exige
  SQLite real + assinatura de extrator). Sobre uma pasta sem estrutura/indice:
    A. -AsJson NUNCA lanca: bloqueio vira { status: BLOCK, reason } + exit 1
       (JSON parseavel), nao um throw.
    B. Default (texto) lanca BLOCK: exit nao-zero e sem JSON estruturado no stdout
       (caminho retrocompativel por grep GATE_OK).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'XpzKbPrePushSelfTestSupport.ps1')

$engine = Join-Path $PSScriptRoot 'Test-XpzKbIndexGate.ps1'
$roots = [System.Collections.Generic.List[string]]::new()

function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw "FALHA: $Message" }
}

try {
  # Pasta vazia (sem wrapper de estrutura, sem indice): o gate deve bloquear.
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-indexgate-{0}" -f ([guid]::NewGuid().ToString('N')))
  [void](New-Item -ItemType Directory -Path $root -Force); $roots.Add($root)

  # --- A: -AsJson nunca lanca -> { status: BLOCK, reason } + exit 1 ---
  $a = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-AsJson')
  Assert-True ($a.exit -eq 1) "A: exit 1 esperado; obtido $($a.exit)"
  Assert-True ($null -ne $a.json) "A: stdout deveria ser JSON parseavel (contrato -AsJson nunca lanca)"
  Assert-True ($a.json.status -eq 'BLOCK') "A: status BLOCK esperado; obtido $($a.json.status)"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$a.json.reason)) "A: reason deveria estar preenchido"

  # --- B: default (texto) lanca -> exit nao-zero, sem JSON estruturado ---
  $b = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root)
  Assert-True ($b.exit -ne 0) "B: exit nao-zero esperado no caminho texto (throw BLOCK); obtido $($b.exit)"
  Assert-True ($null -eq $b.json -or $null -eq $b.json.status) "B: caminho texto nao deveria emitir JSON estruturado no stdout"

  'XPZ_KB_INDEX_GATE_CONTRACT_SELFTEST_OK'
}
finally {
  foreach ($r in $roots) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
