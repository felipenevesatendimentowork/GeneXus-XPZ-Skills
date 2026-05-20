# Ideias Implementadas

Registro de ideias que sairam de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Setup popula `kb-source-metadata.md` a partir da KB nativa, sem depender do XPZ

**Importancia original:** alta
**Status:** concluida em 2026-05-20

### Origem

Investigacao iniciada em 2026-05-17 a partir de relato da pasta paralela `C:\Dev\Test\Gx_wsEducacaoSpTeste`. A IDE GeneXus exportava `.xpz` com `<Source />` vazio em pelo menos dois caminhos de export, deixando `kb-source-metadata.md` sem `Source/@kb` e `Source/Version/@guid`. Como `Test-GeneXusImportFileEnvelope.ps1` bloqueia `Source` vazio, empacotamentos posteriores dependiam de workaround inadequado como `SkipGate`.

### Implementacao

- `scripts/Resolve-GeneXusKbIdentity.ps1`: motor compartilhado somente leitura para resolver identidade estavel da KB nativa local.
- `scripts/Update-XpzKbSourceMetadataIdentity.ps1`: atualizador conservador dos campos de identidade estavel em `kb-source-metadata.md`, preenchendo ausentes e bloqueando divergencias nao vazias sem aprovacao explicita.
- `xpz-kb-parallel-setup/examples/Resolve-KbIdentity.example.ps1`: wrapper sanitizado para reconstrucao local controlada.
- `xpz-kb-parallel-setup/SKILL.md`: setup inicial com KB nativa confirmada deve resolver identidade antes de declarar `kb-source-metadata.md` apto; metadata ausente, incompleto ou ilegivel e bloqueado pelos gates de metadata; divergencia preenchida contra a KB nativa ficou registrada como frente futura em `999-ideias-pendentes.md`; correcao de campos ausentes ou divergentes usa o atualizador somente em frente aprovada.
- `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `README.md`, `09-inventario-e-rastreabilidade-publica.md`, `xpz-builder/SKILL.md` e `xpz-msbuild-import-export/SKILL.md`: regras alinhadas para autoridade de campo, bloqueio cross-KB e rastreabilidade operacional.

### Decisao final

A frente do `Resolve` esta encerrada. O fluxo normal downstream continua lendo `kb-source-metadata.md`; `Resolve` nao vira fallback ad hoc de `xpz-sync`, `xpz-builder` ou import MSBuild. Se no futuro surgir necessidade de wrapper adicional ou automacao local especifica, isso deve ser tratado como nova frente: o agente deve estudar a documentacao vigente e propor o caminho aplicavel naquele contexto.

### Rastreabilidade privada

O exemplo sanitizado `xpz-kb-parallel-setup/examples/Resolve-KbIdentity.example.ps1` foi registrado no `GeneXus-XPZ-PrivateMap`, ligado ao alias privado `KB_Teste_Paralela_A`.
