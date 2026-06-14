#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test do tratamento de stdin nos adapters da skill xpz-llm-delegate.
#
# Bug coberto: um CLI agentico (opencode/gemini/copilot) chamado de uma shell
# headless sem TTY TRAVA lendo o stdin herdado (pipe aberto, sem EOF). O runner
# dos adapters argument-based fecha o stdin via "$null |" (EOF puro). Os adapters
# stdin-based (codex/claude-code) entregam o prompt POR stdin e NAO podem fecha-lo.
#
# Duas camadas:
#  (A) Prova comportamental do mecanismo: um fake-detector le o stdin; com stdin
#      fechado ($null = EOF) ele retorna e sai 7; com stdin aberto ele bloqueia.
#  (B) Guard estatico anti-regressao: cada adapter argument-based contem o
#      fechamento "$null | & ([string]$req.exe)"; cada stdin-based usa
#      -RedirectStandardInput e NAO fecha o stdin do CLI.

$scriptsDir = $PSScriptRoot

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

# --- (A) Prova comportamental do mecanismo ---------------------------------

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-llm-stdin-selftest-' + [System.Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

try {
    # fake-detector: na sonda --version/--help imprime e sai 0; senao le o stdin
    # ate o EOF (retorna na hora se fechado; bloqueia se aberto) e sai 7.
    $detector = Join-Path $tempRoot 'fake-detector.ps1'
    @'
param()
if ($args -contains '--version' -or $args -contains '--help') { 'fake 1.0'; exit 0 }
[void][Console]::In.ReadToEnd()
exit 7
'@ | Set-Content -LiteralPath $detector -Encoding utf8

    # Positivo: "$null |" entrega EOF puro -> o detector retorna e sai 7, rapido.
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $null | & pwsh -NoProfile -File $detector 1> $null 2> $null
    $closedCode = $LASTEXITCODE
    $closedSecs = $sw.Elapsed.TotalSeconds
    Assert-True ($closedCode -eq 7) "Com stdin fechado (`$null |), o detector deveria sair 7; saiu $closedCode."
    Assert-True ($closedSecs -lt 20) "Com stdin fechado, o detector deveria retornar rapido; levou $([math]::Round($closedSecs,1))s."

    # Negativo (controle): com stdin ABERTO (RedirectStandardInput nao fechado), o
    # detector bloqueia em ReadToEnd -> prova que o teste positivo nao e vacuo.
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'pwsh'
    $psi.Arguments = "-NoProfile -File `"$detector`""
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        # stdin aberto e sem dados: o detector deve continuar bloqueado.
        $exitedBlocked = $proc.WaitForExit(4000)
        Assert-True (-not $exitedBlocked) 'Com stdin ABERTO, o detector deveria bloquear lendo stdin (prova que o fix nao e vacuo).'
    }
    finally {
        # Limpeza da arvore de processo (o filho nativo nao morre matando so o pai).
        try { $proc.Kill($true) } catch { }
        try { $proc.Dispose() } catch { }
    }

    # --- (B) Guard estatico anti-regressao nos adapters reais --------------

    $argumentBased = @(
        'Invoke-OpenCode.ps1'
        'Start-OpenCodeJob.ps1'
        'Invoke-Gemini.ps1'
        'Invoke-Copilot.ps1'
    )
    foreach ($name in $argumentBased) {
        $path = Join-Path $scriptsDir $name
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Adapter argument-based ausente: $name"
        $text = [System.IO.File]::ReadAllText($path)
        Assert-True ($text -match '\$null\s*\|\s*&\s*\(\[string\]\$req\.exe\)') `
            "Adapter argument-based '$name' deveria fechar o stdin do CLI no runner com '`$null | & ([string]`$req.exe)' (regressao do fix de stdin headless)."
    }

    $stdinBased = @(
        'Invoke-Codex.ps1'
        'Start-CodexJob.ps1'
        'Invoke-ClaudeCode.ps1'
        'Start-ClaudeCodeJob.ps1'
    )
    foreach ($name in $stdinBased) {
        $path = Join-Path $scriptsDir $name
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Adapter stdin-based ausente: $name"
        $text = [System.IO.File]::ReadAllText($path)
        Assert-True ($text -match '-RedirectStandardInput') `
            "Adapter stdin-based '$name' deveria entregar o prompt via Start-Process -RedirectStandardInput."
        Assert-True (-not ($text -match '\$null\s*\|\s*&\s*\(\[string\]\$req\.exe\)')) `
            "Adapter stdin-based '$name' NAO pode fechar o stdin do CLI: o prompt e entregue POR stdin."
    }

    Write-Output 'OK: Test-LlmDelegateStdinHandlingSelfTest.ps1'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
