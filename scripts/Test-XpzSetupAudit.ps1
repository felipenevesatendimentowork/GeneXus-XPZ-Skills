[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbRoot,

    [Parameter(Mandatory = $true)]
    [string]$GateWrapperPath,

    [Parameter(Mandatory = $true)]
    [string]$MetadataWrapperTestPath,

    [string]$PowerShellRuntimeTestPath,

    [string]$NamingWrapperPath,

    [string]$SourceSanityWrapperPath,

    [string]$PackageCollisionWrapperPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-WrapperText {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "BLOCK: wrapper ausente: $Path"
    }

    $output = & $Path 2>&1
    if (-not $?) {
        $text = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw "BLOCK: wrapper falhou sem saida: $Path"
        }

        throw $text
    }

    return (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
}

function Get-MetadataField {
    param(
        [string[]]$Lines,
        [string]$FieldName
    )

    $pattern = '^\s*{0}\s*[:=]\s*(?<value>.+?)\s*$' -f [regex]::Escape($FieldName)
    foreach ($line in $Lines) {
        $match = [regex]::Match($line, $pattern)
        if ($match.Success) {
            return $match.Groups['value'].Value.Trim()
        }
    }

    return $null
}

function Normalize-Value {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $trimmed = $Value.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed -eq '(ausente)') {
        return $null
    }

    return $trimmed
}

function Emit-Line {
    param(
        [string]$Key,
        [string]$Value
    )

    '{0}: {1}' -f $Key, $Value
}

$scriptDir = Split-Path -Parent $PSCommandPath

$powerShellRuntimeRaw = $null
$powerShellRuntimeStatus = $null
try {
    if (-not $PowerShellRuntimeTestPath) {
        throw "BLOCK: wrapper de runtime PowerShell nao informado"
    }
    $powerShellRuntimeRaw = Invoke-WrapperText -Path $PowerShellRuntimeTestPath
    if ($powerShellRuntimeRaw -match '\bPOWERSHELL_RUNTIME_OK\b') {
        $powerShellRuntimeStatus = 'OK'
    } else {
        $powerShellRuntimeStatus = 'BLOCK'
    }
} catch {
    $powerShellRuntimeRaw = $_.Exception.Message.Trim()
    $powerShellRuntimeStatus = 'BLOCK'
}

if ($powerShellRuntimeStatus -ne 'OK') {
    Emit-Line -Key 'powershell/runtime' -Value $powerShellRuntimeStatus
    Emit-Line -Key 'powershell/runtime.evidencia' -Value $(if ($powerShellRuntimeRaw) { $powerShellRuntimeRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
    Emit-Line -Key 'estado_operacional_sugerido' -Value 'runtime_powershell_bloqueado'
    exit 1
}

$metadataPath = Join-Path $KbRoot 'kb-source-metadata.md'
if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    throw "BLOCK: kb-source-metadata.md nao encontrado: $metadataPath"
}

$metadataLines = [System.IO.File]::ReadAllLines($metadataPath)
$lastMaterialization = Normalize-Value (Get-MetadataField -Lines $metadataLines -FieldName 'last_xpz_materialization_run_at')

$gateRaw = $null
$gateStatus = $null
$inventorySemanticStatus = $null
try {
    $gateRaw = Invoke-WrapperText -Path $GateWrapperPath
    $gateStatus = if ($gateRaw -match '\bGATE_OK\b') { 'OK' } else { 'PENDENTE' }
} catch {
    $gateRaw = $_.Exception.Message.Trim()
    $gateStatus = 'BLOCK'
}

$inventorySemanticMatch = if ($gateRaw) {
    [regex]::Match($gateRaw, 'inventory_validation_status\s*[:=]\s*(?<value>\S+)')
} else {
    [regex]::Match('', 'a^')
}
if ($inventorySemanticMatch.Success) {
    $inventorySemanticStatus = $inventorySemanticMatch.Groups['value'].Value.Trim()
} elseif ($gateStatus -eq 'BLOCK' -and $gateRaw -match 'inventario semantico|inventory_validation_status') {
    $inventorySemanticStatus = 'BLOCK'
} else {
    $inventorySemanticStatus = 'PENDENTE'
}

$metadataWrapperRaw = $null
$metadataWrapperStatus = $null
try {
    $metadataWrapperRaw = Invoke-WrapperText -Path $MetadataWrapperTestPath
    if ($metadataWrapperRaw -match '\bMETADATA_WRAPPER_OK\b') {
        $metadataWrapperStatus = 'OK'
    } elseif ($metadataWrapperRaw -match '\bPENDENTE_DE_DADOS\b') {
        $metadataWrapperStatus = 'PENDENTE_DE_DADOS'
    } else {
        $metadataWrapperStatus = 'PENDENTE'
    }
} catch {
    $metadataWrapperRaw = $_.Exception.Message.Trim()
    if ($metadataWrapperRaw -match '\bPENDENTE_DE_DADOS\b') {
        $metadataWrapperStatus = 'PENDENTE_DE_DADOS'
    } else {
        $metadataWrapperStatus = 'BLOCK'
    }
}

$syncStatus = if ($lastMaterialization) { 'OK' } else { 'PENDENTE' }
$syncEvidence = if ($lastMaterialization) {
    "last_xpz_materialization_run_at=$lastMaterialization"
} else {
    'last_xpz_materialization_run_at ausente'
}

$namingRaw = $null
$namingStatus = 'INDETERMINADO'
if ($lastMaterialization) {
    try {
        if (-not $NamingWrapperPath) {
            $defaultNamingScriptPath = Join-Path $scriptDir 'Test-XpzObjetosDaKbNaming.ps1'
            if (Test-Path -LiteralPath $defaultNamingScriptPath -PathType Leaf) {
                $namingOutput = & $defaultNamingScriptPath -ParallelKbRoot $KbRoot -AsJson 2>&1
            } else {
                throw "BLOCK: wrapper de naming nao informado"
            }
        } else {
            $namingOutput = & $NamingWrapperPath -AsJson 2>&1
        }

        $namingExitCode = $LASTEXITCODE
        $namingRaw = (($namingOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
        $namingData = $namingRaw | ConvertFrom-Json
        $indetermined = @($namingData.all | Where-Object { $_.StatusNaming -in @('INDETERMINADO', 'TIPO_DESCONHECIDO') })
        if ($namingData.status -eq 'NAMING_DIVERGENT' -or $namingExitCode -eq 1) {
            $namingStatus = 'DIVERGENT'
        } elseif ($namingData.status -eq 'NAMING_INDETERMINADO' -or $indetermined.Count -gt 0) {
            $namingStatus = 'INDETERMINADO'
        } elseif ($namingData.status -eq 'NAMING_OK' -and $namingExitCode -eq 0) {
            $namingStatus = 'OK'
        } else {
            $namingStatus = 'INDETERMINADO'
        }
        $divergentList = @($namingData.divergent) -join ','
        $namingRaw = "status=$($namingData.status); divergent=$divergentList; total=$(@($namingData.all).Count)"
    } catch {
        $namingRaw = $_.Exception.Message.Trim()
        $namingStatus = 'INDETERMINADO'
    }
} else {
    $namingRaw = 'last_xpz_materialization_run_at ausente; naming nao auditado'
}

$packagesDir = Join-Path $KbRoot 'PacotesGeradosParaImportacaoNaKbNoGenexus'
$packageDirExists = Test-Path -LiteralPath $packagesDir -PathType Container
$hasSourceSanityWrapper = $SourceSanityWrapperPath -and (Test-Path -LiteralPath $SourceSanityWrapperPath -PathType Leaf)
$hasPackageCollisionWrapper = $PackageCollisionWrapperPath -and (Test-Path -LiteralPath $PackageCollisionWrapperPath -PathType Leaf)

if ($packageDirExists -or $hasSourceSanityWrapper -or $hasPackageCollisionWrapper) {
    if ($hasSourceSanityWrapper -and $hasPackageCollisionWrapper) {
        $packageAuditStatus = 'OK'
    } else {
        $packageAuditStatus = 'PENDENTE'
    }
} else {
    $packageAuditStatus = 'NAO_ADOTADO'
}

$packageEvidenceParts = @()
$packageEvidenceParts += ('packages_dir={0}' -f $(if ($packageDirExists) { 'presente' } else { 'ausente' }))
$packageEvidenceParts += ('source_sanity_wrapper={0}' -f $(if ($hasSourceSanityWrapper) { 'presente' } else { 'ausente' }))
$packageEvidenceParts += ('package_collision_wrapper={0}' -f $(if ($hasPackageCollisionWrapper) { 'presente' } else { 'ausente' }))
$packageEvidence = $packageEvidenceParts -join '; '

$inventoryScriptPath = Join-Path $scriptDir 'Test-XpzWrapperInventory.ps1'
$examplesPath = Join-Path (Split-Path -Parent $scriptDir) 'xpz-kb-parallel-setup\examples'
$inventoryStatus = 'INVENTORY_UNKNOWN'
if (Test-Path -LiteralPath $inventoryScriptPath -PathType Leaf) {
    try {
        $inventoryOutput = (& $inventoryScriptPath -KbParallelRoot $KbRoot -SkillsExamplesPath $examplesPath 2>&1 |
            ForEach-Object { $_.ToString() }) -join ' '
        $inventoryStatus = $inventoryOutput.Trim()
    } catch {
        $inventoryStatus = "INVENTORY_UNKNOWN: $($_.Exception.Message.Trim())"
    }
} else {
    $inventoryStatus = 'INVENTORY_UNKNOWN: motor Test-XpzWrapperInventory.ps1 ausente'
}

$hasInventoryMethodologyPendencies = $inventoryStatus -match '\b(INVENTORY_GAPS|INVENTORY_SHORT_NAMING|INVENTORY_CUSTOMIZED)\b'
$hasMetadataWrapperPendencies = $metadataWrapperStatus -ne 'OK'

$suggestedState = switch ($true) {
    ($powerShellRuntimeStatus -ne 'OK') { 'runtime_powershell_bloqueado'; break }
    ($syncStatus -eq 'PENDENTE') { 'pronto_para_primeira_materializacao'; break }
    ($namingStatus -eq 'DIVERGENT') { 'naming_objetos_da_kb_pendente'; break }
    ($hasMetadataWrapperPendencies) { 'atualizacao_metodologica_pendente'; break }
    ($hasInventoryMethodologyPendencies) { 'atualizacao_metodologica_pendente'; break }
    ($syncStatus -eq 'OK' -and $gateStatus -eq 'OK' -and $inventorySemanticStatus -eq 'OK' -and $packageAuditStatus -eq 'OK') { 'materializado_e_indice_validado'; break }
    ($syncStatus -eq 'OK' -and $gateStatus -eq 'OK' -and $inventorySemanticStatus -eq 'OK' -and $packageAuditStatus -eq 'NAO_ADOTADO') { 'materializado_e_indice_validado'; break }
    ($syncStatus -eq 'OK' -and $gateStatus -eq 'OK' -and $inventorySemanticStatus -eq 'OK' -and $packageAuditStatus -eq 'PENDENTE') { 'auditoria_de_empacotamento_pendente'; break }
    default { 'wrappers_atualizados' }
}

Emit-Line -Key 'powershell/runtime' -Value $powerShellRuntimeStatus
Emit-Line -Key 'powershell/runtime.evidencia' -Value $(if ($powerShellRuntimeRaw) { $powerShellRuntimeRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'sync/materializacao' -Value $syncStatus
Emit-Line -Key 'sync/materializacao.evidencia' -Value $syncEvidence
Emit-Line -Key 'naming/objetos-da-kb' -Value $namingStatus
Emit-Line -Key 'naming/objetos-da-kb.evidencia' -Value $(if ($namingRaw) { $namingRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'indice/gate' -Value $gateStatus
Emit-Line -Key 'indice/gate.evidencia' -Value $(if ($gateRaw) { $gateRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'indice/semantica' -Value $inventorySemanticStatus
Emit-Line -Key 'indice/semantica.evidencia' -Value $(if ($gateRaw) { $gateRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'metadata wrapper' -Value $metadataWrapperStatus
Emit-Line -Key 'metadata wrapper.evidencia' -Value $(if ($metadataWrapperRaw) { $metadataWrapperRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'empacotamento local' -Value $packageAuditStatus
Emit-Line -Key 'empacotamento local.evidencia' -Value $packageEvidence
if ($inventoryStatus -match '\|') {
    foreach ($inventoryPart in @($inventoryStatus -split '\|')) {
        $trimmedInventoryPart = $inventoryPart.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmedInventoryPart)) {
            Emit-Line -Key 'wrappers/inventario' -Value $trimmedInventoryPart
        }
    }
} else {
    Emit-Line -Key 'wrappers/inventario' -Value $inventoryStatus
}
Emit-Line -Key 'estado_operacional_sugerido' -Value $suggestedState
