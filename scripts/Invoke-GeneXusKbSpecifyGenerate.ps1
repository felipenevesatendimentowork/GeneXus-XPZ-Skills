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
Quando true, força a regeneração de TODOS os objetos da KB, independentemente de mudança.
Equivale a "Rebuild All" da IDE (não a "Build All"): muda a semântica de SpecifyAll/GenerateOnly
incremental para regeneração total. Em KB grande pode durar horas e regenerar centenas/milhares
de objetos, incluindo subtype groups. Default: false.

Operação ampla bloqueada por política: ForceRebuild=true só pode ser usado em conjunto com
-AllowWideRebuild e confirmação explícita por frase exata do usuário (modo interativo) ou
-AllowWideRebuild -ConfirmWideRebuild (modo não-interativo). Tentativa sem -AllowWideRebuild
é bloqueada com exit 46.

.PARAMETER DetailedNavigation
Quando true, executa navegação detalhada. Default: false.

.PARAMETER AllowWideRebuild
Switch. Único caminho autorizado para habilitar -ForceRebuild true. Em modo interativo
(sem -ConfirmWideRebuild), exige que o usuário digite no terminal a frase exata:
    entendo que isto pode regerar a KB inteira e aceito o custo
Em modo não-interativo (com -ConfirmWideRebuild), a confirmação é feita pelo chamador
via parâmetro. Sem este switch, -ForceRebuild true é bloqueado por política (exit 46).

.PARAMETER ConfirmWideRebuild
Switch. Usado em conjunto com -AllowWideRebuild para dispensar o Read-Host interativo
da frase de confirmação. Destina-se exclusivamente a processos desanexados onde não
há terminal disponível. Usar -ConfirmWideRebuild sem -AllowWideRebuild é bloqueado
por política (exit 46). O chamador é responsável por obter confirmação explícita do
usuário humano com a frase exata antes de passar -ConfirmWideRebuild — este parâmetro
não dispensa a confirmação, apenas muda o canal.

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

    [switch]$AllowWideRebuild,

    [switch]$ConfirmWideRebuild,

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

function Split-NonEmptyLines {
    param([string]$Text)
    # Preserva tipagem [string[]] mesmo quando o resultado tem 0 ou 1 elemento.
    # Sem isso, o PowerShell faz unwrapping em propriedade de hashtable:
    #   0 elementos -> $null (JSON: null)
    #   1 elemento  -> string solta (JSON: string em vez de array)
    # Duas quirks distintas a tratar:
    #   - 1+ elementos: `, $result` impede o unwrapping no retorno
    #   - 0 elementos: `[string[]]$x = @()` vira `$null`; usar [string[]]::new(0) explicito
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ,([string[]]::new(0))
    }
    [string[]]$result = @($Text -split "(`r`n|`n|`r)" |
                          Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    return ,$result
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

    # Eventos pós-build detectados (start c:, start cmd, e variantes prefixadas com REM
    # quando o GeneXus encena comandos que tentou rodar mas falharam, ex.: .Bat ausente).
    # KB configurada com ações pós-build que disparam (ou tentam disparar) processos externos.
    # Registrar como warning mesmo quando a classificação principal for bem-sucedida.
    $postBuildLines = @($StdOutText -split "`r?`n" |
                        Where-Object { $_ -match '^\s*(REM\s+)?start\s+(c:|cmd)' })
    if ($postBuildLines.Count -gt 0) {
        foreach ($evtLine in $postBuildLines) {
            $trimmed = $evtLine.Trim()
            $shown = if ($trimmed -match '^(?i)REM\s+') { "(commented) $trimmed" } else { $trimmed }
            Add-WarningMessage -Message ('Evento pós-build detectado em stdout: "{0}". A KB disparou (ou tentou disparar) processos externos durante o SpecifyAll.' -f $shown)
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
$script:PathEnrichment  = [ordered]@{
    applied        = $false
    subdirsAdded   = @()
    subdirsSkipped = @()
}

$confirmWideRebuildMode    = $null
$allowWideRebuildConfirmed = $false

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

try {
    # Gate de segurança: -ConfirmWideRebuild sem -AllowWideRebuild não tem sentido e é bloqueado por política
    if ($ConfirmWideRebuild.IsPresent -and -not $AllowWideRebuild.IsPresent) {
        Add-BlockingReason -Reason '-ConfirmWideRebuild so pode ser usado em conjunto com -AllowWideRebuild. Para confirmar regeneracao ampla interativamente, use apenas -AllowWideRebuild. Para modo nao-interativo, use -AllowWideRebuild -ConfirmWideRebuild apos confirmar a operacao com o usuario humano.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = '-ConfirmWideRebuild requer -AllowWideRebuild. Execute novamente com -AllowWideRebuild -ConfirmWideRebuild apos confirmar a operacao com o usuario humano.'
            exitCode         = 46
            stage            = 'pre-specify-generate'
            requestedContext = [ordered]@{
                VersionName                = $VersionName
                EnvironmentName            = $EnvironmentName
                ForceRebuild               = $ForceRebuild
                DetailedNavigation         = $DetailedNavigation
                AllowWideRebuildRequested  = $false
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
                pathEnrichment    = $script:PathEnrichment
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

    # Gate de segurança: -ForceRebuild=true sem -AllowWideRebuild é bloqueado por política
    # ForceRebuild=true muda SpecifyAll/GenerateOnly de incremental para regeneracao total
    # de TODOS os objetos da KB. Em KB grande pode levar horas e regenerar centenas/milhares.
    if ($ForceRebuild -eq 'true' -and -not $AllowWideRebuild.IsPresent) {
        Add-BlockingReason -Reason 'ForceRebuild=true muda SpecifyAll/GenerateOnly de incremental para regeneracao TOTAL de todos os objetos da KB. Em KB grande pode levar horas e regenerar centenas/milhares de objetos. So pode ser habilitado via -AllowWideRebuild com confirmacao explicita do usuario. Para verificacao incremental, omita ForceRebuild ou use ForceRebuild=false.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = 'ForceRebuild=true requer -AllowWideRebuild e confirmacao explicita do usuario por frase exata. Para verificacao incremental, omita ForceRebuild.'
            exitCode         = 46
            stage            = 'pre-specify-generate'
            requestedContext = [ordered]@{
                VersionName                = $VersionName
                EnvironmentName            = $EnvironmentName
                ForceRebuild               = $ForceRebuild
                DetailedNavigation         = $DetailedNavigation
                AllowWideRebuildRequested  = $false
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
                pathEnrichment    = $script:PathEnrichment
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
                VersionName                = $VersionName
                EnvironmentName            = $EnvironmentName
                ForceRebuild               = $ForceRebuild
                DetailedNavigation         = $DetailedNavigation
                AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
                pathEnrichment    = $script:PathEnrichment
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

    # Enriquecer $env:PATH com subdirs do GeneXus que hospedam tools chamadas internamente
    # por Process.Start sem caminho absoluto (gxexec, UpdConfigWeb, BuildService, Reor.exe).
    # Ver nota detalhada no wrapper irmao Invoke-GeneXusKbBuildAll.ps1. Em SpecifyGenerate
    # puro (sem compile) a falha pode aparecer se SpecifyAll disparar reorg internamente.
    $gxSubPathCandidates = @(
        $resolvedGeneXusDir,
        (Join-Path $resolvedGeneXusDir 'gxnet'),
        (Join-Path $resolvedGeneXusDir 'gxnet\bin'),
        (Join-Path $resolvedGeneXusDir 'gxnetcore')
    )
    $gxSubPathsAdded   = @($gxSubPathCandidates | Where-Object { Test-Path -LiteralPath $_ })
    $gxSubPathsSkipped = @($gxSubPathCandidates | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($gxSubPathsAdded.Count -gt 0) {
        $env:PATH = ($gxSubPathsAdded -join ';') + ';' + $env:PATH
    }
    $script:PathEnrichment = [ordered]@{
        applied        = ($gxSubPathsAdded.Count -gt 0)
        subdirsAdded   = $gxSubPathsAdded
        subdirsSkipped = $gxSubPathsSkipped
    }
    if ($gxSubPathsSkipped.Count -gt 0) {
        Add-WarningMessage -Message ("Subdirs esperados do GeneXus ausentes em '{0}': {1}. Instalacao pode estar nao-padrao; tools internas chamadas por Process.Start sem caminho absoluto (gxexec, UpdConfigWeb) podem falhar." -f $resolvedGeneXusDir, ($gxSubPathsSkipped -join ', '))
    }
    Add-StrategyTrace -Message ("PATH enriquecido com subdirs do GeneXus para tools internas: [{0}]. Subdirs ausentes: [{1}]." -f ($gxSubPathsAdded -join ', '), ($gxSubPathsSkipped -join ', '))

    # Confirmação explícita de regeneração ampla (ForceRebuild=true + -AllowWideRebuild)
    # -AllowWideRebuild so autoriza ForceRebuild=true; sozinho com ForceRebuild=false e redundante.
    if ($ForceRebuild -eq 'true' -and $AllowWideRebuild.IsPresent) {
        if ($ConfirmWideRebuild.IsPresent) {
            $allowWideRebuildConfirmed = $true
            $confirmWideRebuildMode    = 'parameter'
            Add-StrategyTrace -Message 'AllowWideRebuild confirmado via -ConfirmWideRebuild (modo nao-interativo). ForceRebuild=true autorizado.'
        } else {
            $confirmWideRebuildMode = 'interactive'
            Write-Host ''
            Write-Host 'AVISO: O parametro -AllowWideRebuild foi especificado e ForceRebuild=true.'
            Write-Host ''
            Write-Host ('KB alvo:      {0}' -f $resolvedKbPath)
            Write-Host ('GeneXusDir:   {0}' -f $resolvedGeneXusDir)
            Write-Host ''
            Write-Host 'ForceRebuild=true muda SpecifyAll/GenerateOnly de incremental para regeneracao'
            Write-Host 'TOTAL de TODOS os objetos da KB. Em KB grande pode levar horas e regenerar'
            Write-Host 'centenas/milhares de objetos, incluindo subtype groups.'
            Write-Host ''
            Write-Host 'Para confirmar, digite EXATAMENTE a frase abaixo (sem aspas):'
            Write-Host '    entendo que isto pode regerar a KB inteira e aceito o custo'
            Write-Host ''
            $wideRebuildConfirmation = Read-Host 'Confirmacao'

            if ($wideRebuildConfirmation -ne 'entendo que isto pode regerar a KB inteira e aceito o custo') {
                Add-BlockingReason -Reason 'Regeneracao ampla (ForceRebuild=true) nao confirmada pelo usuario com a frase exata. Execucao cancelada por seguranca.'
                $aborted = [ordered]@{
                    status           = 'cancelado pelo usuario'
                    summary          = 'Regeneracao ampla nao confirmada pelo usuario. SpecifyAll/GenerateOnly cancelado por seguranca.'
                    exitCode         = 47
                    stage            = 'pre-specify-generate'
                    requestedContext = [ordered]@{
                        VersionName                = $VersionName
                        EnvironmentName            = $EnvironmentName
                        ForceRebuild               = $ForceRebuild
                        DetailedNavigation         = $DetailedNavigation
                        AllowWideRebuildRequested  = $true
                        AllowWideRebuildConfirmed  = $false
                        ConfirmWideRebuildMode     = $confirmWideRebuildMode
                    }
                    observedContext  = [ordered]@{
                        ActiveVersion     = $null
                        ActiveEnvironment = $null
                        SpecifyDone       = $false
                        GenerateDone      = $false
                        pathEnrichment    = $script:PathEnrichment
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

            $allowWideRebuildConfirmed = $true
            Add-StrategyTrace -Message 'AllowWideRebuild confirmado pelo usuario interativamente via frase exata. ForceRebuild=true autorizado.'
        }
    } elseif ($AllowWideRebuild.IsPresent) {
        Add-WarningMessage -Message '-AllowWideRebuild foi informado, mas ForceRebuild=false; o autorizador e redundante neste cenario (nenhuma regeneracao ampla foi solicitada). Para regenerar a KB inteira, passar tambem -ForceRebuild true.'
        Add-StrategyTrace -Message '-AllowWideRebuild redundante: ForceRebuild=false, nenhuma regeneracao ampla a confirmar.'
    }

    $msBuildFilePath = Join-Path $artifactDirectory 'specifygenerate.msbuild'
    $stdOutPath      = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath      = Join-Path $artifactDirectory 'msbuild.stderr.log'

    $projectContent = New-MsBuildProjectContent -ResolvedGeneXusDir $resolvedGeneXusDir -ResolvedKbPath $resolvedKbPath
    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))
    Add-StrategyTrace -Message ('Arquivo .msbuild temporário gerado em: {0}' -f $msBuildFilePath)

    $msBuildExitCode = Invoke-MsBuildFile -ResolvedMsBuildPath $resolvedMsBuildPath -MsBuildFilePath $msBuildFilePath -StdOutPath $stdOutPath -StdErrPath $stdErrPath
    $stdOutText = Read-TextFileSafe -PathValue $stdOutPath
    $stdErrText = Read-TextFileSafe -PathValue $stdErrPath

    # GeneXus 18 grava exatamente 3 linhas "context [anonymous] N:N attribute component
    # isn't defined" no stderr durante SpecifyAll — ruído sistêmico do modo headless;
    # a IDE absorve sem registrar. Filtrar antes de classificar.
    $stdErrFilteredNoise = @([regex]::Matches($stdErrText, '(?m)context \[anonymous\] \d+:\d+ attribute component isn''t defined') | ForEach-Object { $_.Value }) -join "`n"
    $stdErrFiltered      = ($stdErrText -replace '(?m)^context \[anonymous\] \d+:\d+ attribute component isn''t defined\r?\n?', '').Trim()

    # Ruido estrutural do dotnet publish em Program Files\GAM\Platforms\NetCore*.
    # Duas assinaturas independentes sao aceitas:
    #   1. error MSB3491 + is denied/acesso negado + caminho da instalacao do GeneXus
    #   2. NuGet.targets(...): error : + is denied/acesso negado + caminho da instalacao do GeneXus
    # Em ambos os casos o caminho deve conter \Library\GAM\Platforms\. Linhas que casam
    # uma assinatura completa sao removidas de stdout antes de classificar e listadas
    # em stdoutFilteredNoise. Linhas que casem apenas alguns criterios permanecem como
    # diagnostico legitimo.
    # Cobertura empirica: o padrao foi verificado via BuildAll em 2026-05-12 (matriz 2x2
    # KB/Environment); para SpecifyAll puro, ainda nao ha evidencia empirica de presenca
    # ou ausencia deste ruido. O filtro e idempotente: se o ruido nao aparece, nada e
    # removido; se aparecer, e removido com a mesma assinatura precisa.
    $stdOutLines             = if ([string]::IsNullOrEmpty($stdOutText)) { @() } else { $stdOutText -split "`r?`n" }
    $stdOutNoiseLines        = @()
    $stdOutNonNoiseLines     = @()
    foreach ($line in $stdOutLines) {
        $isGamAccessDenied = (($line -match 'is denied') -or ($line -match 'acesso negado')) -and
                             ($line -match '\\GeneXus\\') -and
                             ($line -match '\\Library\\GAM\\Platforms\\')
        $isGamMsb3491Noise = ($line -match 'error MSB3491') -and $isGamAccessDenied
        $isGamNuGetNoise   = ($line -match 'NuGet\.targets\(\d+,\d+\):\s*error\s*:') -and $isGamAccessDenied
        $isGamNoise        = $isGamMsb3491Noise -or $isGamNuGetNoise
        if ($isGamNoise) { $stdOutNoiseLines += $line } else { $stdOutNonNoiseLines += $line }
    }
    $stdOutFilteredNoise = ($stdOutNoiseLines -join "`n")
    $stdOutFiltered      = ($stdOutNonNoiseLines -join "`n")

    $specifyDoneMarker  = Get-MarkerValue -Text $stdOutText -Marker '__SPECIFY_DONE__='
    $generateDoneMarker = Get-MarkerValue -Text $stdOutText -Marker '__GENERATE_DONE__='
    $specifyDone  = ($specifyDoneMarker -eq 'true')
    $generateDone = ($generateDoneMarker -eq 'true')

    $setVersionFailed     = [bool]($stdOutText -match 'Set Active Version falhou')
    $setEnvironmentFailed = [bool]($stdOutText -match 'Set Active Environment falhou')

    $activeVersionOutput      = Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'"
    $activeEnvironmentOutput  = Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'"
    $missingEnvironmentOutput = Get-RegexValue -Text $stdOutText -Pattern "Ambiente '([^']+)' n[aã]o existe"

    if ($setVersionFailed) {
        $actualVersion = if (-not [string]::IsNullOrWhiteSpace($activeVersionOutput)) { $activeVersionOutput } else { '(desconhecida)' }
        Add-BlockingReason -Reason ("SetActiveVersion falhou — a versao '{0}' nao existe nesta KB. A versao ativa no momento da abertura era '{1}'. Para usar a versao ativa, omita o parametro -VersionName." -f $VersionName, $actualVersion)
    }

    if ($setEnvironmentFailed) {
        $actualEnvironment = if (-not [string]::IsNullOrWhiteSpace($activeEnvironmentOutput)) { $activeEnvironmentOutput } else { '(desconhecido)' }
        $requestedEnvironment = if (-not [string]::IsNullOrWhiteSpace($missingEnvironmentOutput)) { $missingEnvironmentOutput } else { $EnvironmentName }
        Add-BlockingReason -Reason ("SetActiveEnvironment falhou — o Environment '{0}' nao existe nesta KB. O Environment ativo no momento da abertura era '{1}'. Para usar o Environment ativo, omita o parametro -EnvironmentName." -f $requestedEnvironment, $actualEnvironment)
    }

    if (-not [string]::IsNullOrWhiteSpace($VersionName) -and [string]::IsNullOrWhiteSpace($activeVersionOutput) -and -not $setVersionFailed) {
        Add-WarningMessage -Message 'Versão solicitada, mas o retorno de GetActiveVersion veio vazio.'
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName) -and [string]::IsNullOrWhiteSpace($activeEnvironmentOutput) -and -not $setEnvironmentFailed) {
        Add-WarningMessage -Message 'Environment solicitado, mas o retorno de GetActiveEnvironment veio vazio.'
    }

    $buildStatus = Resolve-BuildStatus -MsBuildExitCode $msBuildExitCode -SpecifyDone $specifyDone -GenerateDone $generateDone -StdOutText $stdOutFiltered -StdErrText $stdErrFiltered

    $stdOutBlockingPatternRegex = 'Access denied|error MSB|: error |FAILED|at System\.|at Microsoft\.'
    $blockingPatternMatch       = [regex]::Match($stdOutFiltered, $stdOutBlockingPatternRegex)
    $detectedBlockingPattern    = if ($blockingPatternMatch.Success) { $blockingPatternMatch.Value } else { $null }

    # Inclui linhas prefixadas com REM: o GeneXus encena assim quando o comando pos-build
    # foi tentado mas falhou (ex.: .Bat ausente). Marca essas com sufixo "(commented) "
    # para o consumidor distinguir entre executou vs apenas tentou.
    $postBuildEventLines = @([regex]::Matches($stdOutFiltered, '(?im)^\s*(REM\s+)?(start\s+c:|start\s+cmd)[^\r\n]*') |
                             ForEach-Object {
                                 $value = $_.Value.Trim()
                                 if ($value -match '^(?i)REM\s+') { "(commented) $value" } else { $value }
                             })

    $buildWarningLines   = @([regex]::Matches($stdOutFiltered, '(?m)[^\r\n]*\(\d+,\d+\)\s*:\s*warning\s*:[^\r\n]*') |
                             ForEach-Object { $_.Value.Trim() })

    # Promover warnings pmm00xx (versao de modulo GeneXus) a alertas top-level.
    # pmm00xx aparecem em buildWarnings mas o usuario nao costuma inspecionar essa
    # lista interna. Surfacing-los em warnings garante visibilidade no resumo do
    # JSON. Resolucao tipica: 'Update Modules' na IDE. pmm0045 (inversao de versao)
    # merece texto mais explicito porque sinaliza estado nao trivial (modulo
    # satelite exige versao MAIS NOVA do modulo principal do que a instalada).
    foreach ($wLine in $buildWarningLines) {
        if ($wLine -match 'warning\s*:\s*(pmm\d{4}):\s*([^\r\n]+)') {
            $pmmCode = $matches[1]
            $pmmMsg  = $matches[2].Trim()
            if ($pmmCode -eq 'pmm0045') {
                Add-WarningMessage -Message "Alerta de inversao de versao de modulo ($pmmCode): $pmmMsg Modulo satelite exige versao MAIS NOVA do modulo principal — pode exigir update do GeneXus instalado ou downgrade de modulos da KB. Inspecionar via 'Update Modules' na IDE."
            } else {
                Add-WarningMessage -Message "Alerta de versao de modulo ($pmmCode): $pmmMsg Resolver via 'Update Modules' na IDE."
            }
        }
    }

    if ($buildStatus.ExitCode -ne 0 -and $script:BlockingReasons.Count -eq 0) {
        Add-BlockingReason -Reason 'MSBuild falhou sem causa acionável classificada; consulte executionEvidence e logs brutos nos artefatos.'
    }

    $diagnostic = [ordered]@{
        status           = $buildStatus.Status
        summary          = $buildStatus.Summary
        exitCode         = $buildStatus.ExitCode
        executionEvidence = [ordered]@{
            msBuildExitCode = $msBuildExitCode
            msBuildFailed = ($msBuildExitCode -ne 0)
            wrapperExitCode = $buildStatus.ExitCode
            StdOutPath = $stdOutPath
            StdErrPath = $stdErrPath
        }
        stage            = 'specify-generate'
        requestedContext = [ordered]@{
            VersionName                = $VersionName
            EnvironmentName            = $EnvironmentName
            ForceRebuild               = $ForceRebuild
            DetailedNavigation         = $DetailedNavigation
            AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
            AllowWideRebuildConfirmed  = $allowWideRebuildConfirmed
            ConfirmWideRebuildMode     = $confirmWideRebuildMode
        }
        observedContext  = [ordered]@{
            ActiveVersion     = $activeVersionOutput
            ActiveEnvironment = $activeEnvironmentOutput
            SpecifyDone       = $specifyDone
            GenerateDone      = $generateDone
            MsBuildExitCode   = $msBuildExitCode
            pathEnrichment    = $script:PathEnrichment
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
        stdoutSignals        = [ordered]@{
            blockingPattern = $detectedBlockingPattern
            postBuildEvents = $postBuildEventLines
            buildWarnings   = $buildWarningLines
        }
        stdoutFilteredNoise  = Split-NonEmptyLines -Text $stdOutFilteredNoise
        stderrContent        = Split-NonEmptyLines -Text $stdErrFiltered
        stderrFilteredNoise  = Split-NonEmptyLines -Text $stdErrFilteredNoise
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
            VersionName                = $VersionName
            EnvironmentName            = $EnvironmentName
            ForceRebuild               = $ForceRebuild
            DetailedNavigation         = $DetailedNavigation
            AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
            AllowWideRebuildConfirmed  = $allowWideRebuildConfirmed
            ConfirmWideRebuildMode     = $confirmWideRebuildMode
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
        stdoutSignals        = [ordered]@{
            blockingPattern = $null
            postBuildEvents = @()
            buildWarnings   = @()
        }
        stdoutFilteredNoise  = @()
        stderrContent        = @()
        stderrFilteredNoise  = @()
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
