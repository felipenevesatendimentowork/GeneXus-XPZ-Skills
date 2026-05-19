#requires -Version 7.4
<#
.SYNOPSIS
    Compara os wrappers locais da pasta paralela com os exemplos canonicos do repositorio de skills.

.DESCRIPTION
    Infere o prefixo KB a partir dos scripts presentes em scripts/, enumera os exemplos
    em SkillsExamplesPath (*.example.ps1) e verifica se cada wrapper esperado existe
    localmente. Quando a inferencia falha por scripts usarem naming curto (sem prefixo KB),
    tenta obter o nome da KB em kb-source-metadata.md e detecta se os scripts existem no
    padrao curto em vez do padrao canonico. Retorna:
      INVENTORY_OK                        - todos os wrappers canonicos presentes com naming padrao
      INVENTORY_GAPS: <nomes ausentes>    - wrappers ausentes (nem padrao nem curto encontrado)
      INVENTORY_SHORT_NAMING: <lista>     - wrappers existem no padrao curto; renomear para padrao
      INVENTORY_CUSTOMIZED: <lista>        - wrappers presentes com divergencia metodologica objetiva
      INVENTORY_UNKNOWN: <motivo>         - nao foi possivel determinar o estado

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB.

.PARAMETER SkillsExamplesPath
    Caminho para a pasta examples/ do repositorio de skills XPZ
    (xpz-kb-parallel-setup/examples).

.OUTPUTS
    String: "INVENTORY_OK", "INVENTORY_GAPS: <nomes ausentes>",
    "INVENTORY_SHORT_NAMING: <nomes esperados>",
    "INVENTORY_CUSTOMIZED: <nomes e motivos>", ou
    "INVENTORY_UNKNOWN: <motivo>"

.EXAMPLE
    .\Test-XpzWrapperInventory.ps1 `
        -KbParallelRoot "C:\DevTests\Gx_MyCinema" `
        -SkillsExamplesPath "C:\Dev\Knowledge\GeneXus-XPZ-Skills\xpz-kb-parallel-setup\examples"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbParallelRoot,

    [Parameter(Mandatory = $true)]
    [string]$SkillsExamplesPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsPath = Join-Path $KbParallelRoot 'scripts'

function Get-RequiresVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $pattern = '^\s*#requires\s+-version\s+(?<version>\d+(\.\d+)*)\b'
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $match = [regex]::Match($line, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            return $match.Groups['version'].Value
        }

        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0) {
            continue
        }
        if ($trimmed.StartsWith('#')) {
            continue
        }
        if ($trimmed -eq '<#') {
            continue
        }

        break
    }

    return $null
}

if (-not (Test-Path -LiteralPath $scriptsPath -PathType Container)) {
    Write-Output "INVENTORY_UNKNOWN: pasta scripts nao encontrada em $KbParallelRoot"
    exit 0
}

if (-not (Test-Path -LiteralPath $SkillsExamplesPath -PathType Container)) {
    Write-Output "INVENTORY_UNKNOWN: pasta examples nao encontrada em $SkillsExamplesPath"
    exit 0
}

# Inferir prefixo KB a partir dos scripts existentes (ex: Test-MyCinemaKbIndexGate.ps1 -> MyCinema)
$kbPrefix = $null
foreach ($f in Get-ChildItem -LiteralPath $scriptsPath -Filter '*.ps1' -Name | Sort-Object) {
    if ($f -match '^[A-Za-z]+-([A-Za-z0-9]+)Kb[A-Za-z]') {
        $kbPrefix = $Matches[1]
        break
    }
}

# Quando a inferencia falha, tentar obter o nome da KB em kb-source-metadata.md
if ([string]::IsNullOrWhiteSpace($kbPrefix)) {
    $metadataPath = Join-Path $KbParallelRoot 'kb-source-metadata.md'
    if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        $inSourceVersion = $false
        foreach ($line in [System.IO.File]::ReadAllLines($metadataPath)) {
            if ($line -match '^\s*kb_name\s*[:=]\s*(?<value>\S+)') {
                $candidate = $Matches['value'].Trim()
                if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                    $kbPrefix = $candidate; break
                }
            }
            if ($line -match '^\s*##\s+Source/Version') { $inSourceVersion = $true; continue }
            if ($inSourceVersion -and $line -match '^\s*##\s') { $inSourceVersion = $false }
            if ($inSourceVersion -and $line -match '^\s*\|\s*name\s*\|\s*(?<value>[^|]+)\|') {
                $candidate = $Matches['value'].Trim()
                if (-not [string]::IsNullOrWhiteSpace($candidate) -and $candidate -notmatch '^[-\s]+$') {
                    $kbPrefix = $candidate; break
                }
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($kbPrefix)) {
    Write-Output 'INVENTORY_UNKNOWN: nao foi possivel inferir o prefixo KB a partir dos scripts nem de kb-source-metadata.md'
    exit 0
}

# Mapear cada exemplo para o nome local esperado e verificar presenca
$absent      = [System.Collections.Generic.List[string]]::new()
$shortNaming = [System.Collections.Generic.List[string]]::new()
$customized  = [System.Collections.Generic.List[string]]::new()
$optionalBaseNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
[void]$optionalBaseNames.Add('New-KbImportPackage')
[void]$optionalBaseNames.Add('Notify-TaskComplete')
[void]$optionalBaseNames.Add('Resolve-KbIdentity')
$requiresVersionExemptBaseNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
[void]$requiresVersionExemptBaseNames.Add('Test-KbPowerShellRuntime')

foreach ($exampleFile in Get-ChildItem -LiteralPath $SkillsExamplesPath -Filter '*.example.ps1' -Name | Sort-Object) {
    $baseName = $exampleFile -replace '\.example\.ps1$', ''

    if ($baseName -match '^([A-Za-z]+-)(Kb.+)$') {
        $standardLocalName = "$($Matches[1])${kbPrefix}$($Matches[2]).ps1"
        $shortLocalName    = "$baseName.ps1"
    } else {
        $standardLocalName = "$baseName.ps1"
        $shortLocalName    = $null
    }

    $standardPath   = Join-Path $scriptsPath $standardLocalName
    $examplePath    = Join-Path $SkillsExamplesPath $exampleFile
    $standardExists = Test-Path -LiteralPath $standardPath -PathType Leaf
    $shortExists    = $shortLocalName -and (Test-Path -LiteralPath (Join-Path $scriptsPath $shortLocalName) -PathType Leaf)

    if ($standardExists) {
        if (-not $requiresVersionExemptBaseNames.Contains($baseName)) {
            $canonicalRequiresVersion = Get-RequiresVersion -Path $examplePath
            $localRequiresVersion = Get-RequiresVersion -Path $standardPath
            if ($canonicalRequiresVersion -and $localRequiresVersion -ne $canonicalRequiresVersion) {
                $localLabel = if ($localRequiresVersion) { $localRequiresVersion } else { 'ausente' }
                $customized.Add(('{0}(reason=requires_version_mismatch: local={1} canonical={2})' -f $standardLocalName, $localLabel, $canonicalRequiresVersion))
            }
        }
    } elseif ($shortExists) {
        $shortNaming.Add($standardLocalName)
    } elseif ($optionalBaseNames.Contains($baseName)) {
        # Wrapper recomendado, mas ainda nao obrigatorio no inventario canonico.
    } else {
        $absent.Add($standardLocalName)
    }
}

$statusParts = [System.Collections.Generic.List[string]]::new()
if ($shortNaming.Count -gt 0) {
    $statusParts.Add("INVENTORY_SHORT_NAMING: $($shortNaming -join ', ')")
}
if ($customized.Count -gt 0) {
    $statusParts.Add("INVENTORY_CUSTOMIZED: $($customized -join ', ')")
}
if ($absent.Count -gt 0) {
    $statusParts.Add("INVENTORY_GAPS: $($absent -join ', ')")
}

if ($statusParts.Count -eq 0) {
    Write-Output 'INVENTORY_OK'
} else {
    Write-Output ($statusParts -join ' | ')
}
exit 0
