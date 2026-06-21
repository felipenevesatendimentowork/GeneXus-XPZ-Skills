#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test do tratamento de stdin nos adapters da skill xpz-llm-delegate.
#
# Bug coberto: um CLI agentico (opencode/gemini/copilot) chamado de uma shell
# headless sem TTY TRAVA lendo o stdin herdado (pipe aberto, sem EOF).
#
# Dois regimes de adapter, ambos dao EOF ao CLI (anti-hang):
#  - stdin-based (Invoke-Codex/Start-CodexJob, Invoke-ClaudeCode/Start-ClaudeCodeJob,
#    Invoke-OpenCode/Start-OpenCodeJob): entregam o prompt POR stdin via
#    Start-Process -RedirectStandardInput <arquivo>; o fim do arquivo da EOF. O prompt
#    fica FORA do argv (resolve o limite ~32KB de linha de comando do Windows).
#  - argument-based (Invoke-Gemini/Invoke-Copilot): passam o prompt como ARGUMENTO e
#    fecham o stdin no runner com "$null | & ([string]$req.exe)" (EOF puro, sem bytes).
#
# Camadas:
#  (A) Prova comportamental do EOF: um fake-detector le o stdin; com stdin fechado
#      ($null = EOF) ele retorna e sai 7; com stdin aberto ele bloqueia.
#  (B) Guard estatico anti-regressao: cada adapter stdin-based usa -RedirectStandardInput e
#      NAO fecha o stdin com "$null | & ..."; cada argument-based fecha com "$null | & ...".
#  (C) Prova comportamental do opencode stdin-based + limite ~32KB: chama o adapter REAL
#      (Invoke-OpenCode) com um fake-exe injetado (-OpenCodeExe) e um prompt > 32KB via
#      -MessagePath; o prompt chega pelo stdin (argv estouraria ~32KB) e o adapter devolve
#      a resposta parseada do stream. Escopo: prova o MECANISMO de entrega (stdin, fora do
#      argv); a capacidade do opencode REAL de consumir stdin foi verificada empiricamente
#      fora deste self-test.

$scriptsDir = $PSScriptRoot

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

# --- (A) Prova comportamental do mecanismo de EOF ---------------------------

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

    # argument-based: prompt no argv + stdin fechado com "$null | & ([string]$req.exe)".
    $argumentBased = @(
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

    # stdin-based: prompt via -RedirectStandardInput (arquivo); NAO fecha o stdin com "$null | & ...".
    $stdinBased = @(
        'Invoke-Codex.ps1'
        'Start-CodexJob.ps1'
        'Invoke-ClaudeCode.ps1'
        'Start-ClaudeCodeJob.ps1'
        'Invoke-OpenCode.ps1'
        'Start-OpenCodeJob.ps1'
    )
    foreach ($name in $stdinBased) {
        $path = Join-Path $scriptsDir $name
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Adapter stdin-based ausente: $name"
        $text = [System.IO.File]::ReadAllText($path)
        Assert-True ($text -match '-RedirectStandardInput') `
            "Adapter stdin-based '$name' deveria entregar o prompt via Start-Process -RedirectStandardInput."
        Assert-True (-not ($text -match '\$null\s*\|\s*&\s*\(\[string\]\$req\.exe\)')) `
            "Adapter stdin-based '$name' NAO pode fechar o stdin do CLI com '`$null | & ([string]`$req.exe)': o prompt e entregue POR stdin."
    }

    # SPEC 3: os adapters opencode NAO podem mais passar o prompt no argv (limite ~32KB).
    # O prompt sai do argv (vai por stdin) e os args ficam literais sem o prompt.
    foreach ($name in @('Invoke-OpenCode.ps1', 'Start-OpenCodeJob.ps1')) {
        $path = Join-Path $scriptsDir $name
        $text = [System.IO.File]::ReadAllText($path)
        Assert-True (-not $text.Contains('$req.prompt')) `
            "Adapter '$name' NAO pode mais referenciar `$req.prompt (resquicio do runner com prompt no argv)."
        Assert-True ($text.Contains("@('run', '--format', 'json')")) `
            "Adapter '$name' deveria montar os args do opencode sem o prompt: @('run', '--format', 'json')."
    }

    # --- (C) Prova comportamental: opencode stdin-based + prompt > 32KB -----

    # fake-exe REAL (executavel invocavel por Start-Process -FilePath): um .cmd que chama um
    # leitor pwsh. O leitor consome todo o stdin, mede o tamanho e emite o stream JSON minimo
    # do opencode (text + step_finish reason=stop) que OpenCodeStreamSupport sabe parsear.
    $fakeReader = Join-Path $tempRoot 'fake-reader.ps1'
    @'
$s = [Console]::In.ReadToEnd()
$n = $s.Length
'{"type":"text","part":{"messageID":"m1","text":"FAKELEN=' + $n + '"}}'
'{"type":"step_finish","part":{"reason":"stop"}}'
'@ | Set-Content -LiteralPath $fakeReader -Encoding utf8

    $fakeCmd = Join-Path $tempRoot 'fake-opencode.cmd'
    @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-reader.ps1"
'@ | Set-Content -LiteralPath $fakeCmd -Encoding ascii

    # Prompt > 32KB (limite de linha de comando do Windows ~32767). Por argv estouraria;
    # por stdin (o que o adapter faz) passa.
    $bigLen = 40000
    $bigPrompt = ('A' * $bigLen)
    $bigFile = Join-Path $tempRoot 'big-prompt.txt'
    Set-Content -LiteralPath $bigFile -Value $bigPrompt -Encoding utf8 -NoNewline

    $invoke = Join-Path $scriptsDir 'Invoke-OpenCode.ps1'
    $answer = & $invoke -OpenCodeExe $fakeCmd -MessagePath $bigFile -Model 'fake/model' -TimeoutSec 60
    $answer = [string]$answer

    Assert-True ($answer -match 'FAKELEN=(\d+)') `
        "O adapter opencode deveria devolver a resposta parseada do fake-exe (FAKELEN=<n>); devolveu: '$answer'."
    $seen = [int]$Matches[1]
    Assert-True ($seen -ge 32768) `
        "O prompt > 32KB deveria chegar inteiro pelo stdin; o fake-exe leu $seen chars (esperado >= 32768) — sinal de que o prompt nao passou por stdin."

    Write-Output 'OK: Test-LlmDelegateStdinHandlingSelfTest.ps1'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
