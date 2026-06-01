# 13 — Rotina de revisão pré-push

## Papel do documento

Fonte **autoritativa** da rotina pré-push deste repositório. O `AGENTS.md` na raiz apenas aponta para este arquivo; agentes e mantenedores devem seguir o conteúdo integral aqui antes de considerar push liberado.

## Escopo

A rotina pré-push é de **análise, busca de coerência e relatório** ao usuário. **Não** inclui alterar arquivos nem criar commits com base no relatório. Em face dos gaps, o agente **apresenta** o diagnóstico e, se fizer sentido, um diff ou lista de alterações sugeridas, e **só grava** no repositório após **aprovação explícita** do usuário **depois** do relatório — mesmo que a intenção inicial da sessão fosse aplicar correções; a pré-push não autoriza aplicar automaticamente com base apenas nessa intenção inicial. Uma única aprovação explícita (ex.: «ok, aplica os gaps do relatório») cobre o **conjunto** de alterações sugeridas, salvo o usuário pedir confirmação item a item.

## Passo mecânico inicial

Executar `scripts/Invoke-PrePushMechanicalChecks.ps1` em `pwsh` 7.4+ (`-AsJson` quando o chamador for agente). Por padrão o script compara a branch atual com `origin/main` — ou seja, **tudo que foi commitado localmente e ainda não foi enviado ao remoto** (desde o último push usual em `main`). Contagem de commits, lista de commits, arquivos alterados e `git diff --check` usam **o mesmo** intervalo (`BaseRef..HEAD`, com `BaseRef` default `origin/main`); não altere `-BaseRef` salvo necessidade explícita. O script classifica os arquivos **do diff desse intervalo**, delega parse PowerShell a `scripts/Test-PsScriptsParse.ps1` (inclui `scripts/*.ps1`, `scripts-maintenance/*.ps1` e `*.example.ps1` fora de `historico/`) e parse Python sem bytecode a `scripts/Test-PyScriptsParse.ps1` — **sem** substituir a busca semântica abaixo. O orquestrador **avisa** (sem falhar o gate mecânico) se a branch não for `main` ou se a working tree tiver alterações não commitadas fora desse intervalo.

### Forma canônica de invocação do orquestrador

Usar **uma e apenas uma** destas formas literais:

- Quando `cwd` é a raiz do repositório: `pwsh -NoProfile -File scripts/Invoke-PrePushMechanicalChecks.ps1 -AsJson`
- Quando `cwd` não é a raiz: `pwsh -NoProfile -File "<path-absoluto-com-backslashes>\scripts\Invoke-PrePushMechanicalChecks.ps1" -AsJson`

### Limites do passo mecânico (evitar leituras erradas)

- **Parse PowerShell:** `Test-PsScriptsParse.ps1` varre **todo** o repositório ativo (`scripts/*.ps1`, `scripts-maintenance/*.ps1` e `*.example.ps1` fora de `historico/`) — gate de saúde do repo, **não** limitado ao diff do intervalo. Pode falhar o mecânico com `commitsAhead=0` se houver script quebrado fora do que mudou.
- **Parse Python:** `Test-PyScriptsParse.ps1` varre `scripts/*.py` e usa `ast.parse`, sem `py_compile` e sem gerar `__pycache__/*.pyc`; falha de escrita em bytecode não deve bloquear validação de sintaxe.
- **Working tree:** com `commitsAhead=0` não há diff nem `git diff --check` no intervalo («nada commitado pendente de push»). A pré-push **não** substitui revisão de alterações **só** na working tree; o orquestrador avisa contagens, mas não analisa esses arquivos no intervalo.
- **`exit 0` vs push:** `exit 0` do orquestrador **não** significa «pode dar push» nem pré-push concluída. Ler `PUSH_READINESS` (e `pushReadiness` no JSON): com `blocked`, push fica proibido até integrar o remoto, mesmo com parse/whitespace limpos.
- **`pushReadiness=blocked`:** bloqueia **push** e torna diff/arquivos do intervalo apenas diagnósticos; **não** dispensa a fase semântica sobre os commits locais ainda pendentes — continuar o relatório de coerência cruzada.
- **Gates consultivos:** `Test-PrePushTraceabilityCoverage.ps1` e `Test-GeneXusUnexpectedCharacter.ps1` apontam riscos objetivos; **não** substituem a fase semântica nem autorizam concluir a pré-push sozinhos.

### Referência remota fresca

Quando a intenção for comparar contra o **remoto real atual**, garantir `origin/main` atualizada com `git fetch origin` **antes** do passo mecânico. Ref inexistente (o script falha com mensagem clara) e ref existente porém desatualizada são casos distintos — a segunda pode superestimar commits «à frente» ou mascarar divergência com o remoto.

### Remoto à frente (`commitsBehind`)

Quando `commitsBehind > 0`, o intervalo `BaseRef..HEAD` deixa de representar limpidamente «só o que falta enviar» — compara árvores divergentes; lista de arquivos e `git diff --check` nesse intervalo são **apenas diagnósticos**. O orquestrador emite `pushReadiness=blocked` (sem falhar parse/whitespace). A pré-push **não** deve ser considerada liberada para push até integrar o remoto: se ainda não houve fetch, `git fetch origin`; se `commitsBehind` persistir, integrar com o usuário (ex.: `git pull --rebase origin main` ou merge) — não fazer push automático.

## Fase semântica — por frente alterada

### 1. Inventário da frente

Identificar termos, scripts, wrappers, parâmetros, estados, caminhos e regras operacionais introduzidos ou modificados.

### 2. Busca no repositório

Buscar esses mesmos termos no repositório inteiro (não parar no primeiro arquivo que contém o termo).

### 3. Comparação documental

Comparar a documentação afetada com:

- skills relacionadas
- `README.md`
- `02-regras-operacionais-e-runtime.md`
- `08-guia-para-agente-gpt.md`
- `09-inventario-e-rastreabilidade-publica.md`, quando a frente alterar script compartilhado, contrato metodológico, skill, checklist, nomenclatura operacional, estado, parâmetro, wrapper ou evidência pública rastreável
- exemplos canônicos `*.example.ps1` nas skills afetadas (hoje principalmente `xpz-kb-parallel-setup/examples/`; não há `examples/` na raiz)
- scripts compartilhados em `scripts/`

### 4. Paridade motor ↔ promessa documental (obrigatório)

Quando a frente introduzir ou alterar regra que cite **motor por nome** (ex.: «`Query-KbIntelligenceIndex` usa catálogo efetivo», «exit `11`», «`-ParallelKbRoot`»):

1. Ler o trecho do motor citado (`.py` / `.ps1`), não só a documentação.
2. Se a doc citar **dois artefatos** na mesma regra (base + override, parâmetro, exit code), ambos devem existir no motor ou no wrapper que a doc manda usar.
3. Se existir motor **par** na mesma frente (ex.: `Build-KbIntelligenceIndex` já aceita `-ParallelKbRoot` / `--catalog-override-path`), outro motor que aplique a **mesma decisão** (gate, bloqueio, classificação) deve expor o mesmo contrato, salvo justificativa explícita no relatório.

**Red flags objetivas (grep / leitura de arquivo):**

- Doc diz «catálogo efetivo» (base + `gx-object-type-catalog.override.json`), mas o motor usa só `gx-object-type-catalog.json` fixo ao lado do script.
- `Build-KbIntelligenceIndex.ps1` expõe `-ParallelKbRoot` e `Query-KbIntelligenceIndex.ps1` não.
- Selftest da frente não exercita override quando a doc promete catálogo efetivo no query.

### 5. Regra em camadas para skills longas

Ao alinhar nomenclatura ou contrato (ex.: `lastUpdate`, `-AcervoPath`, `executionEvidence`, `pathEnrichment`, `queryableByKbIntelligence`), varrer o `SKILL.md` **e os satélites que ele manda carregar** antes de considerar a frente fechada — não basta o `SKILL.md` estar alinhado. Exemplos em `xpz-builder`: [quality-checklist.md](xpz-builder/quality-checklist.md), [wwp-packaging.md](xpz-builder/wwp-packaging.md), `responsibilities-by-type/*.md`. Três cortes: (1) checklist final ou gates de fechamento; (2) fluxo operacional e captura de resultado; (3) inventário de scripts e contratos por script.

### 6. Checklist de gaps

Confirmar se há:

- documentação antiga que contradiz a nova
- exemplos canônicos desatualizados
- scripts cujo contrato não bate com a descrição
- checklist que promete validação que o script não executa
- checklist em **satélite** do `SKILL.md` desatualizado frente ao `SKILL.md`, `02` ou scripts da mesma frente
- nova ferramenta documentada em uma skill, mas ausente nas skills correlatas
- rastreabilidade pública desatualizada em `09-inventario-e-rastreabilidade-publica.md` (presença do termo não basta — comparar abrangência)
- rastreabilidade agregada demais no `09` (motor vs bateria com papéis distintos)
- selftest que não cobre contrato novo documentado (reportar como área não coberta ou gap de teste)

### 7. Relatório

Reportar separadamente:

- gaps confirmados
- flags descartados, com justificativa
- áreas não cobertas pela busca

### 8. Veredicto

Encerrar com linha fixa:

`VEREDICTO: nenhum gap confirmado`

ou

`VEREDICTO: N gap(s) confirmado(s)`

(`N` = contagem de gaps confirmados). Avisos descartados e áreas não cobertas **não** contam como gap. A linha é obrigatória mesmo quando o mecânico passou; ausência significa pré-push não concluída.

## Conclusão

A rotina pré-push não está concluída enquanto a busca semântica acima não tiver sido executada e reportada, mesmo que `git diff --check`, parse e testes locais estejam limpos. **Não** tratar `exit 0` do passo mecânico como pré-push concluída **nem** como autorização de push quando `PUSH_READINESS=blocked`.

## Padrões de busca por tipo de frente

### Catálogo efetivo / KbIntelligence

- Positivo nos motores citados: `merge`, `override`, `ParallelKbRoot`, `catalog-override-path`, `GeneXusObjectTypeCatalogCore`, `resolve_effective`.
- Negativo: `CATALOG_PATH = Path(__file__).with_name("gx-object-type-catalog.json")` sem merge no mesmo fluxo que aplica `queryableByKbIntelligence` ou bloqueio semântico.

### MSBuild headless

Ver `10-base-operacional-msbuild-headless.md` e gate `Test-PrePushMsBuildProbeDocParity.ps1` quando o intervalo tocar motores MSBuild.

## Scripts do orquestrador

| Script | Papel |
| --- | --- |
| `scripts/Invoke-PrePushMechanicalChecks.ps1` | Orquestrador mecânico (git, parse, avisos) |
| `scripts/Test-PyScriptsParse.ps1` | Parse AST de `scripts/*.py` sem gerar bytecode |
| `scripts/Test-PrePushTraceabilityCoverage.ps1` | Rastreabilidade editorial + paridade motor/doc (consultivo) |
| `scripts/Test-PrePushMsBuildProbeDocParity.ps1` | Paridade MSBuild probe (quando aplicável) |
| `scripts/Test-GeneXusUnexpectedCharacter.ps1` | Caracteres Unicode inesperados em .md/.ps1 (consultivo) |

## Espelho em outros documentos

- `08-guia-para-agente-gpt.md`: resumo operacional para agentes GPT; em divergência, **este arquivo (`13`) prevalece** para a rotina pré-push completa.
- `09-inventario-e-rastreabilidade-publica.md`: evidência dos scripts listados acima.
