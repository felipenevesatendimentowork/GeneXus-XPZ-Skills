#requires -Version 7.4
<#
.SYNOPSIS
    Contrato de assinatura do extrator KbIntelligence (motor compartilhado).

.DESCRIPTION
    Fonte canônica da versão: EXTRACTOR_SIGNATURE_VERSION em Build-KbIntelligenceIndex.py.
    Hash: SHA-256 dos bytes de Build-KbIntelligenceIndex.py no repositório ativo.
    Índices sem extractor_signature_* na metadata são tratados como gerados por motor antigo.
#>

Set-StrictMode -Version Latest

function Get-GeneXusKbIntelligenceExtractorScriptPath {
    return (Join-Path $PSScriptRoot 'Build-KbIntelligenceIndex.py')
}

function Get-GeneXusKbIntelligenceExtractorSignatureVersionFromSource {
    $scriptPath = Get-GeneXusKbIntelligenceExtractorScriptPath
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Build-KbIntelligenceIndex.py nao encontrado: $scriptPath"
    }

    $content = [System.IO.File]::ReadAllText($scriptPath)
    $match = [regex]::Match(
        $content,
        'EXTRACTOR_SIGNATURE_VERSION\s*=\s*"(?<version>[^"]+)"'
    )
    if (-not $match.Success) {
        throw 'EXTRACTOR_SIGNATURE_VERSION ausente em Build-KbIntelligenceIndex.py'
    }

    return $match.Groups['version'].Value
}

function Get-GeneXusKbIntelligenceExpectedExtractorSignature {
    $scriptPath = Get-GeneXusKbIntelligenceExtractorScriptPath
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Build-KbIntelligenceIndex.py nao encontrado: $scriptPath"
    }

    $bytes = [System.IO.File]::ReadAllBytes($scriptPath)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    $hex = -join ($hash | ForEach-Object { $_.ToString('x2') })

    return [ordered]@{
        extractor_signature_version = (Get-GeneXusKbIntelligenceExtractorSignatureVersionFromSource)
        extractor_signature_hash    = $hex
    }
}

function Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Metadata
    )

    $expected = Get-GeneXusKbIntelligenceExpectedExtractorSignature
    $storedVersion = $Metadata['extractor_signature_version']
    $storedHash = $Metadata['extractor_signature_hash']

    if ([string]::IsNullOrWhiteSpace($storedVersion) -or [string]::IsNullOrWhiteSpace($storedHash)) {
        return [ordered]@{
            ok      = $false
            reason  = 'indice_sem_assinatura_extrator'
            summary = 'Indice gerado por motor antigo (metadata sem extractor_signature_version/hash) — regenerar com Build-KbIntelligenceIndex.py atual.'
            expected = $expected
            stored   = [ordered]@{
                extractor_signature_version = $storedVersion
                extractor_signature_hash    = $storedHash
            }
        }
    }

    if ($storedVersion -ne $expected.extractor_signature_version) {
        return [ordered]@{
            ok      = $false
            reason  = 'extrator_version_defasada'
            summary = ('Assinatura do extrator defasada (versao indexada {0}, motor atual {1}) — regenerar indice.' -f $storedVersion, $expected.extractor_signature_version)
            expected = $expected
            stored   = [ordered]@{
                extractor_signature_version = $storedVersion
                extractor_signature_hash    = $storedHash
            }
        }
    }

    if ($storedHash -ne $expected.extractor_signature_hash) {
        return [ordered]@{
            ok      = $false
            reason  = 'extrator_hash_defasado'
            summary = 'Indice gerado por build do extrator diferente do motor compartilhado atual — regenerar indice.'
            expected = $expected
            stored   = [ordered]@{
                extractor_signature_version = $storedVersion
                extractor_signature_hash    = $storedHash
            }
        }
    }

    return [ordered]@{
        ok      = $true
        reason  = $null
        summary = $null
        expected = $expected
        stored   = [ordered]@{
            extractor_signature_version = $storedVersion
            extractor_signature_hash    = $storedHash
        }
    }
}

function Get-GeneXusKbIntelligenceExtractorSignatureFromIndexMetadataText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IndexMetadataText
    )

    $metadata = @{}
    foreach ($line in ($IndexMetadataText -split "(`r`n|`n|`r)")) {
        if ($line -match '^(?<key>[A-Za-z0-9_]+)\s*:\s*(?<value>.+)$') {
            $metadata[$Matches.key] = $Matches.value.Trim()
        }
    }

    return $metadata
}
