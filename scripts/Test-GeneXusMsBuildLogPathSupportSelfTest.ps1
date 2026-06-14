#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$supportPath = Join-Path $PSScriptRoot 'GeneXusMsBuildLogPathSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusMsBuildLogPathSupport.ps1 nao encontrado: $supportPath"
}
. $supportPath

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [object]$Expected,
        [object]$Actual,
        [string]$Message
    )

    if ($Expected -ne $Actual) {
        throw ("{0} Esperado: {1}; obtido: {2}" -f $Message, $Expected, $Actual)
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-msbuild-logpath-selftest-' + [System.Guid]::NewGuid().ToString('N'))

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

    # Cenario 1: -LogPath aponta para um diretorio existente -> bloqueia.
    $existingDirectory = Join-Path $tempRoot 'artefatos'
    [System.IO.Directory]::CreateDirectory($existingDirectory) | Out-Null
    $dirRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $existingDirectory
    Assert-Equal -Expected $true -Actual $dirRejection.rejected -Message 'Diretorio existente deveria ser rejeitado.'
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($dirRejection.reason)) -Message 'Rejeicao deveria trazer reason.'
    Assert-Equal -Expected $existingDirectory -Actual $dirRejection.resolvedLogPath -Message 'resolvedLogPath deveria ecoar a entrada.'

    # Cenario 2: arquivo-a-criar (inexistente, com pai valido) -> NAO bloqueia.
    # Caso legitimo: -LogPath ainda nao existe; o wrapper o cria. A condicao
    # -PathType Container (e nao -not -PathType Leaf) e o que preserva este caso.
    $fileToCreate = Join-Path $existingDirectory 'build.log'
    $createRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $fileToCreate
    Assert-Equal -Expected $false -Actual $createRejection.rejected -Message 'Arquivo-a-criar com pai valido nao deveria ser rejeitado.'
    Assert-Equal -Expected $null -Actual $createRejection.reason -Message 'Caso valido nao deveria ter reason.'

    # Cenario 3: arquivo de log ja existente -> NAO bloqueia (sobrescrita legitima).
    $existingFile = Join-Path $existingDirectory 'previo.log'
    [System.IO.File]::WriteAllText($existingFile, 'conteudo', (Get-Utf8NoBomEncoding))
    $fileRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $existingFile
    Assert-Equal -Expected $false -Actual $fileRejection.rejected -Message 'Arquivo de log existente nao deveria ser rejeitado.'

    # Cenario 4: vazio / whitespace / null -> NAO bloqueia (sem -LogPath, sem gate).
    $emptyRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath ''
    Assert-Equal -Expected $false -Actual $emptyRejection.rejected -Message 'String vazia nao deveria ser rejeitada.'
    $whitespaceRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath '   '
    Assert-Equal -Expected $false -Actual $whitespaceRejection.rejected -Message 'Whitespace nao deveria ser rejeitado.'
    $nullRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $null
    Assert-Equal -Expected $false -Actual $nullRejection.rejected -Message 'Null nao deveria ser rejeitado.'

    # Cenario 5: o bloco JSON de bloqueio carrega exitCode 50 e contrato minimo.
    $json = New-GeneXusMsBuildLogPathBlockJson -WrapperName 'Invoke-GeneXusKbBuildAll.ps1' -ResolvedLogPath $existingDirectory -Reason $dirRejection.reason
    $parsed = $json | ConvertFrom-Json -Depth 8
    Assert-Equal -Expected 50 -Actual ([int]$parsed.exitCode) -Message 'Bloco de bloqueio deveria carregar exitCode 50.'
    Assert-Equal -Expected 'bloqueado por parametro invalido' -Actual $parsed.status -Message 'Bloco deveria trazer status de parametro invalido.'
    Assert-Equal -Expected 'Invoke-GeneXusKbBuildAll.ps1' -Actual $parsed.wrapper -Message 'Bloco deveria ecoar o wrapper.'
    Assert-Equal -Expected $existingDirectory -Actual $parsed.resolvedPaths.LogPath -Message 'Bloco deveria carregar o LogPath resolvido.'
    Assert-True -Condition (@($parsed.blockingReasons).Count -ge 1) -Message 'Bloco deveria ter blockingReasons nao vazio.'

    Write-Output 'GENEXUS_MSBUILD_LOGPATH_SUPPORT_SELFTEST_OK'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
