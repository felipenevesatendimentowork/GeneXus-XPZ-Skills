#requires -Version 7.4
<#
.SYNOPSIS
    Chama o Gemini CLI (sincrono) e devolve a resposta final em texto.
.DESCRIPTION
    Backend gemini da skill xpz-llm-delegate. Usa `gemini -p` com `--approval-mode plan`
    e `--output-format json`, modo consultivo/read-only comprovado nos testes locais.

    CONFIDENCIALIDADE: este script NAO decide se o payload pode ir ao Google. Antes de
    enviar payload sensivel, passe por Resolve-LlmDelegateAuthorization.ps1 -Backend
    gemini.
.PARAMETER Message
    Prompt a enviar ao Gemini.
.PARAMETER Model
    Modelo aceito pelo Gemini CLI. Default: gemini-3-flash-preview.
.PARAMETER ApprovalMode
    Modo de aprovacao do Gemini CLI. Default: plan.
.PARAMETER Cd
    Diretorio de trabalho do processo Gemini. Default: diretorio atual do chamador.
.PARAMETER GeminiExe
    Forca caminho do comando gemini.
.PARAMETER TimeoutSec
    Tempo maximo de espera.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $Message,
    [string] $Model = 'gemini-3-flash-preview',
    [ValidateSet('default', 'auto_edit', 'yolo', 'plan')] [string] $ApprovalMode = 'plan',
    [string] $Cd,
    [string] $GeminiExe,
    [int] $TimeoutSec = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot 'GeminiCliSupport.ps1')

if ($ApprovalMode -ne 'plan') {
    throw 'BLOCK: Invoke-Gemini.ps1 permite somente ApprovalMode=plan na delegacao XPZ.'
}

$exe = Resolve-GeminiExe -Override $GeminiExe
$workDir = if ($Cd) { (Resolve-Path -LiteralPath $Cd).Path } else { (Get-Location).Path }

$out = New-TemporaryFile
$err = New-TemporaryFile
$req = New-TemporaryFile
$runner = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, '.ps1')
$request = [ordered]@{
    exe = $exe
    prompt = $Message
    model = $Model
    approvalMode = $ApprovalMode
    stdoutPath = $out.FullName
    stderrPath = $err.FullName
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $req.FullName -Encoding utf8
@'
param([Parameter(Mandatory)][string]$RequestPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$req = Get-Content -LiteralPath $RequestPath -Raw -Encoding utf8 | ConvertFrom-Json
$gmArgs = @(
    '-p', [string]$req.prompt,
    '--approval-mode', [string]$req.approvalMode,
    '--output-format', 'json',
    '--model', [string]$req.model
)
& ([string]$req.exe) @gmArgs 1> ([string]$req.stdoutPath) 2> ([string]$req.stderrPath)
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $runner -Encoding utf8

try {
    $p = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $runner, '-RequestPath', $req.FullName) `
        -WorkingDirectory $workDir -NoNewWindow -PassThru
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        throw "BLOCK: Gemini CLI excedeu ${TimeoutSec}s e foi encerrado."
    }

    $stdoutText = Get-Content -LiteralPath $out.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    $stderrText = Get-Content -LiteralPath $err.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue

    if ($p.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($stdoutText)) {
        $json = $null
        try { $json = $stdoutText | ConvertFrom-Json } catch {
            throw "BLOCK: Gemini CLI retornou JSON invalido: $($_.Exception.Message)"
        }
        if ($json.PSObject.Properties['response'] -and -not [string]::IsNullOrWhiteSpace([string]$json.response)) {
            return ([string]$json.response).TrimEnd("`r", "`n")
        }
    }

    $errMsg = Get-GeminiErrorMessage -StdoutText $stdoutText -StderrText $stderrText
    if ($errMsg) { throw "BLOCK: Gemini CLI retornou erro: $errMsg" }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: Gemini CLI saiu com codigo $($p.ExitCode) sem resposta.`nstderr:`n$stderrText"
    }
    throw 'BLOCK: Gemini CLI nao produziu response no JSON.'
}
finally {
    Remove-Item -LiteralPath $out.FullName, $err.FullName, $req.FullName, $runner -Force -ErrorAction SilentlyContinue
}
