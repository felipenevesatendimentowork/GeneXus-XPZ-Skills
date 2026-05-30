# Handoff — Matriz `exportTaskLabel` (DataView + SDP) na máquina do colega

**Destinatário:** agente na pasta paralela de uma KB GeneXus que **tenha instâncias** de `DataView`, `SmartDevicesApplication` e/ou `SmartDevicesPlus`.  
**Solicitante:** mantenedor da base `GeneXus-XPZ-Skills` (Antonio) — integrará o resultado em `10a-gx-export-task-labels.md` e, se houver divergência comprovada, em `scripts/gx-object-type-catalog.json`.  
**Data do handoff:** 2026-05-30.

---

## O que o mantenedor precisa receber de volta

Um único pacote (ZIP ou pasta compartilhada) contendo **no mínimo**:

| Artefato | Caminho sugerido (relativo à pasta de saída) |
|----------|-----------------------------------------------|
| Resposta estruturada | `colega-export-task-label-resposta.json` (modelo abaixo) |
| Resumo legível | `colega-export-task-label-resposta.md` (mesmos fatos em prosa) |
| Matriz por tipo | `matrix/<KbId>/DataView/matrix-summary.json` (e SDP, se testados) |
| Logs de export | `matrix/<KbId>/<Tipo>/run-*/export.json` para cada tipo testado |
| Metadados da KB | cópia ou trecho de `kb-source-metadata.md` da pasta paralela |

**Não** alterar `scripts/gx-object-type-catalog.json` nem fazer `git push` no repositório `GeneXus-XPZ-Skills` — só entregar evidência.

---

## Contexto (leia antes de executar)

Na campanha P5 (2026-05-30), três KBs indexadas (FabricaBrasil18, wsEducacaoSpTeste, OnlineShopSS) tinham **zero** objetos desses tipos no índice — a matriz MSBuild **não rodou** para eles.

| Tipo catálogo | GUID (referência) | O que falta provar |
|---------------|-------------------|---------------------|
| `DataView` | `19abc6ff-2cd2-0000-0006-6d172bc2333b` | Rótulo aceito pela task Export em `-ObjectList` |
| `SmartDevicesApplication` | `9bdcc055-174e-4af6-96cb-a2ceef6c5f09` | idem |
| `SmartDevicesPlus` | `c84ec0ea-d159-46e2-a118-2108860379bb` | idem |

**Regra:** só registrar `exportTaskLabel` no catálogo quando a matriz mostrar **divergência** (export limpo com rótulo da task ≠ nome do catálogo), como em `WorkWithForWeb` → `WorkWith`. Se `DataView:Nome` exportar limpo e o pacote tiver `DataView:Nome`, **não** inventar campo — veredito `catalogMatchesTask`.

Documentação de referência no repositório (se existir clone local):

- `10a-gx-export-task-labels.md`
- `scripts/Run-ExportTaskLabelMatrix.ps1`
- `scripts/GeneXusExportTaskLabelSupport.ps1`

---

## Pré-requisitos na máquina do colega

1. **PowerShell 7.4+** (`pwsh`) no PATH.
2. **GeneXus** instalado e KB nativa acessível (caminho local ou UNC resolvível).
3. **Repositório `GeneXus-XPZ-Skills`** clonado e atualizado na branch `main` (commits com P5 + P1: matriz `exportTaskLabel` e pré-validação no export seletivo). Anotar o caminho absoluto como `$RepoRoot`.
4. **Pasta paralela** com:
   - `ObjetosDaKbEmXml/` (acervo XML materializado)
   - `KbIntelligence/kb-intelligence.sqlite` (índice **recente**)
   - `kb-source-metadata.md` (caminho da KB nativa)
5. Permissão para **export MSBuild headless** (task Export) — a matriz gera XPZ temporários em subpastas de `Temp/`.

---

## Variáveis (preencher no início da sessão)

Substituir pelos valores reais **antes** de rodar os comandos:

```powershell
# Pasta paralela (sessão do colega — normalmente o cwd do agente)
$ParallelKbRoot = 'C:\CAMINHO\PARA\Gx_SuaKbParalela'

# Clone da base metodológica (GeneXus-XPZ-Skills)
$RepoRoot = 'C:\CAMINHO\PARA\GeneXus-XPZ-Skills'

# Identificador curto para artefatos (sem espaços)
$KbId = 'NomeDaKb'   # ex.: Evo1, ClienteX

# Saída deste handoff
$HandoffRoot = Join-Path $ParallelKbRoot 'Temp\export-task-label-handoff-20260530'
```

**KB nativa:** ler de `kb-source-metadata.md` (tabela `UNCPath` ou equivalente). Exemplo de resolução:

```powershell
$meta = Get-Content (Join-Path $ParallelKbRoot 'kb-source-metadata.md') -Raw -Encoding UTF8
if ($meta -match '\|\s*UNCPath\s*\|\s*([^\|\r\n]+)\s*\|') {
    $KbPath = $matches[1].Trim() -replace '^\\\\[^\\]+\\[^\\]+\\', 'C:\'
} else {
    throw 'Não foi possível ler UNCPath em kb-source-metadata.md'
}
```

Se o caminho for UNC, usar o valor literal que o GeneXus aceita no MSBuild (não forçar `C:\` se a resolução falhar).

---

## Fase 0 — Setup da pasta paralela (obrigatório)

Se a sessão estiver na pasta paralela, o agente deve seguir **`xpz-kb-parallel-setup`** (skill global) **antes** de consultas ou export.

Confirmar índice:

```powershell
$indexPath = Join-Path $ParallelKbRoot 'KbIntelligence\kb-intelligence.sqlite'
if (-not (Test-Path -LiteralPath $indexPath)) {
    throw "Índice ausente: $indexPath — executar rebuild (Build-KbIntelligenceIndex) antes da matriz."
}
```

---

## Fase 1 — Descobrir espécimes (nomes reais na KB)

Para **cada** tipo abaixo, obter pelo menos um nome de objeto. Se `total = 0`, registrar no relatório e **pular** a Fase 2 para esse tipo.

```powershell
$QueryScript = Join-Path $RepoRoot 'scripts\Query-KbIntelligenceIndex.py'
$typesToFind = @('DataView', 'SmartDevicesApplication', 'SmartDevicesPlus')

$specimens = [ordered]@{}
foreach ($tipo in $typesToFind) {
    $raw = & python $QueryScript --query list-by-type --index-path $indexPath --object-type $tipo --limit 3 --format json
    if ($LASTEXITCODE -ne 0) { throw "list-by-type falhou para $tipo (exit $LASTEXITCODE)" }
    $parsed = $raw | ConvertFrom-Json
    $specimens[$tipo] = [ordered]@{
        total   = $parsed.total
        names   = @($parsed.results | ForEach-Object { $_.name })
        first   = if ($parsed.results.Count -gt 0) { $parsed.results[0].name } else { $null }
    }
}
$specimens | ConvertTo-Json -Depth 5
```

**Escolha do espécime:** usar `first` (primeiro do índice). Se o export falhar por objeto inválido/lock, tentar o segundo nome da lista e documentar.

---

## Fase 2 — Matriz MSBuild por tipo (com espécime)

Criar pasta de saída:

```powershell
New-Item -ItemType Directory -Path $HandoffRoot -Force | Out-Null
$MatrixRoot = Join-Path $HandoffRoot 'matrix'
```

Para cada tipo com `specimens[tipo].first` não nulo:

```powershell
$MatrixScript = Join-Path $RepoRoot 'scripts\Run-ExportTaskLabelMatrix.ps1'

# Repetir bloco para DataView, SmartDevicesApplication, SmartDevicesPlus
$CatalogTypeName = 'DataView'
$SpecimenObjectName = $specimens['DataView'].first

$outDir = Join-Path $MatrixRoot "$KbId\$CatalogTypeName"
& pwsh -NoProfile -File $MatrixScript `
    -CatalogTypeName $CatalogTypeName `
    -SpecimenObjectName $SpecimenObjectName `
    -KbPath $KbPath `
    -ParallelKbRoot $ParallelKbRoot `
    -KbId $KbId `
    -OutputDirectory $outDir
```

O script testa candidatos na ordem: `Tipo:Nome`, variantes de `folderName`, extras do catálogo (ex. só para `WorkWithForWeb`), e por fim **só o nome** (formato degradado — não usar em automação).

**Export seletivo:** com `-ParallelKbRoot`, o wrapper aplica pré-validação P1 (`objectListPreflight`). `not_in_index` gera **aviso** e segue; homônimo ou índice inválido → exit **35** (parar e reportar).

---

## Fase 3 — Interpretar veredito (por tipo)

Ler `matrix-summary.json` e classificar (mesma lógica de `Merge-ExportTaskLabelCampaignResults.ps1`):

| Veredito | Condição | Ação para o mantenedor |
|----------|----------|-------------------------|
| `catalogMatchesTask` | Algum run com `cleanSuccess=true` e `candidateTypeLabel` = nome do catálogo | **Não** adicionar `exportTaskLabel` |
| `divergence` | `cleanSuccess=true` com `candidateTypeLabel` ≠ catálogo (um só) | Registrar `exportTaskLabel` = rótulo vencedor |
| `ambiguous` | Mais de um rótulo alternativo limpo | Escalar — não alterar catálogo sem decisão humana |
| `nameOnlyWorks` | Só export por nome sem `Tipo:` | **Não** usar em automação; reportar |
| `inconclusive` | Nenhum run limpo | Reportar; não inventar label |
| `skipped_no_specimen` | Sem objeto no índice | Informar total=0 |

**Export limpo** = `processExitCode=0`, `invalidTypesRejected` vazio, sem `exportErrors` / Categoria B, `objectInXpz=true`.

---

## Fase 4 — Montar a resposta para o mantenedor

Gravar `$HandoffRoot\colega-export-task-label-resposta.json`:

```json
{
  "handoffVersion": "2026-05-30-dataview-sdp",
  "generatedAt": "<ISO-8601>",
  "executor": "<nome ou iniciais do colega>",
  "parallelKbRoot": "<caminho>",
  "kbPath": "<caminho nativo>",
  "kbId": "<KbId>",
  "geneXusXpzSkillsRepo": {
    "path": "<RepoRoot>",
    "branch": "main",
    "commit": "<git rev-parse HEAD em RepoRoot, se disponível>"
  },
  "index": {
    "path": "<indexPath>",
    "lastBuildHint": "<opcional: data do sqlite ou log de rebuild>"
  },
  "specimenDiscovery": {
    "DataView": { "total": 0, "names": [], "specimenUsed": null },
    "SmartDevicesApplication": { "total": 0, "names": [], "specimenUsed": null },
    "SmartDevicesPlus": { "total": 0, "names": [], "specimenUsed": null }
  },
  "results": [
    {
      "catalogTypeName": "DataView",
      "specimenObjectName": "Exemplo",
      "verdict": "catalogMatchesTask | divergence | ambiguous | nameOnlyWorks | inconclusive | skipped_no_specimen",
      "exportTaskLabel": null,
      "catalogMatchesTask": true,
      "winningObjectList": "DataView:Exemplo",
      "inventoryTypes": ["DataView"],
      "note": "texto curto",
      "matrixSummaryPath": "caminho absoluto para matrix-summary.json",
      "invalidTypesRejectedSample": [],
      "exportErrorsSample": []
    }
  ],
  "artifactsRoot": "<HandoffRoot>",
  "blockers": []
}
```

Gerar também `colega-export-task-label-resposta.md` com tabela:

| Tipo | Espécime | Veredito | `exportTaskLabel` sugerido | Observação |
|------|----------|----------|----------------------------|------------|

**Enviar ao mantenedor:** ZIP de `$HandoffRoot` (ou upload da pasta `matrix/` + JSON + MD).

---

## Problemas frequentes

| Sintoma | Causa provável | Ação |
|---------|----------------|------|
| exit **35** no export | Homônimo no índice ou índice inválido | Corrigir índice ou escolher outro espécime; anexar `export.json` da run bloqueada |
| exit **48** | Tipo rejeitado no log MSBuild | Normal para candidato errado; outro candidato na mesma matriz pode vencer |
| `total=0` no list-by-type | Acervo/index desatualizado | Rebuild índice após sync XPZ |
| Matriz lenta | MSBuild por candidato | Esperado; não interromper sem registrar runs parciais |

---

## Prompt copiável para o agente do colega

Copiar **todo** o bloco abaixo para uma nova conversa do agente, com a pasta paralela como workspace (ou ajustar caminhos na primeira mensagem).

```text
Você está na pasta paralela de uma KB GeneXus que contém objetos DataView e/ou Smart Devices Plus (tipos SmartDevicesApplication, SmartDevicesPlus).

Tarefa: executar o handoff de matriz exportTaskLabel descrito no arquivo abaixo e devolver o pacote de evidência ao solicitante (Antonio / GeneXus-XPZ-Skills). Não alterar o catálogo upstream nem fazer push.

1. Ler integralmente (se existir no disco do colega) ou pedir o caminho do clone de GeneXus-XPZ-Skills e abrir:
   historico/handoff-export-task-label-dataview-sdp-colega-20260530.md

2. Seguir as fases 0–4 do handoff na ordem:
   - xpz-kb-parallel-setup se aplicável
   - confirmar KbIntelligence/kb-intelligence.sqlite
   - list-by-type para DataView, SmartDevicesApplication, SmartDevicesPlus
   - Run-ExportTaskLabelMatrix.ps1 para cada tipo com espécime
   - gerar colega-export-task-label-resposta.json e .md em Temp/export-task-label-handoff-20260530/

3. Variáveis obrigatórias a preencher no início:
   - $ParallelKbRoot = <esta pasta paralela>
   - $RepoRoot = <clone GeneXus-XPZ-Skills na main recente>
   - $KbId = <nome curto da KB>

4. Entregável final na resposta do chat:
   - Tabela resumo (tipo, veredito, exportTaskLabel ou “ausente”, espécime usado)
   - Caminho do ZIP ou pasta HandoffRoot
   - Lista de blockers se algum tipo não pôde ser testado
   - Commit hash do RepoRoot se git disponível

5. Proibições:
   - Não inventar exportTaskLabel sem run cleanSuccess com divergência
   - Não aplicar -ApplyCatalog no Merge-ExportTaskLabelCampaignResults.ps1
   - Não commitar no repositório GeneXus-XPZ-Skills sem pedido explícito

Se o arquivo handoff não estiver local, clonar ou atualizar https://github.com/<org>/GeneXus-XPZ-Skills (main) e usar o path historico/handoff-export-task-label-dataview-sdp-colega-20260530.md na raiz do clone.

FIM DO PROMPT
```

---

## Integração pelo mantenedor (Antonio) — após receber o pacote

1. Validar vereditos nos `matrix-summary.json` recebidos.
2. Se `divergence`: patch em `scripts/gx-object-type-catalog.json` + linha em `10a-gx-export-task-labels.md` + trilíngue README se necessário.
3. Se `catalogMatchesTask` para os três: atualizar `10a` (secção “tipos sem espécime”) com nota “confirmado em KB &lt;KbId&gt; em 2026-05-30” — **sem** campo `exportTaskLabel`.
4. Arquivar cópia do pacote em `historico/export-task-label-handoff-colega-20260530/` (opcional).

---

## Referência rápida — comandos em uma linha (após variáveis)

```powershell
# Descoberta
python "$RepoRoot\scripts\Query-KbIntelligenceIndex.py" --query list-by-type --index-path $indexPath --object-type DataView --limit 3 --format json

# Matriz (exemplo DataView)
pwsh -NoProfile -File "$RepoRoot\scripts\Run-ExportTaskLabelMatrix.ps1" -CatalogTypeName DataView -SpecimenObjectName "<NOME>" -KbPath $KbPath -ParallelKbRoot $ParallelKbRoot -KbId $KbId -OutputDirectory "$MatrixRoot\$KbId\DataView"
```

Substituir `<NOME>` e repetir para `SmartDevicesApplication` e `SmartDevicesPlus`.
