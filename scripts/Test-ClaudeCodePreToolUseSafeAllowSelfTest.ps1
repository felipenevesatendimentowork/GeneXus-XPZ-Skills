# Test-ClaudeCodePreToolUseSafeAllowSelfTest.ps1 - gate do hook PreToolUse do CLAUDE CODE (auto-allow).
# Corpus adversarial (deve -> defer) + happy-path (deve -> allow) + escopo.
# Token de sucesso: "OK: Test-ClaudeCodePreToolUseSafeAllowSelfTest.ps1". Exit 1 em falha.
# Ver claude-code-pretooluse-auto-allow-design.md (secao 4).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
. (Join-Path $here 'ClaudeCodePreToolUseSafeAllowSupport.ps1')

$python = $null
$cmd = Get-Command -Name python -ErrorAction SilentlyContinue
if ($cmd) { $python = $cmd.Source }
if (-not $python) {
    $cmd = Get-Command -Name python3 -ErrorAction SilentlyContinue
    if ($cmd) { $python = $cmd.Source }
}
if (-not $python) { Write-Host 'SKIP/FAIL: python nao encontrado (caminho Bash exige shlex)'; exit 1 }

$helper = Join-Path $here 'Get-ClaudeCodeBashSafeSegments.py'
$repo = Split-Path -Parent $here
$roots = @($repo)
$cwd = $repo

$cases = @(
    # --- happy-path: deve ALLOW ---
    @{ tool = 'Bash'; cmd = 'git status'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git log'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git log --oneline -5'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git log | head'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git log | head -20'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git diff'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git show HEAD'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git rev-parse HEAD'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git branch'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git branch --show-current'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git branch -a'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'git -C somerepo status'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'cat file.txt'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'wc -l file.txt'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'ls'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'rg foo'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'rg -n foo file'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'rg "foo bar" file'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'date'; exp = 'allow' },
    @{ tool = 'Bash'; cmd = 'date +%Y'; exp = 'allow' },

    # --- adversarial: deve DEFER ---
    @{ tool = 'Bash'; cmd = 'git log --output=foo'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'git -c core.pager=x log'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'git --exec-path=/tmp status'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'git diff --ext-diff'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'git branch topic'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'rg --pre payload x'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'pwsh -nop -c whoami'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'bash -c "git status"'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'git show HEAD:path > out'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'cat a | xargs rm'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'git log ; rm -rf x'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'FOO=bar git log'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'tail -F x'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'tail -f x'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'head -c 9 > out'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'git log $(whoami)'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'echo `whoami`'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'date 010203'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = "git status`ngit log"; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'git commit -m x'; exp = 'defer' },
    @{ tool = 'Bash'; cmd = 'rm -rf x'; exp = 'defer' },

    # --- PowerShell: defer na v1 (campo de input nao confirmado) ---
    @{ tool = 'PowerShell'; cmd = 'Get-ChildItem'; exp = 'defer' },
    @{ tool = 'PowerShell'; cmd = 'Get-Content x'; exp = 'defer' },

    # --- ferramenta desconhecida: defer ---
    @{ tool = 'Edit'; cmd = 'whatever'; exp = 'defer' }
)

$fail = 0
foreach ($c in $cases) {
    $got = Get-PtuDecision -ToolName $c.tool -Command $c.cmd -Cwd $cwd -Roots $roots -PythonExe $python -HelperPath $helper
    if ($got -ne $c.exp) {
        Write-Host "FAIL: [$($c.tool)] '$($c.cmd)' esperado=$($c.exp) obtido=$got"
        $fail++
    }
}

# Fast-path: 'defer' barato vs 'escalate'; invariante "nunca allow"; defer sem python.
$fpDefer = Get-PtuBashFastPath -Command 'rm -rf x'
if ($fpDefer -ne 'defer') { Write-Host "FAIL: fast-path 'rm' esperado=defer obtido=$fpDefer"; $fail++ }
$fpAssign = Get-PtuBashFastPath -Command 'FOO=bar git log'
if ($fpAssign -ne 'defer') { Write-Host "FAIL: fast-path assign esperado=defer obtido=$fpAssign"; $fail++ }
$fpEsc = Get-PtuBashFastPath -Command 'git log | head'
if ($fpEsc -ne 'escalate') { Write-Host "FAIL: fast-path 'git' esperado=escalate obtido=$fpEsc"; $fail++ }
$fpNewline = Get-PtuBashFastPath -Command "git status`ngit log"
if ($fpNewline -ne 'defer') { Write-Host "FAIL: fast-path newline esperado=defer obtido=$fpNewline"; $fail++ }
foreach ($probe in @('git log', 'rm -rf x', 'cat a', 'npm i', '', '| x', '$(rm) x')) {
    $r = Get-PtuBashFastPath -Command $probe
    if ($r -eq 'allow') { Write-Host "FAIL: fast-path retornou allow para '$probe'"; $fail++ }
}
# Prova de que o caminho comum nao precisa de python: 'rm' defere mesmo com python invalido.
$fpNoPy = Get-PtuDecision -ToolName 'Bash' -Command 'rm -rf x' -Cwd $cwd -Roots $roots -PythonExe 'C:\nao-existe-python.exe' -HelperPath $helper
if ($fpNoPy -ne 'defer') { Write-Host "FAIL: fast-path defer sem python esperado=defer obtido=$fpNoPy"; $fail++ }

# Escopo: cwd fora das raizes -> defer mesmo para comando happy.
$gotScope = Get-PtuDecision -ToolName 'Bash' -Command 'git status' -Cwd 'C:\Temp\fora' -Roots $roots -PythonExe $python -HelperPath $helper
if ($gotScope -ne 'defer') { Write-Host "FAIL: escopo fora-da-raiz esperado=defer obtido=$gotScope"; $fail++ }

# Escopo: subpasta da raiz -> em escopo.
$gotSub = Get-PtuDecision -ToolName 'Bash' -Command 'git status' -Cwd (Join-Path $repo 'scripts') -Roots $roots -PythonExe $python -HelperPath $helper
if ($gotSub -ne 'allow') { Write-Host "FAIL: escopo subpasta esperado=allow obtido=$gotSub"; $fail++ }

if ($fail -eq 0) {
    Write-Host 'OK: Test-ClaudeCodePreToolUseSafeAllowSelfTest.ps1'
}
else {
    Write-Host "FAILED: $fail caso(s)"
    exit 1
}
