#requires -Version 7.4

<#
.SYNOPSIS
    Garante que a raiz do repositório de skills XPZ seja um repositório Git
    ligado ao remoto oficial no GitHub.

.DESCRIPTION
    Cobre o Cenário A descrito em xpz-skills-setup/SKILL.md: o usuário baixou o
    repositório como ZIP do GitHub, descompactou no PC e abriu uma sessao pedindo
    o setup. A pasta tem todo o conteúdo, mas não e um repositório Git.

    Fluxo deterministico:
      1. Garante o executavel Git (instala via winget quando ausente e permitido).
      2. Se a pasta já for repositório: confere se origin aponta para o oficial.
      3. Se não for: git init + remote oficial + fetch + reset --mixed origin/<branch>,
         ligando a historia oficial SEM sobrescrever os arquivos vindos do ZIP.
      4. Gate anti-destrutivo: se o working tree divergir do oficial, reporta e para;
         o alinhamento destrutivo (reset --hard) só ocorre com -AlignToOfficial.

    NÃO clona pasta vazia: nesse caso esta skill nem existe na pasta. O clone e
    pre-requisito documentado (Cenário B no SKILL.md).

.OUTPUTS
    Texto legivel por padrão; objeto JSON com -AsJson. O campo "label" e
    deterministico e destinado a interpretacao por agente.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RepoRoot,

    [string]$OfficialRemoteUrl = 'https://github.com/GxBrasilNOficial/GeneXus-XPZ-Skills.git',

    [string]$DefaultBranch = 'main',

    [bool]$InstallGitIfMissing = $true,

    [switch]$AlignToOfficial,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:GitExe = $null

function Resolve-RepoRoot {
    param([string]$Requested)

    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        return (Resolve-Path -LiteralPath $Requested).Path
    }
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        throw 'BLOCK: nao foi possivel inferir a raiz do repositorio a partir de PSScriptRoot.'
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

function Write-Result {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Label,
        [string[]]$Messages = @(),
        [string[]]$Drift = @(),
        [string]$Remote = '',
        [string]$Branch = ''
    )

    $result = [ordered]@{
        status   = $Status
        label    = $Label
        remote   = $Remote
        branch   = $Branch
        drift    = @($Drift)
        messages = @($Messages)
    }

    if ($AsJson) {
        $result | ConvertTo-Json -Depth 6 | Write-Output
    }
    else {
        Write-Output ('{0}: {1}' -f $Status, $Label)
        foreach ($m in $Messages) { Write-Output ('  - {0}' -f $m) }
        if (@($Drift).Count -gt 0) {
            Write-Output '  divergencias (working tree x oficial):'
            foreach ($d in $Drift) { Write-Output ('    {0}' -f $d) }
        }
    }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string[]]$GitArgs,
        [switch]$AllowFailure
    )

    $out = & $script:GitExe @GitArgs 2>&1
    $code = $LASTEXITCODE
    $text = (@($out) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "BLOCK: git $($GitArgs -join ' ') falhou (exit $code): $text"
    }
    return [pscustomobject]@{ ExitCode = $code; Text = $text }
}

function ConvertTo-NormalizedUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    $u = $Url.Trim().ToLowerInvariant()
    $u = $u.TrimEnd('/')
    if ($u.EndsWith('.git')) { $u = $u.Substring(0, $u.Length - 4) }
    return $u
}

function Update-SessionPathFromEnvironment {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($machine)) { $parts += $machine }
    if (-not [string]::IsNullOrWhiteSpace($user)) { $parts += $user }
    if ($parts.Count -gt 0) { $env:Path = $parts -join ';' }
}

function Find-GitExecutable {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
    )
    foreach ($c in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($c) -and (Test-Path -LiteralPath $c -PathType Leaf)) {
            return $c
        }
    }
    return $null
}

# --- 1. Garantir o executavel Git ---------------------------------------------
$gitPath = Find-GitExecutable
if (-not $gitPath) {
    if (-not $InstallGitIfMissing) {
        return (Write-Result -Status 'BLOCK' -Label 'GIT_MISSING_NO_INSTALL' -Messages @(
                'Git nao encontrado e instalacao automatica desabilitada (-InstallGitIfMissing:$false).',
                'Instale o Git (https://git-scm.com/download/win) ou rode com instalacao habilitada.'))
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        return (Write-Result -Status 'BLOCK' -Label 'GIT_MISSING_NO_INSTALLER' -Messages @(
                'Git ausente e winget indisponivel para instalacao automatica.',
                'Instale o Git manualmente: https://git-scm.com/download/win e reabra a sessao.'))
    }

    if ($PSCmdlet.ShouldProcess('Git.Git', 'Instalar Git via winget')) {
        $wingetArgs = @('install', '--id', 'Git.Git', '-e', '--source', 'winget',
            '--accept-package-agreements', '--accept-source-agreements', '--silent')
        & winget @wingetArgs 2>&1 | Out-Null
        $wingetExit = $LASTEXITCODE

        Update-SessionPathFromEnvironment
        $gitPath = Find-GitExecutable

        if (-not $gitPath) {
            if ($wingetExit -ne 0) {
                return (Write-Result -Status 'BLOCK' -Label 'GIT_INSTALL_FAILED' -Messages @(
                        "winget retornou exit $wingetExit ao instalar Git.Git.",
                        'A instalacao pode exigir elevacao (UAC). Instale manualmente e reabra a sessao.'))
            }
            return (Write-Result -Status 'ACTION_REQUIRED' -Label 'GIT_INSTALLED_REOPEN_SHELL' -Messages @(
                    'Git instalado, mas o PATH desta sessao ainda nao o expoe.',
                    'Reabra a sessao (ou o terminal) e rode o setup novamente.'))
        }
    }
    else {
        return (Write-Result -Status 'ACTION_REQUIRED' -Label 'GIT_INSTALL_SKIPPED' -Messages @(
                'Instalacao do Git nao confirmada (WhatIf). Nenhuma acao executada.'))
    }
}
$script:GitExe = $gitPath

# --- 2/3. Resolver estado do repositório --------------------------------------
$root = Resolve-RepoRoot -Requested $RepoRoot
$officialNorm = ConvertTo-NormalizedUrl -Url $OfficialRemoteUrl

$insideCheck = Invoke-Git -GitArgs @('-C', $root, 'rev-parse', '--is-inside-work-tree') -AllowFailure
$isRepo = ($insideCheck.ExitCode -eq 0 -and $insideCheck.Text.Trim() -eq 'true')

if ($isRepo) {
    $originCheck = Invoke-Git -GitArgs @('-C', $root, 'remote', 'get-url', 'origin') -AllowFailure
    if ($originCheck.ExitCode -ne 0) {
        # Repositório sem origin: ligar ao oficial e nada destrutivo.
        if ($PSCmdlet.ShouldProcess($root, "Adicionar remote origin -> $OfficialRemoteUrl")) {
            Invoke-Git -GitArgs @('-C', $root, 'remote', 'add', 'origin', $OfficialRemoteUrl) | Out-Null
            return (Write-Result -Status 'OK' -Label 'ORIGIN_ADDED' -Remote $OfficialRemoteUrl -Messages @(
                    'Repositorio ja existia sem origin; remote oficial adicionado.',
                    'Rode git fetch origin para sincronizar referencias.'))
        }
        return (Write-Result -Status 'ACTION_REQUIRED' -Label 'ORIGIN_ADD_SKIPPED' -Messages @(
                'Adicao de origin nao confirmada (WhatIf).'))
    }

    $currentNorm = ConvertTo-NormalizedUrl -Url $originCheck.Text
    if ($currentNorm -eq $officialNorm) {
        $branchInfo = Invoke-Git -GitArgs @('-C', $root, 'rev-parse', '--abbrev-ref', 'HEAD') -AllowFailure
        return (Write-Result -Status 'OK' -Label 'GIT_ALREADY_LINKED' `
                -Remote $originCheck.Text.Trim() -Branch $branchInfo.Text.Trim() -Messages @(
                'A raiz ja e um repositorio Git ligado ao remoto oficial. Nenhuma acao necessaria.'))
    }

    return (Write-Result -Status 'BLOCK' -Label 'REMOTE_MISMATCH' `
            -Remote $originCheck.Text.Trim() -Messages @(
            "origin aponta para outro remoto: $($originCheck.Text.Trim())",
            "Oficial esperado: $OfficialRemoteUrl",
            'Nao alterado automaticamente. Ajuste o remoto manualmente se desejar religar ao oficial.'))
}

# --- Bootstrap: pasta com conteúdo, sem .git ----------------------------------
if (-not $PSCmdlet.ShouldProcess($root, "Inicializar repositorio Git e ligar a $OfficialRemoteUrl")) {
    return (Write-Result -Status 'ACTION_REQUIRED' -Label 'BOOTSTRAP_SKIPPED' -Messages @(
            'Bootstrap nao confirmado (WhatIf). Nenhuma acao executada.'))
}

$initResult = Invoke-Git -GitArgs @('-C', $root, 'init', '-b', $DefaultBranch) -AllowFailure
if ($initResult.ExitCode -ne 0) {
    # git antigo sem 'init -b': init simples + apontar HEAD para a branch desejada.
    Invoke-Git -GitArgs @('-C', $root, 'init') | Out-Null
    Invoke-Git -GitArgs @('-C', $root, 'symbolic-ref', 'HEAD', "refs/heads/$DefaultBranch") | Out-Null
}

Invoke-Git -GitArgs @('-C', $root, 'remote', 'add', 'origin', $OfficialRemoteUrl) | Out-Null
Invoke-Git -GitArgs @('-C', $root, 'fetch', 'origin', $DefaultBranch) | Out-Null
Invoke-Git -GitArgs @('-C', $root, 'reset', '--mixed', "origin/$DefaultBranch") | Out-Null
Invoke-Git -GitArgs @('-C', $root, 'branch', "--set-upstream-to=origin/$DefaultBranch", $DefaultBranch) -AllowFailure | Out-Null

$statusResult = Invoke-Git -GitArgs @('-C', $root, 'status', '--porcelain') -AllowFailure
$driftLines = @()
if (-not [string]::IsNullOrWhiteSpace($statusResult.Text)) {
    $driftLines = @($statusResult.Text -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

if ($driftLines.Count -eq 0) {
    return (Write-Result -Status 'OK' -Label 'GIT_LINKED_CLEAN' `
            -Remote $OfficialRemoteUrl -Branch $DefaultBranch -Messages @(
            'Repositorio inicializado e ligado ao oficial. Working tree identico ao oficial.'))
}

if (-not $AlignToOfficial) {
    return (Write-Result -Status 'ACTION_REQUIRED' -Label 'GIT_LINKED_WITH_DRIFT' `
            -Remote $OfficialRemoteUrl -Branch $DefaultBranch -Drift $driftLines -Messages @(
            'Repositorio ligado ao oficial, mas o conteudo do ZIP diverge do oficial.',
            'Nada foi sobrescrito. Para alinhar o working tree ao oficial (DESTRUTIVO), rode com -AlignToOfficial.'))
}

if ($PSCmdlet.ShouldProcess($root, 'Alinhar working tree ao oficial (git reset --hard)')) {
    Invoke-Git -GitArgs @('-C', $root, 'reset', '--hard', "origin/$DefaultBranch") | Out-Null
    return (Write-Result -Status 'OK' -Label 'ALIGNED_TO_OFFICIAL' `
            -Remote $OfficialRemoteUrl -Branch $DefaultBranch -Messages @(
            'Working tree alinhado ao oficial via reset --hard. Arquivos rastreados agora batem com origin/' + $DefaultBranch + '.',
            'Arquivos nao rastreados (untracked) foram preservados.'))
}

return (Write-Result -Status 'ACTION_REQUIRED' -Label 'ALIGN_SKIPPED' -Drift $driftLines -Messages @(
        'Alinhamento destrutivo nao confirmado (WhatIf).'))
