#requires -Version 7.4
<#
.SYNOPSIS
    Chama o Claude Code CLI (sincrono) e devolve a resposta final em texto.
.DESCRIPTION
    Backend claude-code da skill xpz-llm-delegate. Envia o prompt por stdin para evitar
    payload em argumento de processo, usa `claude -p` e captura stdout. Por padrao roda em
    modo de consulta curta restrita: sem persistencia de sessao, max-turns baixo,
    permission-mode plan e ferramentas somente leitura.

    CONFIDENCIALIDADE: este script NAO decide se o payload pode ir para Anthropic. Antes de
    enviar payload sensivel, passe por Resolve-LlmDelegateAuthorization.ps1 -Backend
    claude-code.
.PARAMETER Message
    Prompt a enviar ao Claude Code. Enviado por stdin.
.PARAMETER Model
    Modelo aceito pelo Claude Code. Default: claude-opus-4-8.
.PARAMETER PermissionMode
    Modo de permissao do Claude Code. Default: plan.
.PARAMETER Tools
    Lista de ferramentas disponiveis. Default: Read,Glob,Grep. Use "" para desabilitar.
.PARAMETER MaxTurns
    Limite de turnos agenticos em modo print. Default: 1.
.PARAMETER Cd
    Diretorio de trabalho do processo Claude Code. Default: diretorio atual do chamador.
.PARAMETER ClaudeExe
    Forca caminho de claude.exe.
.PARAMETER TimeoutSec
    Tempo maximo de espera. Modelos externos podem ser lentos.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $Message,
    [string] $Model = 'claude-opus-4-8',
    [ValidateSet('default', 'acceptEdits', 'plan', 'auto', 'dontAsk', 'bypassPermissions')] [string] $PermissionMode = 'plan',
    [string] $Tools = 'Read,Glob,Grep',
    [ValidateRange(1, 100)] [int] $MaxTurns = 1,
    [string] $Cd,
    [string] $ClaudeExe,
    [int] $TimeoutSec = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot 'ClaudeCodeCliSupport.ps1')

if ($PSBoundParameters.ContainsKey('PermissionMode') -and $PermissionMode -eq 'bypassPermissions') {
    throw 'BLOCK: Invoke-ClaudeCode.ps1 nao permite PermissionMode=bypassPermissions.'
}

$exe = Resolve-ClaudeCodeExe -Override $ClaudeExe
$workDir = if ($Cd) { (Resolve-Path -LiteralPath $Cd).Path } else { (Get-Location).Path }

$arguments = @(
    '-p',
    '--model', $Model,
    '--output-format', 'text',
    '--no-session-persistence',
    '--permission-mode', $PermissionMode
)
try {
    $helpText = (& $exe --help 2>&1 | Out-String)
    if ($helpText -match [regex]::Escape('--max-turns')) {
        $arguments += @('--max-turns', "$MaxTurns")
    }
} catch { }
if (-not [string]::IsNullOrWhiteSpace($Tools)) {
    $arguments += @('--tools', $Tools)
}

$in = (New-TemporaryFile).FullName
$out = (New-TemporaryFile).FullName
$err = (New-TemporaryFile).FullName
Set-Content -LiteralPath $in -Value $Message -Encoding utf8 -NoNewline

try {
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $workDir `
        -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err `
        -RedirectStandardInput $in
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        throw "BLOCK: Claude Code excedeu ${TimeoutSec}s e foi encerrado."
    }

    $stdoutText = Get-Content -LiteralPath $out -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    $stderrText = Get-Content -LiteralPath $err -Raw -Encoding utf8 -ErrorAction SilentlyContinue

    if ($p.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($stdoutText)) {
        return $stdoutText.TrimEnd("`r", "`n")
    }

    $errMsg = Get-ClaudeCodeErrorMessage -StdoutText $stdoutText -StderrText $stderrText
    if ($errMsg) { throw "BLOCK: Claude Code retornou erro: $errMsg" }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: Claude Code saiu com codigo $($p.ExitCode) sem resposta.`nstderr:`n$stderrText"
    }
    throw 'BLOCK: Claude Code nao produziu resposta.'
}
finally {
    Remove-Item -LiteralPath $in, $out, $err -Force -ErrorAction SilentlyContinue
}
