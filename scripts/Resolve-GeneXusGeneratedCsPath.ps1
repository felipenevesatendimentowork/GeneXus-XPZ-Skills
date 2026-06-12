#requires -Version 7.4
<#
.SYNOPSIS
    Resolve o caminho direto do .cs gerado por objeto GeneXus a partir do metadata da pasta paralela.

.DESCRIPTION
    Le kb-source-metadata.md, resolve o environment operacional e usa o mapeamento
    kb_environment_web_dirs para montar <webDir>\<objectName-lowercase>.cs sem varredura
    recursiva da KB nativa.

    Se o metadata não tiver mapeamento de output/web por environment, bloqueia e orienta
    reconciliar a pasta paralela via xpz-kb-parallel-setup.

.PARAMETER KbPath
    Caminho da KB nativa GeneXus. Usado para contexto e validação leve; o webDir vem do metadata.

.PARAMETER ObjectName
    Nome do objeto GeneXus.

.PARAMETER ObjectType
    Tipo do objeto GeneXus. Campo informativo reservado para diagnostico.

.PARAMETER EnvironmentName
    Environment GeneXus a resolver. Se omitido, usa deployment_environment_name; em KB
    single-environment, usa o único nome em kb_environment_names.

.PARAMETER ParallelKbRoot
    Raiz da pasta paralela da KB para resolver kb-source-metadata.md.

.PARAMETER KbMetadataPath
    Caminho explicito para kb-source-metadata.md.

.PARAMETER AsJson
    Emite saida JSON estruturada.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [string]$ObjectName,

    [string]$ObjectType,

    [string]$EnvironmentName,

    [string]$ParallelKbRoot,

    [string]$KbMetadataPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbDeploymentEnvironmentSupport.ps1')

function New-BlockedResult {
    param(
        [string]$Reason,
        [string]$MetadataPath
    )

    return [ordered]@{
        status             = 'BLOCK'
        reason             = $Reason
        kbPath             = $KbPath
        metadataPath       = $MetadataPath
        objectName         = $ObjectName
        objectType         = $ObjectType
        environmentName    = $EnvironmentName
        nextStep           = 'Executar xpz-kb-parallel-setup para reconciliar kb-source-metadata.md com kb_environment_output_dirs e kb_environment_web_dirs.'
    }
}

$resolvedKbPath = [System.IO.Path]::GetFullPath($KbPath)
$metadataPathResolved = Resolve-GeneXusKbSourceMetadataPath -KbMetadataPath $KbMetadataPath -ParallelKbRoot $ParallelKbRoot

if ([string]::IsNullOrWhiteSpace($metadataPathResolved)) {
    $blocked = New-BlockedResult -Reason 'KbMetadataPath/ParallelKbRoot ausente; metadata da pasta paralela e obrigatorio para resolver .cs gerado.' -MetadataPath $null
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$metadataPathResolved = [System.IO.Path]::GetFullPath($metadataPathResolved)
$fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $metadataPathResolved
if (-not $fields.MetadataFound) {
    $blocked = New-BlockedResult -Reason "kb-source-metadata.md nao encontrado: $metadataPathResolved" -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$requestedEnvironment = if ([string]::IsNullOrWhiteSpace($EnvironmentName)) { $null } else { $EnvironmentName.Trim() }
$resolvedEnvironment = $null
$environmentSource = $null

if ($requestedEnvironment) {
    $resolvedEnvironment = $requestedEnvironment
    $environmentSource = 'parameter'
} elseif (-not [string]::IsNullOrWhiteSpace($fields.deployment_environment_name)) {
    $resolvedEnvironment = $fields.deployment_environment_name
    $environmentSource = 'deployment_environment_name'
} elseif ($fields.kb_environment_names.Count -eq 1) {
    $resolvedEnvironment = $fields.kb_environment_names[0]
    $environmentSource = 'single_environment_metadata'
} else {
    $blocked = New-BlockedResult -Reason 'EnvironmentName ausente e metadata nao define deployment_environment_name nem KB single-environment.' -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($name in $fields.kb_environment_names) {
    [void]$known.Add($name)
}

if ($known.Count -gt 0 -and -not $known.Contains($resolvedEnvironment)) {
    $blocked = New-BlockedResult -Reason ("Environment '{0}' nao consta em kb_environment_names ({1})." -f $resolvedEnvironment, ($fields.kb_environment_names -join ', ')) -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

if ($fields.kb_environment_web_dirs.Count -eq 0) {
    $blocked = New-BlockedResult -Reason 'kb_environment_web_dirs ausente em kb-source-metadata.md; nao inferir por scan de pastas da KB nativa.' -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

if (-not $fields.kb_environment_web_dirs.Contains($resolvedEnvironment)) {
    $blocked = New-BlockedResult -Reason ("kb_environment_web_dirs nao contem mapeamento para environment '{0}'." -f $resolvedEnvironment) -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$webDir = $fields.kb_environment_web_dirs[$resolvedEnvironment]
if ([string]::IsNullOrWhiteSpace($webDir)) {
    $blocked = New-BlockedResult -Reason ("kb_environment_web_dirs contem caminho vazio para environment '{0}'." -f $resolvedEnvironment) -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$generatedFileName = $ObjectName.Trim().ToLowerInvariant() + '.cs'
$csPath = Join-Path $webDir $generatedFileName
$exists = Test-Path -LiteralPath $csPath -PathType Leaf

$result = [ordered]@{
    status             = 'CS_PATH_RESOLVED'
    kbPath             = $resolvedKbPath
    metadataPath       = $metadataPathResolved
    objectName         = $ObjectName
    objectType         = $ObjectType
    environmentName    = $resolvedEnvironment
    environmentSource  = $environmentSource
    webDirectory       = $webDir
    generatedFileName  = $generatedFileName
    csPath             = $csPath
    exists             = $exists
    readOnly           = $true
    resolutionSource   = 'kb-source-metadata.kb_environment_web_dirs'
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output 'CS_PATH_RESOLVED'
    Write-Output ("environment : {0} ({1})" -f $resolvedEnvironment, $environmentSource)
    Write-Output ("webDirectory: {0}" -f $webDir)
    Write-Output ("csPath      : {0}" -f $csPath)
    Write-Output ("exists      : {0}" -f $exists)
}
