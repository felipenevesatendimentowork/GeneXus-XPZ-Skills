#requires -Version 7.4
<#
.SYNOPSIS
    Chama o opencode (one-shot, sincrono) e devolve a resposta em texto.
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Resolve o opencode.exe real (atras do
    shim npm) e executa via runner temporario para preservar prompt multilinha como um
    unico argumento nativo. Bloqueia ate a resposta (ou ate -TimeoutSec).

    Esta e a invocacao sincrona canonica. Para tarefas longas que você quer disparar sem
    bloquear, use Start-OpenCodeJob.ps1.

    CONFIDENCIALIDADE: este script NÃO decide para onde o dado pode ir. Antes de enviar
    payload sensivel (conteúdo de pasta paralela de KB) a um modelo, o chamador deve passar
    pelo gate Resolve-LlmDelegateAuthorization.ps1, conforme a skill xpz-llm-delegate.
.PARAMETER Message
    Prompt a enviar ao agente (posicional, obrigatório).
.PARAMETER Model
    Modelo no formato provider/modelo (ex: openai/gpt-5.4). Opcional: omitido usa o default
    da config do opencode (~/.config/opencode/opencode.json).
.PARAMETER Agent
    Nome do agente do opencode a usar. Opcional.
.PARAMETER Raw
    Devolve o stream JSON cru (um evento por linha) em vez do texto final.
.PARAMETER AllText
    Devolve toda a narracao (preambulos de passo + resposta final) concatenada, em vez de só a resposta final.
.PARAMETER TimeoutSec
    Tempo máximo de espera pela resposta (default 180s).
.EXAMPLE
    .\Invoke-OpenCode.ps1 "oi"
.EXAMPLE
    .\Invoke-OpenCode.ps1 "resuma este log" -Model openai/gpt-5.4
.EXAMPLE
    .\Invoke-OpenCode.ps1 "oi" -Raw      # stream JSON cru (tool-calls, custo, tokens)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $Message,
    [string] $Model,
    [string] $Agent,
    [switch] $Raw,
    [switch] $AllText,
    [int]    $TimeoutSec = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Garante saida UTF-8 (acentos) ao devolver o texto pelo stdout
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

# Funções compartilhadas de parsing do stream do opencode (dot-source)
. (Join-Path $PSScriptRoot 'OpenCodeStreamSupport.ps1')

# 1) Resolve o .exe real por tras do shim .ps1/.cmd do npm
$exe = Get-ChildItem -Path "$env:APPDATA\npm\node_modules\opencode-ai" `
    -Recurse -Filter 'opencode.exe' -ErrorAction SilentlyContinue |
    Where-Object FullName -like '*windows-x64\bin\opencode.exe' |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $exe) { throw "BLOCK: opencode.exe nao encontrado sob $env:APPDATA\npm" }

# 2) Arquivos temporarios e runner. O prompt fica em JSON, nao na command line do runner.
$out = New-TemporaryFile
$err = New-TemporaryFile
$req = New-TemporaryFile
$runner = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, '.ps1')
$request = [ordered]@{
    exe = $exe
    prompt = $Message
    model = $Model
    agent = $Agent
    stdoutPath = $out.FullName
    stderrPath = $err.FullName
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $req.FullName -Encoding utf8
@'
param([Parameter(Mandatory)][string]$RequestPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$req = Get-Content -LiteralPath $RequestPath -Raw -Encoding utf8 | ConvertFrom-Json
$ocArgs = @('run', [string]$req.prompt, '--format', 'json')
if (-not [string]::IsNullOrWhiteSpace([string]$req.model)) { $ocArgs += @('--model', [string]$req.model) }
if (-not [string]::IsNullOrWhiteSpace([string]$req.agent)) { $ocArgs += @('--agent', [string]$req.agent) }
# stdin fechado ($null = EOF puro, sem bytes) para o opencode nao travar lendo o stdin
# herdado de uma shell headless sem TTY. Depende deste runner ser 'pwsh -File' (nao -Command).
$null | & ([string]$req.exe) @ocArgs 1> ([string]$req.stdoutPath) 2> ([string]$req.stderrPath)
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $runner -Encoding utf8

try {
    $p = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $runner, '-RequestPath', $req.FullName) -NoNewWindow -PassThru
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        $p.Kill(); throw "BLOCK: opencode excedeu ${TimeoutSec}s e foi encerrado."
    }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: opencode saiu com codigo $($p.ExitCode).`nstderr:`n$(Get-Content -LiteralPath $err.FullName -Raw -ErrorAction SilentlyContinue)"
    }

    $lines = Get-Content -LiteralPath $out.FullName -Encoding utf8
    if ($Raw) { return $lines }

    $events = ConvertFrom-OpenCodeStreamLines -Lines $lines

    # Erro explicito do agente no stream tem prioridade sobre a ausencia de texto
    $errMsg = Get-OpenCodeStreamErrorMessage -Events $events
    if ($errMsg) { throw "BLOCK: opencode retornou erro no stream: $errMsg" }

    $parts = @(Get-OpenCodeTextParts -Events $events)
    if ($parts.Count -eq 0) { throw "BLOCK: nenhum evento de texto na resposta. Use -Raw para inspecionar." }

    # -AllText: toda a narracao; default: resposta final (última mensagem concatenada)
    if ($AllText) { return (Get-OpenCodeAllText -TextParts $parts) }
    return (Get-OpenCodeFinalText -TextParts $parts)
}
finally {
    Remove-Item -LiteralPath $out.FullName, $err.FullName, $req.FullName, $runner -Force -ErrorAction SilentlyContinue
}
