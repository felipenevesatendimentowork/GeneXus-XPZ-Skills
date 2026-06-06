#requires -Version 7.4
<#
.SYNOPSIS
    Gate consultivo: detecta termo de contrato introduzido no diff e mencoes
    equivalentes do repositorio que podem ter ficado com o conjunto antigo.

.DESCRIPTION
    Suporte mecanico da regra simetrica do passo 2 de 13-revisao-pre-push.md:
    quando a frente ADICIONA parametro/alias/flag a um contrato, o termo novo
    deve aparecer em todas as mencoes equivalentes da mesma operacao.

    Heuristica determinista por TRANSICAO no diff (nao por novidade global do
    token no repo — um alias pode ja existir noutro fluxo e ainda assim ser novo
    para este contrato):

      1. Quebra o diff BaseRef..HEAD em hunks.
      2. Em cada hunk, compara tokens de contrato (-Xxx, --xxx, .PARAMETER Xxx)
         das linhas removidas e adicionadas. Um token T e INTRODUZIDO no hunk se
         aparece em linha adicionada e em nenhuma linha removida do mesmo hunk.
      3. Quando uma linha adicionada co-localiza T (introduzido) com um token P
         que existia no hunk (presente em linha removida), registra o par (T, P):
         e a assinatura de "alias acrescentado a uma enumeracao existente"
         (ex.: '- ...-ObjectNames ou -ObjectGuids' -> '+ ...-ObjectList,
         -ObjectNames ou -ObjectGuids').
      4. Varre o estado atual do repositorio (.md, .ps1, .py fora de historico/)
         por linhas que mencionam P sem T (ignorando a propria declaracao de P:
         .PARAMETER P e bloco param): cada uma e uma CANDIDATA a mencao defasada.

    Consultivo: nao prova propagacao completa nem reprova sozinho. Findings sao
    severity 'warn'; o orquestrador os despeja em agentWarnings e a fase
    semantica confronta e justifica ou corrige cada candidata. Falso positivo e
    barato (justificar/descartar); o custo alto e o falso negativo (termo novo
    que ficou so com o conjunto antigo, invisivel no diff). Limitacao conhecida:
    so dispara quando ha transicao co-localizada no diff; alias adicionado sem
    enumeracao pre-existente no mesmo hunk nao gera par.

.PARAMETER RootPath
    Raiz do repositorio. Default: pai de scripts/.

.PARAMETER BaseRef
    Referencia base do intervalo BaseRef..HEAD. Default: origin/main.

.PARAMETER ChangedFiles
    Arquivos alterados no intervalo (informativo; aceito para o contrato comum
    dos gates do orquestrador). A deteccao usa o diff e o estado atual do repo.

.PARAMETER MaxFindings
    Teto de candidatas reportadas. Default: 30.

.PARAMETER AsJson
    Emite diagnostico estruturado em JSON.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [AllowEmptyCollection()]
    [string[]]$ChangedFiles = @(),

    [ValidateRange(1, 500)]
    [int]$MaxFindings = 30,

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

# Tokens de contrato: parametro PowerShell (-Xxx, inicial maiuscula para nao
# casar operadores -eq/-not/-join), flag CLI/Python (--xxx) e bloco .PARAMETER Xxx.
$psParamRegex  = [regex]::new('(?<![A-Za-z0-9_])-(?<name>[A-Z][A-Za-z0-9]+)')
$cliFlagRegex  = [regex]::new('(?<![A-Za-z0-9_])--(?<name>[a-z][a-z0-9-]+)')
$paramDocRegex = [regex]::new('\.PARAMETER\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)')

function Get-LineTokens {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)

    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($rx in @($psParamRegex, $cliFlagRegex, $paramDocRegex)) {
        foreach ($m in $rx.Matches($Line)) {
            [void]$names.Add($m.Groups['name'].Value)
        }
    }
    return @($names | Sort-Object -Unique)
}

function Test-TokensRelated {
    # Reduz ruido de co-localizacao coincidente (ex.: linhas de invocacao
    # 'pwsh -NoProfile -File ... -FrontPrefix'): so trata como par quando os dois
    # tokens compartilham morfema (prefixo OU sufixo comum >= 4 chars,
    # case-insensitive). Alias/enumeracao de contrato quase sempre compartilham
    # raiz (ObjectList/ObjectNames -> 'Object'; InputPath/Path -> 'Path').
    param(
        [Parameter(Mandatory = $true)][string]$A,
        [Parameter(Mandatory = $true)][string]$B
    )

    $a = $A.ToLowerInvariant()
    $b = $B.ToLowerInvariant()
    $min = [Math]::Min($a.Length, $b.Length)

    $prefix = 0
    while ($prefix -lt $min -and $a[$prefix] -eq $b[$prefix]) { $prefix++ }

    $suffix = 0
    while ($suffix -lt $min -and $a[$a.Length - 1 - $suffix] -eq $b[$b.Length - 1 - $suffix]) { $suffix++ }

    return ($prefix -ge 4 -or $suffix -ge 4)
}

$wordRegexCache = @{}
function Get-WordRegex {
    # Casa o token como palavra em qualquer forma (inclui $Token de codigo).
    param([Parameter(Mandatory = $true)][string]$Token)

    if (-not $wordRegexCache.ContainsKey($Token)) {
        $pattern = '(?<![A-Za-z0-9_])' + [regex]::Escape($Token) + '(?![A-Za-z0-9_])'
        $wordRegexCache[$Token] = [regex]::new($pattern)
    }
    return $wordRegexCache[$Token]
}

$mentionRegexCache = @{}
function Get-MentionRegex {
    # Casa o token apenas como mencao de contrato (prosa, doc, -Param), NAO como
    # variavel $Token de codigo interno (a lookbehind exclui '$').
    param([Parameter(Mandatory = $true)][string]$Token)

    if (-not $mentionRegexCache.ContainsKey($Token)) {
        $pattern = '(?<![A-Za-z0-9_$])' + [regex]::Escape($Token) + '(?![A-Za-z0-9_])'
        $mentionRegexCache[$Token] = [regex]::new($pattern)
    }
    return $mentionRegexCache[$Token]
}

$declRegexCache = @{}
function Test-IsOwnDeclarationLine {
    # Linha que apenas declara/documenta o proprio token P (nao e enumeracao da
    # operacao): .PARAMETER P, [tipo]$P, $P = ...
    param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line
    )

    if (-not $declRegexCache.ContainsKey($Token)) {
        $escaped = [regex]::Escape($Token)
        # .PARAMETER P  |  declaracao de parametro terminando em $P[,)]  |  atribuicao $P =
        $pattern = '(^\s*\.PARAMETER\s+' + $escaped + '\b)|(\$' + $escaped + '\s*[,)]?\s*$)|(\$' + $escaped + '\s*=)'
        $declRegexCache[$Token] = [regex]::new($pattern)
    }
    return $declRegexCache[$Token].IsMatch($Line)
}

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path

# Confirma que a ref base existe (sem fallback automatico).
$refCheck = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-parse', '--verify', $BaseRef)
if ($refCheck.ExitCode -ne 0) {
    throw ("Ref base '{0}' nao encontrada; rode git fetch origin ou passe -BaseRef valido." -f $BaseRef)
}

$range = "$BaseRef..HEAD"
$diffResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', $range)
if ($diffResult.ExitCode -ne 0) {
    throw ("Falha ao obter diff do intervalo {0}." -f $range)
}

# Quebra o patch em hunks; coleta linhas adicionadas e removidas de cada hunk.
$hunks = [System.Collections.Generic.List[object]]::new()
$currentAdded = $null
$currentRemoved = $null

function Save-CurrentHunk {
    if ($null -ne $currentAdded -and ($currentAdded.Count -gt 0 -or $currentRemoved.Count -gt 0)) {
        $script:hunks.Add([pscustomobject]@{
            Added   = @($currentAdded)
            Removed = @($currentRemoved)
        })
    }
}

foreach ($line in @($diffResult.Lines)) {
    if ($line.StartsWith('@@')) {
        Save-CurrentHunk
        $currentAdded = [System.Collections.Generic.List[string]]::new()
        $currentRemoved = [System.Collections.Generic.List[string]]::new()
        continue
    }
    if ($line.StartsWith('diff --git') -or $line.StartsWith('+++') -or $line.StartsWith('---')) {
        # Fronteira de arquivo / cabecalho: encerra hunk corrente.
        Save-CurrentHunk
        $currentAdded = $null
        $currentRemoved = $null
        continue
    }
    if ($null -eq $currentAdded) {
        continue
    }
    if ($line.StartsWith('+')) {
        [void]$currentAdded.Add($line.Substring(1))
    } elseif ($line.StartsWith('-')) {
        [void]$currentRemoved.Add($line.Substring(1))
    }
}
Save-CurrentHunk

# Pares (TokenIntroduzido, TokenPreExistente) por transicao co-localizada.
$pairKeys = [System.Collections.Generic.HashSet[string]]::new()
$pairs = [System.Collections.Generic.List[object]]::new()
$introducedTokens = [System.Collections.Generic.HashSet[string]]::new()

foreach ($hunk in $hunks) {
    $removedTokens = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($removedLine in @($hunk.Removed)) {
        foreach ($token in @(Get-LineTokens -Line $removedLine)) {
            [void]$removedTokens.Add($token)
        }
    }

    foreach ($addedLine in @($hunk.Added)) {
        $tokens = @(Get-LineTokens -Line $addedLine)
        if ($tokens.Count -lt 2) {
            continue
        }

        $introducedInLine = @($tokens | Where-Object { -not $removedTokens.Contains($_) })
        $preExistingInLine = @($tokens | Where-Object { $removedTokens.Contains($_) })
        if ($introducedInLine.Count -eq 0 -or $preExistingInLine.Count -eq 0) {
            continue
        }

        foreach ($newToken in $introducedInLine) {
            [void]$introducedTokens.Add($newToken)
            foreach ($oldToken in $preExistingInLine) {
                if ($newToken -eq $oldToken) {
                    continue
                }
                if (-not (Test-TokensRelated -A $newToken -B $oldToken)) {
                    continue
                }
                $key = '{0}|{1}' -f $newToken, $oldToken
                if ($pairKeys.Add($key)) {
                    $pairs.Add([pscustomobject][ordered]@{
                        newToken = $newToken
                        oldToken = $oldToken
                    })
                }
            }
        }
    }
}

$findings = [System.Collections.Generic.List[object]]::new()
$findingKeys = [System.Collections.Generic.HashSet[string]]::new()
$truncated = $false

if ($pairs.Count -gt 0) {
    $files = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @('.md', '.ps1', '.py') -and
            $_.FullName -notmatch '[\\/](\.git|historico)[\\/]'
        })

    foreach ($file in $files) {
        if ($truncated) { break }

        $fileLines = @()
        try {
            $fileLines = @([System.IO.File]::ReadAllLines($file.FullName))
        } catch {
            continue
        }

        $relPath = ([System.IO.Path]::GetRelativePath($resolvedRoot, $file.FullName) -replace '\\', '/')

        for ($i = 0; $i -lt $fileLines.Count; $i++) {
            if ($truncated) { break }
            $text = $fileLines[$i]

            foreach ($pair in $pairs) {
                # Mencao de contrato do token antigo (prosa/doc/-Param), nao $variavel.
                $oldMentionRx = Get-MentionRegex -Token $pair.oldToken
                if (-not $oldMentionRx.IsMatch($text)) {
                    continue
                }
                # Token novo presente em qualquer forma -> mencao ja propagada.
                $newRx = Get-WordRegex -Token $pair.newToken
                if ($newRx.IsMatch($text)) {
                    continue
                }
                # Declaracao do proprio parametro antigo (.PARAMETER P / bloco param).
                if (Test-IsOwnDeclarationLine -Token $pair.oldToken -Line $text) {
                    continue
                }

                $lineNumber = $i + 1
                $findingKey = '{0}:{1}:{2}|{3}' -f $relPath, $lineNumber, $pair.newToken, $pair.oldToken
                if (-not $findingKeys.Add($findingKey)) {
                    continue
                }

                if ($findings.Count -ge $MaxFindings) {
                    $truncated = $true
                    break
                }

                $findings.Add([pscustomobject][ordered]@{
                    code     = 'NEW_TOKEN_PROPAGATION_CANDIDATE'
                    severity = 'warn'
                    path     = ('{0}:{1}' -f $relPath, $lineNumber)
                    message  = ("termo '{0}' foi introduzido no diff junto de '{1}'; esta mencao tem '{1}' sem '{0}' — confirmar propagacao ou justificar a omissao" -f $pair.newToken, $pair.oldToken)
                })
            }
        }
    }
}

$status = if ($findings.Count -gt 0) { 'warn' } else { 'pass' }

$result = [ordered]@{
    status           = $status
    range            = $range
    introducedTokens = @($introducedTokens | Sort-Object)
    pairsConsidered  = @($pairs)
    candidateCount   = $findings.Count
    truncated        = $truncated
    findings         = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("STATUS={0}" -f $status)
    Write-Output ("RANGE={0}" -f $range)
    Write-Output ("INTRODUCED_TOKENS={0}" -f (@($introducedTokens | Sort-Object) -join ', '))
    Write-Output ("CANDIDATE_COUNT={0}" -f $findings.Count)
    foreach ($finding in @($findings)) {
        Write-Output ("NEW_TOKEN_PROPAGATION_CANDIDATE: {0}: {1}" -f $finding.path, $finding.message)
    }
    if ($truncated) {
        Write-Output 'CANDIDATES_TRUNCATED=true'
    }
}

exit 0
