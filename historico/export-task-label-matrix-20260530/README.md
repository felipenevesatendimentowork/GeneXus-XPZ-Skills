# Matriz exportTaskLabel — campanha 2026-05-30

Campanha P5 (plano A+): cobertura multi-KB e matriz MSBuild por tipo com espécime.

## Arquivos na raiz

| Arquivo | Conteúdo |
|---------|----------|
| `coverage-map.json` | Espécime escolhido por tipo e KBs consultadas |
| `consolidation-report.json` | Vereditos agregados (divergências, match, inconclusos, sem instância) |
| `campaign-log.json` | Log da orquestração (`Invoke-ExportTaskLabelCampaign.ps1`) |

## Pasta `matrix/`

`<KbId>/<CatalogTypeName>/matrix-summary.json` — resumo por tipo.

`run-NN-*/export.json` — log do wrapper por candidato `-ObjectList`; `matrix-export.xpz` quando gerado.

## Reproduzir consolidação sem MSBuild

```powershell
pwsh -NoProfile -File scripts-maintenance/Invoke-ExportTaskLabelCampaign.ps1 -ParseOnly -Force
pwsh -NoProfile -File scripts-maintenance/Merge-ExportTaskLabelCampaignResults.ps1 -ApplyCatalog
```

Resumo editorial: `10a-gx-export-task-labels.md` (seção campanha P5).
