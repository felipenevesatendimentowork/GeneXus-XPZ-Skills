#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do sinal PUBLIC_TRACEABILITY_VERBOSE_LINE de Test-PrePushTraceabilityCoverage.ps1.

.DESCRIPTION
    Monta uma raiz temporaria com um 09 sintetico e invoca o gate com -ChangedFiles
    nao-vazio (pula o git diff; o sinal de verbosidade e invariante sobre o texto do 09).
    Confirma:
      - linha de script no formato verboso antigo (rotulo `Evidencia direta` colado num
        caminho `scripts/` ou `scripts-maintenance/`) -> dispara PUBLIC_TRACEABILITY_VERBOSE_LINE;
      - ponteiro enxuto (`- `scripts/X` (categoria) -- ...`, sem rotulo) -> NAO dispara;
      - bullet de governanca que cita script com texto intermediario (": o script `scripts/...`")
        -> NAO dispara;
      - 09 totalmente enxuto -> status pass, zero findings de verbosidade.
    Nao precisa de git.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-PrePushTraceabilityCoverage.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-traceability-verbose-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')
$utf8NoBom = Get-Utf8NoBomEncoding

function Write-Synthetic09 {
    param([string]$Content)
    [System.IO.File]::WriteAllText((Join-Path $tempRoot '09-inventario-e-rastreabilidade-publica.md'), $Content, $utf8NoBom)
}

function Invoke-Gate {
    $output = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -ChangedFiles '09-inventario-e-rastreabilidade-publica.md' -AsJson 2>&1
    $script:lastExit = $LASTEXITCODE
    return (($output | Out-String).Trim() | ConvertFrom-Json)
}

try {
    # Cenario 1: dois verbosos (scripts/ e scripts-maintenance/) + tres negativos.
    Write-Synthetic09 @'
# 09 sintetico

## Nota sobre o motor operacional compartilhado

- `Evidência direta`: `scripts/FooVerboso.ps1` descreve contrato com parametros, exit codes e consumidores por extenso, duplicando o dono logico.
- `scripts/BarEnxuto.ps1` (motor) — papel em uma frase. Dono: 02. Validação: nenhum.
- `Evidência direta`: o script `scripts/BazGovernanca.ps1` e parte da infraestrutura operacional desta base; nao e ponteiro de script.
- `Evidência direta`: `scripts-maintenance/CampanhaVerbosa.ps1` implementa campanha de manutencao com prosa de contrato longa.
- `scripts-maintenance/CampanhaEnxuta.ps1` (manutenção) — campanha. Dono: 10a.
'@
    $r1 = Invoke-Gate
    if ($script:lastExit -ne 0) { throw "gate deveria sair com exit 0 (consultivo); obtido $($script:lastExit)" }
    if ($r1.status -ne 'warn') { throw "cenario 1: status deveria ser 'warn'; obtido '$($r1.status)'" }
    $verbose1 = @($r1.findings | Where-Object { $_.code -eq 'PUBLIC_TRACEABILITY_VERBOSE_LINE' })
    if ($verbose1.Count -ne 2) {
        throw ("cenario 1: deveria haver 2 PUBLIC_TRACEABILITY_VERBOSE_LINE (scripts/ + scripts-maintenance/); obtido {0}. Findings: {1}" -f $verbose1.Count, (@($r1.findings | ForEach-Object { $_.code }) -join ', '))
    }

    # Cenario 2: 09 totalmente enxuto (sem formato verboso) -> pass, zero verbosidade.
    Write-Synthetic09 @'
# 09 sintetico enxuto

## Nota sobre o motor operacional compartilhado

- `scripts/BarEnxuto.ps1` (motor) — papel em uma frase. Dono: 02. Validação: nenhum.
- `Evidência direta`: o script `scripts/BazGovernanca.ps1` e parte da infraestrutura operacional; nao e ponteiro.
- `Inferência forte`: nota de raciocinio editorial, nao e ponteiro de script.
'@
    $r2 = Invoke-Gate
    if ($script:lastExit -ne 0) { throw "gate deveria sair com exit 0 (consultivo); obtido $($script:lastExit)" }
    $verbose2 = @($r2.findings | Where-Object { $_.code -eq 'PUBLIC_TRACEABILITY_VERBOSE_LINE' })
    if ($verbose2.Count -ne 0) {
        throw ("cenario 2: 09 enxuto nao deveria disparar verbosidade; obtido {0}" -f $verbose2.Count)
    }
    if ($r2.status -ne 'pass') {
        throw ("cenario 2: status deveria ser 'pass'; obtido '$($r2.status)'. Findings: {0}" -f (@($r2.findings | ForEach-Object { $_.code }) -join ', '))
    }

    Write-Output 'OK: Test-PrePushTraceabilityCoverageSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
