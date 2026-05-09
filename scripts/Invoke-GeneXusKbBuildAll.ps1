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

Quando -MonitorLogPath é fornecido, o script aguarda 6 segundos após o MSBuild terminar
antes de ler o arquivo — tempo necessário para Watch-GeneXusMsBuildLog.ps1 drenar as
linhas finais do log (Watch dorme 2s após detectar que o processo morreu; com intervalo
de polling de 3-5s, o pior caso é ~5s). Esse delay não é contabilizado em totalDurationSeconds.

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
Switch. Quando presente, sobrescreve FailIfReorg para false e DoNotExecuteReorg para false.
Em modo interativo (sem -ConfirmReorg), exige que o usuário digite 'sim' no terminal antes
de prosseguir. Em modo não-interativo (com -ConfirmReorg), a confirmação é feita pelo
chamador via parâmetro. É a única forma autorizada de habilitar a reorganização do banco.

.PARAMETER ConfirmReorg
Switch. Usado em conjunto com -AllowReorg para dispensar o Read-Host interativo.
Destina-se exclusivamente a processos desanexados (Start-Process) onde não há terminal
disponível — por exemplo, quando Watch-GeneXusMsBuildLog.ps1 é executado em paralelo.
Usar -ConfirmReorg sem -AllowReorg é bloqueado por política (exit 46).
O chamador é responsável por obter confirmação explícita do usuário humano antes de
passar -ConfirmReorg — este parâmetro não dispensa a confirmação, apenas muda o canal.

.PARAMETER TimeoutSeconds
Segundos máximos de espera pelo MSBuild. Default 0 = sem timeout.
Quando excedido, o processo MSBuild é encerrado e o resultado é classificado como
'timeout em KB grande'. MSBuild pode ainda estar em execução após o encerramento.

.PARAMETER Configuration
Configuração de build a aplicar antes do BuildAll. Valores válidos: Release, Debug,
Performance Test. Quando omitido, a configuração ativa da KB é mantida sem alteração.
Emite SetConfiguration imediatamente antes do BuildAll.

.PARAMETER MonitorLogPath
Caminho opcional do log gravado por Watch-GeneXusMsBuildLog.ps1.
Quando fornecido e o arquivo existir após o build, o script parseia os marcadores
'iniciado'/'terminado' do log do monitor para extrair os timestamps de cada fase
interna do build e popular 'timing.phases' no JSON de resultado.
Sem este parâmetro, 'timing.phases' fica vazio mas probe/msbuild/total são registrados.

.PARAMETER StartWatcher
Switch. Quando presente, o próprio wrapper dispara Watch-GeneXusMsBuildLog.ps1 em janela
visível separada antes de iniciar o MSBuild. Requer -MonitorLogPath. O watcher recebe o
PID do processo wrapper como alvo de monitoramento e o mesmo caminho de -MonitorLogPath
para gravar o log de fases. O JSON de resultado registra watcherContext.watcherLaunched
e watcherContext.watcherPid para evidência auditável. Se o watcher falhar ao iniciar,
o build prossegue com um warning — não bloqueia a execução.

.PARAMETER WatcherIntervalSeconds
Intervalo de polling em segundos do watcher. Repassado a Watch-GeneXusMsBuildLog.ps1.
Padrão: 5. Intervalo válido: 1-60.

.PARAMETER WatcherSilenceThresholdSeconds
Segundos sem nova linha no log antes de o watcher emitir alerta de silêncio.
Repassado a Watch-GeneXusMsBuildLog.ps1. Padrão: 120. Intervalo válido: 30-3600.

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

    [switch]$ConfirmReorg,

    [int]$TimeoutSeconds = 0,

    [string]$MonitorLogPath,

    [switch]$StartWatcher,

    [ValidateRange(1, 60)]
    [int]$WatcherIntervalSeconds = 5,

    [ValidateRange(30, 3600)]
    [int]$WatcherSilenceThresholdSeconds = 120,

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

function Start-WatcherProcess {
    param(
        [string]$LogFilePath,
        [string]$MonitorLogFilePath,
        [int]$Interval,
        [int]$SilenceThreshold
    )

    $scriptDirectory = Split-Path -Parent $PSCommandPath
    $watcherScript   = Join-Path $scriptDirectory 'Watch-GeneXusMsBuildLog.ps1'
    $script:WatcherContext['watcherScriptPath']     = $watcherScript
    $script:WatcherContext['watcherMonitorLogPath'] = $MonitorLogFilePath

    if (-not (Test-Path -LiteralPath $watcherScript -PathType Leaf)) {
        Add-WarningMessage -Message ('Watch-GeneXusMsBuildLog.ps1 nao localizado em: {0}. Watcher nao iniciado.' -f $watcherScript)
        $script:WatcherContext['watcherLaunchError'] = 'script nao localizado'
        return
    }

    try {
        $watchArgs = @(
            '-NoExit', '-NoProfile',
            '-File', $watcherScript,
            '-ProcessId', $PID,
            '-LogPath', $LogFilePath,
            '-MonitorLog', $MonitorLogFilePath,
            '-IntervalSeconds', $Interval,
            '-SilenceThresholdSeconds', $SilenceThreshold
        )
        $watchProc = Start-Process pwsh -ArgumentList $watchArgs -PassThru
        $script:WatcherContext['watcherLaunched'] = $true
        $script:WatcherContext['watcherPid']      = $watchProc.Id
        Add-StrategyTrace -Message ('Watcher iniciado automaticamente: PID={0}, script={1}' -f $watchProc.Id, $watcherScript)
    } catch {
        Add-WarningMessage -Message ('Falha ao iniciar watcher: {0}. Build prossegue sem watcher.' -f $_.Exception.Message)
        $script:WatcherContext['watcherLaunchError'] = $_.Exception.Message
    }
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
    <GetActiveVersion CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveVersionOutput" />
    </GetActiveVersion>
    <GetActiveEnvironment CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveEnvironmentOutput" />
    </GetActiveEnvironment>
    <SetActiveVersion Condition="'`$(KBVersion)' != ''" VersionName="`$(KBVersion)" />
    <SetActiveEnvironment Condition="'`$(KBEnvironment)' != ''" EnvironmentName="`$(KBEnvironment)" />
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

function Get-NowIso {
    return [DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz')
}

function Get-DurationSeconds {
    param([string]$StartIso, [string]$EndIso)
    if ([string]::IsNullOrWhiteSpace($StartIso) -or [string]::IsNullOrWhiteSpace($EndIso)) {
        return $null
    }
    return [int]([DateTime]::Parse($EndIso) - [DateTime]::Parse($StartIso)).TotalSeconds
}

function Get-PhaseTimings {
    param([string]$MonitorLogPath)

    if ([string]::IsNullOrWhiteSpace($MonitorLogPath) -or
        -not (Test-Path -LiteralPath $MonitorLogPath -PathType Leaf)) {
        return @()
    }

    try {
        # Leitura com FileShare.ReadWrite — Watch pode ainda estar com o arquivo aberto
        $lines = New-Object System.Collections.Generic.List[string]
        $fs = New-Object -TypeName System.IO.FileStream -ArgumentList @(
            $MonitorLogPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList @($fs, [System.Text.Encoding]::UTF8)
        try {
            $l = $reader.ReadLine()
            while ($null -ne $l) { [void]$lines.Add($l); $l = $reader.ReadLine() }
        } finally {
            $reader.Dispose()
            $fs.Dispose()
        }

        $starts = [ordered]@{}
        $phases = New-Object System.Collections.ArrayList

        foreach ($line in $lines) {
            # Formato Watch: [yyyy-MM-dd HH:mm:ss] ========== <fase> iniciado/terminado ==========
            if ($line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s+={3,}\s+(.+?)\s+(iniciado|terminado)\s+={3,}') {
                $ts       = $Matches[1]
                $rawName  = $Matches[2].Trim()
                # Chave normalizada (sem espacos) para fechar pares com grafia inconsistente
                # do GeneXus (ex.: "Get Active Version" iniciado / "GetActiveVersion" terminado).
                # O campo name no JSON usa o rawName do terminado — forma canonica do GeneXus.
                $normName = $rawName -replace '\s+', ''
                $state    = $Matches[3]
                if ($state -eq 'iniciado') {
                    # Guarda [normName] -> [ts, rawName] para recuperar o nome original do iniciado
                    # (usado apenas como fallback; terminado sobrescreve o rawName no JSON)
                    $starts[$normName] = @{ ts = $ts; rawName = $rawName }
                } elseif ($state -eq 'terminado' -and $starts.Contains($normName)) {
                    [void]$phases.Add([ordered]@{
                        name            = $rawName          # nome do terminado (forma canonica)
                        start           = $starts[$normName].ts
                        end             = $ts
                        durationSeconds = Get-DurationSeconds -StartIso $starts[$normName].ts -EndIso $ts
                    })
                    $starts.Remove($normName)
                }
            }
        }

        return @($phases)
    } catch {
        Add-WarningMessage -Message ('Get-PhaseTimings falhou: {0}' -f $_.Exception.Message)
        return @()
    }
}

function Get-TimingSection {
    # scriptEnd capturado antes do sleep para nao inflar totalDurationSeconds
    $scriptEnd = Get-NowIso

    # Aguarda Watch drenar as linhas finais do log antes de ler as fases.
    # Watch dorme 2s apos detectar que o processo morreu e so entao grava os
    # marcadores restantes. Com intervalo de polling de 3s, o pior caso e
    # ~5s apos o termino do MSBuild. 6s garante a janela completa.
    if (-not [string]::IsNullOrWhiteSpace($MonitorLogPath)) {
        Start-Sleep -Seconds 6
    }

    return [ordered]@{
        scriptStart            = $script:TimingLog['scriptStart']
        probeStart             = $script:TimingLog['probeStart']
        probeEnd               = $script:TimingLog['probeEnd']
        probeDurationSeconds   = Get-DurationSeconds -StartIso $script:TimingLog['probeStart']  -EndIso $script:TimingLog['probeEnd']
        msbuildStart           = $script:TimingLog['msbuildStart']
        msbuildEnd             = $script:TimingLog['msbuildEnd']
        msbuildDurationSeconds = Get-DurationSeconds -StartIso $script:TimingLog['msbuildStart'] -EndIso $script:TimingLog['msbuildEnd']
        scriptEnd              = $scriptEnd
        totalDurationSeconds   = Get-DurationSeconds -StartIso $script:TimingLog['scriptStart']  -EndIso $scriptEnd
        phases                 = Get-PhaseTimings -MonitorLogPath $MonitorLogPath
    }
}

function Resolve-BuildStatus {
    param(
        [int]$MsBuildExitCode,
        [bool]$KbOpen,
        [bool]$BuildAllDone,
        [bool]$ReorgDetected,
        [bool]$TimedOut,
        [bool]$AllowReorgConfirmed
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

    if ($KbOpen -and -not $BuildAllDone -and $ReorgDetected -and -not $AllowReorgConfirmed) {
        return [ordered]@{
            Status   = 'reorg necessaria detectada'
            Summary  = 'FailIfReorg bloqueou o build. Reorganizacao do banco detectada mas nao executada. Decida o proximo passo: executar reorg com -AllowReorg ou abrir a KB na IDE.'
            ExitCode = 44
        }
    }

    if ($MsBuildExitCode -eq 0 -and $BuildAllDone) {
        $cleanSummary = if ($ReorgDetected -and $AllowReorgConfirmed) {
            'BuildAll concluiu sem erro. Reorganizacao do banco executada com sucesso.'
        } else {
            'BuildAll concluiu sem erro e sem reorg detectada.'
        }
        return [ordered]@{
            Status   = 'compilou limpo'
            Summary  = $cleanSummary
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
$script:TimingLog       = [ordered]@{}
$script:WatcherContext  = [ordered]@{
    startWatcherRequested = $StartWatcher.IsPresent
    watcherLaunched       = $false
    watcherPid            = $null
    watcherMonitorLogPath = $null
    watcherScriptPath     = $null
    watcherLaunchError    = $null
}
$confirmReorgMode       = $null

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath
$script:TimingLog['scriptStart'] = Get-NowIso

try {
    # Gate de segurança: -ConfirmReorg sem -AllowReorg não tem sentido e é bloqueado por política
    if ($ConfirmReorg.IsPresent -and -not $AllowReorg.IsPresent) {
        Add-BlockingReason -Reason '-ConfirmReorg so pode ser usado em conjunto com -AllowReorg. Para confirmar reorg interativamente, use apenas -AllowReorg. Para modo nao-interativo, use -AllowReorg -ConfirmReorg.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = '-ConfirmReorg requer -AllowReorg. Execute novamente com -AllowReorg -ConfirmReorg.'
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration         = $Configuration
                FailIfReorg           = $FailIfReorg
                DoNotExecuteReorg     = $DoNotExecuteReorg
                AllowReorgRequested   = $false
                AllowReorgConfirmed   = $false
                ConfirmReorgMode      = $confirmReorgMode
                StartWatcherRequested = $StartWatcher.IsPresent
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
            watcherContext   = $script:WatcherContext
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-TimingSection
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

    # Gate de segurança: FailIfReorg=false sem -AllowReorg é bloqueado por política
    if ($FailIfReorg -eq 'false' -and -not $AllowReorg.IsPresent) {
        Add-BlockingReason -Reason 'FailIfReorg=false so pode ser habilitado via -AllowReorg com confirmacao interativa explicita. Execute novamente passando -AllowReorg.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = 'FailIfReorg=false requer -AllowReorg e confirmacao interativa. Execute novamente com -AllowReorg.'
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration         = $Configuration
                FailIfReorg           = $FailIfReorg
                DoNotExecuteReorg     = $DoNotExecuteReorg
                AllowReorgRequested   = $false
                AllowReorgConfirmed   = $false
                ConfirmReorgMode      = $confirmReorgMode
                StartWatcherRequested = $StartWatcher.IsPresent
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
            watcherContext   = $script:WatcherContext
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-TimingSection
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

    # Gate de segurança: -StartWatcher requer -MonitorLogPath
    if ($StartWatcher.IsPresent -and [string]::IsNullOrWhiteSpace($MonitorLogPath)) {
        Add-BlockingReason -Reason '-StartWatcher requer -MonitorLogPath. Forneca o caminho do log do monitor para que watcher e build possam ser conectados.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = '-StartWatcher requer -MonitorLogPath. Execute novamente informando -MonitorLogPath com o caminho do log do monitor.'
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration         = $Configuration
                FailIfReorg           = $FailIfReorg
                DoNotExecuteReorg     = $DoNotExecuteReorg
                AllowReorgRequested   = $AllowReorg.IsPresent
                AllowReorgConfirmed   = $false
                ConfirmReorgMode      = $confirmReorgMode
                StartWatcherRequested = $StartWatcher.IsPresent
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
            watcherContext   = $script:WatcherContext
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-TimingSection
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
    $script:TimingLog['probeStart'] = Get-NowIso
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath
    $script:TimingLog['probeEnd'] = Get-NowIso

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
                ConfirmReorgMode           = $confirmReorgMode
                StartWatcherRequested      = $StartWatcher.IsPresent
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
            watcherContext   = $script:WatcherContext
            blockingReasons  = @($probeDiagnostic.blockingReasons + $script:BlockingReasons)
            warnings         = @($probeDiagnostic.warnings)
            strategyTrace    = @($probeDiagnostic.strategyTrace + $script:StrategyTrace)
        }

        $blocked['timing'] = Get-TimingSection
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
        if ($ConfirmReorg.IsPresent) {
            $effectiveFailIfReorg       = 'false'
            $effectiveDoNotExecuteReorg = 'false'
            $allowReorgConfirmed        = $true
            $confirmReorgMode           = 'parameter'
            Add-StrategyTrace -Message 'AllowReorg confirmado via -ConfirmReorg (modo nao-interativo). FailIfReorg=false, DoNotExecuteReorg=false habilitados.'
        } else {
            $confirmReorgMode = 'interactive'
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
                        ConfirmReorgMode           = $confirmReorgMode
                        StartWatcherRequested      = $StartWatcher.IsPresent
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
                    watcherContext   = $script:WatcherContext
                    blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
                    warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
                    strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
                }
                $aborted['timing'] = Get-TimingSection
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
            Add-StrategyTrace -Message 'AllowReorg confirmado pelo usuario interativamente. FailIfReorg=false, DoNotExecuteReorg=false habilitados.'
        }
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

    if ($StartWatcher.IsPresent) {
        Start-WatcherProcess `
            -LogFilePath          $stdOutPath `
            -MonitorLogFilePath   $MonitorLogPath `
            -Interval             $WatcherIntervalSeconds `
            -SilenceThreshold     $WatcherSilenceThresholdSeconds
    }

    $script:TimingLog['msbuildStart'] = Get-NowIso
    $msBuildResult   = Invoke-MsBuildFile -ResolvedMsBuildPath $resolvedMsBuildPath -MsBuildFilePath $msBuildFilePath -StdOutPath $stdOutPath -StdErrPath $stdErrPath
    $script:TimingLog['msbuildEnd'] = Get-NowIso
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

    # Detecta falha de SetActiveVersion (versão informada não existe na KB)
    $setVersionFailed = [bool]($stdOutText -match 'Set Active Version falhou')

    $activeVersionOutput     = Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'"
    $activeEnvironmentOutput = Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'"

    if ($setVersionFailed) {
        $actualVersion = if (-not [string]::IsNullOrWhiteSpace($activeVersionOutput)) { $activeVersionOutput } else { '(desconhecida)' }
        Add-BlockingReason -Reason ("SetActiveVersion falhou — a versao '{0}' nao existe nesta KB. A versao ativa no momento da abertura era '{1}'. Para usar a versao ativa, omita o parametro -VersionName." -f $VersionName, $actualVersion)
    }

    if (-not [string]::IsNullOrWhiteSpace($VersionName) -and [string]::IsNullOrWhiteSpace($activeVersionOutput) -and -not $setVersionFailed) {
        Add-WarningMessage -Message 'Versao solicitada, mas o retorno de GetActiveVersion veio vazio.'
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName) -and [string]::IsNullOrWhiteSpace($activeEnvironmentOutput)) {
        Add-WarningMessage -Message 'Environment solicitado, mas o retorno de GetActiveEnvironment veio vazio.'
    }

    $buildStatus = Resolve-BuildStatus `
        -MsBuildExitCode    $msBuildExitCode `
        -KbOpen             $kbOpen `
        -BuildAllDone       $buildAllDone `
        -ReorgDetected      $reorgDetected `
        -TimedOut           $timedOut `
        -AllowReorgConfirmed $allowReorgConfirmed

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
            ConfirmReorgMode           = $confirmReorgMode
            StartWatcherRequested      = $StartWatcher.IsPresent
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
        watcherContext   = $script:WatcherContext
        stdoutSummary    = Get-TextSummary -Text $stdOutText
        stderrSummary    = Get-TextSummary -Text $stdErrText
        blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
        warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
        strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
    }

    $diagnostic['timing'] = Get-TimingSection
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
            ConfirmReorgMode           = $confirmReorgMode
            StartWatcherRequested      = $StartWatcher.IsPresent
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
        watcherContext   = $script:WatcherContext
        stdoutSummary    = @()
        stderrSummary    = @()
        blockingReasons  = @($_.Exception.Message)
        warnings         = @()
        strategyTrace    = @($script:StrategyTrace)
    }

    $failure['timing'] = Get-TimingSection
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
