#requires -Version 7.4
<#
.SYNOPSIS
    Executa checagens mecanicas iniciais da rotina pre-push.

.DESCRIPTION
    Coordena contexto git (commits pendentes, diff --check, arquivos alterados),
    delega parse PowerShell a scripts/Test-PsScriptsParse.ps1 e classifica
    arquivos do diff para insumo da fase semantica do agente.

    Nao substitui busca de coerencia cruzada, regra em camadas de skills longas
    nem relatorio final ao usuario — ver AGENTS.md secao "Revisao pre-push".
    Emite avisos informativos se a branch nao for main ou se a working tree
    tiver alteracoes nao commitadas fora do intervalo BaseRef..HEAD. Com
    commitsBehind > 0, define pushReadiness=blocked e marca o diff do intervalo
    como apenas diagnostico (sem falhar parse/whitespace).

.PARAMETER RootPath
    Raiz do repositorio. Default: pai de scripts/.

.PARAMETER BaseRef
    Referencia unica do intervalo analisado: commits pendentes, contagem,
    arquivos alterados e diff --check usam sempre BaseRef..HEAD. Default:
    origin/main (copia local do ultimo fetch; desde o ultimo push usual em main).
    Se a ref nao existir, o script falha com mensagem clara (sem fallback
    automatico para main). Com a ref existente mas desatualizada em relacao ao
    remoto, o intervalo pode superestimar commits pendentes; o agente deve
    executar git fetch origin antes da rotina quando precisar comparar contra
    o remoto atual (ver AGENTS.md). O upstream da branch so aparece no JSON
    como contexto informativo.

.PARAMETER AsJson
    Emite diagnostico estruturado em JSON.

.PARAMETER SkipParse
    Pula a invocacao de Test-PsScriptsParse.ps1 (uso excepcional).
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [switch]$AsJson,

    [switch]$SkipParse
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RelativeDisplayPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    return [System.IO.Path]::GetRelativePath(
        [System.IO.Path]::GetFullPath($BasePath),
        [System.IO.Path]::GetFullPath($TargetPath)
    )
}

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

function Test-GitRefExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$Ref
    )

    $result = Invoke-RepoGit -RepositoryRoot $RepositoryRoot -Arguments @('rev-parse', '--verify', $Ref)
    return ($result.ExitCode -eq 0)
}

function Resolve-GitRepositoryContext {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartPath
    )

    $topLevelResult = Invoke-RepoGit -RepositoryRoot $StartPath -Arguments @('rev-parse', '--show-toplevel')
    if ($topLevelResult.ExitCode -ne 0) {
        throw ("Nao foi possivel resolver repositorio git a partir de '{0}'. Verifique o caminho ou use git rev-parse --show-toplevel manualmente. Detalhe: {1}" -f $StartPath, $topLevelResult.Text)
    }

    $repositoryRoot = $topLevelResult.Lines[0].Trim()
    $gitDirResult = Invoke-RepoGit -RepositoryRoot $repositoryRoot -Arguments @('rev-parse', '--git-dir')
    $gitDir = $null
    if ($gitDirResult.ExitCode -eq 0 -and $gitDirResult.Lines.Count -gt 0) {
        $gitDir = $gitDirResult.Lines[0].Trim()
    }

    return [pscustomobject]@{
        RepositoryRoot = $repositoryRoot
        GitDir         = $gitDir
    }
}

function Get-ChangedFileKind {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $normalized = ($RelativePath -replace '\\', '/').Trim()

    if ($normalized -match '^scripts/.+\.ps1$') {
        return 'scripts'
    }
    if ($normalized -match '\.example\.ps1$') {
        return 'examples'
    }
    if ($normalized -match '^historico/') {
        return 'historico'
    }
    if ($normalized -match '/SKILL\.md$') {
        return 'skills'
    }
    if ($normalized -match '^\.github/') {
        return 'workflows'
    }
    if ($normalized -match '^[^/]+\.md$') {
        return 'baseDocs'
    }

    return 'other'
}

function Add-ChangedFilesByKind {
    param(
        [AllowEmptyCollection()]
        [string[]]$RelativePaths = @()
    )

    $byKind = [ordered]@{
        scripts   = @()
        skills    = @()
        baseDocs  = @()
        examples  = @()
        workflows = @()
        historico = @()
        other     = @()
    }

    foreach ($relativePath in @($RelativePaths | Sort-Object)) {
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            continue
        }

        $kind = Get-ChangedFileKind -RelativePath $relativePath
        $byKind[$kind] = @($byKind[$kind] + $relativePath)
    }

    return $byKind
}

function Get-WorkingTreeDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [int]$MaxSamplePaths = 15
    )

    $statusResult = Invoke-RepoGit -RepositoryRoot $RepositoryRoot -Arguments @('status', '--porcelain')
    if ($statusResult.ExitCode -ne 0) {
        throw ("Falha ao ler working tree (git status --porcelain). Detalhe: {0}" -f $statusResult.Text)
    }

    $untrackedFiles = [System.Collections.Generic.List[string]]::new()
    $dirtyTrackedFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($line in @($statusResult.Lines)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }

        $status = $line.Substring(0, 2)
        $path = $line.Substring(3).Trim()
        if ($path -match ' -> ') {
            $path = ($path -split ' -> ', 2)[1].Trim()
        }

        if ($status -eq '??') {
            [void]$untrackedFiles.Add($path)
        } else {
            [void]$dirtyTrackedFiles.Add($path)
        }
    }

    $untrackedAll = @($untrackedFiles)
    $dirtyTrackedAll = @($dirtyTrackedFiles)
    $isClean = ($untrackedAll.Count -eq 0 -and $dirtyTrackedAll.Count -eq 0)

    return [pscustomobject]@{
        Status              = $(if ($isClean) { 'clean' } else { 'dirty' })
        UntrackedCount      = $untrackedAll.Count
        DirtyTrackedCount   = $dirtyTrackedAll.Count
        UntrackedFiles      = @($untrackedAll | Select-Object -First $MaxSamplePaths)
        DirtyTrackedFiles   = @($dirtyTrackedAll | Select-Object -First $MaxSamplePaths)
        UntrackedTruncated  = ($untrackedAll.Count -gt $MaxSamplePaths)
        DirtyTrackedTruncated = ($dirtyTrackedAll.Count -gt $MaxSamplePaths)
    }
}

$startPath = (Resolve-Path -LiteralPath $RootPath).Path
$gitContext = Resolve-GitRepositoryContext -StartPath $startPath
$resolvedRoot = $gitContext.RepositoryRoot
$resolvedGitDir = $gitContext.GitDir

$branchResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
if ($branchResult.ExitCode -ne 0) {
    throw 'Nao foi possivel resolver a branch atual.'
}
$currentBranch = $branchResult.Lines[0].Trim()

$expectedBranch = 'main'
$onExpectedBranch = ($currentBranch -ceq $expectedBranch)
$workingTree = Get-WorkingTreeDiagnostics -RepositoryRoot $resolvedRoot

$upstreamResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-parse', '--abbrev-ref', '@{upstream}')
$upstreamRef = $null
$upstreamConfigured = ($upstreamResult.ExitCode -eq 0)
if ($upstreamConfigured) {
    $upstreamRef = $upstreamResult.Lines[0].Trim()
}

$effectiveBaseRef = $BaseRef
if (-not (Test-GitRefExists -RepositoryRoot $resolvedRoot -Ref $effectiveBaseRef)) {
    throw ("Ref base '{0}' nao encontrada. Para medir commits locais ainda nao enviados ao remoto, confirme que origin/main existe (ex.: git fetch origin) ou passe -BaseRef com uma ref valida. Nao ha fallback automatico para main." -f $BaseRef)
}

$range = "$effectiveBaseRef..HEAD"
$commitLogResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('log', $range, '--oneline')
if ($commitLogResult.ExitCode -ne 0) {
    throw "Falha ao listar commits pendentes para o intervalo $range."
}

$pendingCommits = @($commitLogResult.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

$aheadRange = "${effectiveBaseRef}..HEAD"
$behindRange = "HEAD..${effectiveBaseRef}"
$aheadResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-list', '--count', $aheadRange)
$behindResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-list', '--count', $behindRange)

$commitsAhead = 0
$commitsBehind = 0
if ($aheadResult.ExitCode -eq 0 -and $aheadResult.Lines.Count -gt 0) {
    $commitsAhead = [int]$aheadResult.Lines[0]
}
if ($behindResult.ExitCode -eq 0 -and $behindResult.Lines.Count -gt 0) {
    $commitsBehind = [int]$behindResult.Lines[0]
}

$changedFiles = @()
$whitespaceStatus = 'clean'
$whitespaceIssues = @()

if ($commitsAhead -gt 0) {
    $nameOnlyResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--name-only', $range)
    if ($nameOnlyResult.ExitCode -ne 0) {
        throw "Falha ao listar arquivos alterados para o intervalo $range."
    }
    $changedFiles = @($nameOnlyResult.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $whitespaceResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--check', $range)
    if ($whitespaceResult.ExitCode -ne 0) {
        $whitespaceStatus = 'issues-found'
        $whitespaceIssues = @($whitespaceResult.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
}

$changedFilesByKind = Add-ChangedFilesByKind -RelativePaths $changedFiles

$parseGate = [ordered]@{
    script     = 'scripts/Test-PsScriptsParse.ps1'
    status     = 'skipped'
    exitCode   = $null
    fileCount  = $null
    errorCount = $null
    findings   = @()
}

$mechanicalFailures = [System.Collections.Generic.List[string]]::new()

if (-not $SkipParse) {
    $parseScript = Join-Path $PSScriptRoot 'Test-PsScriptsParse.ps1'
    if (-not (Test-Path -LiteralPath $parseScript -PathType Leaf)) {
        throw "Script de parse nao encontrado: $parseScript"
    }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $parseOutput = & $parseScript -RootPath $resolvedRoot -AsJson 2>&1
    $parseExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction

    $parseJsonText = ($parseOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $parseObject = $null
    if (-not [string]::IsNullOrWhiteSpace($parseJsonText)) {
        $parseObject = $parseJsonText | ConvertFrom-Json
    }

    $parseGate.status = if ($parseExitCode -eq 0) { 'pass' } else { 'fail' }
    $parseGate.exitCode = $parseExitCode
    if ($null -ne $parseObject) {
        $parseGate.fileCount = $parseObject.fileCount
        $parseGate.errorCount = $parseObject.errorCount
        $parseGate.findings = @($parseObject.findings)
    }

    if ($parseExitCode -ne 0) {
        [void]$mechanicalFailures.Add('parse')
    }
}

if ($whitespaceStatus -ne 'clean') {
    [void]$mechanicalFailures.Add('whitespace')
}

$overallStatus = if ($mechanicalFailures.Count -eq 0) { 'pass' } else { 'fail' }

$pushReadiness = if ($commitsBehind -gt 0) { 'blocked' } else { 'ok' }
$intervalDiffDiagnosticOnly = ($commitsBehind -gt 0)

$agentOperationalReminders = @(
    'Antes da rotina, git fetch origin quando origin/main deve refletir o remoto atual; ref inexistente e ref desatualizada sao casos distintos; sem fetch, commitsBehind pode ficar 0 com remoto real ja adiantado.',
    'Parse (Test-PsScriptsParse.ps1) varre todo scripts/ e *.example.ps1 fora de historico/, nao apenas o diff do intervalo.',
    'Com commitsAhead=0 nao ha diff no intervalo; pre-push nao substitui revisao de alteracoes so na working tree (ver avisos de worktree).',
    'exit 0 mecanico nao autoriza push: ler PUSH_READINESS; com blocked, integrar remoto antes do push.',
    'Com PUSH_READINESS=blocked, diff/arquivos do intervalo sao diagnosticos; fase semantica sobre commits locais continua obrigatoria.'
)

$agentWarnings = [System.Collections.Generic.List[string]]::new()
if (-not $onExpectedBranch) {
    [void]$agentWarnings.Add(
        ("Branch atual e '{0}'; este repositorio espera trabalho direto em {1}." -f $currentBranch, $expectedBranch)
    )
}
if ($workingTree.Status -ne 'clean') {
    [void]$agentWarnings.Add(
        ("Working tree fora do intervalo de commits: {0} arquivo(s) rastreado(s) modificado(s) sem commit e {1} nao rastreado(s); a pre-push nao analisa essas alteracoes em BaseRef..HEAD." -f $workingTree.DirtyTrackedCount, $workingTree.UntrackedCount)
    )
}
if ($commitsBehind -gt 0) {
    [void]$agentWarnings.Add(
        ("Remoto ({0}) esta {1} commit(s) a frente de HEAD: intervalo {2} e arquivos listados sao apenas diagnosticos; push bloqueado ate integrar. Se ainda nao houve fetch, git fetch origin; se commitsBehind persistir, integrar (ex.: git pull --rebase origin main) antes do push." -f $effectiveBaseRef, $commitsBehind, $range)
    )
}

$agentSemanticChecklist = @(
    'Fase semantica: seguir integralmente a secao Revisao pre-push do AGENTS.md na raiz do repositorio (fonte autoritativa).',
    'Nao tratar exit 0 deste passo mecanico como pre-push concluida.'
)

$result = [ordered]@{
    status                      = $overallStatus
    pushReadiness               = $pushReadiness
    intervalDiffDiagnosticOnly  = $intervalDiffDiagnosticOnly
    rootPath                    = $resolvedRoot
    git                    = [ordered]@{
        repositoryRoot      = $resolvedRoot
        gitDir              = $resolvedGitDir
        branch              = $currentBranch
        expectedBranch      = $expectedBranch
        onExpectedBranch    = $onExpectedBranch
        workingTree         = [ordered]@{
            status                = $workingTree.Status
            untrackedCount        = $workingTree.UntrackedCount
            dirtyTrackedCount     = $workingTree.DirtyTrackedCount
            untrackedFiles        = @($workingTree.UntrackedFiles)
            dirtyTrackedFiles     = @($workingTree.DirtyTrackedFiles)
            untrackedTruncated    = $workingTree.UntrackedTruncated
            dirtyTrackedTruncated = $workingTree.DirtyTrackedTruncated
        }
        upstream            = $upstreamRef
        baseRef             = $effectiveBaseRef
        range               = $range
        commitsAhead        = $commitsAhead
        commitsBehind       = $commitsBehind
        pendingCommits      = @($pendingCommits)
        changedFiles        = @($changedFiles)
        changedFilesByKind  = $changedFilesByKind
        whitespaceCheck     = $whitespaceStatus
        whitespaceIssues    = @($whitespaceIssues)
    }
    gates                  = [ordered]@{
        parse = $parseGate
    }
    mechanicalFailures       = @($mechanicalFailures)
    agentOperationalReminders = @($agentOperationalReminders)
    agentWarnings             = @($agentWarnings)
    agentSemanticChecklist   = @($agentSemanticChecklist)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 8
} else {
    Write-Output ("STATUS={0}" -f $overallStatus)
    Write-Output ("BRANCH={0} INTERVALO_BASE={1} UPSTREAM_INFORMATIVO={2}" -f $currentBranch, $effectiveBaseRef, $(if ($upstreamRef) { $upstreamRef } else { '(nao configurado)' }))
    Write-Output ("ON_EXPECTED_BRANCH={0} EXPECTED_BRANCH={1}" -f $(if ($onExpectedBranch) { 'true' } else { 'false' }), $expectedBranch)
    Write-Output ("WORKING_TREE={0} UNTRACKED={1} DIRTY_TRACKED={2}" -f $workingTree.Status, $workingTree.UntrackedCount, $workingTree.DirtyTrackedCount)
    foreach ($warning in @($agentWarnings)) {
        Write-Output ("AVISO: {0}" -f $warning)
    }
    foreach ($path in @($workingTree.UntrackedFiles)) {
        Write-Output ("WORKING_TREE_UNTRACKED: {0}" -f $path)
    }
    foreach ($path in @($workingTree.DirtyTrackedFiles)) {
        Write-Output ("WORKING_TREE_DIRTY: {0}" -f $path)
    }
    if ($workingTree.UntrackedTruncated -or $workingTree.DirtyTrackedTruncated) {
        Write-Output 'WORKING_TREE_PATHS_TRUNCATED=true'
    }
    Write-Output ("COMMITS_AHEAD={0} COMMITS_BEHIND={1}" -f $commitsAhead, $commitsBehind)
    Write-Output ("PUSH_READINESS={0}" -f $pushReadiness)
    if ($intervalDiffDiagnosticOnly) {
        Write-Output 'INTERVAL_DIFF_DIAGNOSTIC_ONLY=true'
    }
    Write-Output 'NOTA=Com origin/main existente mas desatualizada, a contagem pode nao refletir o remoto atual; git fetch origin antes da rotina quando necessario (ver AGENTS.md).'

    if ($commitsAhead -eq 0) {
        Write-Output 'PENDING_COMMITS=none'
    } else {
        foreach ($commitLine in $pendingCommits) {
            Write-Output ("PENDING_COMMIT: {0}" -f $commitLine)
        }
    }

    Write-Output ("WHITESPACE_CHECK={0}" -f $whitespaceStatus)
    foreach ($issue in $whitespaceIssues) {
        Write-Output ("WHITESPACE_ISSUE: {0}" -f $issue)
    }

    Write-Output ("PARSE_GATE={0}" -f $parseGate.status)
    if ($parseGate.status -ne 'skipped') {
        Write-Output ("PARSE_FILES={0} PARSE_ERRORS={1}" -f $parseGate.fileCount, $parseGate.errorCount)
        foreach ($finding in @($parseGate.findings)) {
            Write-Output ("PARSE_ERROR: {0}:{1}:{2}: {3}" -f $finding.file, $finding.line, $finding.column, $finding.message)
        }
    }

    if ($changedFiles.Count -gt 0) {
        Write-Output 'CHANGED_FILES_BY_KIND:'
        foreach ($kind in @($changedFilesByKind.Keys)) {
            $paths = @($changedFilesByKind[$kind])
            if ($paths.Count -eq 0) {
                continue
            }
            Write-Output ("  {0}:" -f $kind)
            foreach ($path in $paths) {
                Write-Output ("    - {0}" -f $path)
            }
        }
    }

    Write-Output 'AGENT_SEMANTIC_CHECKLIST:'
    foreach ($item in $agentSemanticChecklist) {
        Write-Output ("  - {0}" -f $item)
    }
}

if ($mechanicalFailures.Count -gt 0) {
    exit 1
}

exit 0
