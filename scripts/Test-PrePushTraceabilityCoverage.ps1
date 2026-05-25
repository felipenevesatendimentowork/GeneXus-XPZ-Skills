#requires -Version 7.4
<#
.SYNOPSIS
    Detecta riscos objetivos de rastreabilidade editorial na rotina pre-push.

.DESCRIPTION
    Checagem consultiva para apontar zonas de risco que a fase semantica deve
    justificar. Nao tenta provar cobertura documental completa.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [AllowEmptyCollection()]
    [string[]]$ChangedFiles = @(),

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-RepoGit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & git -C $RepositoryRoot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @()
    if ($null -ne $output) {
        $lines = @($output | ForEach-Object { $_.ToString() })
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines    = $lines
        Text     = ($lines -join [Environment]::NewLine)
    }
}

function Normalize-RepoPath {
    param([string]$Path)

    return (($Path -replace '\\', '/').Trim())
}

function Add-Finding {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Target,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Path = $null
    )

    $Target.Add([pscustomobject][ordered]@{
        code     = $Code
        severity = 'warn'
        path     = $Path
        message  = $Message
    })
}

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path
$normalizedChangedFiles = @($ChangedFiles | ForEach-Object { Normalize-RepoPath -Path $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
if ($normalizedChangedFiles.Count -eq 0) {
    $changedResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--name-only', "$BaseRef..HEAD")
    if ($changedResult.ExitCode -ne 0) {
        throw ("Falha ao listar arquivos alterados em {0}..HEAD: {1}" -f $BaseRef, $changedResult.Text)
    }
    $normalizedChangedFiles = @($changedResult.Lines | ForEach-Object { Normalize-RepoPath -Path $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

$publicTraceabilityPath = Join-Path $resolvedRoot '09-inventario-e-rastreabilidade-publica.md'
$agentGuidePath = Join-Path $resolvedRoot '08-guia-para-agente-gpt.md'
$publicTraceabilityText = if (Test-Path -LiteralPath $publicTraceabilityPath -PathType Leaf) {
    [System.IO.File]::ReadAllText($publicTraceabilityPath)
} else {
    ''
}
$agentGuideText = if (Test-Path -LiteralPath $agentGuidePath -PathType Leaf) {
    [System.IO.File]::ReadAllText($agentGuidePath)
} else {
    ''
}

$findings = [System.Collections.Generic.List[object]]::new()

$agentsChanged = $normalizedChangedFiles -contains 'AGENTS.md'
if ($agentsChanged) {
    $agentsDiff = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--unified=0', "$BaseRef..HEAD", '--', 'AGENTS.md')
    if ($agentsDiff.ExitCode -eq 0 -and
        $agentsDiff.Text -match '(?i)(pre-push|pré-push|09-inventario|rastreabilidade)' -and
        -not ($normalizedChangedFiles -contains '08-guia-para-agente-gpt.md')) {
        Add-Finding -Target $findings -Code 'AGENTS_PREPUSH_NOT_MIRRORED_IN_08' -Path '08-guia-para-agente-gpt.md' -Message 'AGENTS.md alterou regra pre-push/rastreabilidade, mas 08-guia-para-agente-gpt.md nao aparece no intervalo; avaliar se o guia do agente ficou defasado.'
    }
}

$scriptRiskPattern = '(INVENTORY_[A-Z_]+|DRIFT_[A-Z_]+|executionEvidence|watcherContext|pathEnrichment|diagnosticDegraded|compactSignals|PUSH_READINESS|pushReadiness|estado_operacional_sugerido|atualizacao_metodologica_pendente)'
$changedScriptPaths = @($normalizedChangedFiles | Where-Object { $_ -match '^scripts/.+\.(ps1|py|json)$' })
foreach ($scriptPath in $changedScriptPaths) {
    $scriptDiff = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--unified=0', "$BaseRef..HEAD", '--', $scriptPath)
    if ($scriptDiff.ExitCode -ne 0) {
        continue
    }

    $scriptBaseName = Split-Path -Leaf $scriptPath
    $isTraceabilityDetector = $scriptBaseName -eq 'Test-PrePushTraceabilityCoverage.ps1'
    $addedDiffText = (@($scriptDiff.Lines | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' }) -join [Environment]::NewLine)
    $removedDiffText = (@($scriptDiff.Lines | Where-Object { $_ -match '^-' -and $_ -notmatch '^---' }) -join [Environment]::NewLine)
    $scriptHasTraceabilityRisk = $addedDiffText -match $scriptRiskPattern
    if ($scriptHasTraceabilityRisk -and $publicTraceabilityText -notmatch [regex]::Escape($scriptBaseName)) {
        Add-Finding -Target $findings -Code 'PUBLIC_TRACEABILITY_MISSING_SCRIPT' -Path $scriptPath -Message ("{0} mudou contrato/sinal rastreavel, mas 09-inventario-e-rastreabilidade-publica.md nao menciona o script nominalmente." -f $scriptPath)
    }

    $tokens = if ($isTraceabilityDetector) {
        @()
    } else {
        $addedTokens = @([regex]::Matches($addedDiffText, $scriptRiskPattern) | ForEach-Object { $_.Value } | Sort-Object -Unique)
        $removedTokens = @([regex]::Matches($removedDiffText, $scriptRiskPattern) | ForEach-Object { $_.Value } | Sort-Object -Unique)
        @($addedTokens | Where-Object { $removedTokens -notcontains $_ })
    }
    foreach ($token in $tokens) {
        if ($publicTraceabilityText -notmatch [regex]::Escape($token)) {
            Add-Finding -Target $findings -Code 'PUBLIC_TRACEABILITY_MISSING_TOKEN' -Path $scriptPath -Message ("Token rastreavel '{0}' aparece no diff de {1}, mas nao aparece no 09." -f $token, $scriptPath)
        }
    }
}

$selfTestChangedPaths = @($changedScriptPaths | Where-Object { $_ -match 'SelfTest\.ps1$' })
foreach ($selfTestPath in $selfTestChangedPaths) {
    $selfTestBaseName = Split-Path -Leaf $selfTestPath
    $motorBaseName = $selfTestBaseName -replace 'SelfTest\.ps1$', '.ps1'
    if ($motorBaseName -ne $selfTestBaseName -and $publicTraceabilityText -match [regex]::Escape($selfTestBaseName) -and $publicTraceabilityText -notmatch [regex]::Escape($motorBaseName)) {
        Add-Finding -Target $findings -Code 'PUBLIC_TRACEABILITY_AGGREGATED_ROLE_RISK' -Path $selfTestPath -Message ("09 menciona a bateria {0}, mas nao menciona o motor correspondente {1}; avaliar rastreabilidade agregada demais." -f $selfTestBaseName, $motorBaseName)
    }
}

if (($normalizedChangedFiles -contains 'AGENTS.md') -and ($normalizedChangedFiles -contains '08-guia-para-agente-gpt.md')) {
    foreach ($requiredPhrase in @('09-inventario-e-rastreabilidade-publica.md', 'encontrar o termo', 'rastreabilidade agregada')) {
        if ($agentGuideText -notmatch [regex]::Escape($requiredPhrase)) {
            Add-Finding -Target $findings -Code 'AGENT_GUIDE_PREPUSH_RULE_INCOMPLETE' -Path '08-guia-para-agente-gpt.md' -Message ("08-guia-para-agente-gpt.md foi alterado junto com AGENTS.md, mas nao contem marcador esperado da regra pre-push: {0}" -f $requiredPhrase)
        }
    }
}

$orchestratorPath = 'scripts/Invoke-PrePushMechanicalChecks.ps1'
if ($normalizedChangedFiles -contains $orchestratorPath) {
    $orchestratorDiff = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--unified=0', "$BaseRef..HEAD", '--', $orchestratorPath)
    if ($orchestratorDiff.ExitCode -eq 0) {
        $addedOrchestratorText = (@($orchestratorDiff.Lines | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' }) -join [Environment]::NewLine)
        $referencedGateScripts = @([regex]::Matches($addedOrchestratorText, 'Test-[A-Za-z0-9-]+\.ps1') |
            ForEach-Object { $_.Value } |
            Where-Object { $_ -ne 'Test-PsScriptsParse.ps1' } |
            Sort-Object -Unique)
        foreach ($gateScript in $referencedGateScripts) {
            if ($agentGuideText -notmatch [regex]::Escape($gateScript)) {
                Add-Finding -Target $findings -Code 'AGENT_GUIDE_MISSING_ORCHESTRATOR_GATE' -Path '08-guia-para-agente-gpt.md' -Message ("Invoke-PrePushMechanicalChecks.ps1 passou a referenciar {0}, mas 08-guia-para-agente-gpt.md nao cita esse gate nominalmente." -f $gateScript)
            }
        }
    }
}

$status = if ($findings.Count -gt 0) { 'warn' } else { 'pass' }
$result = [ordered]@{
    status       = $status
    baseRef      = $BaseRef
    changedFiles = @($normalizedChangedFiles)
    findings     = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 8
} else {
    Write-Output ("TRACEABILITY_COVERAGE={0}" -f $status)
    foreach ($finding in $findings) {
        Write-Output ("TRACEABILITY_FINDING: {0}: {1}" -f $finding.code, $finding.message)
    }
}

exit 0
