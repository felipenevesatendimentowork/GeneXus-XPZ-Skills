#requires -Version 7.4
<#
.SYNOPSIS
    Chama o opencode (one-shot, sincrono) e devolve a resposta em texto.
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Resolve o opencode.exe real (atras do shim npm)
    e o executa com o prompt entregue por STDIN (arquivo), FORA do argv. Entregar o prompt por
    stdin (e nao como argumento posicional de 'run') resolve o limite ~32KB de linha de comando do
    Windows para prompts grandes e usa redirecao EXPLICITA de stdout/stderr a arquivo
    (Start-Process -RedirectStandard*), evitando o erro nao-deterministico "StandardOutputEncoding
    is only supported when standard output is redirected" do padrao antigo (& exe 1> arquivo dentro
    de um runner temporario). Bloqueia ate a resposta (ou ate -TimeoutSec).

    O opencode le o prompt do stdin quando o argumento posicional de 'run' e omitido (verificado
    empiricamente no opencode em uso nesta maquina, 2026-06). Espelha o padrao stdin-based de
    Invoke-Codex.ps1.

    Esta e a invocacao sincrona canonica. Para tarefas longas que você quer disparar sem
    bloquear, use Start-OpenCodeJob.ps1.

    CONFIDENCIALIDADE: este script NÃO decide para onde o dado pode ir. Antes de enviar
    payload sensivel (conteúdo de pasta paralela de KB) a um modelo, o chamador deve passar
    pelo gate Resolve-LlmDelegateAuthorization.ps1, conforme a skill xpz-llm-delegate.
.PARAMETER Message
    Prompt a enviar ao agente (posicional). Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Util para prompts
    grandes (acima do limite ~32KB de linha de comando) e para evitar substituicao de comando
    ("$(cat ...)") na linha de comando do chamador.
.PARAMETER Model
    Modelo no formato provider/modelo (ex: openai/gpt-5.4). Opcional: omitido usa o default
    da config do opencode (~/.config/opencode/opencode.json).
.PARAMETER Agent
    Nome do agente do opencode a usar. Opcional.
.PARAMETER OpenCodeExe
    Forca um caminho de opencode.exe (contorna a descoberta automatica). Usado tambem pelos
    self-tests para injetar um fake-exe.
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
    .\Invoke-OpenCode.ps1 -MessagePath .\prompt-grande.txt -Model ollama-cloud/deepseek-v4-pro
.EXAMPLE
    .\Invoke-OpenCode.ps1 "oi" -Raw      # stream JSON cru (tool-calls, custo, tokens)
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [string] $Model,
    [string] $Agent,
    [string] $OpenCodeExe,
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

# Prompt: inline (-Message) ou de arquivo (-MessagePath). Le como UTF-8.
if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
    if (-not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }
    $Message = Get-Content -LiteralPath $MessagePath -Raw -Encoding utf8
}

# 1) Resolve o opencode.exe: override explicito (-OpenCodeExe) ou descoberta sob %APPDATA%\npm
if ($OpenCodeExe) {
    if (-not (Test-Path -LiteralPath $OpenCodeExe -PathType Leaf)) {
        throw "BLOCK: -OpenCodeExe nao encontrado: $OpenCodeExe"
    }
    $exe = $OpenCodeExe
} else {
    $exe = Get-ChildItem -Path "$env:APPDATA\npm\node_modules\opencode-ai" `
        -Recurse -Filter 'opencode.exe' -ErrorAction SilentlyContinue |
        Where-Object FullName -like '*windows-x64\bin\opencode.exe' |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $exe) { throw "BLOCK: opencode.exe nao encontrado sob $env:APPDATA\npm" }
}

# 2) Prompt via STDIN (arquivo), fora do argv. O opencode le o stdin quando o argumento
#    posicional de 'run' e omitido; -RedirectStandardInput entrega o arquivo e da EOF ao final
#    (anti-hang headless preservado: o CLI nao fica preso lendo um stdin herdado sem fim).
$ocArgs = @('run', '--format', 'json')
if (-not [string]::IsNullOrWhiteSpace($Model)) { $ocArgs += @('--model', $Model) }
if (-not [string]::IsNullOrWhiteSpace($Agent)) { $ocArgs += @('--agent', $Agent) }

$in  = (New-TemporaryFile).FullName
Set-Content -LiteralPath $in -Value $Message -Encoding utf8 -NoNewline
$out = (New-TemporaryFile).FullName
$err = (New-TemporaryFile).FullName

try {
    $startedAt = Get-Date
    $p = Start-Process -FilePath $exe -ArgumentList $ocArgs -NoNewWindow -PassThru `
        -RedirectStandardInput $in -RedirectStandardOutput $out -RedirectStandardError $err
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill($true) } catch { }
        $usageLimit = Get-OpenCodeUsageLimitError -SinceTime $startedAt
        if ($usageLimit) {
            throw "BLOCK: opencode atingiu o limite de uso do provider (HTTP 429) e ficou retentando em silencio ate ${TimeoutSec}s: $usageLimit. NAO e timeout tecnico nem indisponibilidade do provider; aguardar o reset do ciclo de uso (ex.: ollama-cloud weekly usage limit)."
        }
        throw "BLOCK: opencode excedeu ${TimeoutSec}s e foi encerrado."
    }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: opencode saiu com codigo $($p.ExitCode).`nstderr:`n$(Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue)"
    }

    $lines = Get-Content -LiteralPath $out -Encoding utf8
    if ($Raw) { return $lines }

    $events = ConvertFrom-OpenCodeStreamLines -Lines $lines

    # Erro explicito do agente no stream tem prioridade sobre a ausencia de texto
    $errMsg = Get-OpenCodeStreamErrorMessage -Events $events
    if ($errMsg) { throw "BLOCK: opencode retornou erro no stream: $errMsg" }

    $parts = @(Get-OpenCodeTextParts -Events $events)
    $finalText = Get-OpenCodeFinalText -TextParts $parts

    # Achado D: NAO devolver preambulo como resposta. Apos o erro explicito (acima, prioritario),
    # aplicar a precedencia de conclusao SEMPRE sobre a resposta final (Get-OpenCodeFinalText),
    # nunca sobre a narracao do -AllText: reason!=stop -> truncado; step_finish/reason ausente ->
    # sem-conclusao; texto final vazio -> empty. So depois de 'ok' escolhemos o retorno.
    $signal = Get-OpenCodeCompletionSignal -Events $events
    $verdict = Get-OpenCodeCompletionVerdict -HasStepFinish $signal.hasStepFinish -Reason $signal.reason -FinalText $finalText
    if ($verdict.status -ne 'ok') { throw $verdict.message }

    # -AllText: toda a narracao; default: resposta final (última mensagem concatenada)
    if ($AllText) { return (Get-OpenCodeAllText -TextParts $parts) }
    return $finalText
}
finally {
    Remove-Item -LiteralPath $out, $err, $in -Force -ErrorAction SilentlyContinue
}
