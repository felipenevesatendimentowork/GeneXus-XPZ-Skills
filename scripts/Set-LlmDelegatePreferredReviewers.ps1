#requires -Version 7.4
<#
.SYNOPSIS
    Grava a lista CURADA de revisores preferidos do usuario para a oferta de revisao por
    pares (machine-level), a partir de uma selecao ja feita pelo usuario.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.
    Esta lista e PREFERENCIA do usuario (fato da MAQUINA), distinta de:
      - capabilities.json  (probe do que esta instalado; mesmo dir, regenerado)
      - llm-delegation-policy.json (autorizacao por-KB; raiz da pasta paralela)

    NAO e verdade do gate: o Resolve-LlmDelegateAuthorization.ps1 continua soberano por
    destino+sensibilidade. Preferencia != autorizacao.

    SCHEMA DE 2 EIXOS (ver `## ANATOMIA` do SKILL): cada revisor guarda
      - targetModelKey : chave de DESTINO canonica (ex.: openai/gpt-5.5) -> politica/autorizacao
      - invokeArgs     : argumentos sanitizados do adapter (model, e quando aplicavel
                         profile/oss/localProvider) -> mecanica da chamada
    canonicalModel sozinho nao reproduz a chamada do Codex (que usa -Model nu + profile/oss).

    SANITIZACAO POR DESENHO: grava SOMENTE backend, targetModelKey e invokeArgs com os
    campos permitidos (model/profile/oss/localProvider). NUNCA token, chave, baseURL,
    header, path de config ou politica.

    VETO DURO: revisores cujo modelo casa baixo-aterramento-comprovado (Mistral Large 3,
    Nemotron 3 Ultra — ver README, politica de modelos) sao DESCARTADOS com aviso, mesmo
    que o usuario os tenha escolhido (a preferencia nao supera o veto duro).

    A SELECAO e feita pelo usuario (gatilhos em 15/SKILL): o agente monta o menu
    (`opencode models` para o catalogo opencode + capabilities.json/defaults para os demais),
    o usuario escolhe, e este script PERSISTE a escolha. read-only -> oferta -> confirmacao.
.PARAMETER ReviewersJson
    JSON (array) dos revisores escolhidos: [{ "backend": "...", "targetModelKey": "...",
    "invokeArgs": { "model": "...", "profile": "...", "oss": true, "localProvider": "..." } }].
.PARAMETER OutputPath
    Caminho do arquivo. Default: %LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json.
.EXAMPLE
    .\Set-LlmDelegatePreferredReviewers.ps1 -ReviewersJson '[{"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro"}]'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $ReviewersJson,
    [string] $OutputPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate' | Join-Path -ChildPath 'preferred-reviewers.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) { return $Obj.PSObject.Properties[$Name].Value }
    return $null
}

# Veto duro por baixo aterramento comprovado (README, politica de modelos). Casado pelo
# NOME do modelo (parte apos a ultima '/'), case-insensitive.
$hardVetoPatterns = @('mistral-large-3', 'nemotron-3-ultra')
$allowedBackends = @('opencode', 'codex', 'claude-code', 'copilot', 'gemini')

$parsed = $null
try { $parsed = $ReviewersJson | ConvertFrom-Json } catch {
    throw "BLOCK: -ReviewersJson nao e JSON valido: $($_.Exception.Message)"
}
$items = @($parsed)

$kept = [System.Collections.Generic.List[object]]::new()
$discardedVeto = [System.Collections.Generic.List[object]]::new()
$skipped = [System.Collections.Generic.List[object]]::new()

foreach ($it in $items) {
    $backend = [string](Get-Prop $it 'backend')
    $target = [string](Get-Prop $it 'targetModelKey')
    if ([string]::IsNullOrWhiteSpace($backend) -or [string]::IsNullOrWhiteSpace($target)) { $skipped.Add($target); continue }
    if ($allowedBackends -notcontains $backend) { $skipped.Add($target); continue }

    $modelPart = @($target -split '/')[-1]
    $isVeto = $false
    foreach ($v in $hardVetoPatterns) { if ($modelPart.ToLowerInvariant().Contains($v)) { $isVeto = $true; break } }
    if ($isVeto) { $discardedVeto.Add($target); continue }

    # invokeArgs sanitizado: so campos permitidos.
    $inv = Get-Prop $it 'invokeArgs'
    $invClean = [ordered]@{}
    foreach ($f in @('model', 'profile', 'localProvider')) {
        $val = Get-Prop $inv $f
        if ($null -ne $val -and -not [string]::IsNullOrWhiteSpace([string]$val)) { $invClean[$f] = [string]$val }
    }
    $ossVal = Get-Prop $inv 'oss'
    if ($ossVal -is [bool] -and $ossVal) { $invClean['oss'] = $true }
    # model default quando ausente: Codex usa o nome nu; demais usam a chave de destino.
    if (-not $invClean.Contains('model')) {
        $invClean['model'] = if ($backend -eq 'codex') { $modelPart } else { $target }
    }

    $kept.Add([pscustomobject]@{
            backend        = $backend
            targetModelKey = $target
            invokeArgs     = [pscustomobject]$invClean
        })
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$doc = [pscustomobject]@{
    schemaVersion = 1
    updatedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    reviewers     = @($kept)
}
Set-Content -LiteralPath $OutputPath -Value ($doc | ConvertTo-Json -Depth 8) -Encoding utf8

[pscustomobject]@{
    written       = $kept.Count
    discardedVeto = @($discardedVeto)
    skipped       = @($skipped)
    outputPath    = $OutputPath
} | ConvertTo-Json -Depth 6 -Compress
