#requires -Version 7.4
<#
.SYNOPSIS
    Classifica o destino de uma chamada ao GitHub Copilot CLI.
.DESCRIPTION
    Backend copilot da skill xpz-llm-delegate. O Copilot CLI envia o prompt ao servico
    do GitHub Copilot; portanto, a localidade e sempre external. A chave canonica usada
    pelo gate e github-copilot/<modelo>, nunca openai/<modelo>, porque o destino
    operacional e o servico Copilot, nao uma chamada direta ao provider do modelo.

    Saida: objeto JSON de maquina no stdout.
.PARAMETER Model
    Modelo solicitado ao Copilot CLI. Default: gpt-5-mini, observado como default local
    do CLI validado nesta maquina.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Model = 'gpt-5-mini'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modelParts = @($Model -split '/')
$modelId = $modelParts[$modelParts.Count - 1].Trim()
if ([string]::IsNullOrWhiteSpace($modelId)) { $modelId = 'gpt-5-mini' }

[pscustomobject]@{
    model          = $Model
    modelId        = $modelId
    provider       = 'github-copilot'
    baseUrl        = $null
    locality       = 'external'
    canonicalModel = "github-copilot/$modelId"
    reason         = 'GitHub Copilot CLI usa servico externo do GitHub Copilot; chave por destino github-copilot/<modelo>'
} | ConvertTo-Json -Compress
