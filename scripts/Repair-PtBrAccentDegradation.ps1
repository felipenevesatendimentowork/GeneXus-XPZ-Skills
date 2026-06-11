#requires -Version 7.4
<#
.SYNOPSIS
    Corrige a degradacao de acentuacao pt-BR INEQUIVOCA (palavras cuja forma sem
    acento nunca e lexema pt-BR valido) nos arquivos indicados, preservando caixa.

.DESCRIPTION
    Contraparte aplicadora do detector Measure-PtBrAccentDegradation.ps1. NAO toca
    em tokens ambiguos (esta/tem/vem/so/numero) nem na conjuncao 'e': esses exigem
    decisao humana e ficam de fora por construcao.

    Garantias de fidelidade ao detector:
    - Faz dot-source do detector para reaproveitar EXATAMENTE a mesma lista curada
      ($correctMap), o mesmo regex de inequivocas ($inequivRegex) e a mesma
      supressao de codigo (cercas ``` / ~~~ e code inline `...`).
    - A mascara de code inline e LENGTH-PRESERVING (cada span vira o mesmo numero de
      espacos), de modo que os offsets de match no texto mascarado batem 1:1 com o
      texto original; a substituicao ocorre sempre no texto original.
    - Preserva caixa: ALLCAPS -> ALLCAPS, Title -> Title, resto -> minuscula curada.
    - Preserva EOL exato (split com captura de '(\r?\n)') e grava UTF-8 sem BOM,
      conforme .gitattributes (*.md text eol=lf) e a regra do repositorio.

    Em .ps1 a deteccao do detector mede so comentarios; este aplicador, por seguranca,
    so opera arquivos .md (.ps1/.example.ps1 ficam fora deste passo).

.PARAMETER Files
    Caminhos (relativos a RepoRoot ou absolutos) dos .md a corrigir.
.PARAMETER RepoRoot
    Raiz do repositorio. Default: a pasta acima de scripts/.
.PARAMETER DryRun
    Nao grava nada; so reporta quantas substituicoes ocorreriam por arquivo.
.EXAMPLE
    pwsh -NoProfile -File scripts/Repair-PtBrAccentDegradation.ps1 -Files 02-regras-operacionais-e-runtime.md -DryRun
.EXAMPLE
    pwsh -NoProfile -File scripts/Repair-PtBrAccentDegradation.ps1 -Files 02-regras-operacionais-e-runtime.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string[]] $Files,
    [string] $RepoRoot,
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

# Dot-source o detector: define $correctMap, $inequivRegex, supressao e
# Get-Utf8NoBomEncoding (o detector retorna antes do main quando dot-sourced).
. (Join-Path $PSScriptRoot 'Measure-PtBrAccentDegradation.ps1')

# ---------------------------------------------------------------------------
# Preserva a caixa da forma encontrada ao aplicar a forma correta (minuscula).
# ---------------------------------------------------------------------------
function Get-CasedReplacement {
    param(
        [Parameter(Mandatory)] [string] $Found,
        [Parameter(Mandatory)] [string] $Correct
    )
    $upper = $Found.ToUpperInvariant()
    $lower = $Found.ToLowerInvariant()
    # ALLCAPS (tem ao menos uma letra com caixa): NAO -> NAO
    if (($Found -ceq $upper) -and ($Found -cne $lower)) {
        return $Correct.ToUpperInvariant()
    }
    # Title: primeira maiuscula, restante minusculo -> Padrao -> Padrao
    $first = $Found.Substring(0, 1)
    if ($Found.Length -gt 1) { $rest = $Found.Substring(1) } else { $rest = '' }
    if (($first -ceq $first.ToUpperInvariant()) -and ($first -cne $first.ToLowerInvariant()) `
            -and ($rest -ceq $rest.ToLowerInvariant())) {
        return $Correct.Substring(0, 1).ToUpperInvariant() + $Correct.Substring(1)
    }
    # default: forma curada (minuscula)
    return $Correct
}

# ---------------------------------------------------------------------------
# Corrige uma linha de markdown, respeitando cercas e code inline.
# Retorna [pscustomobject]{ Line; Count }.
# ---------------------------------------------------------------------------
function Repair-MarkdownLine {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Line,
        [Parameter(Mandatory)] [ref] $InFence
    )
    if ($Line -match '^\s*(```|~~~)') {
        $InFence.Value = -not $InFence.Value
        return [pscustomobject]@{ Line = $Line; Count = 0 }
    }
    if ($InFence.Value) {
        return [pscustomobject]@{ Line = $Line; Count = 0 }
    }

    # Mascara code inline preservando comprimento (offsets continuam batendo).
    $masked = [regex]::Replace($Line, '`[^`]*`', { param($m) ' ' * $m.Value.Length })
    $matches = @($inequivRegex.Matches($masked))
    if ($matches.Count -eq 0) {
        return [pscustomobject]@{ Line = $Line; Count = 0 }
    }

    $sb = [System.Text.StringBuilder]::new($Line)
    $n = 0
    # Da direita para a esquerda: preserva os offsets ainda nao processados.
    for ($k = $matches.Count - 1; $k -ge 0; $k--) {
        $m = $matches[$k]
        $found = $Line.Substring($m.Index, $m.Length)
        $correct = $correctMap[$found.ToLowerInvariant()]
        if ([string]::IsNullOrEmpty($correct)) { continue }
        $repl = Get-CasedReplacement -Found $found -Correct $correct
        [void]$sb.Remove($m.Index, $m.Length)
        [void]$sb.Insert($m.Index, $repl)
        $n++
    }
    return [pscustomobject]@{ Line = $sb.ToString(); Count = $n }
}

# ---------------------------------------------------------------------------
# Processa cada arquivo
# ---------------------------------------------------------------------------
$enc = Get-Utf8NoBomEncoding
$grandTotal = 0
foreach ($rel in $Files) {
    if ([System.IO.Path]::IsPathRooted($rel)) {
        $full = $rel
    } else {
        $full = Join-Path $RepoRoot $rel
    }
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Host "AUSENTE: $rel"
        continue
    }
    if ($full -notmatch '\.md$') {
        Write-Host "IGNORADO (nao .md): $rel"
        continue
    }

    $text = [System.IO.File]::ReadAllText($full)
    # Em arquivo trilingue, corrige SO a faixa pt-BR (ignora secoes ES/EN, onde
    # ha colisao com espanhol). Get-PtBrLineCount vem do detector dot-sourced.
    $ptBrEnd = Get-PtBrLineCount -Text $text
    # Split com captura: indices pares = conteudo de linha; impares = EOL.
    $parts = @([regex]::Split($text, '(\r?\n)'))
    $inFence = $false
    $fileCount = 0
    for ($i = 0; $i -lt $parts.Count; $i += 2) {
        $lineNo = ($i / 2) + 1
        if ($lineNo -gt $ptBrEnd) { continue }
        $res = Repair-MarkdownLine -Line $parts[$i] -InFence ([ref]$inFence)
        $parts[$i] = $res.Line
        $fileCount += $res.Count
    }
    $newText = -join $parts

    if ($DryRun) {
        Write-Host ("[dry-run] {0}: {1} substituicoes" -f ($rel -replace '\\', '/'), $fileCount)
    } else {
        if ($newText -ne $text) {
            [System.IO.File]::WriteAllText($full, $newText, $enc)
        }
        Write-Host ("{0}: {1} substituicoes" -f ($rel -replace '\\', '/'), $fileCount)
    }
    $grandTotal += $fileCount
}

Write-Host ''
$prefix = if ($DryRun) { '[dry-run] ' } else { '' }
Write-Host ("{0}TOTAL: {1} substituicoes inequivocas" -f $prefix, $grandTotal)
