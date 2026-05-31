#requires -Version 7.4
<#
.SYNOPSIS
    Leitura de campos de environment em kb-source-metadata.md e resolucao de -EnvironmentName para wrappers MSBuild.

.DESCRIPTION
    Inventario de environments da KB nativa ocorre somente via xpz-kb-parallel-setup
    (Set-XpzKbSourceMetadataDeployment.ps1). Build/import apenas leem o metadata gravado.
#>

Set-StrictMode -Version Latest

function Get-GeneXusKbSourceMetadataDirectField {
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

function Normalize-GeneXusKbMetadataScalar {
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

function Resolve-GeneXusKbSourceMetadataPath {
    param(
        [string]$KbMetadataPath,
        [string]$ParallelKbRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($KbMetadataPath)) {
        return [System.IO.Path]::GetFullPath($KbMetadataPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) {
        return [System.IO.Path]::GetFullPath((Join-Path $ParallelKbRoot 'kb-source-metadata.md'))
    }

    return $null
}

function Read-GeneXusKbDeploymentMetadataFields {
    param([string]$MetadataPath)

    $result = [ordered]@{
        MetadataPath                  = $MetadataPath
        MetadataFound                 = $false
        deployment_environment_name   = $null
        deployment_hosting_kind       = $null
        kb_environment_count          = $null
        kb_environment_names          = @()
    }

    if ([string]::IsNullOrWhiteSpace($MetadataPath) -or -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        return [pscustomobject]$result
    }

    $result.MetadataFound = $true
    $lines = [System.IO.File]::ReadAllLines($MetadataPath)

    $result.deployment_environment_name = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'deployment_environment_name'
    )

    $result.deployment_hosting_kind = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'deployment_hosting_kind'
    )

    $countRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_count'
    )
    if ($countRaw) {
        $parsedCount = 0
        if ([int]::TryParse($countRaw, [ref]$parsedCount)) {
            $result.kb_environment_count = $parsedCount
        }
    }

    $namesRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_names'
    )
    if ($namesRaw) {
        $splitNames = @(
            $namesRaw -split '[,;]' |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_.Length -gt 0 }
        )
        $result.kb_environment_names = $splitNames
    }

    return [pscustomobject]$result
}

function Resolve-GeneXusKbValidationEnvironment {
    param(
        [string]$EnvironmentName,
        [string]$KbMetadataPath,
        [string]$ParallelKbRoot
    )

    $requested = if ([string]::IsNullOrWhiteSpace($EnvironmentName)) { $null } else { $EnvironmentName.Trim() }
    $resolvedMetadataPath = Resolve-GeneXusKbSourceMetadataPath -KbMetadataPath $KbMetadataPath -ParallelKbRoot $ParallelKbRoot

    $context = [ordered]@{
        validationEnvironmentRequested   = $requested
        validationEnvironmentResolved    = $null
        deploymentEnvironmentSource      = $null
        kbEnvironmentCount               = $null
        kbEnvironmentNames               = @()
        multiEnvironmentKbFromMetadata     = $null
        kbSourceMetadataPath             = $resolvedMetadataPath
        kbSourceMetadataFound            = $false
        deployment_environment_name    = $null
    }

    $blockingReasons = New-Object System.Collections.Generic.List[string]

    if (-not $resolvedMetadataPath) {
        if ($requested) {
            $context.validationEnvironmentResolved = $requested
            $context.deploymentEnvironmentSource = 'parameter'
            return [pscustomobject][ordered]@{
                Proceed           = $true
                EnvironmentName   = $requested
                BlockingReasons   = @()
                Summary           = $null
                Context           = $context
            }
        }

        $blockingReasons.Add(
            'Sem -EnvironmentName e sem kb-source-metadata.md resolvivel (-KbMetadataPath ou -ParallelKbRoot). Informe -EnvironmentName explicito ou aponte metadata da pasta paralela atualizado pelo xpz-kb-parallel-setup.'
        ) | Out-Null

        return [pscustomobject][ordered]@{
            Proceed           = $false
            EnvironmentName   = $null
            BlockingReasons   = $blockingReasons.ToArray()
            Summary           = 'Environment de validacao/deploy indefinido: metadata da pasta paralela ausente e -EnvironmentName nao informado.'
            Context           = $context
        }
    }

    $fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $resolvedMetadataPath
    $context.kbSourceMetadataFound = $fields.MetadataFound
    $context.deployment_environment_name = $fields.deployment_environment_name
    $context.kbEnvironmentCount = $fields.kb_environment_count
    $context.kbEnvironmentNames = @($fields.kb_environment_names)

    if (-not $fields.MetadataFound) {
        $blockingReasons.Add("kb-source-metadata.md nao encontrado: $resolvedMetadataPath") | Out-Null
        return [pscustomobject][ordered]@{
            Proceed           = $false
            EnvironmentName   = $null
            BlockingReasons   = $blockingReasons.ToArray()
            Summary           = 'kb-source-metadata.md ausente ou ilegivel para resolucao de Environment.'
            Context           = $context
        }
    }

    if ($null -eq $fields.kb_environment_count) {
        $blockingReasons.Add(
            'Campo kb_environment_count ausente em kb-source-metadata.md. Executar atualizacao de environments via xpz-kb-parallel-setup (Set-XpzKbSourceMetadataDeployment.ps1 na pasta paralela).'
        ) | Out-Null
        return [pscustomobject][ordered]@{
            Proceed           = $false
            EnvironmentName   = $null
            BlockingReasons   = $blockingReasons.ToArray()
            Summary           = 'Metadata de environments incompleto: falta kb_environment_count.'
            Context           = $context
        }
    }

    $context.multiEnvironmentKbFromMetadata = ($fields.kb_environment_count -gt 1)

    if ($fields.kb_environment_count -le 0) {
        $blockingReasons.Add('kb_environment_count invalido em kb-source-metadata.md (deve ser >= 1).') | Out-Null
        return [pscustomobject][ordered]@{
            Proceed           = $false
            EnvironmentName   = $null
            BlockingReasons   = $blockingReasons.ToArray()
            Summary           = 'kb_environment_count invalido no metadata.'
            Context           = $context
        }
    }

    if ($fields.kb_environment_count -eq 1) {
        if ($requested) {
            $context.validationEnvironmentResolved = $requested
            $context.deploymentEnvironmentSource = 'parameter'
            return [pscustomobject][ordered]@{
                Proceed           = $true
                EnvironmentName   = $requested
                BlockingReasons   = @()
                Summary           = $null
                Context           = $context
            }
        }

        $context.deploymentEnvironmentSource = 'geneXus-active-default-single'
        return [pscustomobject][ordered]@{
            Proceed           = $true
            EnvironmentName   = $null
            BlockingReasons   = @()
            Summary           = $null
            Context           = $context
        }
    }

    if ($requested) {
        $context.validationEnvironmentResolved = $requested
        $context.deploymentEnvironmentSource = 'parameter'

        if ($fields.kb_environment_names.Count -gt 0) {
            $known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($name in $fields.kb_environment_names) {
                [void]$known.Add($name)
            }
            if (-not $known.Contains($requested)) {
                $blockingReasons.Add(
                    ("-EnvironmentName '{0}' nao consta em kb_environment_names do metadata ({1})." -f $requested, ($fields.kb_environment_names -join ', '))
                ) | Out-Null
            }
        }

        if ($blockingReasons.Count -gt 0) {
            return [pscustomobject][ordered]@{
                Proceed           = $false
                EnvironmentName   = $null
                BlockingReasons   = $blockingReasons.ToArray()
                Summary           = 'Environment informado diverge do inventario gravado no metadata.'
                Context           = $context
            }
        }

        return [pscustomobject][ordered]@{
            Proceed           = $true
            EnvironmentName   = $requested
            BlockingReasons   = @()
            Summary           = $null
            Context           = $context
        }
    }

    if ($fields.deployment_environment_name) {
        $context.validationEnvironmentResolved = $fields.deployment_environment_name
        $context.deploymentEnvironmentSource = 'kb-source-metadata'
        return [pscustomobject][ordered]@{
            Proceed           = $true
            EnvironmentName   = $fields.deployment_environment_name
            BlockingReasons   = @()
            Summary           = $null
            Context           = $context
        }
    }

    $blockingReasons.Add(
        'KB com multiplos environments (kb_environment_count > 1): informe -EnvironmentName ou preencha deployment_environment_name em kb-source-metadata.md via xpz-kb-parallel-setup.'
    ) | Out-Null

    return [pscustomobject][ordered]@{
        Proceed           = $false
        EnvironmentName   = $null
        BlockingReasons   = $blockingReasons.ToArray()
        Summary           = 'Environment de validacao/deploy indefinido para KB multi-environment.'
        Context           = $context
    }
}

function Test-GeneXusKbActiveEnvironmentMatchesValidation {
    param(
        [AllowNull()][string]$ActiveEnvironment,
        [hashtable]$DeploymentEnvironmentContext
    )

    if ($null -eq $DeploymentEnvironmentContext) {
        return $true
    }

    $resolved = $DeploymentEnvironmentContext['validationEnvironmentResolved']
    if ([string]::IsNullOrWhiteSpace($resolved)) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($ActiveEnvironment)) {
        return $false
    }

    return ($ActiveEnvironment.Trim() -ieq $resolved.Trim())
}
