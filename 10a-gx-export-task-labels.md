# 10a — Rótulos da task Export vs catálogo interno

## Status

Documento de divergências entre o vocabulário aceito pela task MSBuild `Export` em `-ObjectList` (`Tipo:Nome`) e os rótulos usados em `scripts/gx-object-type-catalog.json`, KbIntelligence e pastas do acervo (`folderName`).

## Regra operacional

- Montar `-ObjectList` com o **rótulo da task Export**, não com o nome do tipo no catálogo ou no índice, quando existir divergência documentada abaixo.
- Consultar `exportTaskLabel` em `scripts/gx-object-type-catalog.json` quando o consumidor montar lista a partir do catálogo ou de `search-objects` / `list-by-type`.
- O inventário pós-export (`packageInventory`, `Get-GeneXusImportPackageObjectInventory.ps1`) classifica objetos pelo **catálogo/GUID** (`WorkWithForWeb` para `78cecefe-...`). Após export com `-ObjectList "WorkWith:Nome"`, o par no pacote aparece como `WorkWithForWeb:Nome` — isso **não** é falha de export; o confronto delta estrito `Tipo:Nome` pode marcar `requestedItemsMissing` para `WorkWith:Nome` mesmo com o objeto presente. Usar `package-inventory.json` (`nominalInventoryAt`), `objectsByType` ou comparar só o `Nome` quando o rótulo Export for conhecido; `extrasSample` cobre só extras de `<Objects>` no resumo JSON, não atributos top-level.
- Em importação, equivalências diferentes podem existir (ex.: `Panel` vs `SDPanel` em `itemAliasMatches` — ver `10-base-operacional-msbuild-headless.md`); não assumir que o mesmo alias vale na exportação.

## Fallback silencioso por nome vs divergência de rótulo

- **Divergência de rótulo** (este documento): lista com `exportTaskLabel` da task (`WorkWith:Nome`) e pacote com tipo do catálogo (`WorkWithForWeb:Nome`) — export correto; `requestedItemsMissing` estrito é falso negativo até confronto por alias no inventário.
- **Fallback silencioso por nome** (anti-padrão em `xpz-msbuild-import-export/SKILL.md`): a task GeneXus (ou camada equivalente) resolve por nome global ignorando o tipo pedido, ou entrega objeto homônimo de outro tipo, **sem** `invalidTypesRejected` / Categoria B — `exitCode=0` engana se o agente não confrontar identidade no inventário e, quando possível, no índice antes do MSBuild.
- **Tipo inválido no log** (`WorkWithForWeb:Nome` com `error : ... is not a valid type`): **não** é silêncio — wrapper rebaixa para **exit 48**; ver Categorias A/B na skill MSBuild.

## Tabela de divergências conhecidas

| GUID | Catálogo / pasta / índice | `exportTaskLabel` (task Export) | Evidência | Notas |
|------|---------------------------|----------------------------------|-----------|-------|
| `78cecefe-be7d-4980-86ce-8d6e91fba04b` | `WorkWithForWeb` | `WorkWith` | Matriz A1 em 2026-05-25, KB FabricaBrasil18, `WorkWithWebCliente`; artefatos em `C:\Dev\Prod\Gx_FabricaBrasil\Temp\export-task-label-matrix-20260525\` | Controle positivo quebrado: `WorkWithForWeb:Nome` → `error : WorkWithForWeb is not a valid type`, `invalidTypesRejected` contém `WorkWithForWeb`. `WorkWith:Nome` → sem `invalidTypesRejected`, XPZ com o objeto (tipo no pacote: `WorkWithForWeb`). |

### Matriz A1 (resumo)

| Candidato `-ObjectList` | `invalidTypesRejected` | `error : ... is not a valid type` | Objeto no XPZ |
|-------------------------|------------------------|-----------------------------------|---------------|
| `WorkWithForWeb:WorkWithWebCliente` | `WorkWithForWeb` | sim | sim (fallback por nome) |
| `WWP:...` | `WWP` | sim | não |
| `WorkWith:...` | (vazio) | não | sim (`WorkWithForWeb` no inventário) |
| `WorkWithDevicesForWeb:...` | `WorkWithDevicesForWeb` | sim | não |
| `WorkWith for Web:...` | `Web` (parser) | sim | não |
| `PatternInstance:...` | `PatternInstance` | sim | não |
| só `WorkWithWebCliente` | (vazio) | não | inventário degradado (formato exige `Tipo:Nome`) |

## Critério de aceite (smoke)

Para cada candidato em KB com instância real:

- `invalidTypesRejected` vazio no top-level de `export.json`
- Nenhuma linha `error : ... is not a valid type` em `msbuild.stdout.log` / `exportErrors`
- Objeto alvo presente no XPZ (ver `objectsByType` / inventário; não depender só de `requestedItemsFound` quando o `Tipo` da lista for `WorkWith` e o pacote reportar `WorkWithForWeb`)

## Referências

- `scripts/gx-object-type-catalog.json` — campo `exportTaskLabel` por tipo
- `xpz-msbuild-import-export/SKILL.md` — parâmetro `-ObjectList`, anti-padrão **fallback silencioso por nome**, Categorias A/B e barragem `exitCode=48`
- `scripts/Invoke-GeneXusXpzExport.ps1` — `invalidTypesRejected`, inventário pós-export, `exportErrors` → exit 48
- `scripts/msbuild-exit-codes.catalog.json` — código 48 (Categoria B)
