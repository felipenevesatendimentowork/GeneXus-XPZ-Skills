#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local para verificar frescor do setup da pasta paralela da KB em relacao ao repositorio de skills XPZ.

.DESCRIPTION
Delega ao motor compartilhado Test-XpzSetupFreshness.ps1 com os caminhos fixos desta pasta paralela.
Retorna GATE_ONLY quando o repositorio de skills nao foi atualizado desde o ultimo audit concluido
com sucesso; retorna AUDIT_REQUIRED com motivo nos demais casos.

Usado como primeira acao obrigatoria da PRE-CONDICAO em xpz-kb-parallel-setup ao ser invocado
pelo gatilho global (quando o usuario nao pede explicitamente setup, atualizacao ou auditoria).

.EXAMPLE
.\Test-KbSetupFreshness.ps1
#>

param(
    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills",

    [string]$PowerShellRuntimeWrapperPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$KbParallelRoot = Split-Path -Parent $PSScriptRoot
$PowerShellRuntimeWrapperPath = if ($PowerShellRuntimeWrapperPath) {
    $PowerShellRuntimeWrapperPath
} else {
    Join-Path $PSScriptRoot 'Test-KbPowerShellRuntime.ps1'
}

if (-not (Test-Path -LiteralPath $PowerShellRuntimeWrapperPath -PathType Leaf)) {
    throw "BLOCK: wrapper de runtime PowerShell ausente: $PowerShellRuntimeWrapperPath"
}

& $PowerShellRuntimeWrapperPath
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$enginePath = Join-Path $SharedSkillsRoot 'scripts\Test-XpzSetupFreshness.ps1'

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Engine script not found: $enginePath"
}

& $enginePath -KbParallelRoot $KbParallelRoot -SkillsRoot $SharedSkillsRoot
exit $LASTEXITCODE
