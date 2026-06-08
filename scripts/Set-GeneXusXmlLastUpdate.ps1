#requires -Version 7.4
<#
.SYNOPSIS
    Re-carimba (bump) o lastUpdate de um XML GeneXus ja editado, no proprio arquivo,
    sem copiar do acervo nem aplicar delta.

.DESCRIPTION
    Recalcula o lastUpdate da raiz do Object para max(UtcNow + margem,
    baseline + margem) e grava no proprio arquivo (ou em OutputPath). Reusa o
    motor de calculo (Get-GeneXusXpzLastUpdate.ps1) e as funcoes de leitura,
    gravacao e validacao de GeneXusXmlSurgicalEditSupport.ps1; nao altera nem
    depende do comportamento de edicao do Edit-GeneXusXmlSurgical.ps1.

    Caso de uso principal: re-bumpar um arquivo da frente ja editado (rodada 2+)
    sem sobrescrever a edicao. Sem -BaselineXmlPath, o baseline e o proprio
    arquivo; como o GeneXus preserva o lastUpdate importado como Modified Date,
    bumpar acima do proprio valor anterior garante lastUpdate maior que o objeto
    vivo na KB em rodadas subsequentes. Para garantir acima do acervo, passar
    -BaselineXmlPath apontando para o XML oficial do mesmo objeto em
    ObjetosDaKbEmXml.

.PARAMETER InputPath
    Caminho do XML a re-carimbar.

.PARAMETER OutputPath
    Destino opcional. Quando omitido, grava in-place em InputPath.

.PARAMETER BaselineXmlPath
    XML usado como baseline do calculo. Quando omitido, usa o proprio InputPath.

.PARAMETER FreshnessMarginSeconds
    Margem aplicada sobre UtcNow e sobre o baseline. Default: 60.

.PARAMETER DryRun
    Simula sem gravar nem criar backup.

.PARAMETER AssertWellFormedAfter
    Valida XML apos gravar (default true). Em falha, restaura .bak.

.PARAMETER AsJson
    Saida estruturada JSON.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string]$OutputPath,

    [string]$BaselineXmlPath,

    [ValidateRange(1, 3600)]
    [int]$FreshnessMarginSeconds = 60,

    [switch]$DryRun,

    [bool]$AssertWellFormedAfter = $true,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusXmlSurgicalEditSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusXmlSurgicalEditSupport.ps1 nao encontrado: $supportPath"
}
. $supportPath

function New-BumpError {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )
    return [pscustomobject]@{
        Status   = 'ERROR'
        Code     = $Code
        Message  = $Message
        ExitCode = $ExitCode
    }
}

function Invoke-LastUpdateBumpCore {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [string]$OutputPath,
        [string]$BaselineXmlPath,
        [int]$FreshnessMarginSeconds,
        [switch]$DryRun,
        [bool]$AssertWellFormedAfter
    )

    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        return (New-BumpError -Code 'INPUT_NOT_FOUND' -Message "INPUT_NOT_FOUND: arquivo nao encontrado: $InputPath" -ExitCode 14)
    }

    $resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
    $resolvedOutput = $resolvedInput
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $outputParent = [System.IO.Path]::GetDirectoryName($OutputPath)
        if ([string]::IsNullOrWhiteSpace($outputParent) -or -not (Test-Path -LiteralPath $outputParent -PathType Container)) {
            return (New-BumpError -Code 'OUTPUT_DIR_MISSING' -Message "OUTPUT_DIR_MISSING: diretorio de destino invalido: $OutputPath" -ExitCode 15)
        }
        $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    }

    $sourceText = [System.IO.File]::ReadAllText($resolvedInput)
    $bytesBefore = [System.Text.Encoding]::UTF8.GetByteCount($sourceText)

    $lastUpdateBeforeInfo = Get-FirstObjectLastUpdateFromText -Text $sourceText
    if ($null -eq $lastUpdateBeforeInfo) {
        return (New-BumpError -Code 'NO_LASTUPDATE' -Message 'NO_LASTUPDATE: XML sem lastUpdate="..." na primeira ocorrencia.' -ExitCode 12)
    }
    $lastUpdateBefore = $lastUpdateBeforeInfo.Value

    if (-not [string]::IsNullOrWhiteSpace($BaselineXmlPath)) {
        if (-not (Test-Path -LiteralPath $BaselineXmlPath -PathType Leaf)) {
            return (New-BumpError -Code 'BASELINE_NOT_FOUND' -Message "BASELINE_NOT_FOUND: baseline nao encontrado: $BaselineXmlPath" -ExitCode 16)
        }
        $baselinePathUsed = (Resolve-Path -LiteralPath $BaselineXmlPath).Path
    } else {
        $baselinePathUsed = $resolvedInput
    }

    try {
        $lastUpdateAfter = Get-NewGeneXusLastUpdateValueFromEngine -BaselineXmlPath $baselinePathUsed -FreshnessMarginSeconds $FreshnessMarginSeconds
    } catch {
        return (New-BumpError -Code 'NO_LASTUPDATE' -Message $_.Exception.Message -ExitCode 12)
    }

    $patchedText = Set-FirstObjectLastUpdateInText -Text $sourceText -NewLastUpdateValue $lastUpdateAfter
    $bytesAfter = [System.Text.Encoding]::UTF8.GetByteCount($patchedText)

    $wellFormed = $null
    $wellFormedError = $null
    $bakPath = $null

    if (-not $DryRun.IsPresent) {
        $utf8NoBom = (Get-Utf8NoBomEncoding)
        if (Test-Path -LiteralPath $resolvedOutput -PathType Leaf) {
            $bakPath = "$resolvedOutput.bak"
            [System.IO.File]::Copy($resolvedOutput, $bakPath, $true)
        }
        [System.IO.File]::WriteAllText($resolvedOutput, $patchedText, $utf8NoBom)

        if ($AssertWellFormedAfter) {
            $writtenText = [System.IO.File]::ReadAllText($resolvedOutput)
            $postWrite = Test-GeneXusXmlWellFormed -Text $writtenText
            $wellFormed = $postWrite.WellFormed
            $wellFormedError = $postWrite.ErrorMessage
            if (-not $postWrite.WellFormed) {
                if ($null -ne $bakPath -and (Test-Path -LiteralPath $bakPath -PathType Leaf)) {
                    [System.IO.File]::Copy($bakPath, $resolvedOutput, $true)
                }
                return (New-BumpError -Code 'XML_NOT_WELLFORMED_AFTER' -Message "XML_NOT_WELLFORMED_AFTER: $($postWrite.ErrorMessage)" -ExitCode 13)
            }
        }

        if ($null -ne $bakPath -and (Test-Path -LiteralPath $bakPath -PathType Leaf)) {
            Remove-Item -LiteralPath $bakPath -Force
            $bakPath = $null
        }
    } elseif ($AssertWellFormedAfter) {
        $wfDry = Test-GeneXusXmlWellFormed -Text $patchedText
        $wellFormed = $wfDry.WellFormed
        $wellFormedError = $wfDry.ErrorMessage
    }

    return [pscustomobject]@{
        Status                 = 'OK'
        Code                   = 'BUMP_OK'
        Message                = 'BUMP_OK'
        ExitCode               = 0
        DryRun                 = [bool]$DryRun.IsPresent
        InputPath              = $resolvedInput
        OutputPath             = $resolvedOutput
        BytesBefore            = $bytesBefore
        BytesAfter             = $bytesAfter
        LastUpdateBefore       = $lastUpdateBefore
        LastUpdateAfter        = $lastUpdateAfter
        LastUpdateBaselinePath = $baselinePathUsed
        FreshnessMarginSeconds = $FreshnessMarginSeconds
        WellFormed             = $wellFormed
        WellFormedError        = $wellFormedError
        BakPath                = $bakPath
    }
}

function Write-BumpHumanOutput {
    param([Parameter(Mandatory = $true)][pscustomobject]$Result)
    if ($Result.Status -eq 'ERROR') {
        Write-Output $Result.Message
        return
    }
    Write-Output 'BUMP_OK'
    Write-Output ("  input         : {0}" -f $Result.InputPath)
    Write-Output ("  output        : {0}" -f $Result.OutputPath)
    Write-Output ("  dryRun        : {0}" -f $Result.DryRun)
    Write-Output ("  lastUpdate    : {0} -> {1}" -f $Result.LastUpdateBefore, $Result.LastUpdateAfter)
    Write-Output ("  baseline      : {0}" -f $Result.LastUpdateBaselinePath)
    if ($null -ne $Result.WellFormed) {
        Write-Output ("  wellFormed    : {0}" -f $Result.WellFormed)
    }
}

function ConvertTo-BumpJsonOutput {
    param([Parameter(Mandatory = $true)][pscustomobject]$Result)
    if ($Result.Status -eq 'ERROR') {
        return [pscustomobject]@{
            status  = 'ERROR'
            code    = $Result.Code
            message = $Result.Message
        }
    }
    return [pscustomobject]@{
        status                 = 'OK'
        code                   = $Result.Code
        dryRun                 = $Result.DryRun
        inputPath              = $Result.InputPath
        outputPath             = $Result.OutputPath
        bytesBefore            = $Result.BytesBefore
        bytesAfter             = $Result.BytesAfter
        lastUpdateBefore       = $Result.LastUpdateBefore
        lastUpdateAfter        = $Result.LastUpdateAfter
        lastUpdateBaselinePath = $Result.LastUpdateBaselinePath
        freshnessMarginSeconds = $Result.FreshnessMarginSeconds
        wellFormed             = $Result.WellFormed
        wellFormedError        = $Result.WellFormedError
        bakPath                = $Result.BakPath
    }
}

try {
    $coreResult = Invoke-LastUpdateBumpCore `
        -InputPath $InputPath `
        -OutputPath $OutputPath `
        -BaselineXmlPath $BaselineXmlPath `
        -FreshnessMarginSeconds $FreshnessMarginSeconds `
        -DryRun:$DryRun.IsPresent `
        -AssertWellFormedAfter $AssertWellFormedAfter

    if ($AsJson) {
        ConvertTo-BumpJsonOutput -Result $coreResult | ConvertTo-Json -Depth 5 -Compress
    } else {
        Write-BumpHumanOutput -Result $coreResult
    }
    exit [int]$coreResult.ExitCode
} catch {
    $message = $_.Exception.Message
    if ($AsJson) {
        [pscustomobject]@{ status = 'ERROR'; code = 'INTERNAL_ERROR'; message = $message } | ConvertTo-Json -Depth 3 -Compress
    } else {
        Write-Output $message
    }
    exit 90
}
