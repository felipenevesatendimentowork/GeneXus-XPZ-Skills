<#
.SYNOPSIS
Executa build completo pós-import via MSBuild: BuildAll (specify + generate + compile).

.DESCRIPTION
Implementa a etapa de validação completa da skill xpz-msbuild-build: reaproveita o probe
Test-GeneXusMsBuildSetup.ps1, abre a KB em modo headless controlado, posiciona versão e
Environment quando informados, executa BuildAll com parâmetros explícitos e fecha a KB.

Classifica o resultado em seis categorias operacionais:
  - compilou limpo
  - compilou com erros
  - reorg necessária detectada
  - timeout em KB grande
  - KB inacessível
  - operação concluída, pendente de confirmação funcional

Por padrão, FailIfReorg=true bloqueia o build se reorganização for necessária, sem executá-la.
Reorg só ocorre quando -AllowReorg é passado e o usuário confirma interativamente.

.PARAMETER KbPath
Caminho da KB a ser usada no build.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários desta execução.

.PARAMETER LogPath
Caminho completo do log JSON desta execução.

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, usa fallback do probe.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, usa fallback do probe.

.PARAMETER VersionName
Nome opcional da versão a posicionar antes do build.

.PARAMETER EnvironmentName
Nome opcional do Environment a posicionar antes do build.

.PARAMETER ForceRebuild
Quando true, força a regeneração mesmo que o objeto não tenha mudado. Default: false.

.PARAMETER CompileMains
Quando true, compila também os objetos Main além do Developer Menu. Default: false.

.PARAMETER DetailedNavigation
Quando true, executa navegação detalhada. Default: false.

.PARAMETER FailIfReorg
Quando true, bloqueia o build se reorganização for necessária sem executá-la. Default: true.
Não pode ser definido como false sem usar -AllowReorg — a tentativa é bloqueada por política.

.PARAMETER DoNotExecuteReorg
Quando true, gera o script de reorg sem executá-lo. Default: false.
Ignorado quando FailIfReorg=true porque o build falha antes de chegar à reorg.

.PARAMETER AllowReorg
Switch. Quando presente, sobrescreve FailIfReorg para false e DoNotExecuteReorg para false,
e exige confirmação interativa antes de prosseguir. É a única forma autorizada de habilitar
a execução da reorganização do banco de dados.

.PARAMETER TimeoutSeconds
Segundos máximos de espera pelo MSBuild. Default 0 = sem timeout.
Quando excedido, o processo MSBuild é encerrado e o resultado é classificado como
'timeout em KB grande'. MSBuild pode ainda estar em execução após o encerramento.

.PARAMETER Configuration
Configuração de build a aplicar antes do BuildAll. Valores válidos: Release, Debug,
Performance Test. Quando omitido, a configuração ativa da KB é mantida sem alteração.
Emite SetConfiguration imediatamente antes do BuildAll.

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
    [string]$CompileMains = 'false',

    [ValidateSet('true', 'false')]
    [string]$DetailedNavigation = 'false',

    [ValidateSet('Release', 'Debug', 'Performance Test')]
    [string]$Configuration,

    [ValidateSet('true', 'false')]
    [string]$FailIfReorg = 'true',

    [ValidateSet('true', 'false')]
    [string]$DoNotExecuteReorg = 'false',

    [switch]$AllowReorg,

    [int]$TimeoutSeconds = 0,

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
    $artifactDirectory = Join-Path $baseDirectory ('gx-buildall-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function New-MsBuildProjectContent {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedKbPath,
        [string]$EffectiveFailIfReorg,
        [string]$EffectiveDoNotExecuteReorg
    )

    $targetsPath = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    $targetsEscaped            = Escape-Xml -Value $targetsPath
    $kbPathEscaped             = Escape-Xml -Value $ResolvedKbPath
    $versionEscaped            = Escape-Xml -Value $VersionName
    $environmentEscaped        = Escape-Xml -Value $EnvironmentName
    $forceRebuildEscaped       = Escape-Xml -Value $ForceRebuild
    $compileMainsEscaped       = Escape-Xml -Value $CompileMains
    $detailedNavigationEscaped = Escape-Xml -Value $DetailedNavigation
    $configurationEscaped      = Escape-Xml -Value $Configuration
    $failIfReorgEscaped        = Escape-Xml -Value $EffectiveFailIfReorg
    $doNotExecuteReorgEscaped  = Escape-Xml -Value $EffectiveDoNotExecuteReorg

    return @"
<Project ToolsVersion="Current" DefaultTargets="Run" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$targetsEscaped" />

  <PropertyGroup>
    <KBPath>$kbPathEscaped</KBPath>
    <KBVersion>$versionEscaped</KBVersion>
    <KBEnvironment>$environmentEscaped</KBEnvironment>
    <ForceRebuild>$forceRebuildEscaped</ForceRebuild>
    <CompileMains>$compileMainsEscaped</CompileMains>
    <DetailedNavigation>$detailedNavigationEscaped</DetailedNavigation>
    <FailIfReorg>$failIfReorgEscaped</FailIfReorg>
    <DoNotExecuteReorg>$doNotExecuteReorgEscaped</DoNotExecuteReorg>
    <KBConfiguration>$configurationEscaped</KBConfiguration>
  </PropertyGroup>

  <Target Name="CloseOnError">
    <CloseKnowledgeBase ContinueOnError="WarnAndContinue" />
  </Target>

  <Target Name="Run">
    <OpenKnowledgeBase Directory="`$(KBPath)" CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="OpenOutput" />
    </OpenKnowledgeBase>
    <Message Text="__KB_OPEN__=true" Importance="High" />
    <SetActiveVersion Condition="'`$(KBVersion)' != ''" VersionName="`$(KBVersion)" />
    <SetActiveEnvironment Condition="'`$(KBEnvironment)' != ''" EnvironmentName="`$(KBEnvironment)" />
    <GetActiveVersion CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveVersionOutput" />
    </GetActiveVersion>
    <GetActiveEnvironment CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveEnvironmentOutput" />
    </GetActiveEnvironment>
    <SetConfiguration Condition="'`$(KBConfiguration)' != ''" Configuration="`$(KBConfiguration)" />
    <BuildAll
        ForceRebuild="`$(ForceRebuild)"
        CompileMains="`$(CompileMains)"
        DetailedNavigation="`$(DetailedNavigation)"
        FailIfReorg="`$(FailIfReorg)"
        DoNotExecuteReorg="`$(DoNotExecuteReorg)"
        CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="BuildOutput" />
    </BuildAll>
    <Message Text="__BUILDALL_DONE__=true" Importance="High" />
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
    $process = Start-Process -FilePath $ResolvedMsBuildPath -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $MsBuildFilePath) -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath -NoNewWindow -PassThru

    if ($TimeoutSeconds -gt 0) {
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            try { $process.Kill() } catch { }
            Add-StrategyTrace -Message ('MSBuild encerrado por timeout após {0} segundos.' -f $TimeoutSeconds)
            return [ordered]@{ ExitCode = -1; TimedOut = $true }
        }
    } else {
        $process.WaitForExit()
    }

    return [ordered]@{ ExitCode = $process.ExitCode; TimedOut = $false }
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
        [bool]$KbOpen,
        [bool]$BuildAllDone,
        [bool]$ReorgDetected,
        [bool]$TimedOut
    )

    if ($TimedOut) {
        return [ordered]@{
            Status   = 'timeout em KB grande'
            Summary  = 'O wrapper encerrou por timeout. MSBuild pode ainda estar em execucao. Distinguir timeout do invocador de falha real do MSBuild antes de concluir sobre o resultado.'
            ExitCode = 43
        }
    }

    if (-not $KbOpen) {
        return [ordered]@{
            Status   = 'KB inacessivel'
            Summary  = 'OpenKnowledgeBase falhou antes do build. Verifique KbPath, permissoes e integridade da KB.'
            ExitCode = 40
        }
    }

    if ($KbOpen -and -not $BuildAllDone -and $ReorgDetected) {
        return [ordered]@{
            Status   = 'reorg necessaria detectada'
            Summary  = 'FailIfReorg bloqueou o build. Reorganizacao do banco detectada mas nao executada. Decida o proximo passo: executar reorg com -AllowReorg ou abrir a KB na IDE.'
            ExitCode = 44
        }
    }

    if ($MsBuildExitCode -eq 0 -and $BuildAllDone) {
        return [ordered]@{
            Status   = 'compilou limpo'
            Summary  = 'BuildAll concluiu sem erro e sem reorg detectada.'
            ExitCode = 0
        }
    }

    if ($MsBuildExitCode -eq 0 -and -not $BuildAllDone) {
        return [ordered]@{
            Status   = 'operacao concluida, pendente de confirmacao funcional'
            Summary  = 'MSBuild retornou exitCode 0 mas o marcador de conclusao do BuildAll nao foi detectado. Validacao funcional depende de inspecao na IDE.'
            ExitCode = 0
        }
    }

    return [ordered]@{
        Status   = 'compilou com erros'
        Summary  = 'BuildAll falhou. Verifique stdout e stderr para detalhes dos erros de compilacao ou specify.'
        ExitCode = 45
    }
}

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings        = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace   = New-Object System.Collections.Generic.List[string]

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

try {
    # Gate de segurança: FailIfReorg=false sem -AllowReorg é bloqueado por política
    if ($FailIfReorg -eq 'false' -and -not $AllowReorg.IsPresent) {
        Add-BlockingReason -Reason 'FailIfReorg=false so pode ser habilitado via -AllowReorg com confirmacao interativa explicita. Execute novamente passando -AllowReorg.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = 'FailIfReorg=false requer -AllowReorg e confirmacao interativa. Execute novamente com -AllowReorg.'
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration       = $Configuration
                FailIfReorg         = $FailIfReorg
                DoNotExecuteReorg   = $DoNotExecuteReorg
                AllowReorgRequested = $false
            }
            observedContext  = [ordered]@{
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
            }
            resolvedPaths    = [ordered]@{
                GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
                MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
                KbPath           = (Get-FullPathSafe -PathValue $KbPath)
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath          = $resolvedLogPath
            }
            pathActions      = [ordered]@{ WorkingDirectory = 'blocked-policy' }
            artifacts        = [ordered]@{
                ProbeLogPath     = $null
                MsBuildFilePath  = $null
                StdOutPath       = $null
                StdErrPath       = $null
                ExecutionLogPath = $resolvedLogPath
            }
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath) -and -not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            $parent = [System.IO.Path]::GetDirectoryName($resolvedLogPath)
            if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
                Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
            }
        }
        Write-Output $blockedJson
        exit 46
    }

    if ($VerboseLog.IsPresent) {
        Add-StrategyTrace -Message 'VerboseLog habilitado para detalhamento adicional.'
    }

    $artifactDirectory = New-ArtifactDirectory
    $probeLogPath = Join-Path $artifactDirectory 'probe-stage.json'
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath

    Add-StrategyTrace -Message ('Probe executado antes do build com exitCode {0}.' -f $probeStage.ExitCode)

    if ($probeStage.ExitCode -ne 0) {
        Add-BlockingReason -Reason 'Probe nao apto para prosseguir bloqueou o build.'
        $probeDiagnostic = $probeStage.Diagnostic
        $blocked = [ordered]@{
            status           = 'nao apto para prosseguir'
            summary          = 'Probe bloqueou o build.'
            exitCode         = $probeStage.ExitCode
            stage            = 'probe'
            requestedContext = [ordered]@{
                VersionName                = $VersionName
                EnvironmentName            = $EnvironmentName
                ForceRebuild               = $ForceRebuild
                CompileMains               = $CompileMains
                DetailedNavigation         = $DetailedNavigation
                Configuration              = $Configuration
                EffectiveFailIfReorg       = $FailIfReorg
                EffectiveDoNotExecuteReorg = $DoNotExecuteReorg
                AllowReorgRequested        = $AllowReorg.IsPresent
                AllowReorgConfirmed        = $false
                TimeoutSeconds             = $TimeoutSeconds
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
                ProbeLogPath     = $probeLogPath
                MsBuildFilePath  = $null
                StdOutPath       = $null
                StdErrPath       = $null
                ExecutionLogPath = $resolvedLogPath
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

    # Resolver parâmetros efetivos de reorg
    $effectiveFailIfReorg       = $FailIfReorg
    $effectiveDoNotExecuteReorg = $DoNotExecuteReorg
    $allowReorgConfirmed        = $false

    if ($AllowReorg.IsPresent) {
        Write-Host ''
        Write-Host 'AVISO: O parametro -AllowReorg foi especificado.'
        Write-Host ''
        Write-Host ('KB alvo:      {0}' -f $resolvedKbPath)
        Write-Host ('GeneXusDir:   {0}' -f $resolvedGeneXusDir)
        Write-Host ''
        Write-Host 'A reorganizacao do banco de dados sera executada se o GeneXus detectar'
        Write-Host 'alteracoes estruturais pendentes. Esta operacao altera permanentemente'
        Write-Host 'o esquema do banco de dados e nao pode ser desfeita automaticamente.'
        Write-Host ''
        $confirmation = Read-Host 'Confirma a execucao com reorg habilitada? (sim para confirmar, qualquer outra entrada cancela)'

        if ($confirmation -notin @('sim', 'SIM', 'Sim', 's', 'S')) {
            Add-BlockingReason -Reason 'Reorg nao confirmada pelo usuario. Execucao cancelada por seguranca.'
            $aborted = [ordered]@{
                status           = 'cancelado pelo usuario'
                summary          = 'Execucao com reorg nao confirmada pelo usuario. Build cancelado por seguranca.'
                exitCode         = 47
                stage            = 'pre-build'
                requestedContext = [ordered]@{
                    VersionName                = $VersionName
                    EnvironmentName            = $EnvironmentName
                    ForceRebuild               = $ForceRebuild
                    CompileMains               = $CompileMains
                    DetailedNavigation         = $DetailedNavigation
                    Configuration              = $Configuration
                    EffectiveFailIfReorg       = $effectiveFailIfReorg
                    EffectiveDoNotExecuteReorg = $effectiveDoNotExecuteReorg
                    AllowReorgRequested        = $true
                    AllowReorgConfirmed        = $false
                    TimeoutSeconds             = $TimeoutSeconds
                }
                observedContext  = [ordered]@{
                    ActiveVersion     = $null
                    ActiveEnvironment = $null
                    KbOpen            = $false
                    BuildAllDone      = $false
                    ReorgDetected     = $false
                    TimedOut          = $false
                    MsBuildExitCode   = $null
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
                    MsBuildFilePath  = $null
                    StdOutPath       = $null
                    StdErrPath       = $null
                    ExecutionLogPath = $resolvedLogPath
                }
                blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
                warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
                strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
            }
            $abortedJson = ConvertTo-JsonText -InputObject $aborted
            if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
                Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $abortedJson
            }
            Write-Output $abortedJson
            exit 47
        }

        $effectiveFailIfReorg       = 'false'
        $effectiveDoNotExecuteReorg = 'false'
        $allowReorgConfirmed        = $true
        Add-StrategyTrace -Message 'AllowReorg confirmado pelo usuario. FailIfReorg=false, DoNotExecuteReorg=false habilitados.'
    }

    if ($TimeoutSeconds -gt 0) {
        Add-StrategyTrace -Message ('Timeout configurado: {0} segundos.' -f $TimeoutSeconds)
    } else {
        Add-StrategyTrace -Message 'Sem timeout configurado. MSBuild aguardado por tempo indeterminado.'
    }

    if ([string]::IsNullOrEmpty($Configuration)) {
        Add-StrategyTrace -Message 'Configuration nao especificada. Configuracao ativa da KB sera mantida sem alteracao.'
    } else {
        Add-StrategyTrace -Message ('Configuration especificada: {0}. SetConfiguration sera emitido imediatamente antes do BuildAll.' -f $Configuration)
    }

    $msBuildFilePath = Join-Path $artifactDirectory 'buildall.msbuild'
    $stdOutPath      = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath      = Join-Path $artifactDirectory 'msbuild.stderr.log'

    $projectContent = New-MsBuildProjectContent `
        -ResolvedGeneXusDir $resolvedGeneXusDir `
        -ResolvedKbPath $resolvedKbPath `
        -EffectiveFailIfReorg $effectiveFailIfReorg `
        -EffectiveDoNotExecuteReorg $effectiveDoNotExecuteReorg

    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))
    Add-StrategyTrace -Message ('Arquivo .msbuild temporario gerado em: {0}' -f $msBuildFilePath)

    $msBuildResult   = Invoke-MsBuildFile -ResolvedMsBuildPath $resolvedMsBuildPath -MsBuildFilePath $msBuildFilePath -StdOutPath $stdOutPath -StdErrPath $stdErrPath
    $msBuildExitCode = $msBuildResult.ExitCode
    $timedOut        = $msBuildResult.TimedOut

    $stdOutText = Read-TextFileSafe -PathValue $stdOutPath
    $stdErrText = Read-TextFileSafe -PathValue $stdErrPath

    $kbOpenMarker     = Get-MarkerValue -Text $stdOutText -Marker '__KB_OPEN__='
    $buildAllDoneMarker = Get-MarkerValue -Text $stdOutText -Marker '__BUILDALL_DONE__='
    $kbOpen       = ($kbOpenMarker -eq 'true')
    $buildAllDone = ($buildAllDoneMarker -eq 'true')

    # Detecta reorg pelo conteúdo do stdout/stderr (padrão GeneXus: "reorganization", "reorganizacao")
    $combinedOutput = $stdOutText + $stdErrText
    $reorgDetected  = [bool]($combinedOutput -match '(?i)reorgan')

    $activeVersionOutput     = Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'"
    $activeEnvironmentOutput = Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'"

    if (-not [string]::IsNullOrWhiteSpace($VersionName) -and [string]::IsNullOrWhiteSpace($activeVersionOutput)) {
        Add-WarningMessage -Message 'Versao solicitada, mas o retorno de GetActiveVersion veio vazio.'
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName) -and [string]::IsNullOrWhiteSpace($activeEnvironmentOutput)) {
        Add-WarningMessage -Message 'Environment solicitado, mas o retorno de GetActiveEnvironment veio vazio.'
    }

    $buildStatus = Resolve-BuildStatus `
        -MsBuildExitCode $msBuildExitCode `
        -KbOpen $kbOpen `
        -BuildAllDone $buildAllDone `
        -ReorgDetected $reorgDetected `
        -TimedOut $timedOut

    if ($buildStatus.ExitCode -ne 0) {
        Add-BlockingReason -Reason ('Execucao MSBuild terminou com exitCode {0}. Status: {1}.' -f $msBuildExitCode, $buildStatus.Status)
    }

    if ($buildStatus.Status -eq 'reorg necessaria detectada') {
        Add-WarningMessage -Message 'Recomenda-se abrir a KB na IDE para inspecionar a reorganizacao gerada antes de decidir executa-la.'
    }

    if ($buildStatus.Status -in @('compilou limpo', 'operacao concluida, pendente de confirmacao funcional')) {
        Add-WarningMessage -Message 'Recomenda-se reabrir a KB na IDE para observar warnings ou efeitos colaterais de host.'
    }

    $diagnostic = [ordered]@{
        status           = $buildStatus.Status
        summary          = $buildStatus.Summary
        exitCode         = $buildStatus.ExitCode
        stage            = 'build-all'
        requestedContext = [ordered]@{
            VersionName                = $VersionName
            EnvironmentName            = $EnvironmentName
            ForceRebuild               = $ForceRebuild
            CompileMains               = $CompileMains
            DetailedNavigation         = $DetailedNavigation
            Configuration              = $Configuration
            EffectiveFailIfReorg       = $effectiveFailIfReorg
            EffectiveDoNotExecuteReorg = $effectiveDoNotExecuteReorg
            AllowReorgRequested        = $AllowReorg.IsPresent
            AllowReorgConfirmed        = $allowReorgConfirmed
            TimeoutSeconds             = $TimeoutSeconds
        }
        observedContext  = [ordered]@{
            ActiveVersion     = $activeVersionOutput
            ActiveEnvironment = $activeEnvironmentOutput
            KbOpen            = $kbOpen
            BuildAllDone      = $buildAllDone
            ReorgDetected     = $reorgDetected
            TimedOut          = $timedOut
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
    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json
    Write-Output $json
    exit $buildStatus.ExitCode
}
catch {
    $failure = [ordered]@{
        status           = 'falha operacional'
        summary          = 'Falha interna do script antes de concluir o build.'
        exitCode         = 90
        stage            = 'build-all'
        requestedContext = [ordered]@{
            VersionName                = $VersionName
            EnvironmentName            = $EnvironmentName
            ForceRebuild               = $ForceRebuild
            CompileMains               = $CompileMains
            DetailedNavigation         = $DetailedNavigation
            Configuration              = $Configuration
            EffectiveFailIfReorg       = $FailIfReorg
            EffectiveDoNotExecuteReorg = $DoNotExecuteReorg
            AllowReorgRequested        = $AllowReorg.IsPresent
            AllowReorgConfirmed        = $false
            TimeoutSeconds             = $TimeoutSeconds
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
