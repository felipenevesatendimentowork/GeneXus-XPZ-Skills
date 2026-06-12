#requires -Version 7.4
<#
.SYNOPSIS
    Edicao cirurgica de XML GeneXus preservando conteúdo fora do delta aprovado.

.DESCRIPTION
    Le o arquivo em modo raw (ReadAllText), valida ocorrências literais da ancora,
    aplica Replace ou InsertAfter, atualiza lastUpdate por defeito (exceto com
    -PreserveLastUpdate), grava UTF-8 sem BOM e valida well-formedness opcional.

.PARAMETER InputPath
    Caminho do XML fonte.

.PARAMETER OutputPath
    Destino opcional. Quando omitido, edita in-place em InputPath.

.PARAMETER Anchor
    Substring literal a localizar (multi-linha permitida; escapes do chamador).

.PARAMETER Replacement
    Texto substituto (Replace) ou texto inserido após a ancora (InsertAfter).

.PARAMETER EditMode
    Replace ou InsertAfter.

.PARAMETER ExpectedAnchorCount
    Número esperado de ocorrências da ancora. Default: 1.

.PARAMETER PreserveLastUpdate
    Não atualiza lastUpdate na raiz do Object.

.PARAMETER LastUpdateBaselinePath
    XML usado como baseline para o bump. Quando omitido, usa InputPath.

.PARAMETER DryRun
    Simula o apply sem gravar nem criar backup.

.PARAMETER AssertWellFormedAfter
    Valida XML após gravar (default true). Em falha, restaura .bak.

.PARAMETER AsJson
    Saida estruturada JSON.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string]$Anchor,

    [Parameter(Mandatory = $true)]
    [string]$Replacement,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Replace', 'InsertAfter')]
    [string]$EditMode,

    [ValidateRange(0, 100000)]
    [int]$ExpectedAnchorCount = 1,

    [switch]$PreserveLastUpdate,

    [string]$LastUpdateBaselinePath,

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

function Write-SurgicalHumanOutput {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Result
    )

    if ($Result.Status -eq 'ERROR') {
        Write-Output $Result.Message
        return
    }

    Write-Output 'EDIT_OK'
    Write-Output ("  input         : {0}" -f $Result.InputPath)
    Write-Output ("  output        : {0}" -f $Result.OutputPath)
    Write-Output ("  editMode      : {0}" -f $Result.EditMode)
    Write-Output ("  dryRun        : {0}" -f $Result.DryRun)
    Write-Output ("  anchor_count  : {0} (expected {1})" -f $Result.AnchorCount, $Result.ExpectedAnchorCount)
    Write-Output ("  bytes_before  : {0}" -f $Result.BytesBefore)
    Write-Output ("  bytes_after   : {0}" -f $Result.BytesAfter)
    if ($Result.BytesDelta -ge 0) {
        Write-Output ("  bytes_delta   : +{0}" -f $Result.BytesDelta)
    } else {
        Write-Output ("  bytes_delta   : {0}" -f $Result.BytesDelta)
    }

    if ($Result.PreserveLastUpdate) {
        Write-Output ("  lastUpdate    : {0} (preserved)" -f $Result.LastUpdateBefore)
    } elseif ($Result.WillBumpLastUpdate) {
        Write-Output ("  lastUpdate    : {0} -> {1}" -f $Result.LastUpdateBefore, $Result.LastUpdateAfter)
        if (-not [string]::IsNullOrWhiteSpace($Result.LastUpdateBaselinePath)) {
            Write-Output ("  baseline      : {0}" -f $Result.LastUpdateBaselinePath)
        }
    }

    if ($null -ne $Result.WellFormed) {
        Write-Output ("  wellFormed    : {0}" -f $Result.WellFormed)
    }
}

function ConvertTo-SurgicalJsonOutput {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Result
    )

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
        editMode               = $Result.EditMode
        inputPath              = $Result.InputPath
        outputPath             = $Result.OutputPath
        anchorCount            = $Result.AnchorCount
        expectedAnchorCount    = $Result.ExpectedAnchorCount
        bytesBefore            = $Result.BytesBefore
        bytesAfter             = $Result.BytesAfter
        bytesDelta             = $Result.BytesDelta
        lastUpdateBefore       = $Result.LastUpdateBefore
        lastUpdateAfter        = $Result.LastUpdateAfter
        preserveLastUpdate     = $Result.PreserveLastUpdate
        willBumpLastUpdate     = $Result.WillBumpLastUpdate
        lastUpdateBaselinePath = $Result.LastUpdateBaselinePath
        wellFormed             = $Result.WellFormed
        wellFormedError        = $Result.WellFormedError
        replacementPreview     = $Result.ReplacementPreview
        bakPath                = $Result.BakPath
    }
}

try {
    $coreResult = Invoke-GeneXusXmlSurgicalEditCore `
        -InputPath $InputPath `
        -OutputPath $OutputPath `
        -Anchor $Anchor `
        -Replacement $Replacement `
        -EditMode $EditMode `
        -ExpectedAnchorCount $ExpectedAnchorCount `
        -PreserveLastUpdate:$PreserveLastUpdate.IsPresent `
        -LastUpdateBaselinePath $LastUpdateBaselinePath `
        -DryRun:$DryRun.IsPresent `
        -AssertWellFormedAfter $AssertWellFormedAfter

    if ($AsJson) {
        ConvertTo-SurgicalJsonOutput -Result $coreResult | ConvertTo-Json -Depth 5 -Compress
    } else {
        Write-SurgicalHumanOutput -Result $coreResult
    }

    exit [int]$coreResult.ExitCode
} catch {
    $message = $_.Exception.Message
    if ($AsJson) {
        [pscustomobject]@{
            status  = 'ERROR'
            code    = 'INTERNAL_ERROR'
            message = $message
        } | ConvertTo-Json -Depth 3 -Compress
    } else {
        Write-Output $message
    }
    exit 90
}
