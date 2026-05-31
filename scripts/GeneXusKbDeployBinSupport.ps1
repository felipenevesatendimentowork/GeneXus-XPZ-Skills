#requires -Version 7.4
<#
.SYNOPSIS
    Checagem pos-build de frescor de web\bin do environment de deploy (Ponto 2).

.DESCRIPTION
    Le deployment_hosting_kind do metadata; regras por tipo:
      dotnet-core-self-host  -> GxNetCoreStartup.dll em <Kb>\<Env>\web\bin
      dotnet-framework-iis   -> agregado de *.dll em web\bin

    Severidade hibrida (decisoes fechadas): status novo quando stale; exit 49 so com gate.
#>

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'GeneXusKbDeploymentEnvironmentSupport.ps1')

$script:GeneXusKbDeployBinGateExitCode = 49
$script:GeneXusKbDeployBinStaleStatus = 'compilou-mas-dll-destino-desatualizada'
$script:GeneXusKbDeployBinSuccessStatuses = @(
    'compilou limpo'
    'specify e generate concluidos'
)

function Get-GeneXusKbDeployBinTimeSlack {
    return [TimeSpan]::FromSeconds(5)
}

function Test-GeneXusKbDeployBinBuildSuccessStatus {
    param([string]$Status)

    if ([string]::IsNullOrWhiteSpace($Status)) {
        return $false
    }

    $normalized = $Status.Trim().Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
    foreach ($candidate in $script:GeneXusKbDeployBinSuccessStatuses) {
        $candidateNorm = $candidate.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
        if ($normalized -ieq $candidateNorm) {
            return $true
        }
    }

    return ($Status -ieq 'compilou limpo') -or ($Status -ieq 'specify e generate concluídos')
}

function Get-GeneXusKbDeployBinHostingKindFromMetadata {
    param([string]$MetadataPath)

    if ([string]::IsNullOrWhiteSpace($MetadataPath) -or -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        return $null
    }

    $lines = [System.IO.File]::ReadAllLines($MetadataPath)
    return Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'deployment_hosting_kind'
    )
}

function Resolve-GeneXusKbDeployBinCheckPolicy {
    param(
        [switch]$PostImportDeployValidation,
        [switch]$SkipDeployBinCheck,
        [switch]$StrictDeployBinCheck,
        [string]$MetadataPath,
        [string]$DeploymentHostingKind,
        [string]$ValidationEnvironmentName,
        [string]$BuildSuccessStatus
    )

    $policy = [ordered]@{
        shouldRun          = $false
        gateEnabled        = $false
        mode               = 'skipped'
        skipReason         = $null
        deploymentHostingKind = $DeploymentHostingKind
    }

    if ($SkipDeployBinCheck.IsPresent) {
        $policy.skipReason = 'SkipDeployBinCheck informado.'
        return [pscustomobject]$policy
    }

    if (-not (Test-GeneXusKbDeployBinBuildSuccessStatus -Status $BuildSuccessStatus)) {
        $policy.skipReason = 'Build nao classificado como sucesso operacional para checagem de deploy bin.'
        return [pscustomobject]$policy
    }

    if ([string]::IsNullOrWhiteSpace($ValidationEnvironmentName)) {
        $policy.skipReason = 'Environment de validacao/deploy nao resolvido.'
        return [pscustomobject]$policy
    }

    if ([string]::IsNullOrWhiteSpace($MetadataPath) -or -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        $policy.skipReason = 'kb-source-metadata.md ausente para deployment_hosting_kind.'
        return [pscustomobject]$policy
    }

    $hostingKind = $DeploymentHostingKind
    if ([string]::IsNullOrWhiteSpace($hostingKind)) {
        $hostingKind = Get-GeneXusKbDeployBinHostingKindFromMetadata -MetadataPath $MetadataPath
        $policy.deploymentHostingKind = $hostingKind
    }

    if ([string]::IsNullOrWhiteSpace($hostingKind)) {
        $policy.skipReason = 'deployment_hosting_kind ausente no metadata (gravar via xpz-kb-parallel-setup).'
        return [pscustomobject]$policy
    }

    if ($hostingKind -notin @('dotnet-core-self-host', 'dotnet-framework-iis')) {
        $policy.skipReason = ("deployment_hosting_kind invalido: '{0}'." -f $hostingKind)
        return [pscustomobject]$policy
    }

    $policy.shouldRun = $true
    $policy.gateEnabled = ($StrictDeployBinCheck.IsPresent -or $PostImportDeployValidation.IsPresent)
    $policy.mode = if ($policy.gateEnabled) { 'gate' } else { 'diagnostic' }
    return [pscustomobject]$policy
}

function Get-GeneXusKbDirectoryMaxWriteTime {
    param(
        [string]$RootPath,
        [string[]]$IncludeExtensions,
        [string[]]$ExcludeDirectoryNames = @('bin')
    )

    if ([string]::IsNullOrWhiteSpace($RootPath) -or -not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $null
    }

    $excludeSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $ExcludeDirectoryNames) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            [void]$excludeSet.Add($name.Trim('\', '/'))
        }
    }

    $maxWrite = $null
    $rootFull = [System.IO.Path]::GetFullPath($RootPath)

    foreach ($file in Get-ChildItem -LiteralPath $rootFull -Recurse -File -ErrorAction SilentlyContinue) {
        $relative = $file.FullName.Substring($rootFull.Length).TrimStart('\', '/')
        $segments = @($relative -split '[\\/]')
        $skip = $false
        foreach ($segment in $segments) {
            if ($excludeSet.Contains($segment)) {
                $skip = $true
                break
            }
        }
        if ($skip) {
            continue
        }

        if ($IncludeExtensions -and $IncludeExtensions.Count -gt 0) {
            $matched = $false
            foreach ($ext in $IncludeExtensions) {
                if ($file.Name.EndsWith($ext, [StringComparison]::OrdinalIgnoreCase)) {
                    $matched = $true
                    break
                }
            }
            if (-not $matched) {
                continue
            }
        }

        $candidate = [DateTimeOffset]::new($file.LastWriteTime)
        if ($null -eq $maxWrite -or $candidate -gt $maxWrite) {
            $maxWrite = $candidate
        }
    }

    return $maxWrite
}

function Get-GeneXusKbDeployBinPaths {
    param(
        [string]$KbPath,
        [string]$EnvironmentName
    )

    $envWebPath = Join-Path $KbPath $EnvironmentName
    $envWebPath = Join-Path $envWebPath 'web'
    $envBinPath = Join-Path $envWebPath 'bin'

    return [pscustomobject][ordered]@{
        environmentWebPath = $envWebPath
        environmentBinPath = $envBinPath
        sentinelPath       = Join-Path $envBinPath 'GxNetCoreStartup.dll'
    }
}

function Test-GeneXusKbDeployBinFreshnessCore {
    param(
        [string]$KbPath,
        [string]$EnvironmentName,
        [string]$DeploymentHostingKind,
        [DateTimeOffset]$BuildStartedAt,
        [string]$MetadataPath
    )

    $paths = Get-GeneXusKbDeployBinPaths -KbPath $KbPath -EnvironmentName $EnvironmentName
    $slack = Get-GeneXusKbDeployBinTimeSlack
    $threshold = $BuildStartedAt.Subtract($slack)

    $result = [ordered]@{
        status                     = 'unknown'
        deploymentHostingKind      = $DeploymentHostingKind
        validationEnvironmentName  = $EnvironmentName
        buildStartedAt             = $BuildStartedAt.ToString('o')
        thresholdAt                = $threshold.ToString('o')
        paths                      = [ordered]@{
            environmentWebPath = $paths.environmentWebPath
            environmentBinPath = $paths.environmentBinPath
        }
        binCheck                   = [ordered]@{}
        diagnosticLayer            = [ordered]@{}
        interpretation             = $null
    }

    $envWebMax = Get-GeneXusKbDirectoryMaxWriteTime -RootPath $paths.environmentWebPath -IncludeExtensions @('.cs', '.js', '.aspx', '.dll') -ExcludeDirectoryNames @('bin')
    $envWebFresh = ($null -ne $envWebMax) -and ($envWebMax -ge $threshold)

    $result.diagnosticLayer = [ordered]@{
        environmentWebMaxWriteTime = if ($null -ne $envWebMax) { $envWebMax.ToString('o') } else { $null }
        environmentWebFreshSinceBuild = $envWebFresh
    }

    if ($DeploymentHostingKind -eq 'dotnet-core-self-host') {
        $sentinelPath = $paths.sentinelPath
        $result.binCheck.rule = 'sentinel-GxNetCoreStartup.dll'
        $result.binCheck.sentinelPath = $sentinelPath

        if (-not (Test-Path -LiteralPath $sentinelPath -PathType Leaf)) {
            $result.status = 'unknown'
            $result.binCheck.sentinelFound = $false
            $result.interpretation = 'GxNetCoreStartup.dll ausente em web\bin do environment de deploy.'
            return [pscustomobject]$result
        }

        $fi = Get-Item -LiteralPath $sentinelPath
        $sentinelWrite = [DateTimeOffset]::new($fi.LastWriteTime)
        $sentinelFresh = ($sentinelWrite -ge $threshold)

        $result.binCheck.sentinelFound = $true
        $result.binCheck.sentinelLastWriteTime = $sentinelWrite.ToString('o')
        $result.binCheck.sentinelFreshSinceBuild = $sentinelFresh
        $result.status = if ($sentinelFresh) { 'fresh' } else { 'stale' }
    }
    else {
        $binPath = $paths.environmentBinPath
        $result.binCheck.rule = 'aggregate-web-bin-dll'

        if (-not (Test-Path -LiteralPath $binPath -PathType Container)) {
            $result.status = 'unknown'
            $result.binCheck.binDirectoryFound = $false
            $result.interpretation = 'Pasta web\bin ausente no environment de deploy.'
            return [pscustomobject]$result
        }

        $dllFiles = @(Get-ChildItem -LiteralPath $binPath -Filter '*.dll' -File -ErrorAction SilentlyContinue)
        if ($dllFiles.Count -eq 0) {
            $result.status = 'unknown'
            $result.binCheck.binDirectoryFound = $true
            $result.binCheck.dllCount = 0
            $result.interpretation = 'Nenhuma DLL encontrada em web\bin.'
            return [pscustomobject]$result
        }

        $maxBinWrite = $null
        $newestDll = $null
        foreach ($dll in $dllFiles) {
            $candidate = [DateTimeOffset]::new($dll.LastWriteTime)
            if ($null -eq $maxBinWrite -or $candidate -gt $maxBinWrite) {
                $maxBinWrite = $candidate
                $newestDll = $dll.Name
            }
        }

        $binFresh = ($null -ne $maxBinWrite) -and ($maxBinWrite -ge $threshold)
        $result.binCheck.binDirectoryFound = $true
        $result.binCheck.dllCount = $dllFiles.Count
        $result.binCheck.newestDllName = $newestDll
        $result.binCheck.newestDllLastWriteTime = $maxBinWrite.ToString('o')
        $result.binCheck.binFreshSinceBuild = $binFresh
        $result.status = if ($binFresh) { 'fresh' } else { 'stale' }
    }

    if ($result.status -eq 'stale') {
        if ($envWebFresh) {
            $result.interpretation = 'web\bin desatualizado com artefatos mais novos em <Env>\web\ — suspeita de falha de publicacao/copia para bin.'
        }
        else {
            $result.interpretation = 'web\bin e <Env>\web\ desatualizados apos o build — build pode nao ter recompilado/publicado o necessario neste environment.'
        }
    }
    elseif ($result.status -eq 'fresh') {
        $result.interpretation = 'web\bin do environment de deploy reflete timestamp posterior ao inicio do build (com margem de slack).'
    }

    return [pscustomobject]$result
}

function Invoke-GeneXusKbDeployBinPostBuildClassification {
    param(
        [string]$KbPath,
        [string]$ValidationEnvironmentName,
        [string]$MetadataPath,
        [string]$DeploymentHostingKind,
        [DateTimeOffset]$BuildStartedAt,
        [string]$BuildSuccessStatus,
        [switch]$PostImportDeployValidation,
        [switch]$SkipDeployBinCheck,
        [switch]$StrictDeployBinCheck,
        [string]$OperationLabel = 'Build'
    )

    $policy = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation:$PostImportDeployValidation `
        -SkipDeployBinCheck:$SkipDeployBinCheck `
        -StrictDeployBinCheck:$StrictDeployBinCheck `
        -MetadataPath $MetadataPath `
        -DeploymentHostingKind $DeploymentHostingKind `
        -ValidationEnvironmentName $ValidationEnvironmentName `
        -BuildSuccessStatus $BuildSuccessStatus

    $output = [ordered]@{
        deployBinFreshness = 'skipped'
        deployBinCheck     = [ordered]@{
            mode          = $policy.mode
            gateEnabled   = $policy.gateEnabled
            shouldRun     = $policy.shouldRun
            skipReason    = $policy.skipReason
            hostingKind   = $policy.deploymentHostingKind
        }
        statusReclassified = $false
        newStatus          = $null
        newSummary         = $null
        newExitCode        = $null
        warnings           = @()
        blockingReasons    = @()
    }

    if (-not $policy.shouldRun) {
        if ($policy.skipReason) {
            $output.deployBinCheck.skipReason = $policy.skipReason
        }
        return [pscustomobject]$output
    }

    $freshness = Test-GeneXusKbDeployBinFreshnessCore `
        -KbPath $KbPath `
        -EnvironmentName $ValidationEnvironmentName `
        -DeploymentHostingKind $policy.deploymentHostingKind `
        -BuildStartedAt $BuildStartedAt `
        -MetadataPath $MetadataPath

    $output.deployBinFreshness = $freshness.status
    $output.deployBinCheck = [ordered]@{
        mode                      = $policy.mode
        gateEnabled               = $policy.gateEnabled
        shouldRun                 = $true
        hostingKind               = $policy.deploymentHostingKind
        validationEnvironmentName = $ValidationEnvironmentName
        buildStartedAt            = $freshness.buildStartedAt
        thresholdAt               = $freshness.thresholdAt
        paths                     = $freshness.paths
        binCheck                  = $freshness.binCheck
        diagnosticLayer           = $freshness.diagnosticLayer
        interpretation            = $freshness.interpretation
    }

    if ($freshness.status -eq 'fresh') {
        return [pscustomobject]$output
    }

    if ($freshness.status -eq 'unknown') {
        $output.warnings = @(
            ("Checagem deploy bin inconclusiva ({0}): {1}" -f $OperationLabel, $freshness.interpretation)
        )
        if ($policy.gateEnabled) {
            $output.statusReclassified = $true
            $output.newStatus = $script:GeneXusKbDeployBinStaleStatus
            $output.newSummary = ("{0} concluiu sem erro de MSBuild, mas a checagem de web\bin do environment de deploy foi inconclusiva ({1}). Nao declarar validacao deploy OK." -f $OperationLabel, $freshness.interpretation)
            $output.newExitCode = $script:GeneXusKbDeployBinGateExitCode
            $output.blockingReasons = @(
                'deploy-bin-cheque-inconclusivo: deployment_hosting_kind ou artefatos em web\bin ausentes/ilegiveis.'
            )
        }
        return [pscustomobject]$output
    }

    $output.statusReclassified = $true
    $output.newStatus = $script:GeneXusKbDeployBinStaleStatus
    $output.newSummary = ("{0} concluiu sem erro de MSBuild, mas web\bin do environment de deploy ({1}) nao reflete o build. {2}" -f $OperationLabel, $ValidationEnvironmentName, $freshness.interpretation)
    $output.warnings = @($freshness.interpretation)

    if ($policy.gateEnabled) {
        $output.newExitCode = $script:GeneXusKbDeployBinGateExitCode
        $output.blockingReasons = @(
            ("deploy-bin-desatualizado: web\bin do environment '{0}' anterior ao inicio do build (hosting={1})." -f $ValidationEnvironmentName, $policy.deploymentHostingKind)
        )
    }
    else {
        $output.newExitCode = 0
        $output.warnings = @(
            $freshness.interpretation
            'Modo diagnostico: exitCode MSBuild preservado; nao declarar validacao deploy OK.'
        )
    }

    return [pscustomobject]$output
}
