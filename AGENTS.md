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

**Escopo:** a rotina pré-push é de **análise, busca de coerência e relatório** ao usuário. **Não** inclui, por defeito, alterar arquivos nem criar commits com base no relatório. Em face dos gaps, o agente **apresenta** o diagnóstico e, se fizer sentido, um diff ou lista de alterações sugeridas, e **só grava** no repositório após **aprovação explícita** do usuário ou **pedido explícito** na mesma interação para aplicar essas alterações. Exceção: quando a instrução inicial do usuário já tiver sido explicitamente «aplica as correções que encontrares» ou equivalente.

Para cada frente alterada:

1. Identificar termos, scripts, wrappers, parâmetros, estados, caminhos e regras operacionais introduzidos ou modificados.
2. Buscar esses mesmos termos no repositório inteiro.
3. Comparar a documentação afetada com:
   - skills relacionadas
   - `README.md`
   - `02-regras-operacionais-e-runtime.md`
   - `08-guia-para-agente-gpt.md`
   - exemplos em `examples/`
   - scripts compartilhados em `scripts/`
4. Confirmar se há:
   - documentação antiga que contradiz a nova
   - exemplos canônicos desatualizados
   - scripts cujo contrato não bate com a descrição
   - checklist que promete validação que o script não executa
   - nova ferramenta, caminho ou parâmetro documentado em uma skill, mas ausente nas skills correlatas
5. Reportar separadamente:
   - gaps confirmados
   - flags descartados, com justificativa
   - áreas não cobertas pela busca

A rotina pré-push não está concluída enquanto essa busca de coerência cruzada não tiver sido executada e reportada, mesmo que `git diff --check`, parse e testes locais estejam limpos.

## Rastreabilidade privada de moldes sanitizados

- Quando uma frente criar, fortalecer, recombinar ou ampliar cobertura de molde sanitizado publicável, o agente deve avaliar explicitamente se existe anotação correspondente a registrar no `GeneXus-XPZ-PrivateMap`.
- Essa avaliação faz parte do fechamento metodológico da frente, mesmo quando nenhuma edição for feita imediatamente no repositório privado.
- Se houver necessidade de atualização no `GeneXus-XPZ-PrivateMap`, tratar isso como outro contexto operacional e sinalizar claramente ao usuário antes de editar fora desta base pública.

## Idioma

- Responder ao usuário em português, salvo pedido explícito em outro idioma.
- Quando citar conteúdo técnico originalmente em inglês, traduzir ao explicar sempre que isso melhorar a compreensão.
- Ao explicar uma decisão ao usuário, traduzir termos conceituais técnicos para português (ex: "gate" → "verificação automática" ou "validação"; "playbook" → "roteiro"; "upstream" → "anterior" ou "que serve de base"; "fingerprint" → "marca de localização"; "manifesto" → "resumo descritivo do pacote"). Manter em inglês apenas nomes próprios — identificadores literais como `xpz-builder`, `who-uses`, `import_file.xml`.
- Misturar conceitos em inglês sem tradução em diálogo pt-BR aumenta o risco de o usuário não entender. Quando em dúvida, traduzir ou definir na primeira aparição.
