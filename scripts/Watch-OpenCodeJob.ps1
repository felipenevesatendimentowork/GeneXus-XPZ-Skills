#requires -Version 7.4
<#
.SYNOPSIS
    Monitor incremental de um job assincrono do opencode (disparado por Start-OpenCodeJob.ps1).
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Segue o processo informado (-ProcessId) e le
    o <GUID>.stream.jsonl incrementalmente, traduzindo os eventos JSON do opencode em linhas
    legiveis: chamadas de ferramenta, custo/tokens parciais e texto recebido. Detecta silencio
    prolongado e encerra quando o processo termina, gravando <GUID>.result.json com a resposta
    final e o custo total.

    Espelha o padrao de Watch-GeneXusMsBuildLog.ps1 do repo GeneXus-XPZ-Skills.
.PARAMETER JobId
    GUID do job (nome-base dos arquivos em -TempDir).
.PARAMETER ProcessId
    PID do processo opencode cuja vida delimita o monitoramento.
.PARAMETER TempDir
    Pasta dos arquivos de job. Default: <temp do usuario>\opencode-jobs.
.PARAMETER IntervalSeconds
    Intervalo de polling. Default 2. Faixa 1-30.
.PARAMETER SilenceThresholdSeconds
    Segundos sem nova linha antes de alertar. Default 120. Faixa 30-3600.
.EXAMPLE
    .\Watch-OpenCodeJob.ps1 -JobId a1b2c3 -ProcessId 12345
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $JobId,
    [Parameter(Mandatory = $true)] [int]    $ProcessId,
    [string] $TempDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'opencode-jobs'),
    [ValidateRange(1, 30)]   [int] $IntervalSeconds = 2,
    [ValidateRange(30, 3600)][int] $SilenceThresholdSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$base       = Join-Path $TempDir $JobId
$streamPath = "$base.stream.jsonl"
$reqPath    = "$base.request.json"
$errPath    = "$base.stderr.txt"
$resultPath = "$base.result.json"

# Acumuladores de resultado
$script:texts      = [System.Collections.Generic.List[string]]::new()
$script:totalCost  = [double]0
$script:lastTokens = 0

# ── Helpers ───────────────────────────────────────────────────────────────────

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Write-Line {
    param([string]$Message, [string]$Color = 'Gray')
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor $Color
}

function Read-NewLines {
    param([ref]$Offset)
    $lines = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $streamPath -PathType Leaf)) { return $lines }
    try {
        $fs = [System.IO.FileStream]::new(
            $streamPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        [void]$fs.Seek($Offset.Value, [System.IO.SeekOrigin]::Begin)
        $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
        $l = $reader.ReadLine()
        while ($null -ne $l) { $lines.Add($l); $l = $reader.ReadLine() }
        $Offset.Value = $fs.Position
        $reader.Dispose(); $fs.Dispose()
    } catch {
        Write-Line "AVISO: falha ao ler stream: $($_.Exception.Message)" 'DarkYellow'
    }
    return $lines
}

function Show-Event {
    param($Json)
    $type = Get-Prop $Json 'type'
    $part = Get-Prop $Json 'part'
    switch ($type) {
        'tool_use' {
            $tool  = Get-Prop $part 'tool'
            $state = Get-Prop $part 'state'
            $inp   = Get-Prop $state 'input'
            $cmd   = Get-Prop $inp 'command'
            if (-not $cmd) { $cmd = Get-Prop $inp 'description' }
            $c = [string]$cmd
            if ($c.Length -gt 70) { $c = $c.Substring(0, 70) + '...' }
            Write-Line ("TOOL  {0}: {1}" -f $tool, $c) 'Yellow'
        }
        'text' {
            $t = Get-Prop $part 'text'
            if ($t) {
                $script:texts.Add([string]$t)
                $preview = [string]$t
                if ($preview.Length -gt 100) { $preview = $preview.Substring(0, 100) + '...' }
                Write-Line ("TEXTO: {0}" -f $preview) 'Green'
            }
        }
        'step_finish' {
            $cost = Get-Prop $part 'cost'
            if ($null -ne $cost) { $script:totalCost += [double]$cost }
            $tok = Get-Prop $part 'tokens'
            $tot = Get-Prop $tok 'total'
            if ($null -ne $tot) { $script:lastTokens = [int]$tot }
            Write-Line ("passo concluido | custo parcial USD {0:N5} | tokens {1}" -f $script:totalCost, $script:lastTokens) 'DarkCyan'
        }
        'error' {
            Write-Line ("ERRO no agente: {0}" -f ($Json | ConvertTo-Json -Compress)) 'Red'
        }
        default { }
    }
}

# ── Header ────────────────────────────────────────────────────────────────────

Write-Host "=== Watch-OpenCodeJob =======================================" -ForegroundColor White
if (Test-Path -LiteralPath $reqPath -PathType Leaf) {
    try {
        $req = Get-Content -LiteralPath $reqPath -Raw | ConvertFrom-Json
        Write-Line ("Job   : {0}" -f (Get-Prop $req 'jobId'))  'White'
        Write-Line ("Modelo: {0}" -f (Get-Prop $req 'model'))  'White'
        $pr = [string](Get-Prop $req 'prompt')
        if ($pr.Length -gt 80) { $pr = $pr.Substring(0, 80) + '...' }
        Write-Line ("Prompt: {0}" -f $pr) 'White'
    } catch { }
}
Write-Line ("PID   : {0}" -f $ProcessId) 'White'
Write-Host "-------------------------------------------------------------" -ForegroundColor White

# ── Aguardar stream aparecer (ate 30s) ────────────────────────────────────────

$waited = 0
while (-not (Test-Path -LiteralPath $streamPath -PathType Leaf) -and $waited -lt 30) {
    Write-Line "Aguardando stream do opencode..." 'DarkGray'
    Start-Sleep -Seconds 2; $waited += 2
}

# ── Loop principal ────────────────────────────────────────────────────────────

$offset         = [long]0
$lastActivity   = [DateTime]::Now
$silenceAlerted = $false

try {
    :loop while ($true) {
        $alive = $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
        $new   = @(Read-NewLines ([ref]$offset))

        if ($new.Count -gt 0) {
            $lastActivity   = [DateTime]::Now
            $silenceAlerted = $false
            foreach ($line in $new) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try { $j = $line | ConvertFrom-Json } catch { continue }
                Show-Event $j
            }
        } else {
            $silenceSec = [int]([DateTime]::Now - $lastActivity).TotalSeconds
            if ($silenceSec -ge $SilenceThresholdSeconds -and -not $silenceAlerted) {
                $silenceAlerted = $true
                $procLabel = if ($alive) { "PID $ProcessId ativo" } else { "PID $ProcessId encerrado" }
                Write-Line ("SILENCIO ha ${SilenceThresholdSeconds}s - $procLabel") 'DarkYellow'
            }
        }

        if (-not $alive) {
            Start-Sleep -Seconds 2
            $tail = @(Read-NewLines ([ref]$offset))
            foreach ($line in $tail) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try { $j = $line | ConvertFrom-Json } catch { continue }
                Show-Event $j
            }
            break loop
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
} finally {
    # Resposta final = ultimo evento de texto
    $final = if ($script:texts.Count -gt 0) { $script:texts[$script:texts.Count - 1] } else { '' }

    $errText = ''
    if (Test-Path -LiteralPath $errPath -PathType Leaf) {
        $errText = (Get-Content -LiteralPath $errPath -Raw -ErrorAction SilentlyContinue)
    }
    $status = if ([string]::IsNullOrWhiteSpace($final)) { 'sem-texto' } else { 'completed' }

    $result = [ordered]@{
        jobId      = $JobId
        status     = $status
        finalText  = $final
        totalCost  = $script:totalCost
        tokens     = $script:lastTokens
        stderr     = $errText
        finishedAt = (Get-Date).ToString('o')
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding utf8

    Write-Host "-------------------------------------------------------------" -ForegroundColor White
    Write-Host "RESPOSTA FINAL:" -ForegroundColor Green
    Write-Host $final
    Write-Host ("Custo total USD {0:N5} | tokens {1}" -f $script:totalCost, $script:lastTokens) -ForegroundColor DarkCyan
    Write-Host ("result.json: {0}" -f $resultPath) -ForegroundColor DarkGray
}
