#requires -Version 7.4
<#
.SYNOPSIS
    Dispara um job assincrono (nao-bloqueante) do opencode e abre o watcher.
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Cria um job identificado por GUID em
    <TempDir> e dispara `opencode run` desanexado, com o stream JSON crescendo em
    <GUID>.stream.jsonl. Retorna imediatamente jobId+pid (não bloqueia o chamador). Por
    padrão abre Watch-OpenCodeJob.ps1 numa janela visivel para acompanhar ao vivo; use
    -NoWatcher para suprimir.

    Para perguntas curtas (resposta na hora) use Invoke-OpenCode.ps1. Este script e para
    tarefas longas (ex: 3-6 min) que você quer disparar e acompanhar sem bloquear.

    CONFIDENCIALIDADE: este script NÃO decide para onde o dado pode ir. Antes de enviar
    payload sensivel (conteúdo de pasta paralela de KB) a um modelo, o chamador deve passar
    pelo gate Resolve-LlmDelegateAuthorization.ps1, conforme a skill xpz-llm-delegate.

    Arquivos do job (todos compartilham o mesmo GUID, em <TempDir>):
        <GUID>.request.json   o que foi pedido (model, prompt, agent)
        <GUID>.stream.jsonl   saida do opencode, cresce incrementalmente
        <GUID>.stderr.txt     erros do processo
        <GUID>.stdin.txt      stdin vazio (EOF imediato; destrava o run)
        <GUID>.result.json    resposta final + custo (gravado pelo watcher no fim)
.PARAMETER Message
    Prompt a enviar (posicional, obrigatório).
.PARAMETER Model
    Modelo provider/modelo. Opcional: omitido usa o default da config do opencode.
.PARAMETER Agent
    Nome do agente do opencode. Opcional.
.PARAMETER NoWatcher
    Não abrir a janela do watcher (apenas dispara o job).
.PARAMETER TempDir
    Pasta dos arquivos de job. Default: <temp do usuário>\opencode-jobs.
.PARAMETER KeepDays
    Idade máxima (dias) dos arquivos de job antes da auto-limpeza. Default 3.
.EXAMPLE
    .\Start-OpenCodeJob.ps1 "tarefa longa" -NoWatcher   # dispara sem janela
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $Message,
    [string] $Model,
    [string] $Agent,
    [switch] $NoWatcher,
    [string] $TempDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'opencode-jobs'),
    [int]    $KeepDays = 3
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# 1) Resolve o .exe real por tras do shim npm
$exe = Get-ChildItem -Path "$env:APPDATA\npm\node_modules\opencode-ai" `
    -Recurse -Filter 'opencode.exe' -ErrorAction SilentlyContinue |
    Where-Object FullName -like '*windows-x64\bin\opencode.exe' |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $exe) { throw "BLOCK: opencode.exe nao encontrado sob $env:APPDATA\npm" }

# 2) Pasta de jobs
if (-not (Test-Path -LiteralPath $TempDir -PathType Container)) {
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
}

# 2b) Auto-limpeza: remove arquivos de jobs com mais de -KeepDays dias.
#     Remove por arquivo (LiteralPath); jobs em andamento têm arquivos recentes e são preservados.
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
$errPath    = "$base.stderr.txt"
$stdinPath  = "$base.stdin.txt"
$resultPath = "$base.result.json"

# 4) request.json
$modelLabel = if ($Model) { $Model } else { '(default da config)' }
$agentLabel = if ($Agent) { $Agent } else { $null }
$request = [ordered]@{
    jobId      = $jobId
    model      = $modelLabel
    agent      = $agentLabel
    prompt     = $Message
    startedAt  = (Get-Date).ToString('o')
    streamPath = $streamPath
    resultPath = $resultPath
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reqPath -Encoding utf8

# 5) stdin vazio (EOF imediato — sem isso o run trava)
New-Item -Path $stdinPath -ItemType File -Force | Out-Null

# 6) Dispara o opencode desanexado (janela oculta, não espera)
$ocArgs = @('run', $Message, '--format', 'json')
if ($Model) { $ocArgs += @('--model', $Model) }
if ($Agent) { $ocArgs += @('--agent', $Agent) }

$proc = Start-Process -FilePath $exe -ArgumentList $ocArgs -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $streamPath -RedirectStandardError $errPath -RedirectStandardInput $stdinPath
$procId = $proc.Id

# 7) Abre o watcher numa janela visivel (a menos que -NoWatcher)
$watcher = Join-Path $PSScriptRoot 'Watch-OpenCodeJob.ps1'
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
    jobId  = $jobId
    pid    = $procId
    stream = $streamPath
    result = $resultPath
    watcher = (-not $NoWatcher)
} | ConvertTo-Json -Compress
