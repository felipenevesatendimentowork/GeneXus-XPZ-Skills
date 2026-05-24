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
      INVENTORY_RECOMMENDED_MISSING: <lista> - wrappers recomendados ausentes por sinais objetivos
      INVENTORY_LEGACY_ORPHANS: <lista>    - scripts legados lado a lado com canonicos atuais
      INVENTORY_UNKNOWN: <motivo>         - nao foi possivel determinar o estado

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB.

.PARAMETER SkillsExamplesPath
    Caminho para a pasta examples/ do repositorio de skills XPZ
    (xpz-kb-parallel-setup/examples).

.OUTPUTS
    String: "INVENTORY_OK", "INVENTORY_GAPS: <nomes ausentes>",
    "INVENTORY_SHORT_NAMING: <nomes esperados>",
    "INVENTORY_CUSTOMIZED: <nomes e motivos>",
    "INVENTORY_LEGACY_ORPHANS: <canonico(legacy=antigo)>",
    "INVENTORY_RECOMMENDED_MISSING: <nomes recomendados>", ou
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

$scriptNames = @(Get-ChildItem -LiteralPath $scriptsPath -Filter '*.ps1' -Name | Sort-Object)

function Test-FrontHistory {
    param([string]$RootPath)

    $generatedPath = Join-Path $RootPath 'ObjetosGeradosParaImportacaoNaKbNoGenexus'
    if (-not (Test-Path -LiteralPath $generatedPath -PathType Container)) {
        return $false
    }

    $frontDirs = @(Get-ChildItem -LiteralPath $generatedPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'ArquivoMorto' })
    return $frontDirs.Count -gt 0
}

function Test-GeneratedLastUpdateHistory {
    param([string]$RootPath)

    $generatedPath = Join-Path $RootPath 'ObjetosGeradosParaImportacaoNaKbNoGenexus'
    if (-not (Test-Path -LiteralPath $generatedPath -PathType Container)) {
        return $false
    }

    foreach ($xmlFile in Get-ChildItem -LiteralPath $generatedPath -Recurse -File -Filter '*.xml' -ErrorAction SilentlyContinue) {
        $content = [System.IO.File]::ReadAllText($xmlFile.FullName)
        if ($content -match '\blastUpdate\b') {
            return $true
        }
    }

    return $false
}

function Test-ImportPackageHistory {
    param([string]$RootPath)

    $packagesPath = Join-Path $RootPath 'PacotesGeradosParaImportacaoNaKbNoGenexus'
    if (-not (Test-Path -LiteralPath $packagesPath -PathType Container)) {
        return $false
    }

    $packages = @(Get-ChildItem -LiteralPath $packagesPath -File -Filter '*.import_file.xml' -ErrorAction SilentlyContinue)
    return $packages.Count -gt 0
}

function Test-KbIdentityMetadata {
    param([string]$RootPath)

    $metadataPath = Join-Path $RootPath 'kb-source-metadata.md'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return $false
    }

    $metadataText = [System.IO.File]::ReadAllText($metadataPath)
    return $metadataText -match '(?i)(\bkb\s*\(GUID\)|\bsource_guid\b|\bUNCPath\b|\busername\b|\bversionGuid\b|\bVersion/guid\b)'
}

$recommendedEvidenceByBaseName = @{
    'New-KbFront' = (Test-FrontHistory -RootPath $KbParallelRoot)
    'Get-KbLastUpdate' = (Test-GeneratedLastUpdateHistory -RootPath $KbParallelRoot)
    'New-KbImportPackage' = (Test-ImportPackageHistory -RootPath $KbParallelRoot)
    'Resolve-KbIdentity' = (Test-KbIdentityMetadata -RootPath $KbParallelRoot)
}

# Mapear cada exemplo para o nome local esperado e verificar presenca
$absent      = [System.Collections.Generic.List[string]]::new()
$shortNaming = [System.Collections.Generic.List[string]]::new()
$customized  = [System.Collections.Generic.List[string]]::new()
$recommendedMissing = [System.Collections.Generic.List[string]]::new()
$legacyOrphans = [System.Collections.Generic.List[string]]::new()
$optionalBaseNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
[void]$optionalBaseNames.Add('New-KbImportPackage')
[void]$optionalBaseNames.Add('New-KbFront')
[void]$optionalBaseNames.Add('Get-KbLastUpdate')
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
        if ($shortExists) {
            $legacyOrphans.Add(('{0}(legacy={1})' -f $standardLocalName, $shortLocalName))
        }

        if ($standardLocalName -match '^([A-Za-z]+-)(' + [regex]::Escape($kbPrefix) + ')Kb(.+\.ps1)$') {
            $legacyLocalName = "$($Matches[1])$($Matches[2])$($Matches[3])"
            if ($scriptNames -contains $legacyLocalName) {
                $legacyOrphans.Add(('{0}(legacy={1})' -f $standardLocalName, $legacyLocalName))
            }
        }

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
        if ($recommendedEvidenceByBaseName.ContainsKey($baseName) -and $recommendedEvidenceByBaseName[$baseName]) {
            $recommendedMissing.Add($standardLocalName)
        }
    } else {
        $absent.Add($standardLocalName)
    }
}

$knownLegacyPairs = @(
    @{
        Canonical = ('Test-{0}KbFullSnapshot.ps1' -f $kbPrefix)
        Legacy = ('Test-{0}FullSnapshot.ps1' -f $kbPrefix)
    },
    @{
        Canonical = ('Update-{0}KbFromXpz.ps1' -f $kbPrefix)
        Legacy = ('Update-{0}FromXpz.ps1' -f $kbPrefix)
    },
    @{
        Canonical = ('Test-{0}KbIndexGate.ps1' -f $kbPrefix)
        Legacy = ('Test-{0}KbGate.ps1' -f $kbPrefix)
    }
)
foreach ($knownLegacyPair in $knownLegacyPairs) {
    if (($scriptNames -contains $knownLegacyPair.Canonical) -and ($scriptNames -contains $knownLegacyPair.Legacy)) {
        $entry = '{0}(legacy={1})' -f $knownLegacyPair.Canonical, $knownLegacyPair.Legacy
        if (-not $legacyOrphans.Contains($entry)) {
            $legacyOrphans.Add($entry)
        }
    }
}

$statusParts = [System.Collections.Generic.List[string]]::new()
if ($shortNaming.Count -gt 0) {
    $statusParts.Add("INVENTORY_SHORT_NAMING: $($shortNaming -join ', ')")
}
if ($customized.Count -gt 0) {
    $statusParts.Add("INVENTORY_CUSTOMIZED: $($customized -join ', ')")
}
if ($legacyOrphans.Count -gt 0) {
    $statusParts.Add("INVENTORY_LEGACY_ORPHANS: $($legacyOrphans -join ', ')")
}
if ($absent.Count -gt 0) {
    $statusParts.Add("INVENTORY_GAPS: $($absent -join ', ')")
}
if ($recommendedMissing.Count -gt 0) {
    $statusParts.Add("INVENTORY_RECOMMENDED_MISSING: $($recommendedMissing -join ', ')")
}

if ($statusParts.Count -eq 0) {
    Write-Output 'INVENTORY_OK'
} else {
    Write-Output ($statusParts -join ' | ')
}
exit 0
