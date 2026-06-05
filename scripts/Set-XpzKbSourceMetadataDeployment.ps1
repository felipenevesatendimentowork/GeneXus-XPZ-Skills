#requires -Version 7.4
<#
.SYNOPSIS
    Grava campos de environment/deploy em kb-source-metadata.md (autoridade: xpz-kb-parallel-setup).

.DESCRIPTION
    Atualiza ou insere deployment_environment_name, deployment_hosting_kind,
    kb_environment_count, kb_environment_names e o mapeamento de output/web por environment
    no frontmatter, preservando o restante do arquivo.

    A lista kb_environment_names vem SOMENTE de -KbEnvironmentNames declarado pelo usuario
    (ou agente apos confirmacao explicita). Scan de pastas da KB nativa e inventario automatico
    foram removidos.

    O mapeamento kb_environment_output_dirs vem SOMENTE de -KbEnvironmentOutputDirs declarado
    pelo usuario. kb_environment_web_dirs pode ser informado explicitamente ou derivado de
    -KbNativePath + output dir + web, sem varrer a KB nativa.

    Por padrao valida cada nome informado via SetActiveEnvironment headless (MSBuild).
    Use -SkipEnvironmentNamesMsBuildValidation apenas quando a sondagem MSBuild estiver
    indisponivel por infraestrutura (GeneXus/MSBuild/KB headless inacessivel nesta sessao).

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB.

.PARAMETER MetadataPath
    Caminho explicito para kb-source-metadata.md (prevalece sobre KbParallelRoot).

.PARAMETER DeploymentEnvironmentName
    Identificador MSBuild do environment de validacao/deploy (ex.: NETPostgreSQL).

.PARAMETER DeploymentHostingKind
    Tipo de hospedagem do environment de deploy: dotnet-core-self-host ou dotnet-framework-iis.

.PARAMETER KbEnvironmentNames
    Lista explicita de environments GeneXus (nomes exatos como na IDE / SetActiveEnvironment).

.PARAMETER KbEnvironmentOutputDirs
    Mapeamento explicito Environment=DiretorioOutput para cada environment declarado
    (ex.: NETPostgreSQL=NETPostgreSQL). Nao usar scan de pastas da KB nativa.

.PARAMETER KbEnvironmentWebDirs
    Mapeamento opcional Environment=CaminhoWeb para cada environment declarado. Quando omitido,
    e derivado de -KbNativePath + DiretorioOutput + web.

.PARAMETER KbNativePath
    Caminho da KB nativa GeneXus. Obrigatorio salvo -SkipEnvironmentNamesMsBuildValidation.

.PARAMETER InventoryWorkingDirectory
    Diretorio de trabalho para validacao MSBuild. Obrigatorio salvo -SkipEnvironmentNamesMsBuildValidation.

.PARAMETER InventoryLogPath
    Log JSON opcional da sondagem MSBuild de validacao.

.PARAMETER SkipEnvironmentNamesMsBuildValidation
    Pula validacao SetActiveEnvironment quando a sondagem MSBuild estiver indisponivel.
    Deve ser excecao documentada no handoff; nao usar para contornar nome rejeitado pelo GeneXus.

.PARAMETER InventoryFromGeneXusMsBuild
    REMOVIDO — emite BLOCK (inventario automatico por pastas da KB nativa).

.PARAMETER InventoryFromKbNativePath
    REMOVIDO — emite BLOCK (heuristica web\ incluia CSharpModel, Data* e pastas legadas).

.PARAMETER GeneXusDir
    Instalacao GeneXus (opcional — resolvida pela sondagem).

.PARAMETER MsBuildPath
    Caminho do MSBuild.exe (opcional — resolvido pela sondagem).

.PARAMETER DatabaseUser
    Usuario de banco para abertura headless da validacao (opcional).

.PARAMETER DatabasePassword
    Senha de banco para abertura headless da validacao (opcional).

.PARAMETER AsJson
    Emite JSON em vez de texto simples.
#>

[CmdletBinding()]
param(
    [string]$KbParallelRoot,

    [string]$MetadataPath,

    [Parameter(Mandatory = $true)]
    [string]$DeploymentEnvironmentName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('dotnet-core-self-host', 'dotnet-framework-iis')]
    [string]$DeploymentHostingKind,

    [Parameter(Mandatory = $true)]
    [string[]]$KbEnvironmentNames,

    [Parameter(Mandatory = $true)]
    [string[]]$KbEnvironmentOutputDirs,

    [string[]]$KbEnvironmentWebDirs,

    [string]$KbNativePath,

    [string]$InventoryWorkingDirectory,

    [string]$InventoryLogPath,

    [switch]$SkipEnvironmentNamesMsBuildValidation,

    [switch]$InventoryFromGeneXusMsBuild,

    [switch]$InventoryFromKbNativePath,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string]$DatabaseUser,

    [string]$DatabasePassword,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbDeploymentEnvironmentSupport.ps1')

if ($InventoryFromKbNativePath.IsPresent) {
    throw @'
BLOCK: -InventoryFromKbNativePath foi removido. Pastas com web\ na KB nativa incluem legado (CSharpModel, Data*, backups de environment) e nao representam a lista operacional de environments. Informe -KbEnvironmentNames explicito (confirmado pelo usuario) e valide via MSBuild.
'@
}

if ($InventoryFromGeneXusMsBuild.IsPresent) {
    throw @'
BLOCK: -InventoryFromGeneXusMsBuild foi removido. Inventario automatico por pastas da KB nativa superestima environments (restos _bad, hotfix, etc.). Informe -KbEnvironmentNames explicito (confirmado pelo usuario) e valide cada nome via SetActiveEnvironment headless.
'@
}

if ([string]::IsNullOrWhiteSpace($MetadataPath)) {
    if ([string]::IsNullOrWhiteSpace($KbParallelRoot)) {
        throw 'BLOCK: informe -KbParallelRoot ou -MetadataPath.'
    }
    $MetadataPath = Join-Path $KbParallelRoot 'kb-source-metadata.md'
}

$MetadataPath = [System.IO.Path]::GetFullPath($MetadataPath)

if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
    throw "BLOCK: kb-source-metadata.md ausente: $MetadataPath"
}

$deploymentName = $DeploymentEnvironmentName.Trim()
if ($deploymentName.Length -eq 0) {
    throw 'BLOCK: DeploymentEnvironmentName vazio.'
}

$hostingKind = $DeploymentHostingKind.Trim()
if ($hostingKind.Length -eq 0) {
    throw 'BLOCK: DeploymentHostingKind vazio.'
}

$environmentNames = New-Object System.Collections.Generic.List[string]
foreach ($name in $KbEnvironmentNames) {
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        $environmentNames.Add($name.Trim()) | Out-Null
    }
}

if ($environmentNames.Count -eq 0) {
    throw 'BLOCK: -KbEnvironmentNames vazio ou invalido.'
}

$nameSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($name in $environmentNames) {
    [void]$nameSet.Add($name)
}

$environmentNamesList = @($nameSet | Sort-Object)
$environmentNames = New-Object System.Collections.Generic.List[string]
foreach ($name in $environmentNamesList) {
    $environmentNames.Add($name) | Out-Null
}

$outputDirsRaw = ($KbEnvironmentOutputDirs -join '; ')
$outputDirsMap = Split-GeneXusKbEnvironmentMap -MapRaw $outputDirsRaw
if ($outputDirsMap.Count -eq 0) {
    throw 'BLOCK: -KbEnvironmentOutputDirs vazio ou invalido. Informe Environment=DiretorioOutput para cada environment declarado.'
}

$knownEnvironmentNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($name in $environmentNames) {
    [void]$knownEnvironmentNames.Add($name)
}

foreach ($key in $outputDirsMap.Keys) {
    if (-not $knownEnvironmentNames.Contains($key)) {
        throw ("BLOCK: KbEnvironmentOutputDirs contem environment '{0}' que nao consta em -KbEnvironmentNames." -f $key)
    }
    if ([string]::IsNullOrWhiteSpace($outputDirsMap[$key])) {
        throw ("BLOCK: KbEnvironmentOutputDirs sem diretorio de output para '{0}'." -f $key)
    }
}

foreach ($name in $environmentNames) {
    if (-not $outputDirsMap.Contains($name)) {
        throw ("BLOCK: KbEnvironmentOutputDirs nao contem mapeamento para environment '{0}'." -f $name)
    }
}

$webDirsMap = [ordered]@{}
if ($null -ne $KbEnvironmentWebDirs -and $KbEnvironmentWebDirs.Count -gt 0) {
    $webDirsRaw = ($KbEnvironmentWebDirs -join '; ')
    $webDirsMap = Split-GeneXusKbEnvironmentMap -MapRaw $webDirsRaw
} else {
    if ([string]::IsNullOrWhiteSpace($KbNativePath)) {
        throw 'BLOCK: -KbEnvironmentWebDirs ausente exige -KbNativePath para derivar <KbNativePath>\<OutputDir>\web.'
    }

    $resolvedKbNativePathForWeb = [System.IO.Path]::GetFullPath($KbNativePath)
    foreach ($name in $environmentNames) {
        $webDir = Join-Path (Join-Path $resolvedKbNativePathForWeb $outputDirsMap[$name]) 'web'
        $webDirsMap[$name] = $webDir
    }
}

foreach ($key in $webDirsMap.Keys) {
    if (-not $knownEnvironmentNames.Contains($key)) {
        throw ("BLOCK: KbEnvironmentWebDirs contem environment '{0}' que nao consta em -KbEnvironmentNames." -f $key)
    }
    if ([string]::IsNullOrWhiteSpace($webDirsMap[$key])) {
        throw ("BLOCK: KbEnvironmentWebDirs sem caminho web para '{0}'." -f $key)
    }
}

foreach ($name in $environmentNames) {
    if (-not $webDirsMap.Contains($name)) {
        throw ("BLOCK: KbEnvironmentWebDirs nao contem mapeamento para environment '{0}'." -f $name)
    }
}

$msBuildValidationSkipped = $false
$msBuildValidationPerformed = $false
$msBuildRejectedNames = @()
$msBuildValidationProbeResults = @()

if (-not $SkipEnvironmentNamesMsBuildValidation.IsPresent) {
    if ([string]::IsNullOrWhiteSpace($KbNativePath)) {
        throw 'BLOCK: validacao MSBuild de environments exige -KbNativePath. Se a sondagem headless estiver indisponivel nesta sessao, use -SkipEnvironmentNamesMsBuildValidation com excecao documentada no handoff.'
    }
    if ([string]::IsNullOrWhiteSpace($InventoryWorkingDirectory)) {
        throw 'BLOCK: validacao MSBuild de environments exige -InventoryWorkingDirectory. Se a sondagem headless estiver indisponivel nesta sessao, use -SkipEnvironmentNamesMsBuildValidation com excecao documentada no handoff.'
    }

    . (Join-Path $PSScriptRoot 'GeneXusKbEnvironmentInventorySupport.ps1')

    $inventoryResult = Get-GeneXusKbRegisteredEnvironmentNamesFromMsBuild `
        -KbNativePath $KbNativePath `
        -WorkingDirectory $InventoryWorkingDirectory `
        -LogPath $InventoryLogPath `
        -GeneXusDir $GeneXusDir `
        -MsBuildPath $MsBuildPath `
        -CandidateNames @($environmentNames) `
        -DatabaseUser $DatabaseUser `
        -DatabasePassword $DatabasePassword

    $registeredSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($registeredName in $inventoryResult.kb_environment_names) {
        [void]$registeredSet.Add($registeredName)
    }

    $rejected = New-Object System.Collections.Generic.List[string]
    foreach ($declaredName in $environmentNames) {
        if (-not $registeredSet.Contains($declaredName)) {
            $rejected.Add($declaredName) | Out-Null
        }
    }

    if ($rejected.Count -gt 0) {
        throw ("BLOCK: GeneXus rejeitou environment(s) declarado(s): {0}. Corrija os nomes com o usuario; nao use -SkipEnvironmentNamesMsBuildValidation para contornar rejeicao." -f ($rejected -join ', '))
    }

    $msBuildValidationPerformed = $true
    $msBuildValidationProbeResults = @($inventoryResult.probeResults)
} else {
    $msBuildValidationSkipped = $true
}

if (-not $nameSet.Contains($deploymentName)) {
    throw ("BLOCK: DeploymentEnvironmentName '{0}' nao consta na lista de environments ({1})." -f $deploymentName, ($environmentNames -join ', '))
}

$count = $environmentNames.Count
$namesJoined = ($environmentNames | Sort-Object) -join ', '
$outputDirsJoined = Join-GeneXusKbEnvironmentMap -Map $outputDirsMap
$webDirsJoined = Join-GeneXusKbEnvironmentMap -Map $webDirsMap

. (Join-Path $PSScriptRoot 'XpzTextFileEolSupport.ps1')

$fieldsToWrite = [ordered]@{
    deployment_environment_name = $deploymentName
    deployment_hosting_kind     = $hostingKind
    kb_environment_count        = [string]$count
    kb_environment_names        = $namesJoined
    kb_environment_output_dirs  = $outputDirsJoined
    kb_environment_web_dirs     = $webDirsJoined
}

$fileContext = Get-TextFileLineContext -Path $MetadataPath
$fileLines = $fileContext.Lines

foreach ($fieldName in $fieldsToWrite.Keys) {
    $newLine = '{0}: {1}' -f $fieldName, $fieldsToWrite[$fieldName]
    $fieldPattern = '^\s*{0}\s*[:=]\s*.+$' -f [regex]::Escape($fieldName)
    $updated = $false
    for ($i = 0; $i -lt $fileLines.Count; $i++) {
        if ($fileLines[$i] -match $fieldPattern) {
            $fileLines[$i] = $newLine
            $updated = $true
            break
        }
    }

    if (-not $updated) {
        $insertAt = -1
        $frontmatterClose = -1
        $hasFrontmatter = ($fileLines.Count -gt 0 -and $fileLines[0].Trim() -eq '---')

        if ($hasFrontmatter) {
            for ($i = 1; $i -lt $fileLines.Count; $i++) {
                if ($fileLines[$i].Trim() -eq '---') {
                    $frontmatterClose = $i
                    break
                }
            }

            if ($frontmatterClose -gt 0) {
                $insertAt = $frontmatterClose
            }
        } else {
            for ($i = 0; $i -lt $fileLines.Count; $i++) {
                if ($fileLines[$i] -match '^\s*##\s+') {
                    $insertAt = $i
                    break
                }
            }

            if ($insertAt -lt 0) {
                $insertAt = $fileLines.Count
            }
        }

        if ($insertAt -lt 0) {
            $insertAt = 0
        }

        $fileLines.Insert($insertAt, $newLine)
    }
}

Write-TextFilePreservingEol -Path $MetadataPath -FileContext $fileContext

$result = [ordered]@{
    status                              = 'KB_DEPLOYMENT_METADATA_OK'
    metadataPath                        = $MetadataPath
    deployment_environment_name         = $deploymentName
    deployment_hosting_kind             = $hostingKind
    kb_environment_count                = $count
    kb_environment_names                = @($environmentNames | Sort-Object)
    kb_environment_output_dirs          = $outputDirsMap
    kb_environment_web_dirs             = $webDirsMap
    environmentNamesSource              = 'user_declared'
    msBuildValidationPerformed          = $msBuildValidationPerformed
    msBuildValidationSkipped            = $msBuildValidationSkipped
    msBuildRejectedNames                = $msBuildRejectedNames
    msBuildValidationProbeResults       = $msBuildValidationProbeResults
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    $validationLabel = if ($msBuildValidationSkipped) { 'msbuild_validation=skipped' } else { 'msbuild_validation=ok' }
    Write-Output ("KB_DEPLOYMENT_METADATA_OK: deployment=$deploymentName count=$count names=$namesJoined output_dirs=$outputDirsJoined $validationLabel")
}
