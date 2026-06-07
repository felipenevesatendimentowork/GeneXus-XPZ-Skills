#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de Test-PrePushNewTokenPropagation.ps1.

.DESCRIPTION
    Monta um repositorio git temporario que reproduz a estrutura do gap real
    (frente de padronizacao JSON XPZ): um motor ganha o alias -ObjectList
    co-localizado com -ObjectNames/-ObjectGuids (transicao no diff), enquanto um
    exemplo continua mencionando o conjunto antigo sem o alias novo. Confirma:
      - caso positivo: a mencao defasada vira candidata (status=warn);
      - controle negativo: mencao ja propagada nao vira candidata;
      - declaracao do proprio parametro (.PARAMETER) nao vira candidata.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-PrePushNewTokenPropagation.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-newtoken-propagation-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')
$utf8NoBom = Get-Utf8NoBomEncoding
function Write-TempFile {
    param([string]$RelativePath, [string]$Content)
    $full = Join-Path $tempRoot $RelativePath
    $dir = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $dir)) {
        [void](New-Item -ItemType Directory -Path $dir -Force)
    }
    [System.IO.File]::WriteAllText($full, $Content, $utf8NoBom)
}

function Invoke-TempGit {
    param([string[]]$Arguments)
    $output = & git -C $tempRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("git {0} falhou: {1}" -f ($Arguments -join ' '), (($output | Out-String).Trim()))
    }
    return $output
}

try {
    [void](Invoke-TempGit @('init', '-q'))
    [void](Invoke-TempGit @('config', 'user.email', 'selftest@example.com'))
    [void](Invoke-TempGit @('config', 'user.name', 'Self Test'))
    [void](Invoke-TempGit @('config', 'commit.gpgsign', 'false'))

    # --- Estado base: sem -ObjectList ---
    $motorBase = @'
[CmdletBinding()]
param(
    [string[]]$ObjectNames,
    [string[]]$ObjectGuids
)
<#
.PARAMETER ObjectNames
Nomes de objetos a copiar.
#>
# Quando -ObjectNames ou -ObjectGuids e fornecido, so os listados sao copiados.
if ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0) { $usaGuids = $true }
'@
    Write-TempFile -RelativePath 'motor.ps1' -Content $motorBase

    # Mencao equivalente que ficara defasada (sem ObjectList).
    Write-TempFile -RelativePath 'exemplo.md' -Content "Quando ObjectNames ou ObjectGuids e informado, faz seed do objeto.`n"

    # Controle negativo: mencao ja propagada.
    Write-TempFile -RelativePath 'ok-doc.md' -Content "Use ObjectList, ObjectNames ou ObjectGuids para selecionar objetos.`n"

    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'base'))
    $baseSha = (Invoke-TempGit @('rev-parse', 'HEAD') | Out-String).Trim()

    # --- HEAD: introduz -ObjectList co-localizado (transicao) ---
    $motorHead = @'
[CmdletBinding()]
param(
    [string[]]$ObjectList,
    [string[]]$ObjectNames,
    [string[]]$ObjectGuids
)
<#
.PARAMETER ObjectList
Alias operacional.
.PARAMETER ObjectNames
Nomes de objetos a copiar.
#>
# Quando -ObjectList, -ObjectNames ou -ObjectGuids e fornecido, so os listados sao copiados.
if ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0) { $usaGuids = $true }
'@
    Write-TempFile -RelativePath 'motor.ps1' -Content $motorHead
    # exemplo.md e ok-doc.md permanecem inalterados.

    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'introduz ObjectList'))

    $output = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -BaseRef $baseSha -AsJson 2>&1
    $exitCode = $LASTEXITCODE
    $jsonText = ($output | Out-String).Trim()
    $result = $jsonText | ConvertFrom-Json

    if ($exitCode -ne 0) {
        throw "gate deveria sair com exit 0 (consultivo); obtido $exitCode. Saida: $jsonText"
    }
    if ($result.status -ne 'warn') {
        throw "status deveria ser 'warn' (ha mencao defasada); obtido '$($result.status)'. Saida: $jsonText"
    }
    if (@($result.introducedTokens) -notcontains 'ObjectList') {
        throw "introducedTokens deveria conter 'ObjectList'; obtido: $(@($result.introducedTokens) -join ', ')"
    }

    $candidatePaths = @($result.findings | ForEach-Object { $_.path })
    $exemploHit = @($candidatePaths | Where-Object { $_ -like 'exemplo.md:*' })
    if ($exemploHit.Count -eq 0) {
        throw "exemplo.md (mencao defasada) deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }

    $okHit = @($candidatePaths | Where-Object { $_ -like 'ok-doc.md:*' })
    if ($okHit.Count -ne 0) {
        throw "ok-doc.md (controle negativo, ja propagado) NAO deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }

    $motorHit = @($candidatePaths | Where-Object { $_ -like 'motor.ps1:*' })
    if ($motorHit.Count -ne 0) {
        throw "motor.ps1 nao deveria gerar candidata (descricao ja propagada; .PARAMETER e declaracao filtrados); candidatas: $($candidatePaths -join ', ')"
    }

    Write-Output 'OK: Test-PrePushNewTokenPropagationSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
