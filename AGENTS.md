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
- Nunca gravar arquivo de texto com BOM UTF-8 a menos que o formato do arquivo exija. Em PowerShell, `[System.Text.Encoding]::UTF8` emite BOM por padrão; usar `New-Object System.Text.UTF8Encoding($false)` ou a ferramenta `edit` (que preserva o encoding original). Para `.md` e `.ps1` deste repositório, UTF-8 sem BOM é o padrão.

## Alinhamento entre documentos

- Ao alterar nomenclatura, fluxo ou regra operacional, verificar impacto pelo menos em `README.md`, `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `13-revisao-pre-push.md` (quando a frente alterar a rotina pré-push ou gates associados) e nas skills afetadas.
- Não deixar convenções conflitantes entre a base compartilhada e as skills quando a mudança fizer parte da mesma frente.

## Revisão pré-push

- Fonte **autoritativa** da rotina: [13-revisao-pre-push.md](13-revisao-pre-push.md) (passo mecânico, fase semântica, paridade motor↔doc, veredicto).
- Resumo obrigatório antes de push: executar `scripts/Invoke-PrePushMechanicalChecks.ps1` (`-AsJson` para agentes), depois a busca semântica integral descrita no `13` — **não** basta grep de termos em `.md`; validar implementação dos motores citados.
- Escopo: análise e relatório ao usuário; correções só após aprovação explícita **depois** do relatório pré-push.

## Rastreabilidade privada de moldes sanitizados

- Quando uma frente criar, fortalecer, recombinar ou ampliar cobertura de molde sanitizado publicável, o agente deve avaliar explicitamente se existe anotação correspondente a registrar no `GeneXus-XPZ-PrivateMap`.
- Essa avaliação faz parte do fechamento metodológico da frente, mesmo quando nenhuma edição for feita imediatamente no repositório privado.
- Se houver necessidade de atualização no `GeneXus-XPZ-PrivateMap`, tratar isso como outro contexto operacional e sinalizar claramente ao usuário antes de editar fora desta base pública.

## KbIntelligence — ambiente e consultas

- Rebuild do índice SQLite (`scripts/Build-KbIntelligenceIndex.ps1` / `.py`) exige **Python 3.x utilizável** no `PATH`, resolvido por `scripts/GeneXusPythonPrerequisite.ps1` (rejeita stub `WindowsApps` sem executável real).
- Ausência de Python bloqueia o refresh com exit `8` e mensagem `PREREQUISITO AUSENTE`; a materialização XPZ/XML pode já ter concluído — não tratar como falha do pacote exportado; **rigor**: sync oficial **não** terminou — declarar **fluxo incompleto** (XMLs possivelmente atualizados, índice pendente); não declarar sync OK nem autorizar triagem ampla sem índice; ver `README.md`, `08-guia-para-agente-gpt.md` e `xpz-sync`.
- Wrappers locais `Update-*KbFromXpz` devem chamar o rebuild no **mesmo processo** `pwsh` e propagar a mensagem do motor (não mascarar com só código numérico).
- Antes de `who-uses`, `what-uses`, `impact-basic` ou `functional-trace-basic`, conferir no catálogo efetivo (`scripts/gx-object-type-catalog.json` + override local) se o tipo tem `queryableByKbIntelligence=true`; quando for `false`, `Query-KbIntelligenceIndex.py` aplica o mesmo merge (via `GeneXusObjectTypeCatalogCore.py`, `--parallel-kb-root` / `--catalog-override-path`) e devolve exit `11`, `blocked=true` e `reason=QUERY_NOT_SEMANTIC_FOR_TYPE` — **não** tratar como zero dependências; ver `02`, `08` e `scripts/README-kb-intelligence.md`.

## Idioma

- Responder ao usuário em português, salvo pedido explícito em outro idioma.
- Quando citar conteúdo técnico originalmente em inglês, traduzir ao explicar sempre que isso melhorar a compreensão.
- Ao explicar uma decisão ao usuário, traduzir termos conceituais técnicos para português (ex: "gate" → "verificação automática" ou "validação"; "playbook" → "roteiro"; "upstream" → "anterior" ou "que serve de base"; "fingerprint" → "marca de localização"; "manifesto" → "resumo descritivo do pacote"). Manter em inglês apenas nomes próprios — identificadores literais como `xpz-builder`, `who-uses`, `import_file.xml`.
- Misturar conceitos em inglês sem tradução em diálogo pt-BR aumenta o risco de o usuário não entender. Quando em dúvida, traduzir ou definir na primeira aparição.
