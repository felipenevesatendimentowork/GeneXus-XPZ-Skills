#requires -Version 7.4
<#
.SYNOPSIS
    Gera timestamps UTC no formato GeneXus lastUpdate.

.DESCRIPTION
    Retorna o instante UTC corrente formatado como
    yyyy-MM-ddTHH:mm:ss.0000000Z, evitando que agentes precisem compor
    comandos PowerShell inline para preencher lastUpdate em XMLs gerados.

.PARAMETER Count
    Quantidade de timestamps a devolver. Default: 1.

.PARAMETER AsJson
    Retorna saida JSON estruturada.
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 1000)]
    [int]$Count = 1,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$values = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $Count; $i++) {
    $timestamp = [DateTime]::UtcNow.ToString(
        "yyyy-MM-dd'T'HH:mm:ss'.0000000Z'",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
    $values.Add($timestamp) | Out-Null
}

if ($AsJson) {
    [pscustomobject]@{
        status      = 'OK'
        count       = $Count
        lastUpdates = $values.ToArray()
    } | ConvertTo-Json -Depth 4
    exit 0
}

if ($Count -eq 1) {
    $values[0]
} else {
    $values.ToArray()
}
