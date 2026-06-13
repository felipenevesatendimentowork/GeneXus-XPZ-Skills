#requires -Version 7.4
<#
.SYNOPSIS
    Dispara um job assincrono (nao-bloqueante) do opencode e abre o watcher.
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Cria um job identificado por GUID em
    <TempDir> e dispara um runner PowerShell desanexado que chama `opencode run`, com o
    stream JSON crescendo em <GUID>.stream.jsonl. O runner preserva prompt multilinha
    como argumento nativo unico. Retorna imediatamente jobId+pid (não bloqueia o chamador).
    Por padrão abre Watch-OpenCodeJob.ps1 numa janela visivel para acompanhar ao vivo; use
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
        <GUID>.runner.ps1     runner temporario do job
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
$runnerPath = "$base.runner.ps1"
$resultPath = "$base.result.json"

# 4) request.json
$agentLabel = if ($Agent) { $Agent } else { $null }
$request = [ordered]@{
    jobId      = $jobId
    model      = if ($Model) { $Model } else { $null }
    modelLabel = if ($Model) { $Model } else { '(default da config)' }
    agent      = $agentLabel
    prompt     = $Message
    startedAt  = (Get-Date).ToString('o')
    streamPath = $streamPath
    stderrPath = $errPath
    runnerPath = $runnerPath
    resultPath = $resultPath
    exe        = $exe
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reqPath -Encoding utf8

# 5) Runner: le request.json e chama opencode com array nativo de argumentos. Evita que
#    Start-Process fragmente prompt multilinha em muitos argumentos.
@'
param([Parameter(Mandatory)][string]$RequestPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$req = Get-Content -LiteralPath $RequestPath -Raw -Encoding utf8 | ConvertFrom-Json
$ocArgs = @('run', [string]$req.prompt, '--format', 'json')
if (-not [string]::IsNullOrWhiteSpace([string]$req.model)) { $ocArgs += @('--model', [string]$req.model) }
if (-not [string]::IsNullOrWhiteSpace([string]$req.agent)) { $ocArgs += @('--agent', [string]$req.agent) }
& ([string]$req.exe) @ocArgs 1> ([string]$req.streamPath) 2> ([string]$req.stderrPath)
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $runnerPath -Encoding utf8

# 6) Dispara o runner desanexado (janela oculta, não espera)
$proc = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $runnerPath, '-RequestPath', $reqPath) -WindowStyle Hidden -PassThru
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
