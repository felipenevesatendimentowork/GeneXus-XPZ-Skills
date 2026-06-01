#requires -Version 7.4
<#
.SYNOPSIS
    Valida plausibilidade semantica dos campos de environment/deploy em kb-source-metadata.md.

.DESCRIPTION
    Gate de setup (xpz-kb-parallel-setup): rejeita metadata legado com nomes tipicos de scan
    por pastas web\ (CSharpModel, Data*) e inconsistencias de contagem. A lista correta vem
    do usuario via -KbEnvironmentNames; este gate nao valida existencia no GeneXus (MSBuild).

.PARAMETER MetadataPath
    Caminho para kb-source-metadata.md.

.PARAMETER AsJson
    Emite JSON em vez de linhas textuais.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MetadataPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbDeploymentEnvironmentSupport.ps1')

$MetadataPath = [System.IO.Path]::GetFullPath($MetadataPath)

$result = Test-GeneXusKbDeploymentMetadataPlausibility -MetadataPath $MetadataPath

if ($AsJson) {
    $result | ConvertTo-Json -Depth 4
    if ($result.status -eq 'BLOCK') { exit 1 }
    exit 0
}

switch ($result.status) {
    'OK' {
        Write-Output 'DEPLOYMENT_METADATA_PLAUSIBILITY_OK'
        Write-Output ("deployment_environment_name: {0}" -f $result.deployment_environment_name)
        Write-Output ("kb_environment_count: {0}" -f $result.kb_environment_count)
        Write-Output ("kb_environment_names: {0}" -f ($result.kb_environment_names -join ', '))
    }
    'PENDENTE' {
        foreach ($warning in $result.warnings) {
            Write-Output "PENDENTE: $warning"
        }
        Write-Output 'DEPLOYMENT_METADATA_PENDENTE'
        exit 0
    }
    'BLOCK' {
        foreach ($failure in $result.failures) {
            Write-Output "BLOCK: $failure"
        }
        Write-Output 'DEPLOYMENT_METADATA_IMPLAUSIVEL'
        exit 1
    }
    default {
        throw ("BLOCK: status de plausibilidade desconhecido: {0}" -f $result.status)
    }
}
