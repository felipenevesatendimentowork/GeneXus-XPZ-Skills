#requires -Version 7.4
<#
.SYNOPSIS
    Regressao da deteccao de limite de uso (HTTP 429) do provider no log do opencode.

.DESCRIPTION
    Cobre Get-OpenCodeUsageLimitError (OpenCodeStreamSupport.ps1): o opencode retenta o 429 em
    silencio (stdout/stderr vazios) e so grava o 429 no proprio log; o helper le o log da janela
    do processo e devolve a mensagem do limite. Testado por fixture (sem depender de 429 ao vivo).

    Casos:
      (a) log com "statusCode":429 + "reached your ... usage limit" dentro da janela -> mensagem;
      (b) log sem 429 -> $null;
      (c) log com 429 mas anterior a janela (mtime < SinceTime - slack) -> $null (janela respeitada).
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'OpenCodeStreamSupport.ps1')

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("opencode-usagelimit-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $logDir = Join-Path $tempRoot 'log'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null

    $line429 = '{"level":"ERROR","service":"provider","statusCode":429,"responseBody":"{\"error\":\"you (AntonioJose_Dev) have reached your weekly usage limit, upgrade for higher limits: https://ollama.com/upgrade\"}"}'
    $lineOk  = '{"level":"INFO","service":"session","message":"step_finish reason=stop"}'

    # (a) Positivo: log com 429 escrito agora.
    $log429 = Join-Path $logDir '2026-06-21T000001.log'
    [System.IO.File]::WriteAllText($log429, $line429 + "`n", (Get-Utf8NoBomEncoding))

    $sinceTime = [DateTime]::Now.AddSeconds(-10)
    $hit = Get-OpenCodeUsageLimitError -SinceTime $sinceTime -LogDir $logDir
    if ([string]::IsNullOrWhiteSpace($hit)) {
        throw "ASSERT_FAILED: (a) 429 no log deveria ser detectado, retornou vazio"
    }
    if ($hit -notmatch 'weekly usage limit') {
        throw "ASSERT_FAILED: (a) mensagem detectada nao contem 'weekly usage limit': $hit"
    }

    # (b) Negativo: log sem 429 -> $null.
    $logDirOk = Join-Path $tempRoot 'log-ok'
    New-Item -ItemType Directory -Path $logDirOk -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $logDirOk '2026-06-21T000002.log'), $lineOk + "`n", (Get-Utf8NoBomEncoding))
    $miss = Get-OpenCodeUsageLimitError -SinceTime $sinceTime -LogDir $logDirOk
    if ($null -ne $miss) {
        throw "ASSERT_FAILED: (b) log sem 429 deveria retornar `$null, retornou: $miss"
    }

    # (c) Janela: 429 anterior a janela (mtime antigo) -> $null.
    $logDirOld = Join-Path $tempRoot 'log-old'
    New-Item -ItemType Directory -Path $logDirOld -Force | Out-Null
    $oldLog = Join-Path $logDirOld '2026-06-20T000001.log'
    [System.IO.File]::WriteAllText($oldLog, $line429 + "`n", (Get-Utf8NoBomEncoding))
    (Get-Item -LiteralPath $oldLog).LastWriteTime = [DateTime]::Now.AddHours(-1)
    $outOfWindow = Get-OpenCodeUsageLimitError -SinceTime ([DateTime]::Now.AddSeconds(-10)) -LogDir $logDirOld
    if ($null -ne $outOfWindow) {
        throw "ASSERT_FAILED: (c) 429 fora da janela deveria retornar `$null, retornou: $outOfWindow"
    }

    'OPENCODE_USAGE_LIMIT_DETECTION_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
