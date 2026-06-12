#requires -Version 7.4

<#
.SYNOPSIS
Lança Invoke-GeneXusKbBuildAll.ps1 de forma desacoplada da sessão do agente, via Tarefa
Agendada one-shot do Windows, e sinaliza a conclusão por arquivo-sentinela.

.DESCRIPTION
Modo agente-headless desacoplado da skill xpz-msbuild-build. Resolve a fragilidade do
fluxo de janela visível para builds longos: quando o agente lança o build em segundo
plano, fechar acidentalmente a janela (ou a janela-pai do processo de fundo) derruba o
grupo inteiro de processos (wrapper + MSBuild + GeneXus), matando um BuildAll longo no
meio sem erro no log.

Este orquestrador NÃO altera Invoke-GeneXusKbBuildAll.ps1 — apenas o invoca. Em vez de
criar o build como processo filho da sessão do agente, registra uma Tarefa Agendada
one-shot cujo comando executa o wrapper de build. A tarefa roda sob o serviço do Task
Scheduler, fora da console e do job da sessão do agente: fechar qualquer janela do agente
ou encerrar o app não toca o build.

Ao final do build (sucesso OU falha), o caminho de payload escreve uma sentinela atômica
com o exitCode classificado pelo wrapper e o caminho do JSON de resultado (-LogPath). O
agente faz polling barato da existência da sentinela; quando done=true, lê o JSON pesado
do -LogPath.

Este é o fluxo OPT-IN para build longo. NÃO é o default da skill: o fluxo padrão continua
sendo a janela visível via -StartWatcher no próprio Invoke-GeneXusKbBuildAll.ps1. O modo
desacoplado é acionado por decisão consciente do usuário, sob conselho do agente quando o
build for esperado longo ou for rodar em segundo plano — o trade-off é perder a janela de
progresso ao vivo em troca de robustez a fechar janela/app.

Limitação conhecida (v1): o modo desacoplado não usa watcher, logo timing.phases no JSON
de resultado fica vazio. O monitoramento legível por arquivo permanece: o agente lê o
msbuild.stdout.log do artifact dir (progresso) e a sentinela (conclusão).

Autoridade dos gates: este orquestrador é transporte, não autoridade de política. Os gates
de reorg, wide rebuild e opções caras de build vivem no wrapper Invoke-GeneXusKbBuildAll.ps1
e continuam valendo dentro da tarefa. Repassar -AllowReorg -ConfirmReorg (e equivalentes)
quando a operação tiver sido confirmada com o usuário humano antes do lançamento, pois a
tarefa não tem terminal interativo para Read-Host.

.PARAMETER KbPath
Caminho da KB a ser usada no build. Repassado ao wrapper.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários. Repassado ao wrapper. Não pode estar sob
C:\Program Files (x86).

.PARAMETER LogPath
Caminho completo do log JSON de resultado do build. Repassado ao wrapper. Não pode estar
sob C:\Program Files (x86). A sentinela referencia este caminho.

.PARAMETER SentinelPath
Caminho do arquivo-sentinela de conclusão. Quando omitido, usa <LogPath>.sentinel. Escrito
atomicamente ao final do build (sucesso ou falha) com { done, exitCode, logPath, finishedAt }.

.PARAMETER GeneXusDir
Repassado ao wrapper quando informado.

.PARAMETER MsBuildPath
Repassado ao wrapper quando informado.

.PARAMETER VersionName
Repassado ao wrapper quando informado.

.PARAMETER EnvironmentName
Repassado ao wrapper quando informado.

.PARAMETER ForceRebuild
Repassado ao wrapper ('true'/'false'). O gate -AllowWideRebuild vive no wrapper.

.PARAMETER CompileMains
Repassado ao wrapper ('true'/'false'). O gate -AllowCostlyBuildOptions vive no wrapper.

.PARAMETER DetailedNavigation
Repassado ao wrapper ('true'/'false'). O gate -AllowCostlyBuildOptions vive no wrapper.

.PARAMETER Configuration
Repassado ao wrapper quando informado (Release, Debug, Performance Test).

.PARAMETER FailIfReorg
Repassado ao wrapper ('true'/'false'). Default do wrapper é 'true'.

.PARAMETER DoNotExecuteReorg
Repassado ao wrapper ('true'/'false').

.PARAMETER AllowReorg
Switch repassado ao wrapper. Em modo desacoplado, combinar com -ConfirmReorg.

.PARAMETER ConfirmReorg
Switch repassado ao wrapper. Dispensa o Read-Host interativo. O chamador confirma com o
usuário humano antes de lançar.

.PARAMETER AllowWideRebuild
Switch repassado ao wrapper.

.PARAMETER ConfirmWideRebuild
Switch repassado ao wrapper.

.PARAMETER AllowCostlyBuildOptions
Switch repassado ao wrapper.

.PARAMETER ConfirmCostlyBuildOptions
Switch repassado ao wrapper.

.PARAMETER TimeoutSeconds
Repassado ao wrapper. Segundos máximos de espera pelo MSBuild dentro do wrapper.

.PARAMETER ParallelKbRoot
Repassado ao wrapper quando informado.

.PARAMETER KbMetadataPath
Repassado ao wrapper quando informado.

.PARAMETER PostImportDeployValidation
Switch repassado ao wrapper.

.PARAMETER SkipDeployBinCheck
Switch repassado ao wrapper.

.PARAMETER StrictDeployBinCheck
Switch repassado ao wrapper.

.PARAMETER MaxRuntimeHours
Limite de execução da Tarefa Agendada, em horas. Default 24. Use maior para Rebuild All
em KB muito grande.

.PARAMETER RunDetachedPayload
Switch interno (uso avançado). Quando presente, o script entra no modo payload: lê
-PayloadSpecPath, executa o wrapper de build, escreve a sentinela e tenta remover a própria
tarefa. NÃO chamar diretamente — é o comando que a Tarefa Agendada executa.

.PARAMETER PayloadSpecPath
Caminho do JSON de especificação do payload (usado apenas com -RunDetachedPayload).
#>

[CmdletBinding(DefaultParameterSetName = 'Launch')]
param(
    [Parameter(ParameterSetName = 'Launch', Mandatory = $true)]
    [string]$KbPath,

    [Parameter(ParameterSetName = 'Launch', Mandatory = $true)]
    [string]$WorkingDirectory,

    [Parameter(ParameterSetName = 'Launch', Mandatory = $true)]
    [string]$LogPath,

    [Parameter(ParameterSetName = 'Launch')]
    [string]$SentinelPath,

    [Parameter(ParameterSetName = 'Launch')]
    [string]$GeneXusDir,

    [Parameter(ParameterSetName = 'Launch')]
    [string]$MsBuildPath,

    [Parameter(ParameterSetName = 'Launch')]
    [string]$VersionName,

    [Parameter(ParameterSetName = 'Launch')]
    [string]$EnvironmentName,

    [Parameter(ParameterSetName = 'Launch')]
    [ValidateSet('true', 'false')]
    [string]$ForceRebuild = 'false',

    [Parameter(ParameterSetName = 'Launch')]
    [ValidateSet('true', 'false')]
    [string]$CompileMains = 'false',

    [Parameter(ParameterSetName = 'Launch')]
    [ValidateSet('true', 'false')]
    [string]$DetailedNavigation = 'false',

    [Parameter(ParameterSetName = 'Launch')]
    [ValidateSet('Release', 'Debug', 'Performance Test')]
    [string]$Configuration,

    [Parameter(ParameterSetName = 'Launch')]
    [ValidateSet('true', 'false')]
    [string]$FailIfReorg = 'true',

    [Parameter(ParameterSetName = 'Launch')]
    [ValidateSet('true', 'false')]
    [string]$DoNotExecuteReorg = 'false',

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$AllowReorg,

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$ConfirmReorg,

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$AllowWideRebuild,

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$ConfirmWideRebuild,

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$AllowCostlyBuildOptions,

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$ConfirmCostlyBuildOptions,

    [Parameter(ParameterSetName = 'Launch')]
    [int]$TimeoutSeconds = 0,

    [Parameter(ParameterSetName = 'Launch')]
    [string]$ParallelKbRoot,

    [Parameter(ParameterSetName = 'Launch')]
    [string]$KbMetadataPath,

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$PostImportDeployValidation,

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$SkipDeployBinCheck,

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$StrictDeployBinCheck,

    [Parameter(ParameterSetName = 'Launch')]
    [ValidateRange(1, 168)]
    [int]$MaxRuntimeHours = 24,

    [Parameter(ParameterSetName = 'Payload', Mandatory = $true)]
    [switch]$RunDetachedPayload,

    [Parameter(ParameterSetName = 'Payload', Mandatory = $true)]
    [string]$PayloadSpecPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$ProgramFilesX86 = [System.IO.Path]::GetFullPath('C:\Program Files (x86)')

function Get-FullPathSafe {
    param([string]$PathValue)
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
    return [System.IO.Path]::GetFullPath($PathValue)
}

function Test-IsUnderProgramFilesX86 {
    param([string]$PathValue)
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $false }
    $fullPath = Get-FullPathSafe -PathValue $PathValue
    $candidate = $fullPath.TrimEnd('\')
    $root = $ProgramFilesX86.TrimEnd('\')
    return $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-NowIso {
    return [DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz')
}

function Write-SentinelAtomic {
    param(
        [string]$TargetSentinelPath,
        [int]$ExitCodeValue,
        [string]$ResultLogPath
    )

    $payload = [ordered]@{
        done       = $true
        exitCode   = $ExitCodeValue
        logPath    = $ResultLogPath
        finishedAt = Get-NowIso
    }
    $json = ($payload | ConvertTo-Json -Depth 4)
    $tmpPath = $TargetSentinelPath + '.tmp'
    [System.IO.File]::WriteAllText($tmpPath, $json + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
    # Rename atômico no mesmo volume; overwrite=$true substitui sentinela anterior se houver.
    [System.IO.File]::Move($tmpPath, $TargetSentinelPath, $true)
}

# ─────────────────────────────────────────────────────────────────────────────
# MODO PAYLOAD — executado dentro da Tarefa Agendada
# ─────────────────────────────────────────────────────────────────────────────
if ($PSCmdlet.ParameterSetName -eq 'Payload') {
    if (-not (Test-Path -LiteralPath $PayloadSpecPath -PathType Leaf)) {
        # Sem spec não há como localizar a sentinela; falha dura.
        throw "PayloadSpec não encontrado: $PayloadSpecPath"
    }

    $spec = (Get-Content -LiteralPath $PayloadSpecPath -Raw) | ConvertFrom-Json
    $buildScriptPath = [string]$spec.buildScriptPath
    $sentinelTarget  = [string]$spec.sentinelPath
    $resultLogPath   = [string]$spec.logPath
    $taskNameToClean = [string]$spec.taskName
    [string[]]$buildArgs = @($spec.buildArgs)

    $payloadExit = 90
    try {
        & $buildScriptPath @buildArgs | Out-Null
        $payloadExit = $LASTEXITCODE
        if ($null -eq $payloadExit) { $payloadExit = 90 }
    } catch {
        $payloadExit = 90
    } finally {
        try {
            Write-SentinelAtomic -TargetSentinelPath $sentinelTarget -ExitCodeValue $payloadExit -ResultLogPath $resultLogPath
        } catch {
            # Falha ao gravar a sentinela é o pior caso de observabilidade; registra no stderr da tarefa.
            [Console]::Error.WriteLine("Falha ao gravar sentinela em ${sentinelTarget}: $($_.Exception.Message)")
        }
        # Best-effort: remover a própria tarefa one-shot. A instância em execução continua viva.
        if (-not [string]::IsNullOrWhiteSpace($taskNameToClean)) {
            try {
                Unregister-ScheduledTask -TaskName $taskNameToClean -Confirm:$false -ErrorAction Stop
            } catch {
                # Limpeza é best-effort; não afeta a sentinela já gravada.
            }
        }
    }

    exit $payloadExit
}

# ─────────────────────────────────────────────────────────────────────────────
# MODO LAUNCH — registra e dispara a Tarefa Agendada, retorna ao agente
# ─────────────────────────────────────────────────────────────────────────────

$blockingReasons = New-Object System.Collections.Generic.List[string]

$scriptDirectory = Split-Path -Parent $PSCommandPath
$buildScriptPath = Join-Path $scriptDirectory 'Invoke-GeneXusKbBuildAll.ps1'

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath
$resolvedWorkingDir = Get-FullPathSafe -PathValue $WorkingDirectory
$resolvedKbPath = Get-FullPathSafe -PathValue $KbPath

if ([string]::IsNullOrWhiteSpace($SentinelPath)) {
    $resolvedSentinelPath = $resolvedLogPath + '.sentinel'
} else {
    $resolvedSentinelPath = Get-FullPathSafe -PathValue $SentinelPath
}

function Write-LaunchResult {
    param(
        [string]$Status,
        [string]$Summary,
        [int]$ExitCodeValue,
        [bool]$Started,
        [string]$TaskName
    )

    $result = [ordered]@{
        status           = $Status
        mode             = 'detached-launch'
        summary          = $Summary
        exitCode         = $ExitCodeValue
        started          = $Started
        taskName         = $TaskName
        sentinelPath     = $resolvedSentinelPath
        logPath          = $resolvedLogPath
        buildScriptPath  = $buildScriptPath
        workingDirectory = $resolvedWorkingDir
        artifactBaseDir  = (Join-Path (Split-Path -Parent $scriptDirectory) 'Temp\xpz-msbuild-build')
        pollHint         = 'Aguarde a existência de sentinelPath; quando { done: true }, ler logPath com a ferramenta Read. Para progresso ao vivo, ler o msbuild.stdout.log do artifact dir novo sob artifactBaseDir.'
        blockingReasons  = @($blockingReasons)
    }
    $json = ($result | ConvertTo-Json -Depth 6)
    Write-Output $json
}

# Validações de transporte (não de política — política vive no wrapper de build).
if (-not (Test-Path -LiteralPath $buildScriptPath -PathType Leaf)) {
    $blockingReasons.Add("Wrapper de build não encontrado: $buildScriptPath")
    Write-LaunchResult -Status 'bloqueado por politica de seguranca' -Summary 'Invoke-GeneXusKbBuildAll.ps1 não localizado ao lado deste orquestrador.' -ExitCodeValue 46 -Started $false -TaskName $null
    exit 46
}

if (Test-IsUnderProgramFilesX86 -PathValue $resolvedWorkingDir) {
    $blockingReasons.Add("WorkingDirectory sob Program Files (x86), tratado como somente leitura: $resolvedWorkingDir")
}
if (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath) {
    $blockingReasons.Add("LogPath sob Program Files (x86), tratado como somente leitura: $resolvedLogPath")
}
if (Test-IsUnderProgramFilesX86 -PathValue $resolvedSentinelPath) {
    $blockingReasons.Add("SentinelPath sob Program Files (x86), tratado como somente leitura: $resolvedSentinelPath")
}
if ($blockingReasons.Count -gt 0) {
    Write-LaunchResult -Status 'bloqueado por politica de seguranca' -Summary 'Caminho inseguro sob Program Files (x86). Use pasta sob o repositório (ex.: Temp\).' -ExitCodeValue 46 -Started $false -TaskName $null
    exit 46
}

# Garante a existência do WorkingDirectory e da pasta da sentinela/log.
foreach ($dir in @($resolvedWorkingDir, (Split-Path -Parent $resolvedLogPath), (Split-Path -Parent $resolvedSentinelPath))) {
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Monta os argumentos repassados ao wrapper de build. Modo desacoplado NÃO usa watcher (v1).
$forwardArgs = New-Object System.Collections.Generic.List[string]
$forwardArgs.Add('-KbPath');           $forwardArgs.Add($resolvedKbPath)
$forwardArgs.Add('-WorkingDirectory'); $forwardArgs.Add($resolvedWorkingDir)
$forwardArgs.Add('-LogPath');          $forwardArgs.Add($resolvedLogPath)

function Add-OptionalValue {
    param([string]$Name, [string]$Value)
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        $forwardArgs.Add($Name)
        $forwardArgs.Add($Value)
    }
}

Add-OptionalValue -Name '-GeneXusDir'      -Value $GeneXusDir
Add-OptionalValue -Name '-MsBuildPath'     -Value $MsBuildPath
Add-OptionalValue -Name '-VersionName'     -Value $VersionName
Add-OptionalValue -Name '-EnvironmentName' -Value $EnvironmentName
Add-OptionalValue -Name '-Configuration'   -Value $Configuration
Add-OptionalValue -Name '-ParallelKbRoot'  -Value $ParallelKbRoot
Add-OptionalValue -Name '-KbMetadataPath'  -Value $KbMetadataPath

# Parâmetros ValidateSet 'true'/'false': sempre repassados explicitamente.
$forwardArgs.Add('-ForceRebuild');       $forwardArgs.Add($ForceRebuild)
$forwardArgs.Add('-CompileMains');       $forwardArgs.Add($CompileMains)
$forwardArgs.Add('-DetailedNavigation'); $forwardArgs.Add($DetailedNavigation)
$forwardArgs.Add('-FailIfReorg');        $forwardArgs.Add($FailIfReorg)
$forwardArgs.Add('-DoNotExecuteReorg');  $forwardArgs.Add($DoNotExecuteReorg)

if ($TimeoutSeconds -gt 0) {
    $forwardArgs.Add('-TimeoutSeconds')
    $forwardArgs.Add([string]$TimeoutSeconds)
}

# Switches repassados quando presentes.
function Add-OptionalSwitch {
    param([string]$Name, [bool]$Present)
    if ($Present) { $forwardArgs.Add($Name) }
}

Add-OptionalSwitch -Name '-AllowReorg'                -Present $AllowReorg.IsPresent
Add-OptionalSwitch -Name '-ConfirmReorg'             -Present $ConfirmReorg.IsPresent
Add-OptionalSwitch -Name '-AllowWideRebuild'         -Present $AllowWideRebuild.IsPresent
Add-OptionalSwitch -Name '-ConfirmWideRebuild'       -Present $ConfirmWideRebuild.IsPresent
Add-OptionalSwitch -Name '-AllowCostlyBuildOptions'  -Present $AllowCostlyBuildOptions.IsPresent
Add-OptionalSwitch -Name '-ConfirmCostlyBuildOptions' -Present $ConfirmCostlyBuildOptions.IsPresent
Add-OptionalSwitch -Name '-PostImportDeployValidation' -Present $PostImportDeployValidation.IsPresent
Add-OptionalSwitch -Name '-SkipDeployBinCheck'       -Present $SkipDeployBinCheck.IsPresent
Add-OptionalSwitch -Name '-StrictDeployBinCheck'     -Present $StrictDeployBinCheck.IsPresent

# Nome único da tarefa por execução.
$kbLeaf = Split-Path -Leaf $resolvedKbPath
$kbLeafSafe = ($kbLeaf -replace '[^A-Za-z0-9_]', '')
if ([string]::IsNullOrWhiteSpace($kbLeafSafe)) { $kbLeafSafe = 'Kb' }
$taskSuffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
$taskName = "XpzBuildDetached_${kbLeafSafe}_${taskSuffix}"

# Grava o PayloadSpec na WorkingDirectory (evita quoting frágil na linha de comando da tarefa).
$payloadSpec = [ordered]@{
    buildScriptPath = $buildScriptPath
    buildArgs       = @($forwardArgs)
    sentinelPath    = $resolvedSentinelPath
    logPath         = $resolvedLogPath
    taskName        = $taskName
}
$payloadSpecPath = Join-Path $resolvedWorkingDir ("detached-payload-{0}.json" -f $taskSuffix)
[System.IO.File]::WriteAllText($payloadSpecPath, ($payloadSpec | ConvertTo-Json -Depth 6) + [Environment]::NewLine, (Get-Utf8NoBomEncoding))

# Resolve o caminho do pwsh atual para a action da tarefa.
$pwshPath = $null
try { $pwshPath = (Get-Process -Id $PID).Path } catch { $pwshPath = $null }
if ([string]::IsNullOrWhiteSpace($pwshPath)) {
    $pwshCmd = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue
    if ($null -ne $pwshCmd) { $pwshPath = $pwshCmd.Source }
}
if ([string]::IsNullOrWhiteSpace($pwshPath)) { $pwshPath = 'pwsh.exe' }

$actionArgument = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -RunDetachedPayload -PayloadSpecPath "{1}"' -f $PSCommandPath, $payloadSpecPath

try {
    $action = New-ScheduledTaskAction -Execute $pwshPath -Argument $actionArgument -WorkingDirectory $resolvedWorkingDir
    $principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Hours $MaxRuntimeHours)
    $task = New-ScheduledTask -Action $action -Principal $principal -Settings $settings
    Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
} catch {
    $blockingReasons.Add("Falha ao registrar a Tarefa Agendada: $($_.Exception.Message)")
    Write-LaunchResult -Status 'bloqueado por politica de seguranca' -Summary 'Não foi possível registrar a Tarefa Agendada. Verifique permissões do Task Scheduler.' -ExitCodeValue 46 -Started $false -TaskName $taskName
    exit 46
}

try {
    Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
} catch {
    $blockingReasons.Add("Falha ao iniciar a Tarefa Agendada: $($_.Exception.Message)")
    try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue } catch { }
    Write-LaunchResult -Status 'bloqueado por politica de seguranca' -Summary 'Tarefa registrada mas falhou ao iniciar; tarefa removida.' -ExitCodeValue 46 -Started $false -TaskName $taskName
    exit 46
}

Write-LaunchResult -Status 'build desacoplado disparado' -Summary 'Build longo lançado de forma desacoplada da sessão do agente via Tarefa Agendada. Fechar janela ou app não derruba o build. Aguarde a sentinela e leia o LogPath ao concluir.' -ExitCodeValue 0 -Started $true -TaskName $taskName
exit 0
