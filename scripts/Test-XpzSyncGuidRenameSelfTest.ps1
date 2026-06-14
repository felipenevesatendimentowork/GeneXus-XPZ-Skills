#requires -Version 7.4
<#
.SYNOPSIS
    Self-test da reconciliacao GUID-aware de rename em Sync-GeneXusXpzToXml.ps1.

.DESCRIPTION
    Cenario A (-FullSnapshot, modo materializacao): um atributo renomeado na KB
    (mesmo GUID, nome diferente) e tratado como rename do arquivo no acervo
    (Move-Item antigo -> novo), nao como delete-antigo + create-novo. Esperado:
    um arquivo so (nome novo), sem residuo Extra, sem throw, RenamedByGuid = 1.

    Cenario B (-VerifyOnly -FullSnapshot, modo conferencia): nao toca o disco;
    apenas detecta e classifica o rename por GUID no relatorio
    (RenameResidualsDetected = 1, Renames com Action 'detected'). A conferencia
    em si ainda acusa o acervo desatualizado (exit nao-zero), mas o relatorio,
    gravado antes do throw, ja explica que o Extra/Missing e um rename.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Sync-GeneXusXpzToXml.ps1'
$guid = '11111111-1111-1111-1111-111111111111'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-sync-guid-rename-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

function New-Scenario {
    param([Parameter(Mandatory = $true)][string]$Name)

    $caseRoot = Join-Path $tempRoot $Name
    $acervo = Join-Path $caseRoot 'ObjetosDaKbEmXml'
    $attrDir = Join-Path $acervo 'Attribute'
    [void](New-Item -ItemType Directory -Path $attrDir -Force)

    $oldFile = Join-Path $attrDir 'DistribuidoraNome.xml'
    $oldXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Attribute lastUpdate="2020-01-01T00:00:00.0000000Z" guid="$guid" name="DistribuidoraNome" description="nome antigo"><Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c" /></Attribute>
"@
    [System.IO.File]::WriteAllText($oldFile, $oldXml, (New-Object System.Text.UTF8Encoding($false)))

    $pkgFile = Join-Path $caseRoot 'pacote.xml'
    $pkgXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <Objects />
  <Attributes>
    <Attribute lastUpdate="2026-01-01T00:00:00.0000000Z" guid="$guid" name="DistribuidoraNomeTeste" description="nome novo"><Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c" /></Attribute>
  </Attributes>
</ExportFile>
"@
    [System.IO.File]::WriteAllText($pkgFile, $pkgXml, (New-Object System.Text.UTF8Encoding($false)))

    return [pscustomobject]@{
        Acervo = $acervo
        AttrDir = $attrDir
        OldFile = $oldFile
        NewFile = Join-Path $attrDir 'DistribuidoraNomeTeste.xml'
        PkgFile = $pkgFile
        ReportPath = Join-Path $caseRoot 'report.json'
    }
}

try {
    # --- Cenario A: materializacao real (Apply) ---
    $a = New-Scenario -Name 'apply'
    $outA = & pwsh -NoProfile -File $scriptPath -InputPath $a.PkgFile -DestinationRoot $a.Acervo -FullSnapshot -ReportPath $a.ReportPath -KeepReport 2>&1
    $exitA = $LASTEXITCODE
    if ($exitA -ne 0) {
        throw "A: Sync deveria concluir sem erro (exit 0); obtido exit=$exitA. Saida: $(($outA | Out-String))"
    }
    if (-not (Test-Path -LiteralPath $a.NewFile)) {
        throw "A: arquivo com nome novo deveria existir: $($a.NewFile)"
    }
    if (Test-Path -LiteralPath $a.OldFile) {
        throw "A: arquivo com nome antigo deveria ter sido renomeado (nao deveria existir): $($a.OldFile)"
    }
    $attrCountA = @(Get-ChildItem -LiteralPath $a.AttrDir -Filter *.xml -File).Count
    if ($attrCountA -ne 1) {
        throw "A: deveria sobrar um unico arquivo de atributo; encontrados $attrCountA"
    }
    $reportA = Get-Content -LiteralPath $a.ReportPath -Raw | ConvertFrom-Json
    if ($reportA.Summary.RenamedByGuid -ne 1) {
        throw "A: RenamedByGuid deveria ser 1; obtido $($reportA.Summary.RenamedByGuid)"
    }
    if ($reportA.Summary.FullSnapshotExtra -ne 0) {
        throw "A: FullSnapshotExtra deveria ser 0 (sem residuo); obtido $($reportA.Summary.FullSnapshotExtra)"
    }
    $renamedA = @($reportA.Renames | Where-Object { $_.Action -eq 'renamed' })
    if ($renamedA.Count -ne 1 -or $renamedA[0].OldName -ne 'DistribuidoraNome' -or $renamedA[0].NewName -ne 'DistribuidoraNomeTeste') {
        throw "A: relatorio de rename inesperado: $(($reportA.Renames | ConvertTo-Json -Depth 5))"
    }

    # --- Cenario B: conferencia (VerifyOnly) classifica sem mover ---
    $b = New-Scenario -Name 'verify'
    $outB = & pwsh -NoProfile -File $scriptPath -InputPath $b.PkgFile -DestinationRoot $b.Acervo -VerifyOnly -FullSnapshot -ReportPath $b.ReportPath -KeepReport 2>&1
    $exitB = $LASTEXITCODE
    if (-not (Test-Path -LiteralPath $b.OldFile)) {
        throw "B: VerifyOnly nao deveria tocar o disco; arquivo antigo deveria continuar existindo: $($b.OldFile)"
    }
    if (Test-Path -LiteralPath $b.NewFile) {
        throw "B: VerifyOnly nao deveria criar o arquivo de nome novo: $($b.NewFile)"
    }
    if (-not (Test-Path -LiteralPath $b.ReportPath)) {
        throw "B: relatorio deveria ter sido gravado antes do throw de conferencia (exit=$exitB)."
    }
    $reportB = Get-Content -LiteralPath $b.ReportPath -Raw | ConvertFrom-Json
    if ($reportB.Summary.RenameResidualsDetected -ne 1) {
        throw "B: RenameResidualsDetected deveria ser 1; obtido $($reportB.Summary.RenameResidualsDetected)"
    }
    if ($reportB.Summary.RenamedByGuid -ne 0) {
        throw "B: RenamedByGuid deveria ser 0 em VerifyOnly; obtido $($reportB.Summary.RenamedByGuid)"
    }
    $detectedB = @($reportB.Renames | Where-Object { $_.Action -eq 'detected' })
    if ($detectedB.Count -ne 1 -or $detectedB[0].OldName -ne 'DistribuidoraNome' -or $detectedB[0].NewName -ne 'DistribuidoraNomeTeste') {
        throw "B: classificacao de rename-residual inesperada: $(($reportB.Renames | ConvertTo-Json -Depth 5))"
    }

    Write-Output 'OK: Test-XpzSyncGuidRenameSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
