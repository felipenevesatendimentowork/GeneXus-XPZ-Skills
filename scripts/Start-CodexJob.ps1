#requires -Version 7.4
<#
.SYNOPSIS
    Dispara um job assincrono (nao-bloqueante) do Codex CLI e abre o watcher.
.DESCRIPTION
    Backend codex da skill xpz-llm-delegate. Cria um job identificado por GUID em <TempDir> e
    dispara `codex exec --json` desanexado, com o stream JSONL crescendo em <GUID>.stream.jsonl
    e a resposta final escrita por -o em <GUID>.lastmsg.txt. Retorna imediatamente jobId+pid
    (nao bloqueia o chamador). Por padrao abre Watch-CodexJob.ps1 numa janela visivel; use
    -NoWatcher para suprimir.

    Para perguntas curtas (resposta na hora) use Invoke-Codex.ps1. Este script e para tarefas
    longas que voce quer disparar e acompanhar sem bloquear.

    Sandbox read-only fixo. CONFIDENCIALIDADE: este script NAO decide para onde o dado pode ir;
    passe antes pelo gate Resolve-LlmDelegateAuthorization.ps1 (-Backend codex).

    Arquivos do job (todos compartilham o mesmo GUID, em <TempDir>):
        <GUID>.request.json   o que foi pedido (model, prompt)
        <GUID>.stream.jsonl   eventos do codex exec --json, cresce incrementalmente
        <GUID>.lastmsg.txt    resposta final (output-last-message do codex)
        <GUID>.stderr.txt     erros do processo
        <GUID>.stdin.txt      o prompt enviado via stdin
        <GUID>.result.json    resposta final + status (gravado pelo watcher no fim)
.PARAMETER Message
    Prompt a enviar (posicional, obrigatorio).
.PARAMETER Model
    Modelo do Codex (nu). Default gpt-5.5.
.PARAMETER Oss
    Usa provider open-source local (--oss). Implica modelo local.
.PARAMETER LocalProvider
    Provider OSS local quando -Oss: 'ollama' ou 'lmstudio'.
.PARAMETER Profile
    Profile da config do Codex (-p <id>).
.PARAMETER Cd
    Diretorio de trabalho do agente (-C <dir>).
.PARAMETER CodexExe
    Forca um caminho de codex.exe (contorna a descoberta automatica).
.PARAMETER NoWatcher
    Nao abrir a janela do watcher (apenas dispara o job).
.PARAMETER TempDir
    Pasta dos arquivos de job. Default: <temp do usuario>\codex-jobs.
.PARAMETER KeepDays
    Idade maxima (dias) dos arquivos de job antes da auto-limpeza. Default 3.
.EXAMPLE
    .\Start-CodexJob.ps1 "tarefa longa" -NoWatcher
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $Message,
    [string] $Model = 'gpt-5.5',
    [switch] $Oss,
    [ValidateSet('ollama', 'lmstudio')] [string] $LocalProvider,
    [string] $Profile,
    [string] $Cd,
    [string] $CodexExe,
    [switch] $NoWatcher,
    [string] $TempDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'codex-jobs'),
    [int]    $KeepDays = 3
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Funcoes compartilhadas de descoberta do binario do Codex (dot-source)
. (Join-Path $PSScriptRoot 'CodexCliSupport.ps1')

# 1) Resolve o binario compativel (fail-closed)
$exe = Resolve-CodexExe -Override $CodexExe

# 2) Pasta de jobs
if (-not (Test-Path -LiteralPath $TempDir -PathType Container)) {
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
}

# 2b) Auto-limpeza: remove arquivos de jobs com mais de -KeepDays dias.
try {
    $limite = (Get-Date).AddDays(-[Math]::Abs($KeepDays))
    Get-ChildItem -LiteralPath $TempDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $limite } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
} catch { }

# 3) Identidade do job (GUID sem hifens) e caminhos
$jobId      = [guid]::NewGuid().ToString('N')
$base       = Join-Path $TempDir $jobId
$reqPath    = "$base.request.json"
$streamPath = "$base.stream.jsonl"
$lastMsgPath = "$base.lastmsg.txt"
$errPath    = "$base.stderr.txt"
$stdinPath  = "$base.stdin.txt"
$resultPath = "$base.result.json"

# 4) request.json
$request = [ordered]@{
    jobId       = $jobId
    model       = $Model
    prompt      = $Message
    startedAt   = (Get-Date).ToString('o')
    streamPath  = $streamPath
    lastMsgPath = $lastMsgPath
    resultPath  = $resultPath
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reqPath -Encoding utf8

# 5) stdin = o prompt
Set-Content -LiteralPath $stdinPath -Value $Message -Encoding utf8 -NoNewline

# 6) Dispara o codex exec desanexado (janela oculta, nao espera)
$cxArgs = @(
    'exec', '--skip-git-repo-check', '-s', 'read-only', '--color', 'never',
    '-m', $Model, '--json', '-o', $lastMsgPath
)
if ($Oss) { $cxArgs += '--oss' }
if ($LocalProvider) { $cxArgs += @('--local-provider', $LocalProvider) }
if ($Profile) { $cxArgs += @('-p', $Profile) }
if ($Cd) { $cxArgs += @('-C', $Cd) }
$cxArgs += '-'

$proc = Start-Process -FilePath $exe -ArgumentList $cxArgs -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $streamPath -RedirectStandardError $errPath -RedirectStandardInput $stdinPath
$procId = $proc.Id

# 7) Abre o watcher numa janela visivel (a menos que -NoWatcher)
$watcher = Join-Path $PSScriptRoot 'Watch-CodexJob.ps1'
if (-not $NoWatcher) {
    if (Test-Path -LiteralPath $watcher -PathType Leaf) {
        Start-Process pwsh -WindowStyle Normal -ArgumentList @(
            '-NoExit', '-NoProfile', '-File', $watcher,
            '-JobId', $jobId, '-ProcessId', "$procId", '-TempDir', $TempDir
        ) | Out-Null
    } else {
        Write-Warning "Watcher nao encontrado em $watcher; job segue rodando sem janela."
    }
}

# 8) Devolve a identidade do job ao chamador (JSON compacto numa linha)
[pscustomobject]@{
    jobId   = $jobId
    pid     = $procId
    stream  = $streamPath
    lastmsg = $lastMsgPath
    result  = $resultPath
    watcher = (-not $NoWatcher)
} | ConvertTo-Json -Compress
