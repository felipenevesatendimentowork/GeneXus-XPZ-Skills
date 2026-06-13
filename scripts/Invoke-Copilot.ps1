#requires -Version 7.4
<#
.SYNOPSIS
    Chama o GitHub Copilot CLI (sincrono) e devolve a resposta final em texto.
.DESCRIPTION
    Backend copilot da skill xpz-llm-delegate. Usa `copilot -p` em modo JSONL, com
    instrucoes customizadas desabilitadas, MCP embutido desabilitado e conjunto de
    ferramentas vazio. `--allow-all-tools` permanece porque o Copilot CLI exige permissao
    automatica em modo nao interativo, mas sem ferramentas disponiveis nao ha o que aprovar.

    CONFIDENCIALIDADE: este script NAO decide se o payload pode ir ao GitHub Copilot.
    Antes de enviar payload sensivel, passe por Resolve-LlmDelegateAuthorization.ps1
    -Backend copilot.
.PARAMETER Message
    Prompt a enviar ao Copilot.
.PARAMETER Model
    Modelo aceito pelo Copilot CLI. Default: gpt-5-mini.
.PARAMETER Cd
    Diretorio de trabalho do processo Copilot. Default: diretorio atual do chamador.
.PARAMETER CopilotExe
    Forca caminho do comando copilot.
.PARAMETER TimeoutSec
    Tempo maximo de espera.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $Message,
    [string] $Model = 'gpt-5-mini',
    [string] $Cd,
    [string] $CopilotExe,
    [int] $TimeoutSec = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot 'CopilotCliSupport.ps1')

$exe = Resolve-CopilotExe -Override $CopilotExe
$workDir = if ($Cd) { (Resolve-Path -LiteralPath $Cd).Path } else { (Get-Location).Path }

$out = New-TemporaryFile
$err = New-TemporaryFile
$req = New-TemporaryFile
$runner = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, '.ps1')
$request = [ordered]@{
    exe = $exe
    prompt = $Message
    model = $Model
    stdoutPath = $out.FullName
    stderrPath = $err.FullName
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $req.FullName -Encoding utf8
@'
param([Parameter(Mandatory)][string]$RequestPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$req = Get-Content -LiteralPath $RequestPath -Raw -Encoding utf8 | ConvertFrom-Json
$cpArgs = @(
    '-p', [string]$req.prompt,
    '--model', [string]$req.model,
    '--no-custom-instructions',
    '--disable-builtin-mcps',
    '--stream', 'off',
    '--output-format', 'json',
    '--available-tools=',
    '--allow-all-tools'
)
& ([string]$req.exe) @cpArgs 1> ([string]$req.stdoutPath) 2> ([string]$req.stderrPath)
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $runner -Encoding utf8

try {
    $p = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $runner, '-RequestPath', $req.FullName) `
        -WorkingDirectory $workDir -NoNewWindow -PassThru
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        throw "BLOCK: Copilot CLI excedeu ${TimeoutSec}s e foi encerrado."
    }

    $stdoutText = Get-Content -LiteralPath $out.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    $stderrText = Get-Content -LiteralPath $err.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    $lines = @()
    if (-not [string]::IsNullOrWhiteSpace($stdoutText)) { $lines = @($stdoutText -split "`r?`n") }
    $final = Get-CopilotJsonlFinalText -Lines $lines
    $reportedExitCode = Get-CopilotJsonlExitCode -Lines $lines

    if ($p.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($final)) {
        return $final.TrimEnd("`r", "`n")
    }

    $errMsg = Get-CopilotErrorMessage -StdoutText $stdoutText -StderrText $stderrText
    if ($errMsg) { throw "BLOCK: Copilot CLI retornou erro: $errMsg" }
    if ($null -ne $reportedExitCode -and $reportedExitCode -ne 0) {
        throw "BLOCK: Copilot CLI reportou exitCode $reportedExitCode sem resposta final."
    }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: Copilot CLI saiu com codigo $($p.ExitCode) sem resposta.`nstderr:`n$stderrText"
    }
    throw 'BLOCK: Copilot CLI nao produziu resposta final.'
}
finally {
    Remove-Item -LiteralPath $out.FullName, $err.FullName, $req.FullName, $runner -Force -ErrorAction SilentlyContinue
}
