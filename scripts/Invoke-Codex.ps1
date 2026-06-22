#requires -Version 7.4
<#
.SYNOPSIS
    Chama o Codex CLI (codex exec, sincrono) e devolve a resposta final em texto.
.DESCRIPTION
    Backend codex da skill xpz-llm-delegate. Resolve o codex.exe compativel (app desktop,
    nao o shim npm), envia o prompt via stdin e captura a resposta final pelo arquivo de
    output-last-message (-o). Bloqueia ate a resposta (ou ate -TimeoutSec).

    Esta e a invocacao sincrona canonica. Para tarefas longas que voce quer disparar sem
    bloquear, use Start-CodexJob.ps1.

    Sandbox: read-only fixo (delegacao e leitura/segunda-opiniao, nunca escrita). O Codex
    exec e agentico e PODE ler o filesystem do workspace; isso NAO contorna o gate de
    confidencialidade.

    CONFIDENCIALIDADE: este script NAO decide para onde o dado pode ir. Antes de enviar
    payload sensivel (conteudo de pasta paralela de KB) a um modelo, o chamador deve passar
    pelo gate Resolve-LlmDelegateAuthorization.ps1 (use -Backend codex), conforme a skill.
.PARAMETER Message
    Prompt a enviar ao agente (posicional). Enviado via stdin. Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Util para
    prompts grandes e para evitar substituicao de comando ("(Get-Content ...)") na linha de
    comando do chamador (sem comando composto = sem prompt de autorizacao desnecessario no
    harness). O Codex ja entrega o prompt por stdin, entao -MessagePath nao muda o transporte;
    so muda a origem do texto.
.PARAMETER Model
    Modelo do Codex (nu). Opcional; quando omitido, o adapter nao passa -m e deixa o
    default do proprio Codex/config valer.
.PARAMETER Oss
    Usa provider open-source local (codex exec --oss). Implica modelo local.
.PARAMETER LocalProvider
    Provider OSS local quando -Oss: 'ollama' ou 'lmstudio'.
.PARAMETER Profile
    Profile da config do Codex (codex exec -p <id>).
.PARAMETER Cd
    Diretorio de trabalho do agente (codex exec -C <dir>).
.PARAMETER CodexExe
    Forca um caminho de codex.exe (contorna a descoberta automatica).
.PARAMETER TimeoutSec
    Tempo maximo de espera pela resposta (default 180s). Modelos externos podem ser lentos.
.EXAMPLE
    .\Invoke-Codex.ps1 "resuma este log"
.EXAMPLE
    .\Invoke-Codex.ps1 "oi" -Model gpt-5.5 -TimeoutSec 300
.EXAMPLE
    .\Invoke-Codex.ps1 -MessagePath .\prompt-grande.txt -Model gpt-5.5
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [string] $Model,
    [switch] $Oss,
    [ValidateSet('ollama', 'lmstudio')] [string] $LocalProvider,
    [string] $Profile,
    [string] $Cd,
    [string] $CodexExe,
    [int]    $TimeoutSec = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Garante saida UTF-8 (acentos) ao devolver o texto pelo stdout
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

# Funcoes compartilhadas de descoberta do binario do Codex (dot-source)
. (Join-Path $PSScriptRoot 'CodexCliSupport.ps1')

# Prompt: inline (-Message) ou de arquivo (-MessagePath). Le como UTF-8 antes de qualquer uso.
if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
    if (-not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }
    $Message = Get-Content -LiteralPath $MessagePath -Raw -Encoding utf8
}

# 1) Resolve o binario compativel (fail-closed)
$exe = Resolve-CodexExe -Override $CodexExe

# 2) Argumentos do `codex exec`
$outMsg = (New-TemporaryFile).FullName
$arguments = @(
    'exec', '--skip-git-repo-check', '-s', 'read-only', '--color', 'never',
    '-o', $outMsg
)
if ($Model) { $arguments += @('-m', $Model) }
if ($Oss) { $arguments += '--oss' }
if ($LocalProvider) { $arguments += @('--local-provider', $LocalProvider) }
if ($Profile) { $arguments += @('-p', $Profile) }
if ($Cd) { $arguments += @('-C', $Cd) }
$arguments += '-'   # prompt lido do stdin

# 3) stdin = o prompt
$in = (New-TemporaryFile).FullName
Set-Content -LiteralPath $in -Value $Message -Encoding utf8 -NoNewline
$out = (New-TemporaryFile).FullName
$err = (New-TemporaryFile).FullName

try {
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err -RedirectStandardInput $in
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        throw "BLOCK: codex excedeu ${TimeoutSec}s e foi encerrado."
    }

    $stdoutText = (Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue)
    $stderrText = (Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue)

    $final = ''
    if (Test-Path -LiteralPath $outMsg -PathType Leaf) {
        $final = (Get-Content -LiteralPath $outMsg -Raw -Encoding utf8 -ErrorAction SilentlyContinue)
    }

    # A resposta final (output-last-message) e a evidencia primaria de sucesso: havendo-a,
    # devolve-se direto. So sem resposta investiga-se erro — o stdout/stderr do agente pode
    # conter "ERROR: {...}" de comandos internos (grep, leitura de arquivos) sem ser erro da sessao.
    if (-not [string]::IsNullOrWhiteSpace($final)) {
        return $final.TrimEnd("`r", "`n")
    }

    $errMsg = Get-CodexExecErrorMessage -StdoutText $stdoutText -StderrText $stderrText
    if ($errMsg) { throw "BLOCK: codex retornou erro: $errMsg" }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: codex saiu com codigo $($p.ExitCode) sem resposta.`nstderr:`n$stderrText"
    }
    throw "BLOCK: codex nao produziu resposta (output-last-message vazio)."
}
finally {
    Remove-Item -LiteralPath $out, $err, $in, $outMsg -Force -ErrorAction SilentlyContinue
}
