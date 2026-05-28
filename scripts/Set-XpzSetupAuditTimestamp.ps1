#requires -Version 7.4
<#
.SYNOPSIS
    Grava last_setup_audit_run_at em kb-source-metadata.md da pasta paralela da KB.

.DESCRIPTION
    Atualiza ou insere somente o campo last_setup_audit_run_at, preservando o restante do arquivo.
    Autoridade desta operacao: xpz-kb-parallel-setup (auditoria de setup bem-sucedida).

    Projetado para ser chamado pelo wrapper local Set-*KbSetupAuditTimestamp.ps1 apos auditoria
    completa com estado canonico bem-sucedido ou no subestado setup_apto_com_metadata_pendente.

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB (deve conter kb-source-metadata.md).

.PARAMETER AuditTimestamp
    Timestamp ISO 8601 com fuso horario. Quando omitido, usa o instante atual do sistema.

.PARAMETER AsJson
    Emite objeto JSON em vez de texto simples.

.OUTPUTS
    String "SETUP_AUDIT_TIMESTAMP_OK: <timestamp>" ou JSON com status.

.EXAMPLE
    .\Set-XpzSetupAuditTimestamp.ps1 -KbParallelRoot "C:\DevTests\Gx_MyCinema"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbParallelRoot,

    [string]$AuditTimestamp,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$metadataPath = Join-Path $KbParallelRoot 'kb-source-metadata.md'

if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
  throw "BLOCK: kb-source-metadata.md ausente em $KbParallelRoot"
}

$isoValue = $null
if ([string]::IsNullOrWhiteSpace($AuditTimestamp)) {
  $isoValue = (Get-Date).ToString('o')
} else {
  try {
    $parsed = [DateTimeOffset]::Parse($AuditTimestamp.Trim())
    $isoValue = $parsed.ToString('o')
  } catch {
    throw "BLOCK: AuditTimestamp nao e timestamp valido: '$AuditTimestamp'"
  }
}

$fieldName = 'last_setup_audit_run_at'
$newLine = "${fieldName}: $isoValue"
$fieldPattern = '^\s*{0}\s*[:=]\s*.+$' -f [regex]::Escape($fieldName)

$lines = [System.Collections.Generic.List[string]]@(
  [System.IO.File]::ReadAllLines($metadataPath)
)

$updated = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match $fieldPattern) {
    $lines[$i] = $newLine
    $updated = $true
    break
  }
}

if (-not $updated) {
  $insertAt = -1
  $frontmatterClose = -1
  $hasFrontmatter = ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---')

  if ($hasFrontmatter) {
    for ($i = 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i].Trim() -eq '---') {
        $frontmatterClose = $i
        break
      }
    }

    if ($frontmatterClose -gt 0) {
      $insertAt = $frontmatterClose
      for ($j = 1; $j -lt $frontmatterClose; $j++) {
        if ($lines[$j] -match '^\s*last_xpz_materialization_run_at\s*[:=]') {
          $insertAt = $j + 1
        }
      }
    }
  } else {
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^\s*##\s+') {
        $insertAt = $i
        break
      }
    }

    if ($insertAt -lt 0) {
      $insertAt = $lines.Count
    }

    for ($j = 0; $j -lt $insertAt; $j++) {
      if ($lines[$j] -match '^\s*last_xpz_materialization_run_at\s*[:=]') {
        $insertAt = $j + 1
      }
    }
  }

  if ($insertAt -lt 0) {
    if ($frontmatterClose -gt 0) {
      $insertAt = $frontmatterClose
    } else {
      $insertAt = 0
    }
  }

  $lines.Insert($insertAt, $newLine)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($metadataPath, $lines.ToArray(), $utf8NoBom)

if ($AsJson) {
  [pscustomobject]@{
    status = 'SETUP_AUDIT_TIMESTAMP_OK'
    last_setup_audit_run_at = $isoValue
    metadataPath = $metadataPath
  } | ConvertTo-Json -Compress
  exit 0
}

Write-Output "SETUP_AUDIT_TIMESTAMP_OK: $isoValue"
exit 0
