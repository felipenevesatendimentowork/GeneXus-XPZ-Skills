#requires -Version 7.4
<#
.SYNOPSIS
    Executa casos minimos de validacao do inventario de wrappers XPZ.

.DESCRIPTION
    Cria uma pasta paralela temporaria e uma pasta temporaria de exemplos para validar
    que divergencia de #requires -Version classifica wrapper como CUSTOMIZADO, sem
    tratar Test-*KbPowerShellRuntime.ps1 como falso positivo.
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

    Write-Output 'WRAPPER_INVENTORY_SELFTEST_OK'
} finally {
    if ($tempRoot.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $tempRoot -PathType Container)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
