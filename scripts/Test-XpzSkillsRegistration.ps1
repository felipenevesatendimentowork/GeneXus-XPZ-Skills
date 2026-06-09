#requires -Version 7.4

<#
.SYNOPSIS
    Auditoria deterministica do registro global das skills XPZ nas ferramentas de
    agente instaladas, mais o freshness do MCP global do Cursor.

.DESCRIPTION
    Mecaniza os passos de inventario, deteccao de instalacao e classificacao do
    WORKFLOW de xpz-skills-setup. NAO cria nem remove vinculos: apenas audita e
    classifica. As acoes de resolucao continuam a cargo do agente, apos confirmacao
    explicita do usuario.

    Classificacao por skill x ferramenta instalada:
      OK                          vinculo valido em diretorio nativo da ferramenta
      coberta_por_compatibilidade vinculo valido apenas em diretorio lido por compat
      ausente                     nenhum vinculo valido encontrado
      quebrada                    vinculo presente, mas alvo inexistente

    Regras especiais (espelham xpz-skills-setup/SKILL.md):
      - Codex indexa DOIS ambitos USER (.codex/skills e .agents/skills); presenca
        em qualquer um conta como OK.
      - OpenCode exige vinculo nativo (.config/opencode/skills ou .agents/skills);
        nao conta compatibilidade com .claude/skills.
      - Cursor le por compatibilidade de .claude/skills e .codex/skills.

    Orfas: vinculos sob um diretorio de skills cujo alvo aponta para DENTRO do
    repositorio de skills XPZ, mas cujo nome nao esta mais no inventario da raiz.
    Vinculos para outros repositorios (ex.: nexa) ficam fora de escopo.

    Freshness do MCP do Cursor (Candidato B): compara o server.py instalado com o
    canonico do repositorio e valida config.json/registro em mcp.json.

.OUTPUTS
    Texto legivel por padrao; objeto JSON com -AsJson. Campos "overall" e os
    "label" sao destinados a interpretacao por agente.
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,

    [ValidateSet('compacta', 'expansiva')]
    [string]$Strategy = 'compacta',

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -Name XpzNativeLong -Namespace Xpz -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern uint GetLongPathName(string lpszShortPath, System.Text.StringBuilder lpszLongPath, uint cchBuffer);
'@ -ErrorAction SilentlyContinue | Out-Null

function ConvertTo-LongPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    try {
        $sb = New-Object System.Text.StringBuilder 1024
        $n = [Xpz.XpzNativeLong]::GetLongPathName($Path, $sb, [uint32]1024)
        if ($n -gt 0 -and $n -lt 1024) { return $sb.ToString() }
    }
    catch { }
    return $Path
}

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

function Get-ProfileRoot {
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        throw 'BLOCK: USERPROFILE nao definido.'
    }
    return $env:USERPROFILE
}

function Test-ToolInstalled {
    param([string]$Tool)
    $profileRoot = Get-ProfileRoot
    switch ($Tool) {
        'ClaudeCode' {
            if (Get-Command claude -ErrorAction SilentlyContinue) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.claude\settings.json') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.claude\CLAUDE.md') -PathType Leaf) { return $true }
            return $false
        }
        'Codex' {
            if (Get-Command codex -ErrorAction SilentlyContinue) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.codex\config.toml') -PathType Leaf) { return $true }
            return $false
        }
        'Cursor' {
            if (Get-Command cursor -ErrorAction SilentlyContinue) { return $true }
            $cursorRoot = Join-Path $profileRoot '.cursor'
            if (-not (Test-Path -LiteralPath $cursorRoot -PathType Container)) { return $false }
            foreach ($name in @('mcp.json', 'skills-cursor', 'rules')) {
                if (Test-Path -LiteralPath (Join-Path $cursorRoot $name)) { return $true }
            }
            return $false
        }
        'OpenCode' {
            if (Get-Command opencode -ErrorAction SilentlyContinue) { return $true }
            $configDir = Join-Path $profileRoot '.config\opencode'
            if (Test-Path -LiteralPath (Join-Path $configDir 'opencode.json') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $configDir 'opencode.jsonc') -PathType Leaf) { return $true }
            return $false
        }
    }
    return $false
}

function Get-LinkTarget {
    param([System.IO.FileSystemInfo]$Item)
    $target = $Item.Target
    if ($null -eq $target) { return '' }
    $arr = @($target)
    if ($arr.Count -eq 0) { return '' }
    return [string]$arr[0]
}

function Get-EntryInfo {
    param([string]$DirPath, [string]$Name)

    $full = Join-Path $DirPath $Name
    $info = [ordered]@{
        present     = $false
        linkType    = ''
        target      = ''
        targetValid = $false
    }
    if (-not (Test-Path -LiteralPath $full)) { return $info }

    $info.present = $true
    $item = Get-Item -LiteralPath $full -Force
    if ($item.LinkType) {
        $info.linkType = [string]$item.LinkType
        $info.target = Get-LinkTarget -Item $item
        $info.targetValid = (-not [string]::IsNullOrWhiteSpace($info.target)) -and (Test-Path -LiteralPath $info.target)
    }
    else {
        # Pasta/arquivo real (nao e link). Conta como presente e valido.
        $info.linkType = 'Directory'
        $info.target = $full
        $info.targetValid = $true
    }
    return $info
}

# --- Setup --------------------------------------------------------------------
$root = Resolve-RepoRoot -Requested $RepoRoot
$profileRoot = Get-ProfileRoot

# Inventario: subpastas da raiz que contem SKILL.md
$inventory = @(
    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf } |
        ForEach-Object { $_.Name } | Sort-Object
)
$inventorySet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($s in $inventory) { [void]$inventorySet.Add($s) }

# Mapa de diretorios por ferramenta (nativo + compatibilidade)
$toolDefs = @(
    [ordered]@{ Name = 'ClaudeCode'; Native = @('.claude\skills'); Compat = @() },
    [ordered]@{ Name = 'Codex'; Native = @('.codex\skills', '.agents\skills'); Compat = @() },
    [ordered]@{ Name = 'Cursor'; Native = @('.cursor\skills', '.agents\skills'); Compat = @('.claude\skills', '.codex\skills') },
    [ordered]@{ Name = 'OpenCode'; Native = @('.config\opencode\skills', '.agents\skills'); Compat = @() }
)

$toolsReport = @()
$sumOk = 0; $sumMissing = 0; $sumBroken = 0; $sumCompat = 0

foreach ($def in $toolDefs) {
    $installed = Test-ToolInstalled -Tool $def.Name
    $skillsStatus = @()

    if ($installed) {
        foreach ($skill in $inventory) {
            $status = 'ausente'; $linkType = ''; $target = ''

            foreach ($rel in $def.Native) {
                $dir = Join-Path $profileRoot $rel
                $entry = Get-EntryInfo -DirPath $dir -Name $skill
                if ($entry.present) {
                    if ($entry.targetValid) { $status = 'OK'; $linkType = $entry.linkType; $target = $entry.target; break }
                    else { $status = 'quebrada'; $linkType = $entry.linkType; $target = $entry.target }
                }
            }

            if ($status -eq 'ausente') {
                foreach ($rel in $def.Compat) {
                    $dir = Join-Path $profileRoot $rel
                    $entry = Get-EntryInfo -DirPath $dir -Name $skill
                    if ($entry.present -and $entry.targetValid) {
                        $status = 'coberta_por_compatibilidade'; $linkType = $entry.linkType; $target = $entry.target; break
                    }
                }
            }

            switch ($status) {
                'OK' { $sumOk++ }
                'coberta_por_compatibilidade' { $sumCompat++ }
                'quebrada' { $sumBroken++ }
                'ausente' { $sumMissing++ }
            }

            $skillsStatus += [ordered]@{ name = $skill; status = $status; linkType = $linkType; target = $target }
        }
    }

    $toolsReport += [ordered]@{
        name      = $def.Name
        installed = $installed
        native    = @($def.Native | ForEach-Object { Join-Path $profileRoot $_ })
        compat    = @($def.Compat | ForEach-Object { Join-Path $profileRoot $_ })
        skills    = $skillsStatus
    }
}

# Orfas: varrer cada diretorio de skills conhecido uma unica vez
$rootNorm = (ConvertTo-LongPath -Path $root).TrimEnd('\').ToLowerInvariant()
$allDirs = [System.Collections.Generic.List[string]]::new()
foreach ($rel in @('.claude\skills', '.codex\skills', '.agents\skills', '.cursor\skills', '.config\opencode\skills')) {
    [void]$allDirs.Add((Join-Path $profileRoot $rel))
}
$orphans = @()
foreach ($dir in $allDirs) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
    foreach ($child in (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
        if ($inventorySet.Contains($child.Name)) { continue }
        $childItem = Get-Item -LiteralPath $child.FullName -Force -ErrorAction SilentlyContinue
        if ($null -eq $childItem) { continue }
        $tgt = Get-LinkTarget -Item $childItem
        if ([string]::IsNullOrWhiteSpace($tgt)) { continue }
        # Normaliza o alvo para caminho longo (expande short names 8.3) antes de comparar.
        $tgtResolved = (ConvertTo-LongPath -Path $tgt).TrimEnd('\').ToLowerInvariant()
        if ($tgtResolved.StartsWith($rootNorm)) {
            $orphans += [ordered]@{ dir = $dir; name = $child.Name; target = $tgt }
        }
    }
}

# --- Freshness do MCP do Cursor (Candidato B) ---------------------------------
function Get-CursorMcpReport {
    param([string]$ProfileRoot, [string]$RepoRoot)

    $report = [ordered]@{
        label              = 'MCP_NOT_INSTALLED'
        serverHashMatches  = $false
        agentsPath         = ''
        agentsPathValid    = $false
        registeredInMcpJson = $false
    }

    $mcpDir = Join-Path $ProfileRoot '.cursor\xpz-global-instructions-mcp'
    $installedServer = Join-Path $mcpDir 'server.py'
    $configPath = Join-Path $mcpDir 'config.json'
    $mcpJsonPath = Join-Path $ProfileRoot '.cursor\mcp.json'
    $repoServer = Join-Path $RepoRoot 'scripts\cursor-global-instructions-mcp\server.py'

    if (-not (Test-Path -LiteralPath $installedServer -PathType Leaf)) {
        return $report
    }

    # registro em mcp.json
    if (Test-Path -LiteralPath $mcpJsonPath -PathType Leaf) {
        try {
            $mcpJson = Get-Content -LiteralPath $mcpJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $mcpJson.mcpServers -and
                $null -ne $mcpJson.mcpServers.PSObject.Properties['xpz-global-instructions']) {
                $report.registeredInMcpJson = $true
            }
        }
        catch { }
    }

    # agentsPath
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try {
            $cfg = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $cfg.agentsPath -and -not [string]::IsNullOrWhiteSpace([string]$cfg.agentsPath)) {
                $report.agentsPath = [string]$cfg.agentsPath
                $report.agentsPathValid = Test-Path -LiteralPath $report.agentsPath -PathType Leaf
            }
        }
        catch { }
    }

    # hash do server
    if (Test-Path -LiteralPath $repoServer -PathType Leaf) {
        $installedHash = (Get-FileHash -LiteralPath $installedServer).Hash
        $repoHash = (Get-FileHash -LiteralPath $repoServer).Hash
        $report.serverHashMatches = ($installedHash -eq $repoHash)
    }

    if (-not $report.registeredInMcpJson -or -not $report.agentsPathValid) {
        $report.label = 'MCP_CONFIG_INVALID'
    }
    elseif (-not $report.serverHashMatches) {
        $report.label = 'MCP_SERVER_STALE'
    }
    else {
        $report.label = 'MCP_OK'
    }
    return $report
}

$cursorMcp = Get-CursorMcpReport -ProfileRoot $profileRoot -RepoRoot $root

# --- Veredito -----------------------------------------------------------------
$mcpIsGap = @('MCP_SERVER_STALE', 'MCP_CONFIG_INVALID') -contains $cursorMcp.label
$hasGaps = ($sumMissing -gt 0) -or ($sumBroken -gt 0) -or (@($orphans).Count -gt 0) -or $mcpIsGap
if ($hasGaps) { $overall = 'REGISTRATION_GAPS' } else { $overall = 'REGISTRATION_OK' }

$result = [ordered]@{
    overall         = $overall
    repoRoot        = $root
    strategy        = $Strategy
    skillsInventory = @($inventory)
    tools           = $toolsReport
    orphans         = @($orphans)
    cursorMcp       = $cursorMcp
    summary         = [ordered]@{
        ok              = $sumOk
        coveredByCompat = $sumCompat
        missing         = $sumMissing
        broken          = $sumBroken
        orphans         = @($orphans).Count
        cursorMcp       = $cursorMcp.label
    }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8 | Write-Output
    return
}

# Saida legivel
Write-Output ("OVERALL: {0}" -f $overall)
Write-Output ("Repo: {0}" -f $root)
Write-Output ("Inventario: {0} skills | Estrategia: {1}" -f @($inventory).Count, $Strategy)
Write-Output ''
foreach ($t in $toolsReport) {
    if (-not $t.installed) {
        Write-Output ("[{0}] nao instalada" -f $t.name)
        continue
    }
    Write-Output ("[{0}] instalada" -f $t.name)
    foreach ($s in $t.skills) {
        if ($s.status -ne 'OK') {
            Write-Output ("    {0,-28} {1}" -f $s.name, $s.status)
        }
    }
    $okCount = @($t.skills | Where-Object { $_.status -eq 'OK' }).Count
    Write-Output ("    ({0} OK; demais listadas acima, se houver)" -f $okCount)
}
Write-Output ''
if (@($orphans).Count -gt 0) {
    Write-Output 'Orfas (vinculo para o repo sem skill correspondente):'
    foreach ($o in $orphans) { Write-Output ("    {0}  ->  {1}" -f $o.name, $o.target) }
}
else {
    Write-Output 'Orfas: nenhuma'
}
Write-Output ("MCP Cursor: {0} (server atualizado={1}; registrado={2}; agentsPath valido={3})" -f `
        $cursorMcp.label, $cursorMcp.serverHashMatches, $cursorMcp.registeredInMcpJson, $cursorMcp.agentsPathValid)
Write-Output ''
Write-Output ("Resumo: OK={0} compat={1} ausentes={2} quebradas={3} orfas={4}" -f `
        $sumOk, $sumCompat, $sumMissing, $sumBroken, @($orphans).Count)
