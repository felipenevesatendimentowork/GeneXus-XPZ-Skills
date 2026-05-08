<#
.SYNOPSIS
Executa verificação leve pós-import via MSBuild: SpecifyAll seguido de GenerateOnly.

.DESCRIPTION
Implementa a etapa de verificação leve da skill xpz-msbuild-build: reaproveita o probe
Test-GeneXusMsBuildSetup.ps1, abre a KB em modo headless controlado, posiciona versão e
Environment quando informados, executa SpecifyAll seguido de GenerateOnly com parâmetros
explícitos e fecha a KB. Não compila e não executa reorg.

Classifica o resultado em cinco categorias:
  - specify e generate concluídos
  - operação concluída, pendente de confirmação funcional
  - erro de specify
  - erro de generate
  - KB inacessível

.PARAMETER KbPath
Caminho da KB a ser usada na verificação.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários desta execução.

.PARAMETER LogPath
Caminho completo do log JSON desta execução.

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, usa fallback do probe.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, usa fallback do probe.

.PARAMETER VersionName
Nome opcional da versão a posicionar antes da verificação.

.PARAMETER EnvironmentName
Nome opcional do Environment a posicionar antes da verificação.

.PARAMETER ForceRebuild
Quando true, força a regeneração mesmo que o objeto não tenha mudado. Default: false.

.PARAMETER DetailedNavigation
Quando true, executa navegação detalhada. Default: false.

.PARAMETER VerboseLog
Amplia o detalhamento gravado no log sem alterar o resultado lógico.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string]$VersionName,

    [string]$EnvironmentName,

    [ValidateSet('true', 'false')]
    [string]$ForceRebuild = 'false',

    [ValidateSet('true', 'false')]
    [string]$DetailedNavigation = 'false',

    [switch]$VerboseLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProgramFilesX86 = [System.IO.Path]::GetFullPath('C:\Program Files (x86)')

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

function Get-FullPathSafe {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    return [System.IO.Path]::GetFullPath($PathValue)
}

function Test-IsUnderProgramFilesX86 {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $false
    }

    $fullPath = Get-FullPathSafe -PathValue $PathValue
    $candidate = $fullPath.TrimEnd('\')
    $root = $ProgramFilesX86.TrimEnd('\')
    return $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-JsonText {
    param([object]$InputObject)

    return ($InputObject | ConvertTo-Json -Depth 8)
}

function Write-JsonLog {
    param(
        [string]$TargetLogPath,
        [string]$JsonPayload
    )

    [System.IO.File]::WriteAllText($TargetLogPath, $JsonPayload + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
}

function Add-StrategyTrace {
    param([string]$Message)

    $script:StrategyTrace.Add($Message)
}

function Add-BlockingReason {
    param([string]$Reason)

    if (-not $script:BlockingReasons.Contains($Reason)) {
        $script:BlockingReasons.Add($Reason)
    }
}

function Add-WarningMessage {
    param([string]$Message)

    if (-not $script:Warnings.Contains($Message)) {
        $script:Warnings.Add($Message)
    }
}

function Resolve-ProbeScriptPath {
    $scriptDirectory = Split-Path -Parent $PSCommandPath
    $probePath = Join-Path $scriptDirectory 'Test-GeneXusMsBuildSetup.ps1'
    if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) {
        throw "Probe script not found: $probePath"
    }
    return $probePath
}

function Invoke-ProbeStage {
    param([string]$ProbeLogPath)

    $probeScriptPath = Resolve-ProbeScriptPath
    $probeArgs = @{
        WorkingDirectory = $WorkingDirectory
        LogPath          = $ProbeLogPath
        KbPath           = $KbPath
    }

    if (-not [string]::IsNullOrWhiteSpace($GeneXusDir)) {
        $probeArgs.GeneXusDir = $GeneXusDir
    }
    if (-not [string]::IsNullOrWhiteSpace($MsBuildPath)) {
        $probeArgs.MsBuildPath = $MsBuildPath
    }
    if ($VerboseLog.IsPresent) {
        $probeArgs.VerboseLog = $true
    }

    $probeOutput = & $probeScriptPath @probeArgs
    $probeExitCode = $LASTEXITCODE
    $probeJson = ($probeOutput -join [Environment]::NewLine)
    $probeDiagnostic = $probeJson | ConvertFrom-Json -Depth 8

    return [ordered]@{
        ExitCode   = $probeExitCode
        Json       = $probeJson
        Diagnostic = $probeDiagnostic
    }
}

function Escape-Xml {
    param([string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return [System.Security.SecurityElement]::Escape($Value)
}

function New-ArtifactDirectory {
    $scriptDirectory = Split-Path -Parent $PSCommandPath
    $repositoryRoot = Split-Path -Parent $scriptDirectory
    $tempRoot = Join-Path $repositoryRoot 'Temp'
    $baseDirectory = Join-Path $tempRoot 'xpz-msbuild-build'
    [System.IO.Directory]::CreateDirectory($baseDirectory) | Out-Null
    $artifactDirectory = Join-Path $baseDirectory ('gx-specifygenerate-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function New-MsBuildProjectContent {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedKbPath
    )

    $targetsPath = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    $targetsEscaped     = Escape-Xml -Value $targetsPath
    $kbPathEscaped      = Escape-Xml -Value $ResolvedKbPath
    $versionEscaped     = Escape-Xml -Value $VersionName
    $environmentEscaped = Escape-Xml -Value $EnvironmentName
    $forceRebuildEscaped       = Escape-Xml -Value $ForceRebuild
    $detailedNavigationEscaped = Escape-Xml -Value $DetailedNavigation

    return @"
<Project ToolsVersion="Current" DefaultTargets="Run" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$targetsEscaped" />

  <PropertyGroup>
    <KBPath>$kbPathEscaped</KBPath>
    <KBVersion>$versionEscaped</KBVersion>
    <KBEnvironment>$environmentEscaped</KBEnvironment>
    <ForceRebuild>$forceRebuildEscaped</ForceRebuild>
    <DetailedNavigation>$detailedNavigationEscaped</DetailedNavigation>
  </PropertyGroup>

  <Target Name="CloseOnError">
    <CloseKnowledgeBase ContinueOnError="WarnAndContinue" />
  </Target>

  <Target Name="Run">
    <OpenKnowledgeBase Directory="`$(KBPath)" CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="OpenOutput" />
    </OpenKnowledgeBase>
    <SetActiveVersion Condition="'`$(KBVersion)' != ''" VersionName="`$(KBVersion)" />
    <SetActiveEnvironment Condition="'`$(KBEnvironment)' != ''" EnvironmentName="`$(KBEnvironment)" />
    <GetActiveVersion CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveVersionOutput" />
    </GetActiveVersion>
    <GetActiveEnvironment CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveEnvironmentOutput" />
    </GetActiveEnvironment>
    <SpecifyAll ForceRebuild="`$(ForceRebuild)" DetailedNavigation="`$(DetailedNavigation)" CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="SpecifyOutput" />
    </SpecifyAll>
    <Message Text="__SPECIFY_DONE__=true" Importance="High" />
    <GenerateOnly CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="GenerateOutput" />
    </GenerateOnly>
    <Message Text="__GENERATE_DONE__=true" Importance="High" />
    <Message Text="__OPEN_OUTPUT__=`$(OpenOutput)" Importance="High" />
    <Message Text="__ACTIVE_VERSION__=`$(ActiveVersionOutput)" Importance="High" />
    <Message Text="__ACTIVE_ENVIRONMENT__=`$(ActiveEnvironmentOutput)" Importance="High" />
    <CloseKnowledgeBase />
    <OnError ExecuteTargets="CloseOnError" />
  </Target>
</Project>
"@
}

function Invoke-MsBuildFile {
    param(
        [string]$ResolvedMsBuildPath,
        [string]$MsBuildFilePath,
        [string]$StdOutPath,
        [string]$StdErrPath
    )

    $arguments = @(
        $MsBuildFilePath,
        '/nologo',
        '/verbosity:minimal',
        '/nodeReuse:false',
        '/target:Run'
    )

    Add-StrategyTrace -Message ('MSBuild acionado com alvo Run em: {0}' -f $MsBuildFilePath)
    $process = Start-Process -FilePath $ResolvedMsBuildPath -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $MsBuildFilePath) -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath -NoNewWindow -PassThru -Wait
    return $process.ExitCode
}

function Read-TextFileSafe {
    param([string]$PathValue)

    if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
        return ''
    }

    return [System.IO.File]::ReadAllText($PathValue)
}

function Get-MarkerValue {
    param(
        [string]$Text,
        [string]$Marker
    )

    $match = [regex]::Match($Text, [regex]::Escape($Marker) + '(.*)')
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value.Trim()
}

function Get-RegexValue {
    param(
        [string]$Text,
        [string]$Pattern
    )

    $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value.Trim()
}

function Get-TextSummary {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    return @($Text -split "(`r`n|`n|`r)" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 30)
}

function Resolve-BuildStatus {
    param(
        [int]$MsBuildExitCode,
        [bool]$SpecifyDone,
        [bool]$GenerateDone,
        [string]$StdOutText,
        [string]$StdErrText
    )

    # Padrão bloqueante de maior prioridade: reorg real executada dentro do SpecifyAll.
    # SpecifyAll pode executar Database Impact Analysis, gerar bldReorganization.cs e
    # executar a reorg internamente quando há alterações estruturais pendentes no banco.
    # Esse comportamento é intrínseco à task GeneXus e independe de flags do wrapper.
    if ($StdOutText -match 'Reorganiza') {
        Add-WarningMessage -Message 'Padrão "Reorganiza" detectado em stdout: SpecifyAll executou reorganização real de banco de dados. Confirmar com o usuário se a reorg era esperada e autorizada antes de declarar qualquer sucesso.'
        return [ordered]@{
            Status   = 'reorg detectada ou executada'
            Summary  = 'SpecifyAll disparou reorganização real de banco de dados (padrão "Reorganiza" encontrado em stdout). Este comportamento é intrínseco à task GeneXus quando há alterações estruturais pendentes. Não declarar sucesso sem confirmação explícita do usuário.'
            ExitCode = 43
        }
    }

    # Eventos pós-build detectados (start c:, start cmd): KB configurada com ações
    # pós-build que disparam processos externos. Registrar como warning mesmo quando
    # a classificação principal for bem-sucedida.
    $postBuildLines = @($StdOutText -split "`r?`n" | Where-Object { $_ -match '^\s+start (c:|cmd)' })
    if ($postBuildLines.Count -gt 0) {
        foreach ($evtLine in $postBuildLines) {
            Add-WarningMessage -Message ('Evento pós-build detectado em stdout: "{0}". A KB disparou processos externos durante o SpecifyAll.' -f $evtLine.Trim())
        }
    }

    # Stderr não vazio: qualquer conteúdo em stderr é sinal de risco, independente do exitCode.
    $stderrNonEmpty = -not [string]::IsNullOrWhiteSpace($StdErrText)
    if ($stderrNonEmpty) {
        Add-WarningMessage -Message ('stderr não vazio: conteúdo presente impediu classificação limpa. Inspecionar stderr antes de concluir sobre o resultado.')
    }

    $alertPatterns = @('Access denied')
    $foundAlerts = @($alertPatterns | Where-Object {
        ($StdOutText -match [regex]::Escape($_)) -or ($StdErrText -match [regex]::Escape($_))
    })

    $hasImpediment = ($foundAlerts.Count -gt 0) -or $stderrNonEmpty -or ($postBuildLines.Count -gt 0)

    if ($MsBuildExitCode -eq 0 -and $SpecifyDone -and $GenerateDone -and -not $hasImpediment) {
        return [ordered]@{
            Status   = 'specify e generate concluídos'
            Summary  = 'SpecifyAll e GenerateOnly concluídos sem erro operacional.'
            ExitCode = 0
        }
    }

    if ($MsBuildExitCode -eq 0 -and $SpecifyDone -and $GenerateDone) {
        foreach ($alert in $foundAlerts) {
            Add-WarningMessage -Message ('Padrão de alerta em stdout/stderr impede classificação limpa: "{0}".' -f $alert)
        }
        return [ordered]@{
            Status   = 'operação concluída, pendente de confirmação funcional'
            Summary  = 'SpecifyAll e GenerateOnly concluídos com exitCode 0, mas impedimentos detectados em stdout/stderr (stderr não vazio, padrões de alerta ou eventos pós-build). Validação funcional necessária antes de concluir sobre o resultado.'
            ExitCode = 0
        }
    }

    if (-not $SpecifyDone) {
        return [ordered]@{
            Status   = 'KB inacessível'
            Summary  = 'KB não pôde ser aberta ou SpecifyAll falhou antes de iniciar.'
            ExitCode = 40
        }
    }

    if ($SpecifyDone -and -not $GenerateDone) {
        return [ordered]@{
            Status   = 'erro de generate'
            Summary  = 'SpecifyAll concluído mas GenerateOnly falhou.'
            ExitCode = 42
        }
    }

    # SpecifyDone=false coberto acima; chegou aqui apenas se exitCode<>0 com ambos done
    return [ordered]@{
        Status   = 'erro de specify'
        Summary  = 'SpecifyAll falhou durante a execução.'
        ExitCode = 41
    }
}

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings        = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace   = New-Object System.Collections.Generic.List[string]

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

try {
    if ($VerboseLog.IsPresent) {
        Add-StrategyTrace -Message 'VerboseLog habilitado para detalhamento adicional.'
    }

    $artifactDirectory = New-ArtifactDirectory
    $probeLogPath = Join-Path $artifactDirectory 'probe-stage.json'
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath

    Add-StrategyTrace -Message ('Probe executado antes da verificação com exitCode {0}.' -f $probeStage.ExitCode)

    if ($probeStage.ExitCode -ne 0) {
        Add-BlockingReason -Reason 'Probe não apto para prosseguir bloqueou a verificação.'
        $probeDiagnostic = $probeStage.Diagnostic
        $blocked = [ordered]@{
            status           = 'não apto para prosseguir'
            summary          = 'Probe bloqueou a verificação de specify e generate.'
            exitCode         = $probeStage.ExitCode
            stage            = 'probe'
            requestedContext = [ordered]@{
                VersionName         = $VersionName
                EnvironmentName     = $EnvironmentName
                ForceRebuild        = $ForceRebuild
                DetailedNavigation  = $DetailedNavigation
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
            }
            resolvedPaths    = [ordered]@{
                GeneXusDir       = $probeDiagnostic.resolvedPaths.GeneXusDir
                MsBuildPath      = $probeDiagnostic.resolvedPaths.MsBuildPath
                KbPath           = $probeDiagnostic.resolvedPaths.KbPath
                WorkingDirectory = $probeDiagnostic.resolvedPaths.WorkingDirectory
                LogPath          = $resolvedLogPath
            }
            pathActions      = $probeDiagnostic.pathActions
            artifacts        = [ordered]@{
                ProbeLogPath      = $probeLogPath
                MsBuildFilePath   = $null
                StdOutPath        = $null
                StdErrPath        = $null
                ExecutionLogPath  = $resolvedLogPath
            }
            blockingReasons  = @($probeDiagnostic.blockingReasons + $script:BlockingReasons)
            warnings         = @($probeDiagnostic.warnings)
            strategyTrace    = @($probeDiagnostic.strategyTrace + $script:StrategyTrace)
        }

        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        }
        Write-Output $blockedJson
        exit $probeStage.ExitCode
    }

    $resolvedGeneXusDir  = [string]$probeStage.Diagnostic.resolvedPaths.GeneXusDir
    $resolvedMsBuildPath = [string]$probeStage.Diagnostic.resolvedPaths.MsBuildPath
    $resolvedKbPath      = [string]$probeStage.Diagnostic.resolvedPaths.KbPath

    $msBuildFilePath = Join-Path $artifactDirectory 'specifygenerate.msbuild'
    $stdOutPath      = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath      = Join-Path $artifactDirectory 'msbuild.stderr.log'

    $projectContent = New-MsBuildProjectContent -ResolvedGeneXusDir $resolvedGeneXusDir -ResolvedKbPath $resolvedKbPath
    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))
    Add-StrategyTrace -Message ('Arquivo .msbuild temporário gerado em: {0}' -f $msBuildFilePath)

    $msBuildExitCode = Invoke-MsBuildFile -ResolvedMsBuildPath $resolvedMsBuildPath -MsBuildFilePath $msBuildFilePath -StdOutPath $stdOutPath -StdErrPath $stdErrPath
    $stdOutText = Read-TextFileSafe -PathValue $stdOutPath
    $stdErrText = Read-TextFileSafe -PathValue $stdErrPath

    $specifyDoneMarker  = Get-MarkerValue -Text $stdOutText -Marker '__SPECIFY_DONE__='
    $generateDoneMarker = Get-MarkerValue -Text $stdOutText -Marker '__GENERATE_DONE__='
    $specifyDone  = ($specifyDoneMarker -eq 'true')
    $generateDone = ($generateDoneMarker -eq 'true')

    $activeVersionOutput     = Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'"
    $activeEnvironmentOutput = Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'"

    if (-not [string]::IsNullOrWhiteSpace($VersionName) -and [string]::IsNullOrWhiteSpace($activeVersionOutput)) {
        Add-WarningMessage -Message 'Versão solicitada, mas o retorno de GetActiveVersion veio vazio.'
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName) -and [string]::IsNullOrWhiteSpace($activeEnvironmentOutput)) {
        Add-WarningMessage -Message 'Environment solicitado, mas o retorno de GetActiveEnvironment veio vazio.'
    }

    $buildStatus = Resolve-BuildStatus -MsBuildExitCode $msBuildExitCode -SpecifyDone $specifyDone -GenerateDone $generateDone -StdOutText $stdOutText -StdErrText $stdErrText

    if ($buildStatus.ExitCode -ne 0) {
        Add-BlockingReason -Reason ('Execução MSBuild terminou com exitCode {0}. Status: {1}.' -f $msBuildExitCode, $buildStatus.Status)
    }

    $diagnostic = [ordered]@{
        status           = $buildStatus.Status
        summary          = $buildStatus.Summary
        exitCode         = $buildStatus.ExitCode
        stage            = 'specify-generate'
        requestedContext = [ordered]@{
            VersionName        = $VersionName
            EnvironmentName    = $EnvironmentName
            ForceRebuild       = $ForceRebuild
            DetailedNavigation = $DetailedNavigation
        }
        observedContext  = [ordered]@{
            ActiveVersion     = $activeVersionOutput
            ActiveEnvironment = $activeEnvironmentOutput
            SpecifyDone       = $specifyDone
            GenerateDone      = $generateDone
            MsBuildExitCode   = $msBuildExitCode
        }
        resolvedPaths    = [ordered]@{
            GeneXusDir       = $resolvedGeneXusDir
            MsBuildPath      = $resolvedMsBuildPath
            KbPath           = $resolvedKbPath
            WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
            LogPath          = $resolvedLogPath
        }
        pathActions      = $probeStage.Diagnostic.pathActions
        artifacts        = [ordered]@{
            ProbeLogPath     = $probeLogPath
            MsBuildFilePath  = $msBuildFilePath
            StdOutPath       = $stdOutPath
            StdErrPath       = $stdErrPath
            ExecutionLogPath = $resolvedLogPath
        }
        stdoutSummary    = Get-TextSummary -Text $stdOutText
        stderrSummary    = Get-TextSummary -Text $stdErrText
        blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
        warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
        strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
    }

    $json = ConvertTo-JsonText -InputObject $diagnostic

    # Fallback: gravar sempre no diretório de artefatos, independente de $resolvedLogPath.
    # Garante rastreabilidade mesmo quando o chamador for interrompido antes de ler o JSON.
    $artifactResultPath = Join-Path $artifactDirectory 'specifygenerate-result.json'
    [System.IO.File]::WriteAllText($artifactResultPath, $json + [Environment]::NewLine, (Get-Utf8NoBomEncoding))

    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json
    Write-Output $json
    exit $buildStatus.ExitCode
}
catch {
    $failure = [ordered]@{
        status           = 'falha operacional'
        summary          = 'Falha interna do script antes de concluir a verificação.'
        exitCode         = 90
        stage            = 'specify-generate'
        requestedContext = [ordered]@{
            VersionName        = $VersionName
            EnvironmentName    = $EnvironmentName
            ForceRebuild       = $ForceRebuild
            DetailedNavigation = $DetailedNavigation
        }
        resolvedPaths    = [ordered]@{
            GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
            MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
            KbPath           = (Get-FullPathSafe -PathValue $KbPath)
            WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
            LogPath          = $resolvedLogPath
        }
        pathActions      = [ordered]@{
            WorkingDirectory = 'blocked-internal-error'
        }
        artifacts        = [ordered]@{
            ProbeLogPath     = $null
            MsBuildFilePath  = $null
            StdOutPath       = $null
            StdErrPath       = $null
            ExecutionLogPath = $resolvedLogPath
        }
        stdoutSummary    = @()
        stderrSummary    = @()
        blockingReasons  = @($_.Exception.Message)
        warnings         = @()
        strategyTrace    = @($script:StrategyTrace)
    }

    $failureJson = ConvertTo-JsonText -InputObject $failure
    try {
        if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath) -and -not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            $parent = [System.IO.Path]::GetDirectoryName($resolvedLogPath)
            if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
                Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $failureJson
            }
        }
    } catch {
        # best effort apenas
    }

    Write-Output $failureJson
    exit 90
}
