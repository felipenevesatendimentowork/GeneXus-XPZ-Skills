# AGENTS.md

## Leitura obrigatória

- Ler primeiro o `README.md` local antes de agir.
- Reler a documentação local quando o contexto da conversa ficar longo, ambíguo ou perder aderência às convenções da raiz.

## Interpretação de prompts de terceiros

- Quando o usuário indicar que o texto seguinte é um prompt com sugestões de outro agente, tratar esse texto como insumo de avaliação.
- Neste repositório, o foco é **melhorar as skills XPZ**, não usá-las — então o workflow é:
  1. **Estude a documentação** das skills afetadas para entender sua metodologia
  2. **Estude o prompt** do outro agente para entender a solicitação
  3. **Avalie criticamente**: o que faz sentido, o que conflita, o que precisa ajuste
  4. **Apresente um plano** ao usuário: claramente o que será alterado, por quê e onde
  5. **Aguarde aprovação explícita** antes de fazer qualquer mudança
- Não invoque as skills como ferramentas (via `Skill` tool) — elas são o objeto do seu trabalho, não suporte para ele.

## README trilíngue

- A seção `Português (BR)` do `README.md` é a fonte editorial primária.
- Toda alteração de conteúdo, estrutura, regra operacional ou nomenclatura feita na seção `Português (BR)` deve ser refletida também nas seções `Español` e `English`.
- Não concluir edição do `README.md` com traduções parciais, defasadas ou estruturalmente inconsistentes sem apontar a pendência de forma explícita.

## Escopo da raiz

- Esta raiz é a base metodológica e operacional compartilhada das skills de `XPZ`/XML de GeneXus.
- Regras locais desta raiz devem ser tratadas como regras do repositório; não promovê-las automaticamente a regra universal fora desta base sem evidência documental correspondente.

## Trabalho nas skills XPZ

- Esta raiz contém a documentação metodológica de múltiplas skills (xpz-reader, xpz-builder, xpz-sync, xpz-doc-builder, xpz-daemon, xpz-kb-parallel-setup, xpz-msbuild-import-export, xpz-msbuild-build, xpz-index-triage e xpz-skills-setup) e outros artefatos compartilhados.
- Ao trabalhar na melhoria de uma skill, estudar sua documentação de forma crítica e compreender seu propósito antes de propor mudanças.
- Quando receber um prompt de outro agente solicitando mudança em uma skill, não invoque essa skill como ferramenta — consulte sua documentação, analise o impacto e apresente um plano.
- Ao avaliar mudanças em uma skill, verificar o contexto de uso para o qual ela foi projetada. Exemplo: conteúdo embutido em `xpz-skills-setup` pode parecer desatualizado em relação ao ambiente do mantenedor, mas ser correto para quem está configurando um ambiente do zero — os dois contextos coexistem.
- Antes de pesquisar uma task, abordagem ou ideia nova relacionada às skills XPZ, consultar `999-ideias-pendentes.md` e `998-ideias-descartadas-e-porque.md`. O que já foi avaliado está registrado lá — não repetir a pesquisa.

## Edição segura de Markdown

- Em `.md` longos ou estruturados, preferir edições pequenas, locais e ancoradas por seção.
- Após cada gravação, reler o início do arquivo, a seção alterada e a transição para a seção seguinte.
- Se uma edição automática produzir resultado inesperado, parar e voltar para uma estratégia mais localizada.
- Quando precisar inspecionar encoding, EOL, BOM ou whitespace visível antes de uma edição cirúrgica, usar `scripts/Show-FileWhitespace.ps1` (modos `whitespace`, `encoding`, `mixed`; opção `-AsJson`).

## Alinhamento entre documentos

- Ao alterar nomenclatura, fluxo ou regra operacional, verificar impacto pelo menos em `README.md`, `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md` e nas skills afetadas.
- Não deixar convenções conflitantes entre a base compartilhada e as skills quando a mudança fizer parte da mesma frente.

## Revisão pré-push

Antes de concluir rotina pré-push, não basta ler os diffs dos commits pendentes. O agente deve procurar erros e inconsistências entre o que mudou e o restante do repositório.

**Escopo:** a rotina pré-push é de **análise, busca de coerência e relatório** ao usuário. **Não** inclui alterar arquivos nem criar commits com base no relatório. Em face dos gaps, o agente **apresenta** o diagnóstico e, se fizer sentido, um diff ou lista de alterações sugeridas, e **só grava** no repositório após **aprovação explícita** do usuário **depois** do relatório — mesmo que a intenção inicial da sessão fosse aplicar correções; a pré-push não autoriza aplicar automaticamente com base apenas nessa intenção inicial. Uma única aprovação explícita (ex.: «ok, aplica os gaps do relatório») cobre o **conjunto** de alterações sugeridas, salvo o usuário pedir confirmação item a item.

**Passo mecânico inicial:** executar `scripts/Invoke-PrePushMechanicalChecks.ps1` em `pwsh` 7.4+ (`-AsJson` quando o chamador for agente). Por padrão o script compara a branch atual com `origin/main` — ou seja, **tudo que foi commitado localmente e ainda não foi enviado ao remoto** (desde o último push usual em `main`). Contagem de commits, lista de commits, arquivos alterados e `git diff --check` usam **o mesmo** intervalo (`BaseRef..HEAD`, com `BaseRef` default `origin/main`); não altere `-BaseRef` salvo necessidade explícita. O script classifica os arquivos **do diff desse intervalo** e delega parse a `scripts/Test-PsScriptsParse.ps1` — **sem** substituir a busca semântica abaixo. O orquestrador **avisa** (sem falhar o gate mecânico) se a branch não for `main` ou se a working tree tiver alterações não commitadas fora desse intervalo.

**Limites do passo mecânico (evitar leituras erradas):**

- **Parse:** `Test-PsScriptsParse.ps1` varre **todo** o repositório ativo (`scripts/*.ps1` e `*.example.ps1` fora de `historico/`) — gate de saúde do repo, **não** limitado ao diff do intervalo. Pode falhar o mecânico com `commitsAhead=0` se houver script quebrado fora do que mudou.
- **Working tree:** com `commitsAhead=0` não há diff nem `git diff --check` no intervalo («nada commitado pendente de push»). A pré-push **não** substitui revisão de alterações **só** na working tree; o orquestrador avisa contagens, mas não analisa esses arquivos no intervalo.
- **`exit 0` vs push:** `exit 0` do orquestrador **não** significa «pode dar push» nem pré-push concluída. Ler `PUSH_READINESS` (e `pushReadiness` no JSON): com `blocked`, push fica proibido até integrar o remoto, mesmo com parse/whitespace limpos.
- **`pushReadiness=blocked`:** bloqueia **push** e torna diff/arquivos do intervalo apenas diagnósticos; **não** dispensa a fase semântica sobre os commits locais ainda pendentes — continuar o relatório de coerência cruzada.

**Referência remota fresca:** quando a intenção for comparar contra o **remoto real atual** (não só a cópia local da última vez que você fez fetch), garantir `origin/main` atualizada com `git fetch origin` **antes** do passo mecânico. Ref inexistente (o script falha com mensagem clara) e ref existente porém desatualizada são casos distintos — a segunda pode superestimar commits «à frente» ou mascarar divergência com o remoto.

**Remoto à frente (`commitsBehind`):** quando `commitsBehind > 0`, o intervalo `BaseRef..HEAD` deixa de representar limpidamente «só o que falta enviar» — compara árvores divergentes; lista de arquivos e `git diff --check` nesse intervalo são **apenas diagnósticos**. O orquestrador emite `pushReadiness=blocked` (sem falhar parse/whitespace). A pré-push **não** deve ser considerada liberada para push até integrar o remoto: se ainda não houve fetch, `git fetch origin`; se `commitsBehind` persistir, integrar com o usuário (ex.: `git pull --rebase origin main` ou merge) — não fazer push automático.

**Regra em camadas para skills longas:** ao alinhar nomenclatura ou contrato (ex.: `lastUpdate`, `-AcervoPath`, `executionEvidence`, `pathEnrichment`), varrer o `SKILL.md` **e os satélites que ele manda carregar** antes de considerar a frente fechada — não basta o `SKILL.md` estar alinhado. Exemplos em `xpz-builder`: [quality-checklist.md](xpz-builder/quality-checklist.md), [wwp-packaging.md](xpz-builder/wwp-packaging.md), `responsibilities-by-type/*.md`. Três cortes: (1) checklist final ou gates de fechamento (incluindo satélites de checklist); (2) fluxo operacional e captura de resultado (passos numerados, RESPONSIBILITIES, «Capturar e relatar»); (3) inventário de scripts, constraints e blocos de contrato por script. Quando um termo novo aparecer no `SKILL.md`, buscá-lo também nesses satélites. Se qualquer camada ainda usar só a forma antiga (ex.: `msBuildExitCode` top-level como canônico) sem apontar o bloco canônico (`executionEvidence.msBuildExitCode`), reportar como gap da mesma frente — não tratar como coberto só porque `02`, `08` ou `10` já estão alinhados.

Para cada frente alterada:

1. Identificar termos, scripts, wrappers, parâmetros, estados, caminhos e regras operacionais introduzidos ou modificados.
2. Buscar esses mesmos termos no repositório inteiro.
3. Comparar a documentação afetada com:
   - skills relacionadas
   - `README.md`
   - `02-regras-operacionais-e-runtime.md`
   - `08-guia-para-agente-gpt.md`
   - `09-inventario-e-rastreabilidade-publica.md`, quando a frente alterar script compartilhado, contrato metodológico, skill, checklist, nomenclatura operacional, estado, parâmetro, wrapper ou evidência pública rastreável
   - exemplos canônicos `*.example.ps1` nas skills afetadas (hoje principalmente `xpz-kb-parallel-setup/examples/`; não há `examples/` na raiz)
   - scripts compartilhados em `scripts/`
4. Confirmar se há:
   - documentação antiga que contradiz a nova
   - exemplos canônicos desatualizados
   - scripts cujo contrato não bate com a descrição
   - checklist que promete validação que o script não executa
   - checklist em **satélite** referenciado pelo `SKILL.md` (ex.: `xpz-builder/quality-checklist.md`) com regra de fechamento fraca ou antiga frente ao `SKILL.md`, `02` ou scripts da mesma frente
   - nova ferramenta, caminho ou parâmetro documentado em uma skill, mas ausente nas skills correlatas
   - rastreabilidade pública desatualizada em `09-inventario-e-rastreabilidade-publica.md`; encontrar o termo no `09` não basta, é preciso comparar se a descrição ainda reflete a abrangência atual do contrato, script ou regra
   - rastreabilidade agregada demais em `09-inventario-e-rastreabilidade-publica.md`; quando a frente envolver motor, orquestrador, wrapper e bateria de teste com papéis distintos, cada papel relevante deve ter evidência própria ou justificativa explícita para não registrar separadamente
5. Reportar separadamente:
   - gaps confirmados
   - flags descartados, com justificativa
   - áreas não cobertas pela busca
6. Encerrar o relatório com uma linha de veredicto explícita, em formato fixo: `VEREDICTO: nenhum gap confirmado` ou `VEREDICTO: N gap(s) confirmado(s)` (com `N` igual à contagem da lista acima). Avisos descartados com justificativa e áreas não cobertas **não** contam como gap. A linha de veredicto é obrigatória mesmo quando o mecânico passou e a busca semântica não achou nada; sua ausência significa pré-push não concluída.

A rotina pré-push não está concluída enquanto essa busca de coerência cruzada não tiver sido executada e reportada, mesmo que `git diff --check`, parse (`scripts/Test-PsScriptsParse.ps1`, também invocado por `scripts/Invoke-PrePushMechanicalChecks.ps1`) e testes locais estejam limpos. **Não** tratar `exit 0` do passo mecânico como pré-push concluída **nem** como autorização de push quando `PUSH_READINESS=blocked`.

## Rastreabilidade privada de moldes sanitizados

- Quando uma frente criar, fortalecer, recombinar ou ampliar cobertura de molde sanitizado publicável, o agente deve avaliar explicitamente se existe anotação correspondente a registrar no `GeneXus-XPZ-PrivateMap`.
- Essa avaliação faz parte do fechamento metodológico da frente, mesmo quando nenhuma edição for feita imediatamente no repositório privado.
- Se houver necessidade de atualização no `GeneXus-XPZ-PrivateMap`, tratar isso como outro contexto operacional e sinalizar claramente ao usuário antes de editar fora desta base pública.

## Pré-requisitos de ambiente (trilha KB Intelligence)

- Rebuild do índice SQLite (`scripts/Build-KbIntelligenceIndex.ps1` / `.py`) exige **Python 3.x utilizável** no `PATH`, resolvido por `scripts/GeneXusPythonPrerequisite.ps1` (rejeita stub `WindowsApps` sem executável real).
- Ausência de Python bloqueia o refresh com exit `8` e mensagem `PREREQUISITO AUSENTE`; a materialização XPZ/XML pode já ter concluído — não tratar como falha do pacote exportado.
- Wrappers locais `Update-*KbFromXpz` devem chamar o rebuild no **mesmo processo** `pwsh` e propagar a mensagem do motor (não mascarar com só código numérico).

## Idioma

- Responder ao usuário em português, salvo pedido explícito em outro idioma.
- Quando citar conteúdo técnico originalmente em inglês, traduzir ao explicar sempre que isso melhorar a compreensão.
- Ao explicar uma decisão ao usuário, traduzir termos conceituais técnicos para português (ex: "gate" → "verificação automática" ou "validação"; "playbook" → "roteiro"; "upstream" → "anterior" ou "que serve de base"; "fingerprint" → "marca de localização"; "manifesto" → "resumo descritivo do pacote"). Manter em inglês apenas nomes próprios — identificadores literais como `xpz-builder`, `who-uses`, `import_file.xml`.
- Misturar conceitos em inglês sem tradução em diálogo pt-BR aumenta o risco de o usuário não entender. Quando em dúvida, traduzir ou definir na primeira aparição.
