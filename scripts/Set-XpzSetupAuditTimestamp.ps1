#requires -Version 7.4
<#
.SYNOPSIS
    Grava last_setup_audit_run_at em kb-source-metadata.md da pasta paralela da KB.

.DESCRIPTION
    Atualiza ou insere somente o campo last_setup_audit_run_at, preservando o restante do arquivo
    (conteudo, EOL dominante e newline final).
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

. (Join-Path $PSScriptRoot 'XpzTextFileEolSupport.ps1')

$fieldName = 'last_setup_audit_run_at'
$newFieldLine = "${fieldName}: $isoValue"
$fieldPattern = '^\s*{0}\s*[:=]\s*.+$' -f [regex]::Escape($fieldName)

$fileContext = Get-TextFileLineContext -Path $metadataPath
$fileLines = $fileContext.Lines

$updated = $false
for ($i = 0; $i -lt $fileLines.Count; $i++) {
  if ($fileLines[$i] -match $fieldPattern) {
    $fileLines[$i] = $newFieldLine
    $updated = $true
    break
  }
}

if (-not $updated) {
  $insertAt = -1
  $frontmatterClose = -1
  $hasFrontmatter = ($fileLines.Count -gt 0 -and $fileLines[0].Trim() -eq '---')

  if ($hasFrontmatter) {
    for ($i = 1; $i -lt $fileLines.Count; $i++) {
      if ($fileLines[$i].Trim() -eq '---') {
        $frontmatterClose = $i
        break
      }
    }

    if ($frontmatterClose -gt 0) {
      $insertAt = $frontmatterClose
      for ($j = 1; $j -lt $frontmatterClose; $j++) {
        if ($fileLines[$j] -match '^\s*last_xpz_materialization_run_at\s*[:=]') {
          $insertAt = $j + 1
        }
      }
    }
  } else {
    for ($i = 0; $i -lt $fileLines.Count; $i++) {
      if ($fileLines[$i] -match '^\s*##\s+') {
        $insertAt = $i
        break
      }
    }

    if ($insertAt -lt 0) {
      $insertAt = $fileLines.Count
    }

    for ($j = 0; $j -lt $insertAt; $j++) {
      if ($fileLines[$j] -match '^\s*last_xpz_materialization_run_at\s*[:=]') {
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

  $fileLines.Insert($insertAt, $newFieldLine)
}

Write-TextFilePreservingEol -Path $metadataPath -FileContext $fileContext

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
