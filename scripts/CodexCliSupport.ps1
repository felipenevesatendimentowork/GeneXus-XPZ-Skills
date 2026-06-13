#requires -Version 7.4
<#
.SYNOPSIS
    Funcoes compartilhadas do backend codex da skill xpz-llm-delegate: descoberta do
    binario do Codex CLI compativel.
.DESCRIPTION
    Modulo dot-source consumido por Invoke-Codex.ps1 e Start-CodexJob.ps1. Sem efeitos
    colaterais alem de invocar `codex --version` nos candidatos para escolher a maior versao.

    DESCOBERTA (fail-closed): o shim npm no PATH (Roaming\npm) costuma ser antigo e e
    REJEITADO pelo servidor para modelos novos (ex: gpt-5.5 -> 'requires a newer version of
    Codex'). Por isso a descoberta ignora o PATH e usa os binarios da app desktop OpenAI
    Codex sob %LOCALAPPDATA%\OpenAI\Codex\bin, escolhendo a maior versao (a app mantem o
    binario ativo mais novo ali). Sem candidato -> BLOCK com instrucao.

    Contrato validado por Test-CodexCliSupportSelfTest.ps1.
#>

Set-StrictMode -Version Latest

function Get-CodexExeVersion {
    # Le 'codex-cli X.Y.Z[-alpha.N]' e devolve [version] X.Y.Z (ignora sufixo pre-release).
    param([string]$ExePath)
    try {
        $raw = & $ExePath --version 2>$null
        $line = @($raw)[0]
        $m = [regex]::Match([string]$line, '(\d+)\.(\d+)\.(\d+)')
        if ($m.Success) {
            return [version]("{0}.{1}.{2}" -f $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value)
        }
    } catch { }
    return $null
}

function Resolve-CodexExe {
    # Devolve o caminho do codex.exe a usar. -Override forca um caminho explicito.
    param([string]$Override)

    if ($Override) {
        if (Test-Path -LiteralPath $Override -PathType Leaf) { return $Override }
        throw "BLOCK: -CodexExe informado nao existe: $Override"
    }

    $base = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (-not (Test-Path -LiteralPath $base -PathType Container)) {
        throw "BLOCK: pasta de binarios da app OpenAI Codex nao encontrada: $base. Instale/atualize a app ou o CLI do Codex (o shim npm e rejeitado para gpt-5.5)."
    }

    $candidates = @(Get-ChildItem -LiteralPath $base -Recurse -Filter 'codex.exe' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName)
    if ($candidates.Count -eq 0) {
        throw "BLOCK: nenhum codex.exe encontrado sob $base. Atualize a app/CLI do Codex."
    }

    $best = $null; $bestVer = $null
    foreach ($c in $candidates) {
        $v = Get-CodexExeVersion $c
        if ($null -eq $v) { continue }
        if ($null -eq $bestVer -or $v -gt $bestVer) { $bestVer = $v; $best = $c }
    }
    # Nenhum respondeu --version: ultimo recurso, o primeiro candidato.
    if (-not $best) { $best = $candidates[0] }
    return $best
}

function Get-CodexExecErrorMessage {
    # Extrai mensagem de erro do stdout/stderr do `codex exec` quando o servidor rejeita o
    # pedido (ex: modelo nao suportado). Procura linhas 'ERROR: {json}' e devolve a 'message'.
    param([string]$StdoutText, [string]$StderrText)
    $combined = @($StdoutText, $StderrText) -join "`n"
    $jsonMatches = [regex]::Matches($combined, 'ERROR:\s*(\{.*\})')
    if ($jsonMatches.Count -gt 0) {
        $jsonText = $jsonMatches[$jsonMatches.Count - 1].Groups[1].Value
        try {
            $obj = $jsonText | ConvertFrom-Json
            $msg = $null
            if ($obj.PSObject.Properties['error'] -and $obj.error.PSObject.Properties['message']) {
                $msg = [string]$obj.error.message
            }
            if (-not [string]::IsNullOrWhiteSpace($msg)) { return $msg }
        } catch { }
        return $jsonText
    }
    # Fallback: linha 'ERROR: <texto>' sem JSON balanceado
    $lineMatch = [regex]::Match($combined, 'ERROR:\s*(\S.*)')
    if ($lineMatch.Success) { return $lineMatch.Groups[1].Value.Trim() }
    return $null
}
