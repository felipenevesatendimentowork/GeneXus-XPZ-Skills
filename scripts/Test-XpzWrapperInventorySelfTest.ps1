#requires -Version 7.4
<#
.SYNOPSIS
    Executa casos minimos de validação do inventario de wrappers XPZ.

.DESCRIPTION
    Cria uma pasta paralela temporaria e uma pasta temporaria de exemplos para validar
    que divergencia de #requires -Version classifica wrapper como CUSTOMIZADO, sem
    tratar Test-*KbPowerShellRuntime.ps1 como falso positivo. Também valida os sinais
    consultivos de wrappers recomendados ausentes e os sinais bloqueantes de scripts
    legados orfaos.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$inventoryScriptPath = Join-Path $scriptDir 'Test-XpzWrapperInventory.ps1'

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw "ASSERT_FAILED: $Message | output=$Text"
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Text -match $Pattern) {
        throw "ASSERT_FAILED: $Message | output=$Text"
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-wrapper-inventory-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$kbRoot = Join-Path $tempRoot 'Kb'
$scriptsPath = Join-Path $kbRoot 'scripts'
$examplesPath = Join-Path $tempRoot 'examples'

try {
    [void](New-Item -ItemType Directory -Path $scriptsPath -Force)
    [void](New-Item -ItemType Directory -Path $examplesPath -Force)

    @'
## Source/Version

| field | value |
|---|---|
| name | Demo |
'@ | Set-Content -LiteralPath (Join-Path $kbRoot 'kb-source-metadata.md') -Encoding utf8NoBOM

    @'
#requires -Version 7.4
Write-Output "metadata"
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Get-KbMetadata.example.ps1') -Encoding utf8NoBOM

    @'
#requires -version 5.1
Write-Output "metadata"
'@ | Set-Content -LiteralPath (Join-Path $scriptsPath 'Get-DemoKbMetadata.ps1') -Encoding utf8NoBOM

    @'
Write-Output "runtime"
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Test-KbPowerShellRuntime.example.ps1') -Encoding utf8NoBOM

    @'
Write-Output "runtime"
'@ | Set-Content -LiteralPath (Join-Path $scriptsPath 'Test-DemoKbPowerShellRuntime.ps1') -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern '\bINVENTORY_CUSTOMIZED\b' -Message 'requires divergente deve classificar CUSTOMIZADO'
    Assert-Contains -Text $output -Pattern 'Get-DemoKbMetadata\.ps1\(reason=requires_version_mismatch: local=5\.1 canonical=7\.4\)' -Message 'diagnostico deve identificar wrapper e versoes'
    Assert-NotContains -Text $output -Pattern '\bINVENTORY_OK\b' -Message 'inventario com CUSTOMIZADO nao pode retornar OK'
    Assert-NotContains -Text $output -Pattern 'Test-DemoKbPowerShellRuntime\.ps1\(reason=requires_version_mismatch' -Message 'wrapper de runtime e excecao intencional'

    foreach ($optionalExample in @('New-KbFront', 'Get-KbLastUpdate', 'New-KbImportPackage', 'Resolve-KbIdentity', 'Resolve-KbGeneratedCsPath')) {
        @'
#requires -Version 7.4
Write-Output "optional"
'@ | Set-Content -LiteralPath (Join-Path $examplesPath "$optionalExample.example.ps1") -Encoding utf8NoBOM
    }

    $frontPath = Join-Path $kbRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus\MinhaFrente_11111111-1111-1111-1111-111111111111_20260524'
    $packagesPath = Join-Path $kbRoot 'PacotesGeradosParaImportacaoNaKbNoGenexus'
    [void](New-Item -ItemType Directory -Path $frontPath -Force)
    [void](New-Item -ItemType Directory -Path $packagesPath -Force)
    '<Object lastUpdate="2026-05-24T00:00:00.0000000Z" />' |
        Set-Content -LiteralPath (Join-Path $frontPath 'Objeto.xml') -Encoding utf8NoBOM
    '<ExportFile />' |
        Set-Content -LiteralPath (Join-Path $packagesPath 'MinhaFrente_11111111-1111-1111-1111-111111111111_20260524_01.import_file.xml') -Encoding utf8NoBOM
    '| kb (GUID) | 11111111-1111-1111-1111-111111111111 |' |
        Add-Content -LiteralPath (Join-Path $kbRoot 'kb-source-metadata.md') -Encoding utf8NoBOM

    foreach ($scriptName in @(
        'Test-DemoKbFullSnapshot.ps1',
        'Test-DemoFullSnapshot.ps1',
        'Update-DemoKbFromXpz.ps1',
        'Update-DemoFromXpz.ps1',
        'Test-DemoKbIndexGate.ps1',
        'Test-DemoKbGate.ps1'
    )) {
        '#requires -Version 7.4' |
            Set-Content -LiteralPath (Join-Path $scriptsPath $scriptName) -Encoding utf8NoBOM
    }

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern '\bINVENTORY_LEGACY_ORPHANS\b' -Message 'scripts legados lado a lado devem ser reportados'
    Assert-Contains -Text $output -Pattern 'Test-DemoKbIndexGate\.ps1\(legacy=Test-DemoKbGate\.ps1\)' -Message 'gate legado deve apontar para canonico atual'
    Assert-Contains -Text $output -Pattern '\bINVENTORY_RECOMMENDED_MISSING\b' -Message 'wrappers recomendados ausentes devem ser reportados'
    Assert-Contains -Text $output -Pattern 'New-DemoKbFront\.ps1' -Message 'historico de frente deve recomendar wrapper de abertura'
    Assert-Contains -Text $output -Pattern 'Get-DemoKbLastUpdate\.ps1' -Message 'lastUpdate em XML gerado deve recomendar wrapper de timestamp'
    Assert-Contains -Text $output -Pattern 'New-DemoKbImportPackage\.ps1' -Message 'pacote import_file deve recomendar wrapper de pacote'
    Assert-Contains -Text $output -Pattern 'Resolve-DemoKbIdentity\.ps1' -Message 'metadata de identidade deve recomendar wrapper de identidade'

    @'
#requires -Version 7.4
param(
    [Parameter(Mandatory = $true)][string[]]$KbEnvironmentNames,
    [Parameter(Mandatory = $true)][string[]]$KbEnvironmentOutputDirs,
    [string]$KbNativePath,
    [string]$InventoryWorkingDirectory
)
Write-Output "deployment"
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Set-KbSourceMetadataDeployment.example.ps1') -Encoding utf8NoBOM

    $deploymentStandardPath = Join-Path $scriptsPath 'Set-DemoKbSourceMetadataDeployment.ps1'

    @'
#requires -Version 7.4
param(
    [switch]$InventoryFromKbNativePath,
    [string[]]$KbEnvironmentNames,
    [string[]]$KbEnvironmentOutputDirs,
    [string]$KbNativePath,
    [string]$InventoryWorkingDirectory
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=uses_removed_inventory_discovery\)' -Message 'wrapper com InventoryFromKbNativePath deve ser sinalizado como descoberta automatica removida'

    @'
#requires -Version 7.4
param(
    [string]$KbNativePath,
    [string]$InventoryWorkingDirectory
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=missing_KbEnvironmentNames\)' -Message 'wrapper sem KbEnvironmentNames deve ser sinalizado'

    @'
#requires -Version 7.4
param(
    [string[]]$KbEnvironmentNames,
    [string]$KbNativePath,
    [string]$InventoryWorkingDirectory
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=missing_KbEnvironmentOutputDirs\)' -Message 'wrapper sem KbEnvironmentOutputDirs deve ser sinalizado'

    @'
#requires -Version 7.4
param(
    [string[]]$KbEnvironmentNames,
    [string[]]$KbEnvironmentOutputDirs,
    [string]$InventoryWorkingDirectory
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=missing_KbNativePath_for_msbuild_validation\)' -Message 'wrapper sem KbNativePath deve ser sinalizado'

    @'
#requires -Version 7.4
param(
    [string[]]$KbEnvironmentNames,
    [string[]]$KbEnvironmentOutputDirs,
    [string]$KbNativePath
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=missing_InventoryWorkingDirectory_for_msbuild_validation\)' -Message 'wrapper sem InventoryWorkingDirectory deve ser sinalizado'

    Write-Output 'WRAPPER_INVENTORY_SELFTEST_OK'
} finally {
    if ($tempRoot.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $tempRoot -PathType Container)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
