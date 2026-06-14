---
name: xpz-kb-parallel-setup
description: Prepara e valida a estrutura inicial da pasta paralela da KB para carga inicial, sync de XPZ, índice derivado e artefatos de importação
---

# xpz-kb-parallel-setup

Define e valida a estrutura inicial da pasta paralela da KB usada ao redor de uma Knowledge Base GeneXus. Essa estrutura não substitui a pasta nativa da KB; ela concentra os `XPZ` exportados pela IDE, os XMLs materializados pelo fluxo oficial, o índice derivado para triagem e os artefatos locais preparados para importação posterior.

---

## GUIDELINE

Esta skill e de invocacao obrigatória antes de qualquer ação de consulta, triagem, leitura de XML ou geração de objeto em pasta que contenha `ObjetosDaKbEmXml/` ou `KbIntelligence/`. Nenhuma outra skill de KB (`xpz-index-triage`, `xpz-reader`, `xpz-builder`, `xpz-sync`, `nexa`) pode ser iniciada nessa pasta enquanto esta skill não tiver sido executada na sessao corrente.

**PRE-CONDICAO OBRIGATÓRIA AO SER INVOCADA PELO GATILHO GLOBAL** (não se aplica quando o usuário pede explicitamente setup, atualizacao ou auditoria — nesses casos ir direto ao WORKFLOW passo 1):

Esta pre-condicao e o caminho leve de seguranca para tarefas normais do usuário na KB. Ela deve executar apenas runtime, freshness e gate de índice enquanto o freshness retornar `GATE_ONLY` e o índice retornar `GATE_OK`; não carregar nem aplicar o corpo completo do WORKFLOW nesse caminho curto. `AUDIT_REQUIRED` por assinatura de contrato de setup ausente, invalida ou defasada e comportamento deliberado: após `git pull` da base metodologica, a pasta paralela precisa ser conferida quando a superficie de contrato de `xpz-kb-parallel-setup` mudou, para saber se deve incorporar wrappers, gates, metadata ou regras locais novas. Commits em outras frentes do repositório que não alterem essa superficie não devem, por si só, disparar auditoria completa.

0. Verificar se `Test-*KbPowerShellRuntime.ps1` existe em `scripts/` da pasta paralela e executa-lo antes de qualquer outro wrapper:
   ```powershell
   & "<caminho-absoluto-de-Test-*KbPowerShellRuntime.ps1>"
   ```
   - Se ausente: prosseguir com auditoria completa (WORKFLOW passo 1), mas classificar a pre-condicao como `setup_bloqueado` ate o wrapper ser criado via `atualizar_bootstrap_local`
   - Se retornar `POWERSHELL_RUNTIME_OK`: prosseguir para o passo 1
   - Se retornar `BLOCK:` ou falhar: registrar o erro e bloquear o uso operacional da pasta paralela ate existir `pwsh` com PowerShell 7.4 LTS ou superior
1. Verificar se `Test-*KbSetupFreshness.ps1` existe em `scripts/` da pasta paralela
   - Se ausente: prosseguir com auditoria completa (WORKFLOW passo 1)
2. Se presente, executar:
   ```powershell
   & "<caminho-absoluto-de-Test-*KbSetupFreshness.ps1>"
   ```
2a. Declarar na conversa o resultado obtido pelo script antes de prosseguir:
    - se `GATE_ONLY`: registrar "Test-*KbSetupFreshness.ps1 retornou GATE_ONLY"
    - se `AUDIT_REQUIRED: <motivo>`: registrar "Test-*KbSetupFreshness.ps1 retornou AUDIT_REQUIRED — <motivo>"
    - se script ausente (verificado no passo 1): registrar "Test-*KbSetupFreshness.ps1 ausente — auditoria completa necessária"
    - se erro inesperado: registrar o erro antes de decidir o próximo passo
3. Seguir o output:
   - `AUDIT_REQUIRED: <motivo>` → prosseguir com auditoria completa (WORKFLOW passo 1)
   - `GATE_ONLY` → executar `Test-*KbIndexGate.ps1`; se `GATE_OK`, liberar o fluxo normal; se `BLOCK`, prosseguir com auditoria completa (WORKFLOW passo 1)

O agente não deve raciocinar sobre timestamps por conta própria nem substituir a execução do script por verificacao manual de datas ou de arquivos.

Quando acionada pelo gatilho global, "auditoria completa" significa: executar `Test-*KbPowerShellRuntime.ps1` antes dos demais wrappers; se ele estiver ausente ou retornar `BLOCK:`, classificar como `setup_bloqueado` e não executar uso operacional da pasta paralela. Com runtime aprovado, executar `Test-*KbSetupAudit.ps1` (se existir), seguido de `Test-*KbIndexGate.ps1` (se existir), verificar que `estado_operacional_sugerido` e compativel com a tarefa em curso e liberar o fluxo somente após `GATE_OK`. Depois da auditoria completa, o agente deve classificar explicitamente o subestado transitorio da PRE-CONDICAO antes de voltar a tarefa original; esses rotulos `setup_*` não são estados canonicos de conclusao e não devem ser usados como estado final do setup:
- `setup_apto`: auditoria passou, gate passou e não ha pendencia persistente identificada no motivo original do `AUDIT_REQUIRED`.
- `setup_apto_com_metadata_pendente`: auditoria passou e gate passou, mas o motivo original do `AUDIT_REQUIRED` foi ausencia, defasagem ou inconsistencia de campo persistente em `kb-source-metadata.md`, como `last_setup_audit_run_at` ou `setup_contract_signature_*`.
- `setup_bloqueado`: runtime PowerShell mínimo falhou/ausente, auditoria ou gate falhou, ou `estado_operacional_sugerido` não e compativel com a tarefa em curso.

Quando o motivo original do `AUDIT_REQUIRED` for assinatura de contrato de setup ausente ou defasada e a auditoria completa seguida do gate passar sem pendencia corrigivel, tratar a gravacao de `last_setup_audit_run_at` e `setup_contract_signature_*` como fechamento da pre-condicao bem-sucedida: incluir `Set-*KbSetupAuditTimestamp.ps1` no plano consolidado, ou registrar recusa/adiamento explicito do usuário. Sem esse fechamento, a próxima sessao repetira a auditoria completa pelo mesmo motivo, mesmo com a pasta já conferida.

Se o subestado for `setup_apto_com_metadata_pendente`, o agente não pode prosseguir silenciosamente apenas porque o gate retornou `GATE_OK`. Antes de continuar a tarefa original, montar o **plano consolidado de correcoes** (seção PLANO DE CORRECOES POS-AUDITORIA), incluindo obrigatoriamente a linha de `last_setup_audit_run_at` e `setup_contract_signature_*` com `Set-*KbSetupAuditTimestamp.ps1` quando a auditoria bem-sucedida permitir gravacao. Declarar que a tarefa atual está liberada pelo gate, mas a pasta repetira auditoria completa nas próximas sessoes enquanto o plano não for executado ou adiado explicitamente pelo usuário.

Quando `estado_operacional_sugerido` for `atualizacao_metodologica_pendente`: ler todas as linhas `wrappers/inventario:` da saida e incorporar cada pendencia (`INVENTORY_GAPS`, `INVENTORY_SHORT_NAMING`, `INVENTORY_CUSTOMIZED`, `INVENTORY_LEGACY_ORPHANS`, `INVENTORY_RECOMMENDED_MISSING`) ao **plano consolidado de correcoes**, com explicacao em portugues e sem termos tecnicos em ingles. Não acionar o WORKFLOW de criacao/documentacao (passos 1-7b) — esse WORKFLOW e reservado para quando o usuário pede explicitamente setup, atualizacao ou auditoria.

Quando a saida de `Test-*KbSetupAudit.ps1` trouxer `metadata wrapper:` diferente de `OK` (`PENDENTE_DE_DADOS`, `PENDENTE` ou `BLOCK`), esse resultado também exige `estado_operacional_sugerido=atualizacao_metodologica_pendente`. `GATE_OK`, `NAMING_OK` e inventario sem gaps não neutralizam metadado de identidade ausente ou wrapper de metadata quebrado. O agente deve evidenciar a linha `metadata wrapper.evidencia`, distinguir campo ausente de falha funcional do wrapper e, quando a pendencia for identidade estavel ausente, oferecer reconciliacao via resolvedor/atualizador de identidade antes de declarar estado limpo.

Quando a saida trouxer `metadata/deploy:` diferente de `OK` (`PENDENTE` ou `BLOCK`), tratar como pendencia metodologica da mesma severidade: `metadata wrapper: OK` não prova plausibilidade semantica de `kb_environment_names` nem do mapeamento `kb_environment_output_dirs`/`kb_environment_web_dirs`. O agente deve evidenciar `metadata/deploy.evidencia`, distinguir campos de deploy/output ausentes (`PENDENTE`) de metadata legado ou inconsistente (`BLOCK`), perguntar ao usuário os nomes exatos dos environments e os diretórios de output por environment, validar cada nome via MSBuild (`SetActiveEnvironment` headless) e rerodar `Set-*KbSourceMetadataDeployment.ps1` com `-KbEnvironmentNames` e `-KbEnvironmentOutputDirs` antes de declarar estado limpo.

Após o setup ser concluido com sucesso, qualquer consulta de existência, localização ou triagem de XML deve ser roteada para `xpz-index-triage` antes de abrir arquivos individuais, quando a pasta adotar `KbIntelligence`.

Usar esta skill quando o trabalho exigir preparar, explicar, validar, atualizar ou corrigir a estrutura da pasta paralela da KB. O agente deve separar claramente a pasta nativa da KB da pasta paralela e aplicar os nomes padrão quando o usuário não informar alternativas.

Quando o usuário usar qualquer linguagem que sugira setup — "refazer", "reiniciar", "recriar", "atualizar", "preciso dos novos scripts", "meu gate ta falhando" ou equivalente — em pasta que já tem histórico real, assumir `modo_atualizacao` e confirmar brevemente com o usuário o que sera feito antes de gravar. Se o pedido for genérico, como "refazer o setup", "revisar o setup" ou equivalente, assumir por padrão a intencao `auditar_setup` ate que o usuário peca explicitamente `corrigir_wrapper_local` ou `atualizar_bootstrap_local`. Em pasta com histórico real, `modo_criacao` nunca e uma opção oferecida ou aceita; se o usuário insistir em apagar tudo ou recriar do zero, recusar, explicar que dados existentes não serao destruidos e redirecionar para `modo_atualizacao`.

Essa confirmacao breve antes de gravar deve ser textual, objetiva e aderente ao diagnostico em andamento. Não abrir menu, enquete, questionario ou lista de opções logo no inicio de `modo_atualizacao` quando a auditoria mínima obrigatória ainda não tiver sido concluida.

Em `modo_atualizacao`, a verificacao de naming de `ObjetosDaKbEmXml` não e opcional e não pode ser pulada mesmo quando todos os scripts forem EQUIVALENTE: para cada diretório presente na pasta, o agente deve ler pelo menos um XML, extrair o tipo canonico pelo GUID (ou pelo elemento raiz `<Attribute>`), comparar com o nome do diretório e reportar o resultado — conforme ou divergente — antes de declarar qualquer estado de conclusao.

Dentro de `modo_atualizacao`, separar primeiro a intencao operacional antes de avancar:
- `auditar_setup`: o usuário quer conferir se a pasta paralela está aderente, atualizada e coerente; a saida principal e diagnostico com estado operacional, classificação de scripts, pendencias e **plano consolidado de correcoes** oferecido para execução na mesma sessao
- `corrigir_wrapper_local`: o usuário quer corrigir um wrapper local defasado, quebrado ou reprovado por gate; a saida principal e edicao do wrapper, rerun do gate relevante e handoff atualizado
- `atualizar_bootstrap_local`: o usuário quer incorporar wrappers ou seções documentais ausentes previstos pela base metodologica; a saida principal e completar o bootstrap local faltante sem recriar a pasta

`modo_atualizacao` descreve o contexto da pasta; `auditar_setup`, `corrigir_wrapper_local` e `atualizar_bootstrap_local` descrevem a natureza do trabalho. Não tratar essas tres intencoes como se fossem a mesma coisa só porque acontecem na mesma pasta com histórico real.

Em `auditar_setup`, concluir primeiro a auditoria mínima obrigatória e, em seguida, montar e oferecer o **plano consolidado de correcoes** (seção PLANO DE CORRECOES POS-AUDITORIA) antes de qualquer outro próximo passo operacional. Antes disso, não oferecer `sincronizar XPZ novamente`, `rebuild do indice` ou equivalentes como resposta-padrao a um pedido de "refazer setup".

Quando `auditar_setup` detectar `INVENTORY_SHORT_NAMING` no campo `wrappers/inventario` da saida de `Test-*KbSetupAudit.ps1`: os scripts listados existem com naming curto (ex: `Test-KbIndexGate.ps1`) em vez do naming canonico com prefixo KB (ex: `Test-wsEducacaoSpTesteKbIndexGate.ps1`). Essa divergencia NÃO e opcional, NÃO pode ser descartada como "convencao consistente aceita", NÃO e neutralizada por `GATE_OK`, `STRUCTURE_OK` ou pelo fato de os scripts funcionarem operacionalmente. O naming curto e uma divergencia do padrão desta skill. O agente deve: classificar cada script SHORT_NAMING como CUSTOMIZADO com ação de renome na tabela de 8.h; oferecer `atualizar_bootstrap_local` para executar os renomes; incluir os renomes na lista de trabalho da sessao corrente — não adiar para sessao futura nem condicionar a confirmacao a que o usuário mencione o problema primeiro.

Quando `auditar_setup` detectar `INVENTORY_CUSTOMIZED` no campo `wrappers/inventario` da saida de `Test-*KbSetupAudit.ps1`: os scripts listados existem, mas divergem metodologicamente do exemplo canonico correspondente. Divergencia de `#requires -Version` e divergencia metodologica objetiva quando o exemplo canonico declara uma versão e o wrapper local declara outra versão, mesmo que a lógica funcional restante seja equivalente. O agente deve classificar cada script listado como CUSTOMIZADO na tabela de 8.h, evidenciar o motivo emitido pelo inventario e não declarar `wrappers_atualizados` nem `materializado_e_indice_validado` como estado limpo ate haver decisão explicita sobre a correcao.

Quando `auditar_setup` detectar `INVENTORY_LEGACY_ORPHANS` no campo `wrappers/inventario` da saida de `Test-*KbSetupAudit.ps1`: os scripts listados são nomes antigos que permaneceram na pasta `scripts/` depois que o nome canonico atual já existe. Isso e pendencia metodologica objetiva porque mantem allowlists e documentação local apontando para comandos antigos. O agente deve classificar o arquivo legado como CUSTOMIZADO/legado na tabela de 8.h, oferecer remocao segura e atualizacao de referencias em `.claude\settings.json`, `AGENTS.md`, `README.md` e scripts locais, sempre com aprovacao explicita antes de apagar ou editar.

Quando `auditar_setup` detectar `metadata wrapper: PENDENTE_DE_DADOS`, `metadata wrapper: PENDENTE` ou `metadata wrapper: BLOCK`, ou `metadata/deploy: PENDENTE` ou `metadata/deploy: BLOCK`, não declarar `materializado_e_indice_validado` nem gravar `last_setup_audit_run_at` e `setup_contract_signature_*` como conclusao bem-sucedida. Se o próprio `estado_operacional_sugerido` ainda vier limpo nesse cenário, tratar como divergencia do motor de auditoria e corrigir a metodologia antes de usar o resultado para liberar a pasta.

## PLANO DE CORRECOES POS-AUDITORIA

Aplica-se sempre que esta skill tiver concluido **auditoria mínima** — seja em `auditar_setup`, no BLOCO DE ATUALIZACAO de `modo_atualizacao` ou na **auditoria completa** da PRE-CONDICAO do gatilho global (após `Test-*KbSetupAudit.ps1` e `Test-*KbIndexGate.ps1` com `GATE_OK`, quando aplicavel). Não substitui as regras de aprovacao explicita antes de gravar; consolida **o que oferecer corrigir** e **em que ordem**, para o usuário não precisar descobrir pendencia por pendencia.

### Objetivo

Ao terminar a auditoria, o agente deve entregar ao usuário:

1. **Diagnostico** (estado operacional canonico, dimensoes do `Test-*KbSetupAudit.ps1` quando existir, tabela 8.h quando `modo_atualizacao`).
2. **Plano consolidado de correcoes** — lista única de itens corrigiveis nesta pasta segundo esta skill, cada um com ação proposta, pre-requisito de aprovacao (sim/nao) e skill/intencao usada (`atualizar_bootstrap_local`, `corrigir_wrapper_local`, passo 34, etc.).
3. **Oferta em lote**: perguntar se deseja executar o plano (ou subconjunto) **agora nesta sessao**; não encerrar com apenas "fica pendente" nem recomendar rodada futura por padrão.

`GATE_OK` pode liberar a tarefa original do usuário **em paralelo** ao plano, mas **não** dispensa apresentar o plano quando houver item corrigivel.

### Itens que entram no plano (quando detectados)

Consolidar **todos** os itens abaixo que a auditoria tiver identificado; omitir um item da lista e proibido quando a evidencia existir:

| Origem tipica | Item no plano | Ação preferida | Aprovacao antes de gravar |
|---|---|---|---|
| `setup_apto`, `setup_apto_com_metadata_pendente` ou passo 34 após `AUDIT_REQUIRED` | `last_setup_audit_run_at` ou `setup_contract_signature_*` ausente, vazio ou defasado após auditoria OK; inclui contrato de setup atualizado | `Set-*KbSetupAuditTimestamp.ps1`; rerodar freshness e index gate | Sim, se regra local exigir |
| `INVENTORY_GAPS` / scripts AUSENTE em 8.h | Wrappers ou gates ausentes previstos | `atualizar_bootstrap_local` a partir dos `.example.ps1` | Sim |
| `INVENTORY_SHORT_NAMING` | Naming curto de wrapper | Renome canonico em lote (8.c exceção 2) | Sim, confirmacao em lote |
| `INVENTORY_LEGACY_ORPHANS` | Script legado lado a lado com canonico | Remocao segura + atualizar referencias (8.f.1) | Sim |
| `INVENTORY_CUSTOMIZED` (não SHORT_NAMING) | Wrapper divergente do exemplo | Menu 8.c ou caso deterministico → `corrigir_wrapper_local` | Sim, por script ou lote |
| Caso deterministico (8.a.iii, 8.z) | Wrapper defasado com correcao inequivoca | `corrigir_wrapper_local` sem menu A/B/C/D | Sim, se regra local exigir |
| `metadata wrapper` ≠ OK | Identidade ou contrato de metadata | Reconciliacao via `Resolve-*KbIdentity` / `Update-*KbMetadataIdentity` ou corrigir wrapper | Sim |
| `metadata/deploy` ≠ OK | Plausibilidade de environment/deploy/output em `kb-source-metadata.md` | Perguntar nomes e diretórios de output ao usuário, rerodar `Set-*KbSourceMetadataDeployment.ps1` com `-KbEnvironmentNames` + `-KbEnvironmentOutputDirs` + validação MSBuild; corrigir wrapper se `uses_removed_inventory_discovery` ou parâmetro novo ausente | Sim |
| `declarativo/timestamps=DRIFT_TIMESTAMPS_LITERAIS` | Timestamps literais em `AGENTS.md`/`README.md` | Substituir por ponteiros (`examples/AGENTS.md.example`) | Sim |
| Seção `## Triagem Por Indice` ausente (8.g) | Roteamento para `xpz-index-triage` | Inserir bloco padrão no `AGENTS.md` local | Sim |
| `INVENTORY_RECOMMENDED_MISSING` | Wrappers finos recomendados | Criar a partir dos `.example.ps1` | Sim |
| Naming divergente em `ObjetosDaKbEmXml` (8.g2) | Diretórios com tipo real ≠ nome da pasta | Renome seguro com aprovacao | Sim |
| Prefixo verbal defasado (8.f) | Nome local ≠ exemplo canonico (`Update-` vs `Rebuild-`, etc.) | Renome + atualizar referencias | Sim |
| `Test-*KbPowerShellRuntime.ps1` ausente | Runtime gate ausente | Incorporar wrapper de runtime | Sim |

### Itens que **não** entram no plano desta skill

Não prometer no plano consolidado o que pertence a outra frente, salvo mencionar como **fora de escopo** com skill responsável:

- Materialização XPZ/XML, sync de acervo, `last_xpz_materialization_run_at` → `xpz-sync`
- Rebuild/regeneracao de índice quando defasado por materialização → wrappers de índice + `xpz-sync` encadeado
- Import/build MSBuild, empacotamento de negocio, geração de objetos → skills respectivas
- Scripts **CUSTOMIZADOS** com divergencia editorial de lógica sem correcao deterministica → entram no plano como **decisão do usuário** (8.c), não como "correcao automática"

### Ordem de execução sugerida no plano

Quando o usuário aprovar o pacote, executar na ordem abaixo salvo bloqueio concreto:

1. `Test-*KbPowerShellRuntime.ps1` presente e OK (se estava ausente).
2. Casos deterministicos de wrapper (`corrigir_wrapper_local`) que desbloqueiam gates.
3. `atualizar_bootstrap_local` para scripts AUSENTE e renomes SHORT_NAMING.
4. Limpeza de legados orfaos e alinhamento de prefixos verbais (8.f / 8.f.1).
5. Drift declarativo (`AGENTS.md`/`README.md`) e seção de triagem por índice.
6. Metadata de setup (`Set-*KbSetupAuditTimestamp.ps1`) quando auditoria bem-sucedida permitir.
7. Reconciliacao de identidade estavel quando `metadata wrapper` exigir.
8. Gravacao de environment/deploy/output (`Set-*KbSourceMetadataDeployment.ps1` com `-KbEnvironmentNames` e `-KbEnvironmentOutputDirs` confirmados pelo usuário + validação MSBuild obrigatória) e correcao do wrapper local quando `metadata/deploy`, `uses_removed_inventory_discovery` ou parâmetro novo ausente exigirem. Imediatamente após gravar campos de deploy, reexecutar `Test-*KbMetadataWrapper.ps1`: a gravacao torna obrigatório que `Get-*KbMetadata.ps1` exponha os campos novos, então um leitor antes aprovado pode passar a bloquear com `BLOCK: <campo> existente no metadata nao foi exposto pelo wrapper`. Quando isso ocorrer, e o caso deterministico de 8.a.iii — alinhar `Get-*KbMetadata.ps1` ao exemplo canonico antes de seguir, sem abrir menu A/B/C/D.
9. Wrappers `INVENTORY_RECOMMENDED_MISSING` e naming de `ObjetosDaKbEmXml` aprovados pelo usuário.
10. Rerodar `Test-*KbSetupAudit.ps1`, `Test-*KbSetupFreshness.ps1` (se existir) e `Test-*KbIndexGate.ps1`; atualizar handoff.

### PRE-CONDICAO do gatilho global

Depois de classificar o subestado transitorio (`setup_apto`, `setup_apto_com_metadata_pendente`, `setup_bloqueado`):

- Se `setup_bloqueado`: não voltar a tarefa original; plano só com o que for corrigivel para destravar.
- Se `setup_apto` ou `setup_apto_com_metadata_pendente` com itens corrigiveis: **montar o plano consolidado** antes de retomar a tarefa original; itens de metadata pendente entram como linhas do plano, não como único aviso solto. Quando o único item for atualizar `last_setup_audit_run_at` e `setup_contract_signature_*` após auditoria bem-sucedida exigida por assinatura de contrato ausente ou defasada, ele ainda deve aparecer no plano para restaurar o caminho `GATE_ONLY` das próximas sessoes.
- Registrar decisão do usuário sobre o plano: executado (total/parcial), recusado ou adiado — só entao retomar a tarefa original liberada pelo gate.

### Fechamento de `auditar_setup`

`auditar_setup` **não** fecha apenas com diagnostico. Fecha com diagnostico **+** plano consolidado oferecido **+** registro da decisão do usuário (executar agora, recusar, adiar ou executar subconjunto). Se o usuário aprovar execução, o agente pode transitar para `atualizar_bootstrap_local` e/ou `corrigir_wrapper_local` na mesma sessao sem exigir novo pedido do usuário.

### Politica de delegacao a LLM (opcional, adiavel, nao-bloqueante)

A skill `xpz-llm-delegate` usa um arquivo de politica por-KB na raiz da pasta paralela para autorizar de forma duravel o envio de conteúdo desta KB a modelos externos (ver `xpz-llm-delegate/SKILL.md`). O nome canonico e `llm-delegation-policy.json`; o nome legado `opencode-delegation-policy.json` permanece aceito para retrocompatibilidade.

- Este item **nunca** e gate de setup, não entra na matriz de wrappers exigidos e **não** bloqueia nenhum estado de conclusao. O setup fecha normalmente sem ele.
- Ao concluir o setup, **oferecer** (sem cobrar) definir a politica, com pergunta em prosa e opção explicita de **adiar** — no setup o usuário costuma ter muito a digerir.
- Ausencia do arquivo ⇒ comportamento `ask` no gate (`Resolve-LlmDelegateAuthorization.ps1`); adiar nunca abre brecha.
- Se o usuário aceitar, gravar `llm-delegation-policy.json` (nome canonico) com `schemaVersion`, `defaultExternal` e entradas finas por `provider/modelo` conforme a escolha; nunca presumir `allow-external` por conta própria.
- Se a pasta ja tiver o arquivo com o nome legado `opencode-delegation-policy.json`, ele continua valendo; oferecer (sem cobrar) renomear para `llm-delegation-policy.json`. Com os dois presentes, o `scripts/Resolve-LlmDelegationPolicyPath.ps1` usa o canonico e sinaliza `status=both`.

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositório.
- Toda referência `../arquivo.md` deve ser resolvida a partir da pasta deste `SKILL.md`, e não do diretório de trabalho corrente.
- Na prática, `../` aponta para a base metodológica compartilhada na pasta-pai desta skill.
- Quando a sessão já publicar um caminho desta skill ou de seus exemplos, usar esse caminho publicado como fonte autoritativa; não inferir caminho alternativo por heurística.
- Para `examples/`, resolver primeiro a pasta irmã do `SKILL.md` publicado na sessão. Se o `SKILL.md` publicado vier de fora do repositório corrente, não procurar `examples/` primeiro dentro do workspace atual só porque existe uma pasta de nome parecido.
- Se o caminho publicado da skill estiver fora do workspace atual, isso não autoriza reinterpretar a origem da skill nem trocar automaticamente para um caminho "equivalente" dentro do repositório; o caminho publicado continua prevalecendo até evidência objetiva em contrário.
- Se a leitura dos `examples/` publicados ainda não tiver ocorrido, a auditoria pode seguir provisoriamente com evidência local já disponível (`GATE_OK`, `STRUCTURE_OK`, parse dos wrappers, presença de seções obrigatórias e verificação de naming), deixando a classificação final contra os exemplos como etapa pendente explícita em vez de abrir exploração ampla de caminhos cedo demais.

---

## TRIGGERS

Use esta skill para:
- Carga Inicial de uma KB usando repositório paralelo
- Preparar a estrutura inicial de pastas para fluxos com `XPZ`
- Validar se a pasta paralela da KB está pronta para `sync`, geração de XML ou empacotamento
- Preparar a pasta paralela da KB para uso de índice derivado em `KbIntelligence`
- Auditar setup de pasta paralela existente e, ao final, oferecer na mesma sessao o plano consolidado de correcoes de tudo que esta skill classificar como corrigivel nesta pasta (execução após aprovacao quando a skill exigir)
- Corrigir wrapper local defasado ou reprovado por gate, especialmente quando a evidencia vier de `Test-*KbMetadataWrapper.ps1`, `Test-*KbIndexGate.ps1` ou `Test-*KbStructure.ps1`
- Atualizar wrappers de pasta paralela com histórico de uso para incorporar novos scripts previstos pela base metodologica compartilhada
- Barrar uso operacional da pasta paralela quando `pwsh` com PowerShell 7.4 LTS ou superior não estiver disponível
- Detectar que o `AGENTS.md` da pasta paralela está desatualizado em relacao ao padrão canonico atual — por exemplo, ausencia de seção `## Triagem Por Indice`, lista de wrappers incompleta ou outras seções ausentes identificadas por comparacao com `examples/AGENTS.md.example`
- Verificar se o naming dos diretórios de container em `ObjetosDaKbEmXml` corresponde ao GUID real de cada objeto — especialmente `Folder/`, `Module/` e `PackagedModule/` — e propor correcao quando houver inversao ou divergencia
- Explicar a diferenca entre pasta da KB e pasta paralela da KB
- Confirmar nomes padrão das subpastas quando o usuário não informou alternativas
- Verificar consultivamente a capacidade de importação headless antes de tarefa que dependa de importação real via MSBuild, quando a pasta paralela tiver sinais de uso desse fluxo (`PacotesGeradosParaImportacaoNaKbNoGenexus/` populado, wrapper local de import, ou tarefa mencionando `importar`, `preview`, `MSBuild import`, `import_file.xml` ou `pacote gerado`); ver seção `## CAPACIDADE DE IMPORTACAO HEADLESS`

Do NOT use this skill for:
- Sincronizar `XPZ` específico no acervo oficial (use `xpz-sync`)
- Gerar ou empacotar objetos XML (use `xpz-builder`)
- Analisar estrutura de objeto XML individual (use `xpz-reader`)
- Consultar o índice derivado como etapa analitica principal (use `xpz-index-triage`)
- Regenerar o índice como objetivo principal da tarefa; esta skill prepara a estrutura e os wrappers locais

---

## RESPONSABILIDADES

- Explicar que a pasta nativa da KB e diferente da pasta paralela da KB
- Assumir o termo principal `pasta paralela da KB`
- Se o caminho da pasta nativa da KB não vier no prompt, pedir esse caminho ao usuário antes de concluir o setup inicial
- Se o caminho da pasta nativa da KB vier no prompt, reutilizar esse valor sem pedir novamente
- Se o agente verificar a existência da pasta nativa da KB, declarar o resultado no handoff; se ela não existir ou não estiver acessivel, registrar o caminho informado, manter a regra de não gravacao e fechar o setup com ressalva operacional explicita
- Quando o usuário não informar nomes alternativos, assumir estas subpastas padrão:
  - `scripts`
  - `Temp`
  - `XpzExportadosPelaIDE`
  - `ObjetosDaKbEmXml`
  - `KbIntelligence`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- Explicar que os nomes acima são apenas padrões sugeridos; a função de cada pasta prevalece sobre o nome literal
- Se o usuário informar nomes diferentes, registrar esse mapeamento em `AGENTS.md` e, quando fizer sentido para humanos, também em `README.md` dentro da própria pasta paralela da KB
- Registrar em `AGENTS.md` da pasta paralela o caminho confirmado da pasta nativa da KB
- Registrar em `AGENTS.md` da pasta paralela que a pasta nativa da KB e terreno proibido para gravacao por agentes, com leitura permitida apenas quando o fluxo operacional explicito realmente exigir
- Quando houver `README.md` local para humanos na pasta paralela, espelhar ali a identificacao da pasta nativa da KB e a regra de somente leitura em linguagem clara
- Em setup inicial padrão sem nomes alternativos, sem conflito estrutural e com pasta nativa da KB já informada, evitar exploracao ampla do motor compartilhado e dos exemplos antes de criar a estrutura base; explorar mais só se surgir bloqueio concreto
- Quando a inspecao local da pasta contradisser contexto indireto do ambiente, da sessao ou de hooks, confiar primeiro na inspecao local e seguir com verificacao curta e objetiva, sem narrativa longa de especulacao
- Explicar a função de cada subpasta
- Tratar `ObjetosDaKbEmXml` como snapshot oficial somente leitura para agentes
- `ObjetosDaKbEmXml` é o snapshot oficial da KB e agentes não o editam manualmente (editar o acervo esperando que o pacote use essa versão é anti-padrão; ver `02-regras-operacionais-e-runtime.md`, anti-padrão "editar acervo esperando que o pacote pegue")
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` é a área intermediária de trabalho anterior ao retorno oficial da KB e não atualiza diretamente o acervo oficial
- Preview ou importação bem-sucedida na IDE não atualizam, por si sós, `ObjetosDaKbEmXml`
- `ObjetosDaKbEmXml` só é atualizado depois que a KB devolve `XPZ` oficial e o `xpz-sync` materializa esse retorno
- Tratar `XpzExportadosPelaIDE` como pasta de entrada onde o usuário grava os `.xpz` exportados pela IDE
- Tratar `Temp` como destino preferencial para artefatos efemeros, temporarios de execução, relatórios descartaveis e copias temporarias de SQLite
- Tratar `KbIntelligence` como pasta do índice SQLite derivado e regeneravel, normalmente `KbIntelligence\kb-intelligence.sqlite`, mais relatórios de validação quando o repositório local adotar esse fluxo
- Tratar `kb-source-metadata.md` como metadado operacional da materialização XPZ/XML; ele deve expor `last_xpz_materialization_run_at` quando o fluxo oficial tiver processado um insumo da IDE
- Tratar qualquer memoria local de setup que diga `ainda nao materializada`, `aguardando primeiro XPZ` ou equivalente como estado provisório; depois da primeira materialização oficial bem-sucedida, esse estado não deve continuar sendo apresentado como atual
- Tratar `KbIntelligence\kb-intelligence.sqlite` como dono do metadado `last_index_build_run_at` na tabela `metadata`; esse horario deve ser igual ou posterior a `last_xpz_materialization_run_at` para permitir triagem ampla e geração de objetos de importação; `last_index_build_run_at` e a fonte autoritativa do estado de frescor do índice — qualquer decisão sobre frescor do índice deve consultar esse campo via query `index-metadata`, não criar campo derivado ou espelho em `kb-source-metadata.md`
- Além do frescor por timestamp, `Test-*KbIndexGate.ps1` deve validar `extractor_signature_version` e `extractor_signature_hash` na metadata do SQLite contra o motor compartilhado (`scripts/GeneXusKbIntelligenceExtractorContract.ps1` + `scripts/Build-KbIntelligenceIndex.py` no repositório ativo). Índice sem assinatura ou com assinatura divergente bloqueia com `BLOCK:` mesmo quando `last_index_build_run_at >= last_xpz_materialization_run_at` — regenerar o índice
- Regeneracao do índice via `Rebuild-*KbIntelligenceIndex.ps1` (motor `scripts/Build-KbIntelligenceIndex.ps1`) exige **Python 3.x utilizavel** no `PATH` (`scripts/GeneXusPythonPrerequisite.ps1`; stub da Microsoft Store em `WindowsApps` não conta). Ausencia bloqueia o refresh com exit `8` e mensagem `PREREQUISITO AUSENTE` — **rigor**: sync normal **não** terminou; a materialização XPZ/XML em `ObjetosDaKbEmXml` pode já ter concluido, mas isso **não** equivale a sucesso do fluxo oficial nem autoriza triagem ampla sem índice. Não tratar como falha do pacote exportado; instalar Python 3.x e rerodar o rebuild (`Rebuild-*KbIntelligenceIndex.ps1`). O molde `Update-KbFromXpz.example.ps1` propaga essa mensagem quando o encadeamento de rebuild falhar no mesmo `pwsh`. Ver `README.md`, `02-regras-operacionais-e-runtime.md` e `xpz-sync` da base compartilhada
- Tratar `kb-source-metadata.md` e a saida de `-Query index-metadata` do wrapper local como fontes autoritativas dos timestamps operacionais de materialização e índice; `AGENTS.md` e `README.md` locais servem como memoria auxiliar humana (wrappers, fluxos, pacotes de referencia) e não devem gravar timestamps literais de `last_xpz_materialization_run_at` ou `last_index_build_run_at` — apenas ponteiros para as fontes autoritativas e para a linha `declarativo/timestamps` em `Test-*KbSetupAudit.ps1`
- Tratar `kb-source-metadata.md` por autoridade de campo, não por dono único do arquivo:
  - identidade estavel da KB (`Source/kb (GUID)`, `Source/username`, `Source/UNCPath`, `Source/Version/guid`, `Source/Version/name`): autoridade primaria do setup/resolvedor da KB nativa local; autoridade secundaria do XPZ somente quando o pacote vier completo e coerente com a KB local
  - `KMW` (`MajorVersion`, `MinorVersion`, `Build`): autoridade primaria do XPZ real ou template real comparavel; setup não deve inventar esses valores sem evidencia
  - materialização (`last_xpz_materialization_run_at`, `source_xpz`, `source_refresh_status`): autoridade do fluxo `xpz-sync`
  - auditoria de setup (`last_setup_audit_run_at`, `setup_contract_signature_version`, `setup_contract_signature_hash`): autoridade desta skill, nos estados canonicos permitidos
  - environments GeneXus (`deployment_environment_name`, `deployment_hosting_kind`, `kb_environment_count`, `kb_environment_names`, `kb_environment_output_dirs`, `kb_environment_web_dirs`): autoridade **declarada pelo usuário** (nomes exatos como na IDE e diretórios de output confirmados por environment) via `scripts/Set-XpzKbSourceMetadataDeployment.ps1` (wrapper local `Set-*KbSourceMetadataDeployment.ps1`); **obrigatório** `-KbEnvironmentNames`, `-KbEnvironmentOutputDirs` e validação MSBuild (`SetActiveEnvironment` headless sobre a lista informada); `kb_environment_web_dirs` pode ser derivado de `-KbNativePath` + output dir + `web`, sem scan; scan/inventario automático por pastas da KB nativa (`-InventoryFromKbNativePath`, `-InventoryFromGeneXusMsBuild`) **removido**; `-SkipEnvironmentNamesMsBuildValidation` só quando sondagem MSBuild indisponivel por infraestrutura; build/import/diagnostico de `.cs` só leem metadata gravado
- Tratar `deployment_environment_name` como identificador MSBuild aceito por `SetActiveEnvironment` (ex.: `NETPostgreSQL`), **não** nome descritivo de `GetEnvironmentProperty -Name Name`
- Tratar `deployment_hosting_kind` como `dotnet-core-self-host` ou `dotnet-framework-iis` — gate pos-import olha publicacao em `web\bin` (DLL de objeto + config), não `GxNetCoreStartup.dll` sozinha (`xpz-msbuild-build`, exit **49**)
- Tratar `kb_environment_post_build_event_hashes` (fingerprints SHA-256 dos eventos pos-build conhecidos por environment, encoding plano `env=h1,h2; env2=h3`) como autoridade desta skill via `scripts/Register-GeneXusKbPostBuildEvents.ps1`: registra a partir do JSON de um build (`stdoutSignals.postBuildEvents`), filtra inertes (`REM` comentado), grava o campo plano **e** a secao-espelho legivel `## Eventos pos-build registrados` (linhas cruas, só para auditoria humana — o build le os hashes, não o espelho). Ação sensivel — registrar **desarma** o rebaixamento por evento pos-build daquele environment: exige confirmacao (frase exata interativa ou `-ConfirmRegistration` em modo agente, após o usuário aprovar). O build (`xpz-msbuild-build`) compara os eventos observados por fingerprint: registrado = esperado (não rebaixa); não registrado = rebaixa por cautela; sem registro, rede de seguranca reconhece player de som como benigno
- Tratar `kb_environment_count` = `1` como permissao para omitir `-EnvironmentName` nos wrappers de build quando o environment ativo GeneXus for o único da KB; `kb_environment_count` > `1` exige `-EnvironmentName` explicito ou `deployment_environment_name` preenchido antes de validação pós-import (`xpz-msbuild-build`)
- Em `modo_atualizacao` ou quando campos de environment/deploy/output estiverem ausentes ou suspeitos: **perguntar ao usuário** (1) quais são os environments GeneXus desta KB — nomes exatos como na IDE / `SetActiveEnvironment`; (2) qual e o environment de deploy/validacao headless; (3) qual diretório de output corresponde a cada environment (ex.: `NETPostgreSQL=NETPostgreSQL`, `.Net Environment=NETFrameworkPostgreSQL`); executar `Set-XpzKbSourceMetadataDeployment.ps1` (ou wrapper local) com `-DeploymentEnvironmentName`, `-DeploymentHostingKind`, `-KbEnvironmentNames`, `-KbEnvironmentOutputDirs`, `-KbNativePath` e `-InventoryWorkingDirectory`; validação MSBuild e **obrigatória** salvo sondagem indisponivel (`-SkipEnvironmentNamesMsBuildValidation` com pendencia explicita no handoff). `kb_environment_web_dirs` pode ser derivado pelo motor quando `-KbNativePath` estiver presente; scan automático de pastas da KB nativa e proibido.
- Tratar divergencia de `Source/kb (GUID)` como bloqueio de seguranca: se um pacote, template ou XPZ trouxer GUID de KB preenchido e diferente da KB nativa local registrada/resolvida para a pasta paralela, o agente não deve trocar o `Source` para normalizar o pacote nem prosseguir com import headless; deve bloquear a automacao e encaminhar o usuário para importação manual pela IDE
- Quando a pasta paralela já tiver gerado e importado com sucesso pacotes `import_file.xml`, registrar em `AGENTS.md` local uma seção opcional `## Pacote de referencia conhecido` listando o caminho de pelo menos um pacote real comparavel para cada natureza de pacote praticada nesta pasta (full, delta cirurgico, migracao). Esse caminho serve como candidato default para `-TemplatePackagePath` do motor compartilhado `scripts/New-XpzImportPackage.ps1` em rodadas futuras, conforme a regra de comparabilidade documentada em `xpz-builder/SKILL.md`. Quando essa seção não existir ou não apontar pacote comparavel ao caso corrente, o agente que invocar o motor deve omitir `-TemplatePackagePath` e aceitar o envelope mínimo (warning `envelope-minimo`) explicitamente. Manter essa seção como opcional: a pasta paralela pode operar sem ela enquanto o usuário não tiver pacote comparavel para citar
- Tratar `last_setup_audit_run_at` em `kb-source-metadata.md` como timestamp da última execução de setup ou auditoria de setup concluida com sucesso nesta pasta paralela; tratar `setup_contract_signature_version` e `setup_contract_signature_hash` como a assinatura de contrato de `xpz-kb-parallel-setup` validada nessa auditoria. Gravar esses campos imediatamente após declarar qualquer estado canonico de conclusao bem-sucedido (`pronto_para_primeira_materializacao`, `materializado_e_indice_validado`, `wrappers_atualizados`); não gravar quando a conclusao for `bootstrap_incompleto`, `auditoria_de_empacotamento_pendente` ou `atualizacao_metodologica_pendente`, pois esses estados indicam conclusao parcial e não garantem que a próxima invocacao pode confiar no setup como integro. Esses campos são diferentes dos timestamps operacionais de materialização e índice: `last_xpz_materialization_run_at` pertence ao fluxo `xpz-sync`; `last_index_build_run_at` pertence ao SQLite do `KbIntelligence`; `last_setup_audit_run_at` e `setup_contract_signature_*` pertencem somente a auditoria de setup bem-sucedida.
- Explicar que o fluxo oficial de materialização XPZ/XML deve chamar a regeneracao/validacao do índice derivado compulsoriamente após atualizar `ObjetosDaKbEmXml`
- Explicar que, após processamento bem-sucedido, um `.xpz` em `XpzExportadosPelaIDE` pode ser renomeado para `processado_<nome-original>.xpz`
- Tratar `ObjetosGeradosParaImportacaoNaKbNoGenexus` como area de trabalho para XMLs temporarios destinados a importação manual na IDE
- Tratar `PacotesGeradosParaImportacaoNaKbNoGenexus` como area de saida para `import_file.xml` e, quando aplicavel, `XPZ`
- Tratar `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus` como areas gerenciadas por agente, não como deposito geral do usuário; XML de referencia, exemplo ou template deixado na frente ativa deve ser bloqueio de empacotamento ate ser removido ou tratado por caminho explicito fora da frente
- Por padrão, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus` não precisam ser versionadas em Git; se houver duvida sobre rastrear ou ignorar seu conteúdo, tratar isso como decisão de politica do repositório e pedir aprovacao explicita
- Exigir que cada frente ativa em `ObjetosGeradosParaImportacaoNaKbNoGenexus` use sua própria subpasta `NomeCurto_GUID_YYYYMMDD`
- Explicar que `NomeCurto_GUID_YYYYMMDD` combina nome curto, GUID criado na abertura da frente e data de criacao da frente; `YYYYMMDD` representa a data de criacao da frente, não a data do pacote
- Explicar que a subpasta `NomeCurto_GUID_YYYYMMDD` e a unidade ativa da frente
- Exigir reuso da mesma subpasta quando a frente já existir e estiver sendo retomada
- Exigir que `PacotesGeradosParaImportacaoNaKbNoGenexus` permaneça plano, sem subpastas por frente
- Explicar que novos `XPZ` completos podem ser usados a qualquer momento para reatualizar `ObjetosDaKbEmXml`
- Quando acionado para revisar naming de `ObjetosDaKbEmXml` em pasta paralela existente, ler pelo menos um XML de cada diretório de container (`Folder/`, `Module/`, `PackagedModule/`) e verificar o `Object/@type` real antes de qualquer conclusao sobre inversao ou conformidade
- Distinguir Carga Inicial, atualizacao incremental e empacotamento local
- Em pasta com `PacotesGeradosParaImportacaoNaKbNoGenexus`, auditar separadamente a aderencia do fluxo de empacotamento local; `sync`/indice OK não autorizam concluir sozinho que "está tudo certo"
- Explicar que materializar um `XPZ` completo da IDE inclui quebrar o `full.xml` em XMLs individuais por objeto
- Explicar que o acervo materializado deve ser organizado em subpastas por tipo amigavel de objeto GeneXus
- Explicar que os XMLs materializados devem usar nomes amigaveis dos objetos, não GUID como nome principal
- Explicar que `guid`, `parentGuid`, `parentType` e `moduleGuid` são metadados de apoio para consistencia e rastreabilidade, não o eixo principal de organizacao
- Explicar que o índice em `KbIntelligence` só pode ser gerado depois que `ObjetosDaKbEmXml` existir e contiver o snapshot oficial materializado
- Explicar que `KbIntelligence` não substitui `ObjetosDaKbEmXml`; ele e uma camada derivada para triagem e deve ser regeneravel a partir do snapshot oficial
- Explicar que, se `last_index_build_run_at` estiver ausente ou anterior a `last_xpz_materialization_run_at`, o agente não deve pesquisar o acervo em massa nem gerar objetos para importação; deve tratar isso como exceção operacional e oferecer a regeneracao/validacao do índice antes de seguir
- Prever wrappers locais `.ps1` na pasta `scripts` quando a pasta paralela da KB precisar reconstruir o fluxo operacional local sobre o motor compartilhado; distinguir: scripts com parâmetros estáticos da KB (caminhos fixos, nome da KB, GUIDs) merecem wrapper local; scripts com parâmetros totalmente dinâmicos por execução (ex: `Watch-GeneXusMsBuildLog.ps1`, cujo `-Pid` e `-LogPath` variam a cada build) são chamados diretamente do motor pelo caminho absoluto, sem wrapper local
- Exigir wrapper local `Test-*KbPowerShellRuntime.ps1` como primeiro gate de qualquer uso operacional da pasta paralela; ele deve delegar ao motor compartilhado `scripts\Test-XpzPowerShellRuntime.ps1`, exigir `pwsh` com PowerShell 7.4 LTS ou superior e bloquear o prosseguimento quando retornar `BLOCK:` ou estiver ausente
- Quando a pasta paralela da KB também for usada para gerar XMLs locais e pacotes de importação, prever wrapper local consultivo para gate de sanidade do `Source` antes do empacotamento
- Quando a pasta paralela da KB for inicializada do zero para operar com fluxo oficial de materialização XPZ/XML, tratar a camada mínima de wrappers locais em `scripts` como parte do bootstrap técnico esperado, não como pendencia para a etapa seguinte
- Não declarar `setup inicial concluido`, `estrutura pronta` ou equivalente final se a pasta ainda não tiver a camada mínima de wrappers locais necessária para materialização oficial e, quando adotado, para `KbIntelligence`
- Se a pasta paralela já estiver versionada em Git, tratar `.gitignore` na raiz e `.gitkeep` nas subpastas estruturais vazias como parte esperada do setup inicial padrão
- Se a pasta paralela ainda não estiver versionada em Git, o agente pode oferecer inicializar versionamento Git local como passo opcional de apoio; a decisão pertence ao usuário
- Não executar `git init` por conta própria no setup inicial
- Ao criar `.gitignore` — independente de o repositório já estar versionado ou não — cobrir obrigatoriamente: `Temp`, `KbIntelligence` (apenas `kb-intelligence.sqlite` e `kb-intelligence-validation.json`), `ObjetosGeradosParaImportacaoNaKbNoGenexus`, `PacotesGeradosParaImportacaoNaKbNoGenexus` e `XpzExportadosPelaIDE`; `ObjetosDaKbEmXml` não deve ser ignorado pelo `.gitignore` pois e o acervo oficial versionavel
- Toda pasta coberta no `.gitignore` com o padrão `pasta/*` e `!pasta/.gitkeep` deve ter o arquivo `.gitkeep` correspondente criado no mesmo passo em que o `.gitignore` e gravado; não criar `.gitignore` que referencia `.gitkeep` sem criar o arquivo físico
- Se o usuário aceitar versionamento Git local e o ambiente não tiver Git funcional, o agente pode oferecer instalar ou orientar a instalacao antes de prosseguir com o bootstrap Git
- Alterar `.gitignore`, politica de versionamento ou escopo de arquivos rastreados para viabilizar `git add`/`commit` e decisão de politica do repositório; o agente pode diagnosticar e propor opções, mas não deve mudar essa politica automaticamente só para concluir o fechamento
- Reutilizar o fluxo oficial previsto nas skills e no motor compartilhado antes de considerar qualquer script novo
- Gerar `kb-source-metadata.md` inicial em formato compativel com o motor compartilhado, preservando desde o setup o campo nominal `last_xpz_materialization_run_at`
- Quando o caminho da KB nativa local estiver confirmado no setup inicial, resolver a identidade estavel por `scripts\Resolve-GeneXusKbIdentity.ps1` antes de declarar o metadata apto e gravar `kb-source-metadata.md` já com `Source/kb (GUID)`, `Source/username`, `Source/UNCPath`, `Source/Version/guid` e `Source/Version/name` preenchidos quando a resolucao passar. Se a resolucao falhar, não declarar estado limpo de metadata; registrar a pendencia e orientar a correcao em vez de depender de XPZ futuro com `Source` preenchido.
- Não salvar memoria operacional fora da própria pasta paralela da KB sem autorizacao explicita do usuário; `AGENTS.md`, `README.md` e arquivos operacionais locais são a camada preferencial de memoria do setup
- Ao concluir o setup inicial, declarar explicitamente que a pasta paralela está pronta, mas `ObjetosDaKbEmXml` ainda não foi materializada
- Quando o setup inicial tiver registrado memoria local provisoria de que `ObjetosDaKbEmXml` ainda não foi materializada, exigir refresh dessa memoria local depois da primeira materialização oficial bem-sucedida, para evitar handoff com estado desatualizado
- Em `modo_criacao`, antes de iniciar qualquer escrita, verificar se o prompt de entrada já declara explicitamente a preferencia por `A)` ou `B)`; se sim, prosseguir sem perguntar; se não, perguntar ao usuário qual caminho prefere antes de comecar qualquer trabalho — a pergunta deve ser feita no inicio da skill, não após o setup estar concluido; agente que cria toda a estrutura e só entao pergunta A/B obriga o usuário a aguardar o setup inteiro para responder algo que podia ser respondido antes de qualquer escrita
- Ao concluir o setup inicial, os dois próximos passos são:
  - `A)` o usuário exporta o `.xpz` full pela IDE do GeneXus para `XpzExportadosPelaIDE` e o agente materializa os XMLs depois
  - `B)` o agente tenta gerar o `.xpz` full a partir da pasta nativa da KB, grava esse `.xpz` em `XpzExportadosPelaIDE` e depois materializa os XMLs
- Ao apresentar `A)` e `B)`, dizer explicitamente que `A)` e o caminho preferencial e normalmente mais rápido, enquanto `B)` tende a demorar mais por depender da trilha via `MSBuild`
- Ao orientar o caminho `A)`, preferir descrição funcional estavel como `export full da KB pela IDE` em vez de depender de rotulos exatos de menu, tela ou botao do GeneXus como se fossem universais; se citar caminho de menu, apresentá-lo depois da instrucao principal e marcado explicitamente como exemplo opcional de navegacao, nunca como passo normativo principal
- Se o usuário escolher `B)`, encaminhar a geração do `.xpz` full pela skill `xpz-msbuild-import-export` em vez de improvisar exportação fora dessa trilha
- Ao concluir exportação via `B)`, verificar em `kb-source-metadata.md` se o campo `kb (GUID)` na seção `## Source` foi populado com um GUID real e coerente com a KB nativa local. Exportacoes full geradas via MSBuild ou IDE podem não conter `Source` completo; isso deve ser tratado como metadata incompleto a resolver pela identidade local aprovada, não como motivo automático para pedir reexport. Se o pacote trouxer GUID preenchido de outra KB, bloquear import headless e orientar importação manual pela IDE
- Ao concluir exportação via `B)`, quando o `export.json` emitido por `Invoke-GeneXusXpzExport.ps1` vier com `postProcessingFailed=true` mas o `msbuild.stdout.log` contiver `Export Sucesso` e `__EXPORTED_FILE__=<caminho>` e o arquivo XPZ existir no caminho indicado, NÃO classificar a rodada como `falha operacional` nem reiniciar a exportação; tratar como `XPZ gerado com diagnostico degradado`, declarar o marco `XPZ gerado` no handoff e prosseguir para a materialização; classificação formal e governanca do sub-estado `exportacao headless concluida e XPZ gerado (falha no pos-processamento do wrapper)` pertencem a `xpz-msbuild-import-export` — esta skill apenas roteia para la quando houver duvida
- No handoff após exportação via `B)` com XPZ gerado, reproduzir no texto ao usuário os totais reais de `packageInventory` (`totalObjects`, `totalAttributes`, `objectsByType`, `systemObjectsPresent`, `attributesTopLevelUnreconciled` e `inventoryWarnings` quando existirem), `exportErrors`/`invalidTypesRejected`/`knownStdOutNoise`/`exitCode`/`msBuildCategoryBBlocked` no top-level do `export.json` quando existirem, e o `operationalSubState`; com `exitCode=48` ou sub-estado `exportação parcial com errors do MSBuild — artefato não confiável`, **PARAR** — o XPZ não e entrega limpa; abrir `package-inventory.json` (via `nominalInventoryAt`, `packageInventoryPath` ou `artifacts.PackageInventoryPath`) sempre que `extrasCount > 0`, `attributesTopLevelUnreconciled=true`, ou `systemObjectsPresent` não vazio, e reproduzir a lista nominal completa por bloco — atributos top-level **por nome** somente quando `attributesTopLevelUnreconciled=true`; nunca resumir a rodada com a contagem de entradas de `-ObjectList` — governanca completa em `xpz-msbuild-import-export` (seção inventario após export seletivo)
- Em diagnostico degradado de export/import MSBuild, quando existir `executionEvidence.msBuildExitCode`, trata-lo como fonte canonica do exit bruto do MSBuild; `msBuildExitCode` top-level e compatibilidade transitoria e não deve substituir a leitura canonica nem a classificação da skill `xpz-msbuild-import-export`
- Quando o usuário precisar inspecionar uma propriedade da KB, Version, Environment, Generator, DataStore ou objeto específico sem abrir a IDE, o script `Get-GeneXusKbProperty.ps1` do motor compartilhado está disponível via `xpz-msbuild-import-export`; seu uso e pontual e sob demanda — não faz parte de nenhuma etapa obrigatória do setup

---

## MAPEAMENTO INTENCAO -> FUNÇÃO DA PASTA

- Se a intencao for consultar o acervo materializado da KB:
  - usar a pasta com função de acervo materializado
  - essa pasta recebe XMLs individuais extraidos do `XPZ` exportado pela IDE
  - essa pasta pode usar subpastas por tipo amigavel de objeto GeneXus
- Se a intencao for consultar relacoes, impacto técnico ou trilha funcional curta por índice derivado:
  - usar a pasta `KbIntelligence` como destino do SQLite derivado e dos relatórios de validação
  - usar wrappers locais em `scripts` para consultar ou regenerar o índice
  - manter `ObjetosDaKbEmXml` como fonte normativa e origem de regeneracao do índice
- Se a intencao for gerar XML novo ou copia alterada para futura importação na IDE:
  - usar a pasta com função de geração para importação
  - essa pasta recebe apenas XMLs novos ou copias alteradas geradas pelo agente
  - cada frente ativa deve usar sua própria subpasta `NomeCurto_GUID_YYYYMMDD`
- Se a intencao for guardar `XPZ` exportado pela IDE:
  - usar a pasta com função de entrada de `XPZ`
  - essa pasta não e acervo materializado nem area de geração de XML
- Se a intencao for guardar pacote final de importação:
  - usar a pasta com função de saida de pacotes
  - essa pasta recebe `import_file.xml` e, quando aplicavel, `XPZ`

---

## REGRAS DE NAMING

- Para acervo materializado, preferir subpastas por tipo amigavel de objeto GeneXus, por exemplo `Transaction`, `Procedure`, `WebPanel`
- Para containers GeneXus, adotar a convencao canonica derivada da FabricaBrasil: `Folder/` para objetos com `Object/@type="00000000-0000-0000-0000-000000000008"` (containers criados pelo usuário — "Pastas") e `Module/` para objetos com `Object/@type="00000000-0000-0000-0000-000000000006"` (containers de sistema: Main Programs, ToBeDefined)
- O nome do subdiretorio em `ObjetosDaKbEmXml` NÃO e indicador confiavel do tipo GeneXus entre KBs; a fonte autoritativa e sempre `Object/@type` no XML do objeto
- Para acervo materializado, preferir nome amigavel do objeto como nome do XML, por exemplo `Cliente.xml`, `GeraBoleto.xml`
- Não usar GUID como nome principal de pasta ou arquivo do acervo materializado
- Se houver colisao rara de nome, o GUID pode aparecer apenas como apoio de desambiguacao, nunca como eixo principal da organizacao
- GUID, `parentGuid`, `parentType` e `moduleGuid` servem como metadados de apoio, não como estrutura principal de saida
- Para frente ativa em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, usar a subpasta `NomeCurto_GUID_YYYYMMDD`
- Para pacote final em `PacotesGeradosParaImportacaoNaKbNoGenexus`, usar o formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` representa apenas a rodada curta do pacote naquela frente; não representa versão semantica
- no pacote final, o vinculo com a frente existe apenas pelo prefixo `NomeCurto_GUID_YYYYMMDD` somado ao `nn`

---

## WRAPPERS LOCAIS ESPERADOS

### Matriz de exigencia por wrapper

Referencia rápida para decidir o peso operacional da ausencia de cada wrapper. As regras detalhadas de classificação (AUSENTE / EQUIVALENTE / CUSTOMIZADO) e os critérios de evidencia permanecem em 8.a e 8.g3; esta tabela e leitura rápida, não substituto.

| Wrapper | Obrigatório quando | Ausencia impede |
|---|---|---|
| `Test-*KbPowerShellRuntime.ps1` | sempre (primeiro gate de uso operacional) | qualquer uso operacional da pasta paralela |
| `Test-*KbObjetosDaKbNaming.ps1` | `ObjetosDaKbEmXml` materializado | `wrappers_atualizados` e `materializado_e_indice_validado` limpos |
| `Test-*KbSetupFreshness.ps1` | sempre (invocacao pelo gatilho global) | fast path da PRE-CONDICAO — ausente forca auditoria completa a cada invocacao do gatilho |
| `Set-*KbSetupAuditTimestamp.ps1` | recomendado quando `last_setup_audit_run_at` ou `setup_contract_signature_*` estiver ausente, invalido ou defasado após auditoria bem-sucedida | nenhum estado, enquanto o motor compartilhado puder ser chamado diretamente ou a edicao manual seguir o passo 34 |
| `Update-*KbFromXpz.ps1` | sempre (fluxo oficial de materialização) | `pronto_para_primeira_materializacao` |
| `Test-*KbFullSnapshot.ps1` | sempre (fluxo oficial de materialização) | `pronto_para_primeira_materializacao` |
| `Query-*KbIntelligence.ps1` | `KbIntelligence` adotado | `wrappers_atualizados` |
| `Rebuild-*KbIntelligenceIndex.ps1` | `KbIntelligence` adotado | `wrappers_atualizados` |
| `Test-*KbIndexGate.ps1` | `KbIntelligence` adotado | `wrappers_atualizados` |
| `Get-*KbMetadata.ps1` | `KbIntelligence` adotado | `wrappers_atualizados` |
| `Resolve-*KbIdentity.ps1` | esperado no setup inicial/auditoria quando a pasta tem KB nativa local confirmada e precisa preencher ou conferir identidade estavel; recomendado nas demais reconciliacoes aprovadas em que o XPZ veio com `Source` vazio ou incompleto | metadata apto para empacotamento quando a identidade estavel estiver ausente, incompleta ou divergente |
| `Test-*KbMetadataWrapper.ps1` | `KbIntelligence` adotado | `wrappers_atualizados` |
| `Test-*KbStructure.ps1` | `KbIntelligence` adotado | `wrappers_atualizados` |
| `Test-*KbSetupAudit.ps1` | `KbIntelligence` adotado | `wrappers_atualizados` |
| `Test-*KbSourceSanity.ps1` | empacotamento local adotado | `auditoria_de_empacotamento_pendente` |
| `Test-*KbPackageCollision.ps1` | empacotamento local adotado | `auditoria_de_empacotamento_pendente` |
| `New-*KbFront.ps1` | recomendado quando agentes abrem frentes locais com frequência e precisam evitar comandos PowerShell compostos | nenhum estado, enquanto o motor compartilhado puder ser chamado diretamente ou os passos atomicos forem executados separadamente |
| `Get-*KbLastUpdate.ps1` | recomendado quando agentes atualizam `lastUpdate` em XMLs locais com frequência e precisam evitar comandos PowerShell compostos | nenhum estado, enquanto o motor compartilhado puder ser chamado diretamente ou o timestamp puder ser obtido por comando atômico |
| `New-*KbImportPackage.ps1` | recomendado quando o empacotamento local for recorrente e a KB precisar de comando curto/allowlist | nenhum estado, enquanto o motor compartilhado puder ser chamado diretamente |
| `Notify-TaskComplete.ps1` | opcional | nenhum estado |

- Além do gate obrigatório `Test-*KbPowerShellRuntime.ps1`, a pasta `scripts` deve prever pelo menos dois wrappers locais quando a pasta paralela da KB operar com fluxo oficial de materialização XML sobre o motor compartilhado:
  - wrapper de atualizacao diaria a partir de `.xpz`, XML exportado ou pasta contendo o XML do pacote
  - wrapper de conferencia full que reutiliza o wrapper diario em modo `VerifyOnly + FullSnapshot`
- Quando a pasta paralela precisar reconciliar identidade estavel da KB nativa local porque o XPZ exportado veio com `Source` vazio ou incompleto, recomendar wrapper local fino `Resolve-*KbIdentity.ps1`:
  - delega para `scripts\Resolve-GeneXusKbIdentity.ps1` da base compartilhada
  - opera em modo somente leitura sobre `model.ini`, `knowledgebase.connection` e banco interno da KB
  - retorna `kbGuid`, `kbName`, `versionGuid`, `versionName`, `UNCPath` e `username` para apoiar preenchimento aprovado de `kb-source-metadata.md`
  - quando chamado com opção local equivalente a `-UpdateMetadata`, delega para `scripts\Update-XpzKbSourceMetadataIdentity.ps1`, preenche campos ausentes de identidade estavel e bloqueia divergencias não vazias salvo aprovacao explicita para sobrescrita
  - não substitui o `Get-*KbMetadata.ps1`: resolve identidade a partir da KB nativa; `Get-*KbMetadata.ps1` le o metadata já gravado
- Quando a pasta paralela da KB adotar `KbIntelligence`, a pasta `scripts` também deve prever wrappers locais finos para:
  - consulta do índice derivado em `KbIntelligence\kb-intelligence.sqlite`
  - regeneracao e validação do índice a partir de `ObjetosDaKbEmXml`
  - execução do gate de frescor (`Test-*KbIndexGate.ps1`): chama o wrapper de consulta local com `-Query index-metadata`, le `kb-source-metadata.md`, compara timestamps e retorna `GATE_OK` ou lanca `BLOCK: <motivo>`; depende de `Query-*KbIntelligence.ps1` na mesma pasta; deve ser o único ponto de execução do gate de frescor
  - leitura de campos chave de `kb-source-metadata.md` (`Get-*KbMetadata.ps1`): elimina o padrão recorrente de `Select-String + regex` inline nos chamadores; expoe ao menos `last_xpz_materialization_run_at`, `kb_name` e `source_guid`
    - contrato semantico canonico dos tres campos:
      - `last_xpz_materialization_run_at`: campo de topo ou frontmatter de `kb-source-metadata.md`
      - `kb_name`: campo `name` da tabela na seção `## Source/Version` (nome da KB na IDE)
      - `source_guid`: campo `kb (GUID)` da tabela na seção `## Source` — GUID da KB, não o GUID da versão em `## Source/Version`; implementacoes que lerem `source_guid` de `## Source/Version` serao semanticamente incorretas mesmo com parse valido
  - validação do contrato funcional de metadata (`Test-*KbMetadataWrapper.ps1`): chama o motor compartilhado `Test-XpzKbMetadataWrapper.ps1`, compara o que `Get-*KbMetadata.ps1` expoe contra `kb-source-metadata.md` e retorna `METADATA_WRAPPER_OK`, `METADATA_WRAPPER_INCOMPLETE`, `PENDENTE_DE_DADOS` ou `BLOCK: ...`
  - validação de plausibilidade semantica de environment/deploy/output (`Test-XpzKbDeploymentMetadata.ps1`, consolidada em `Test-*KbSetupAudit.ps1` como `metadata/deploy`): rejeita metadata legado (tipico de scan por pastas `web\`), inconsistencias de contagem e mapeamento de output/web ausente ou divergente; **não** substitui pergunta ao usuário nem validação MSBuild de nomes declarados
  - auditoria de naming de `ObjetosDaKbEmXml` (`Test-*KbObjetosDaKbNaming.ps1`): chama o motor compartilhado `Test-XpzObjetosDaKbNaming.ps1`, cobre todos os diretórios imediatos do snapshot, extrai o tipo real por raiz `Attribute` ou `Object/@type`, compara com o **catalogo efetivo** (`gx-object-type-catalog.json` + `scripts/gx-object-type-catalog.override.json` quando existir) e retorna `NAMING_OK`, `NAMING_DIVERGENT` ou `NAMING_INDETERMINADO`; não renomeia diretórios
  - verificacao de estrutura da pasta paralela (`Test-*KbStructure.ps1`): relatório de presenca/ausencia de pastas, scripts e artefatos esperados; retorna `STRUCTURE_OK` ou lista componentes ausentes; usado no setup e em diagnostico antes de qualquer operacao
  - gate de runtime PowerShell (`Test-*KbPowerShellRuntime.ps1`): chama o motor compartilhado `Test-XpzPowerShellRuntime.ps1`, verifica existência de `pwsh` com PowerShell 7.4 LTS ou superior e bloqueia qualquer uso operacional da pasta paralela se retornar `BLOCK:`; deve ser o primeiro wrapper executado em setup, auditoria, frescor, sync, índice ou empacotamento
  - auditoria agregada de setup (`Test-*KbSetupAudit.ps1`): chama o motor compartilhado `Test-XpzSetupAudit.ps1`, consolida evidencias deterministicas de `powershell/runtime`, `sync/materializacao`, `naming/objetos-da-kb`, `indice/gate`, `indice/semantica`, `metadata wrapper`, `metadata/deploy`, `empacotamento local`, `declarativo/timestamps`, `wrappers/inventario` e `estado_operacional_sugerido`; deve orquestrar os gates específicos, nunca substitui-los como evidencia primaria; quando `-PowerShellRuntimeTestPath` não for informado ao motor compartilhado, ele varre `scripts/Test-*KbPowerShellRuntime.ps1`, usa o wrapper único detectado e, se nenhum existir, emite `powershell/runtime.detecao=missing`, `powershell/runtime.wrapper_sugerido` e `powershell/runtime.molde` sem criar arquivo automaticamente; quando existir e a intencao operacional for `auditar_setup`, o agente deve executa-lo e usar sua saida consolidada como veiculo de handoff — as dimensoes do wrapper substituem a sintese manual dessas mesmas dimensoes, mas não substituem a evidencia dos gates específicos que as fundamentam
- Quando a pasta paralela da KB operar com `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus`, recomendar também wrapper local fino para gate de `Source`, por exemplo `Test-*KbSourceSanity.ps1`:
  - recebe um XML específico em `-InputPath`; `-Path`, quando aceito, e alias de compatibilidade
  - delega para `scripts\Test-GeneXusSourceSanity.ps1` da base compartilhada
  - não repassa `-AsJson` ao motor compartilhado: `Test-GeneXusSourceSanity.ps1` já emite JSON por padrão e NÃO aceita `-AsJson` (trava confirmada por `Test-XpzParameterNamingContract.ps1`); o motor também espera um arquivo, não uma pasta — se o wrapper local precisar varrer varios XML ou montar JSON próprio, faz isso no wrapper sem propagar a flag para baixo
  - retorna JSON por padrão no stdout, suficiente para distinguir `xmlWellFormed`, `sourceSanityStatus` e `probablyImportable`
  - bloqueia empacotamento local quando encontrar `sourceSanityStatus=fail`
  - em `warn`, devolve a lista de warnings e exige revisao conservadora antes do pacote
- Quando a pasta paralela da KB operar com empacotamento local em `PacotesGeradosParaImportacaoNaKbNoGenexus`, recomendar também wrapper local fino para gate de colisao de pacote, por exemplo `Test-*KbPackageCollision.ps1`:
  - recebe `FrontPrefix`, `NN` e `OutputDir`, ou `PackagePath`; `-Path`/`-InputPath`, quando aceitos, são alias de compatibilidade para `PackagePath`
  - delega para `scripts\Test-XpzPackageCollision.ps1` da base compartilhada
  - retorna JSON com `status=ok`, `reason=COLLISION_OK` e exit 0 quando a rodada pretendida ainda não existe
  - retorna JSON com `status=bloqueado`, `reason=PACKAGE_ROUND_COLLISION`, `blockingReasons`, `nextFreeNN`, `nextFreeRound` e exit 20 quando a rodada `nn` já existir para o mesmo prefixo de frente
  - deve ser o único ponto local para decidir se o pacote pode ser gravado ou se a frente deve bloquear por colisao
- Quando agentes abrirem frentes locais com frequência em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, recomendar wrapper local fino para abertura de frente, por exemplo `New-*KbFront.ps1`:
  - recebe `NomeCurto`, opcionalmente `ExtraGuidCount`, `ReuseIfExists` e `AsJson`
  - delega para `scripts\New-GeneXusXpzFront.ps1` da base compartilhada
  - cria ou reutiliza a subpasta `NomeCurto_GUID_YYYYMMDD` em chamada atômica
  - devolve `frontGuid`, `yyyymmdd`, `frontDir`, `createdAtUtc`, GUIDs adicionais e motivo de bloqueio quando aplicavel
  - não decide sozinho se o trabalho e `same front` ou `new front`; essa decisão continua pertencendo ao fluxo da `xpz-builder`
  - este wrapper (ou o motor `New-GeneXusXpzFront.ps1`) é o passo que **cria ou retoma** a pasta da frente; popular (`Copy-*KbAcervoToFront.ps1` / `Copy-GeneXusAcervoToFront.ps1`) e os gates que recebem `-FrontFolder` (9-FD `Test-GeneXusFrontAcervoDrift.ps1` e os demais) operam sobre uma frente **já existente** e não criam a pasta — abrir a frente aqui, com `-ReuseIfExists` para retomar, antes de popular ou empacotar; criar a pasta manualmente é anti-padrão (o motor emite o erro `FRENTE_NAO_ABERTA` quando a frente não existe)
- Quando agentes atualizarem `lastUpdate` em XMLs locais com frequência, recomendar wrapper local fino para timestamp, por exemplo `Get-*KbLastUpdate.ps1`:
  - recebe opcionalmente `Count`, `AsJson`, baseline oficial e margem de frescor
  - delega para `scripts\Get-GeneXusXpzLastUpdate.ps1` da base compartilhada
  - retorna timestamp UTC no formato `yyyy-MM-ddTHH:mm:ss.0000000Z`
  - quando receber baseline oficial, calcula `max(UtcNow + margem, lastUpdate do baseline + margem)`, com margem padrão de 60 segundos
  - não substitui a classificação `modified in this round` vs `reused unchanged for mandatory dependency closure`; apenas fornece o instante canonico para objetos realmente alterados
- Quando o empacotamento local com `import_file.xml` for recorrente, recomendar wrapper local fino para criacao do pacote, por exemplo `New-*KbImportPackage.ps1`:
  - recebe `FrontName`, `NN` e opcionalmente `TemplatePackagePath` e `AcervoPath` (override do acervo; quando omitido, o motor resolve o acervo canonico `<RepoRoot>/ObjetosDaKbEmXml` da pasta paralela); a saida de maquina e JSON por padrão no stdout, sem `-AsJson`
  - delega para `scripts\New-XpzImportPackage.ps1` da base compartilhada
  - o wrapper compartilhado chama o motor Python `scripts\New-XpzImportPackage.py`, le `kb-source-metadata.md`, resolve as pastas padrão da pasta paralela, classifica raizes `Object`/`Attribute`, executa sempre o gate de drift frente-vs-acervo 9-FD (`Test-GeneXusFrontAcervoDrift.ps1`) em modo fail-closed antes do empacotamento, executa o gate de colisao e monta o pacote; no gate 9-FD, `-AcervoPath` e opcional e, quando omitido, o acervo canonico `<RepoRoot>/ObjetosDaKbEmXml` e resolvido automaticamente — sem acervo resolvivel o empacotamento e bloqueado, e o JSON reporta `acervoResolvedBy` (`explicit` ou `convention`); bloqueios esperados voltam como JSON estruturado com `status`, `exitCode`, `stage` e `blockingReasons`, nunca como stack/ANSI para consumo de maquina
  - quando `TemplatePackagePath` for informado, o motor aceita `import_file.xml` ou `.xpz` real comparavel, clona `KMW`, `Source`, `Dependencies`, `ObjectsIdentityMapping` e, quando não houver `Attribute` explicito na frente, preserva também `Attributes` de topo do template; para `Panel`, um par `level id`/`layout id` localizado nesse template comparavel pode ser registrado como confirmado; quando omitido, usa envelope mínimo derivado de `kb-source-metadata.md` e retorna warning para pacote misto/complexo, com ressalva específica de par não verificado para `Panel`
  - este wrapper reduz comando local e facilita allowlist, mas sua ausencia isolada não bloqueia `wrappers_atualizados` enquanto a KB puder chamar o motor compartilhado diretamente com `-RepoRoot`
- Quando agentes precisarem diagnosticar código C# gerado após import/build, recomendar wrapper local fino para resolver caminho de `.cs`, por exemplo `Resolve-*KbGeneratedCsPath.ps1`:
  - recebe `KbPath`, `ObjectName`, opcionalmente `ObjectType`, `EnvironmentName` e `AsJson`
  - delega para `scripts\Resolve-GeneXusGeneratedCsPath.ps1` da base compartilhada
  - le `kb-source-metadata.md` e usa `kb_environment_web_dirs` para montar `<webDir>\<objectName-lowercase>.cs` sem varredura recursiva da KB nativa
  - se `kb_environment_web_dirs` estiver ausente ou sem o environment solicitado, retorna `BLOCK` e orienta executar `xpz-kb-parallel-setup` para reconciliar o metadata; não aceitar chute de diretório nem scan de `C:\GxModels`
  - e somente leitura: não grava, não abre a KB e não invoca MSBuild
- Quando o fluxo iterativo de import+build produzir o sub-estado `importação real efetiva provada, geração de runtime pendente` ou o usuário reportar que o comportamento ainda não mudou após import e build, a checagem de frescor de runtime pode ser executada diretamente pelo script da base compartilhada `scripts\Test-GeneXusRuntimeFreshness.ps1` — não requer wrapper local:
  - `-KbPath` (obrigatório): caminho da KB GeneXus nativa (onde reside `nav_objs.xml`)
  - `-ObjectName` (obrigatório): nome do objeto GeneXus a verificar
  - `-ImportedAt` (obrigatório): timestamp do import como linha de corte (string ISO parseable)
  - `-ObjectType` (opcional): tipo GeneXus do objeto; reservado para uso futuro
  - `-GeneratorOutputPath` (opcional): pasta de output do gerador; antes de informar este parâmetro para diagnostico de `.cs` em KB multi-environment, resolver o caminho com `scripts\Resolve-GeneXusGeneratedCsPath.ps1`/`Resolve-*KbGeneratedCsPath.ps1` a partir de `kb_environment_web_dirs`; se omitido, o script legado deriva `<KbPath>\CSharpModel\web`, o que e apenas complementar e não substitui metadata de output por environment
  - `-AsJson` (opcional): emite saída JSON estruturada em vez de texto humano
  - Status de saída possíveis: `runtime-fresh` (nogenreq + artefatos posteriores ao import), `runtime-stale` (genreq ou artefatos anteriores ao import), `runtime-unknown` (objeto não encontrado em `nav_objs.xml` ou artefatos não localizados)
  - Somente leitura: não grava nada, não abre a KB, não invoca MSBuild
- A ausencia isolada de `Test-*KbSourceSanity.ps1` não impede, por si só, classificar a pasta como tendo camada mínima de wrappers para materialização oficial ou para `KbIntelligence`; ele passa a ser esperado quando a KB adota fluxo local de geração e empacotamento que dependa desse gate.
- A ausencia isolada de `Test-*KbPackageCollision.ps1` também não impede, por si só, classificar a pasta como tendo camada mínima de wrappers para materialização oficial ou para `KbIntelligence`; ele passa a ser esperado quando a KB adota fluxo local de empacotamento com `import_file.xml` local.
- A ausencia isolada de `New-*KbFront.ps1` ou `Get-*KbLastUpdate.ps1` não impede, por si só, classificar a pasta como atualizada; eles são recomendados para reduzir comandos compostos e facilitar allowlist quando a pasta tiver uso recorrente de abertura de frente ou regravacao de `lastUpdate`.
- A ausencia isolada de `New-*KbImportPackage.ps1` não impede, por si só, classificar a pasta como atualizada; ele e recomendado para empacotamento recorrente e allowlist, mas o motor compartilhado pode ser chamado diretamente quando o agente informar `-RepoRoot`.
- Em `auditar_setup`, a ausencia de wrapper recomendado deve ficar visivel quando houver sinal objetivo de uso recorrente: subpastas em `ObjetosGeradosParaImportacaoNaKbNoGenexus/` recomendam `New-*KbFront.ps1`; XMLs gerados com `lastUpdate` recomendam `Get-*KbLastUpdate.ps1`; pacotes `*.import_file.xml` em `PacotesGeradosParaImportacaoNaKbNoGenexus/` recomendam `New-*KbImportPackage.ps1`; metadata de identidade já registrado recomenda `Resolve-*KbIdentity.ps1` para reconciliacoes futuras. Esse sinal não bloqueia estado limpo por si só, mas obriga o handoff a oferecer criacao aprovada dos wrappers finos.
- Scripts legados que sobrevivem lado a lado com o nome canonico atual em `scripts/` são pendencia metodologica, não recomendacao opcional. Exemplos conhecidos: `Test-*FullSnapshot.ps1` quando `Test-*KbFullSnapshot.ps1` já existe; `Update-*FromXpz.ps1` quando `Update-*KbFromXpz.ps1` já existe; `Test-*KbGate.ps1` quando `Test-*KbIndexGate.ps1` já existe. O motor de auditoria deve reportar esses casos como `INVENTORY_LEGACY_ORPHANS`.
- Um helper local de notificacao pode existir como apoio operacional, mas não substitui os wrappers principais
- O wrapper local deve ser fino:
  - resolver caminhos da pasta paralela da KB
  - apontar para o motor compartilhado
  - repassar parâmetros
  - opcionalmente produzir resumo Git, relatório e metadados da KB
- O wrapper local de materialização deve passar caminho de `kb-source-metadata.md` para que `last_xpz_materialization_run_at` seja gravado mesmo quando não houver mudanca material nos XMLs
- O wrapper local de materialização deve chamar o wrapper local de regeneracao/validacao do índice depois de sync bem-sucedido que não seja `VerifyOnly`
- O wrapper local de regeneracao do índice deve preservar os metadados produzidos pelo motor compartilhado, incluindo `last_index_build_run_at`
- Quando o motor compartilhado ganhar parâmetros operacionais relevantes, isso
  não significa automaticamente que os wrappers locais já os exponham
- Se o wrapper local estiver defasado em relacao ao motor compartilhado, tratar
  isso como oportunidade de atualizacao local, mencionar ao usuário e aguardar
  aprovacao explicita; não corrigir automaticamente
- O wrapper local não deve reimplementar o motor compartilhado se o fluxo oficial já existir
- Para reconstruir wrappers locais, usar como referencia os exemplos sanitizados desta skill antes de improvisar um fluxo novo:
  - [Update-KbFromXpz.example.ps1](examples/Update-KbFromXpz.example.ps1)
  - [Test-KbFullSnapshot.example.ps1](examples/Test-KbFullSnapshot.example.ps1)
  - [Query-KbIntelligence.example.ps1](examples/Query-KbIntelligence.example.ps1)
  - [Rebuild-KbIntelligenceIndex.example.ps1](examples/Rebuild-KbIntelligenceIndex.example.ps1)
  - [Test-KbSourceSanity.example.ps1](examples/Test-KbSourceSanity.example.ps1)
  - [Test-KbPackageCollision.example.ps1](examples/Test-KbPackageCollision.example.ps1)
  - [New-KbFront.example.ps1](examples/New-KbFront.example.ps1)
  - [Get-KbLastUpdate.example.ps1](examples/Get-KbLastUpdate.example.ps1)
  - [New-KbImportPackage.example.ps1](examples/New-KbImportPackage.example.ps1)
  - [Copy-KbAcervoToFront.example.ps1](examples/Copy-KbAcervoToFront.example.ps1)
  - [Notify-TaskComplete.example.ps1](examples/Notify-TaskComplete.example.ps1)
  - [Test-KbPowerShellRuntime.example.ps1](examples/Test-KbPowerShellRuntime.example.ps1)
  - [Test-KbObjetosDaKbNaming.example.ps1](examples/Test-KbObjetosDaKbNaming.example.ps1)
  - [gx-object-type-catalog.override.json.example](examples/gx-object-type-catalog.override.json.example)
  - [Test-KbIndexGate.example.ps1](examples/Test-KbIndexGate.example.ps1)
  - [Get-KbMetadata.example.ps1](examples/Get-KbMetadata.example.ps1)
  - [Resolve-KbIdentity.example.ps1](examples/Resolve-KbIdentity.example.ps1)
  - [Test-KbMetadataWrapper.example.ps1](examples/Test-KbMetadataWrapper.example.ps1)
  - [Test-KbSetupAudit.example.ps1](examples/Test-KbSetupAudit.example.ps1)
  - [Test-KbStructure.example.ps1](examples/Test-KbStructure.example.ps1)
  - [Test-KbSetupFreshness.example.ps1](examples/Test-KbSetupFreshness.example.ps1)
  - [Set-KbSetupAuditTimestamp.example.ps1](examples/Set-KbSetupAuditTimestamp.example.ps1)
  - [Set-KbSourceMetadataDeployment.example.ps1](examples/Set-KbSourceMetadataDeployment.example.ps1)
  - [Register-KbPostBuildEvents.example.ps1](examples/Register-KbPostBuildEvents.example.ps1)
  - [Resolve-KbGeneratedCsPath.example.ps1](examples/Resolve-KbGeneratedCsPath.example.ps1)
- Esses `.example.ps1` são exemplos metodologicos importantes para bootstrap técnico e reconstrucao assistida dos wrappers locais finais.
- Quando os wrappers locais precisarem nascer do zero no setup inicial, preferir adaptar os exemplos sanitizados completos desta skill como base do bootstrap técnico, em vez de improvisar wrappers curtos ou parciais que ainda exijam correcao na etapa seguinte.
- Esses `.example.ps1` não substituem o wrapper local real da pasta paralela da KB e não devem virar fallback automático de execução no fluxo normal.
- Wrapper local derivado de `.example.ps1` só conta como wrapper de bootstrap valido depois que o agente validar parse do `.ps1` e ausencia de placeholders sanitizados em valores executaveis, configuração efetiva, caminhos padrão, parâmetros default ou chamadas reais.
- Exemplos em comentario ou blocos de ajuda, como `.EXAMPLE`, não bloqueiam o bootstrap apenas por conterem caminhos ilustrativos; se forem mantidos, não podem ser citados como evidencia de configuração local validada.
- Os exemplos sanitizados de wrappers incorporam uma trilha real de pasta paralela da KB com:
  - metadados da KB gravados em `kb-source-metadata.md`
  - `last_xpz_materialization_run_at` atualizado a cada processamento XPZ/XML solicitado
  - refresh compulsorio do índice derivado após materialização XPZ/XML bem-sucedida
  - resumo Git limitado ao acervo oficial quando houver mudanca material
  - limpeza localizada de residuos de objeto renomeado por `guid`, preservando o XML com nome atual e `lastUpdate` mais confiavel
  - repasse opcional de `ExpectedItems` para distinguir foco esperado e retorno oficial adicional
  - índice derivado em `KbIntelligence\kb-intelligence.sqlite`
  - `last_index_build_run_at` gravado na tabela `metadata` do SQLite e espelhado no relatório de validação
  - consulta e regeneracao do índice por wrappers locais, sem reimplementar o motor compartilhado

---

## GATE DE COMPATIBILIDADE OPERACIONAL

Antes de trabalho substantivo em uma pasta paralela da KB que declare uso de `KbIntelligence`, validar quatro camadas na ordem exata executada pelo `Test-*KbIndexGate.ps1`:

1. Estrutura (primeira camada, executada via `Test-*KbStructure.ps1`): pastas funcionais esperadas, `README.md`, `AGENTS.md`, `kb-source-metadata.md`, `ObjetosDaKbEmXml`, `KbIntelligence` e scripts minimos com os nomes corretos. Se `Test-KbStructure` retornar qualquer coisa diferente de `STRUCTURE_OK`, o gate bloqueia imediatamente — não avancar para camadas internas.
2. Wrappers: scripts locais funcionais em `scripts`, incluindo consulta do índice com suporte a `index-metadata`, regeneracao/validacao do índice com `-FailOnValidationFailure` e materialização XPZ/XML com refresh compulsorio do índice.
3. Semantica de inventario: `index-metadata` deve expor `inventory_validation_status=OK`, confirmando que o inventario do SQLite permanece coerente com o snapshot oficial e com o catalogo técnico compartilhado de tipos.
4. Frescor: `last_index_build_run_at` obtido pelo wrapper local de consulta deve ser igual ou posterior a `last_xpz_materialization_run_at`, lido nominalmente em `kb-source-metadata.md`.

Executar o gate em ordem sequencial e parar no primeiro bloqueio. Não investigar camadas internas enquanto a camada externa estiver invalida; no máximo, mencionar que outras verificacoes podem ser necessárias depois da primeira correcao.

Detectar defasagem de wrappers antes de executar a tarefa de negocio:

- Wrapper de consulta: deve aceitar `index-metadata` pelo próprio wrapper local; se a chamada falhar por parâmetro desconhecido, `ValidateSet` antigo ou ausencia de saida com `last_index_build_run_at`, bloquear.
- Wrapper de consulta: `index-metadata` também deve expor `inventory_validation_status`; se o campo estiver ausente ou diferente de `OK`, bloquear.
- Wrapper de regeneracao: deve existir, aceitar validação com `-FailOnValidationFailure` e gravar `last_index_build_run_at` no índice gerado.
- Wrapper de materialização XPZ/XML: se a pasta adota `KbIntelligence`, deve chamar o wrapper de regeneracao/validacao do índice após sync bem-sucedido que não seja `VerifyOnly`; se não houver evidencia clara desse encadeamento, bloquear próximo sync normal e oferecer atualizacao.
- A existência de `.example.ps1` na base metodologica não reduz esse bloqueio: enquanto o wrapper local real estiver ausente, o fluxo normal deve permanecer bloqueado.
- Evidencia clara de encadeamento significa declaracao local explicita em `README.md`/`AGENTS.md` ou chamada observavel no próprio wrapper local; não presumir compatibilidade só porque a base compartilhada já exige esse comportamento.
- Metadado de materialização: `kb-source-metadata.md` deve expor o campo nominal `last_xpz_materialization_run_at`; se o campo não existir, bloquear. Não aceitar como substituto data do arquivo, `updated`, `generated_at`, `source_xpz`, data de relatório ou qualquer outro metadado aproximado.

Quando o gate falhar por wrapper de materialização defasado, a correcao de compatibilidade deve atualizar o wrapper local antes de qualquer novo sync normal. Não usar o wrapper antigo para "consertar" `kb-source-metadata.md` e depois regenerar o índice manualmente como caminho normal; isso mascara a incompatibilidade que o gate deve tornar visivel.

Se qualquer camada falhar, tratar a pasta paralela como defasada ou incompatível com a versão operacional atual das skills:

- bloquear pesquisa ampla, triagem substantiva e geração de objetos para importação;
- permitir apenas diagnostico mínimo para explicar o que falta;
- não compensar com leitura manual de `kb-intelligence-validation.json`, SQLite direto, `kb-source-metadata.md` isolado, XML oficial de objeto ou varredura em `ObjetosDaKbEmXml`;
- não executar sync normal por wrapper antigo como etapa de reparo de compatibilidade quando o próprio wrapper de sync estiver defasado;
- não executar fluxo normal por `.example.ps1` da base metodologica como substituto do wrapper local real ausente;
- não orientar `sync` seguido de rebuild manual separado do índice como fluxo normal quando a pasta adota `KbIntelligence`;
- oferecer ao usuário a atualizacao da estrutura/wrappers/indice usando esta skill.

O objetivo do bloqueio e tornar visivel que uma pasta paralela ainda precisa receber atualizacao operacional, especialmente em ambientes comunitarios com pastas em diferentes estagios de adocao.

---

## CAPACIDADE DE IMPORTAÇÃO HEADLESS

Verificacao consultiva anterior a execução real de importação via MSBuild. Esta seção não substitui `xpz-msbuild-import-export`: a interpretacao de parâmetros, sub-estados de import e diagnostico JSON pertence a essa skill. Aqui o que se verifica e apenas presenca de motores compartilhados e coerência documental do contrato esperado, antes que a pasta paralela chegue a fase de import real com a trilha defasada.

Acionar esta verificacao quando houver sinais de uso ou intencao de uso do fluxo de importação via MSBuild na pasta paralela:
- `PacotesGeradosParaImportacaoNaKbNoGenexus/` populado, ou
- `ObjetosGeradosParaImportacaoNaKbNoGenexus/` com frente ativa em curso, ou
- wrapper local de import (ex: `Invoke-*KbXpzImport.ps1`) presente em `scripts/`, ou
- tarefa corrente mencionando `importar`, `preview`, `MSBuild import`, `import_file.xml` ou `pacote gerado`.

Verificacoes a executar quando acionada:

1. Presenca em `RepoRoot\scripts\` dos motores compartilhados de import/export:
   - `Test-GeneXusImportFileEnvelope.ps1` (gate de envelope)
   - `Test-GeneXusXpzImportPreview.ps1` (preview headless)
   - `Invoke-GeneXusXpzImport.ps1` (import real headless)
   - `GeneXusMsBuildWatcherSupport.ps1` (helper carregado obrigatoriamente por preview/import para o contrato de watcher e `timing`)
2. Acessibilidade da skill `xpz-msbuild-import-export` na sessao atual, pelo caminho publicado pela própria sessao quando houver — sem inferir caminho por heuristica.
3. Coerência documental do `SKILL.md` de `xpz-msbuild-import-export`: o documento deve continuar declarando, em texto, ambas as regras abaixo, que são o contrato que a verificacao da pasta paralela precisa pressupor:
   - `-InputPath` (aliases retrocompatíveis `-XpzPath` e `-Path`) aceita `.xpz`, `.xml` e `.import_file.xml` com raiz `<ExportFile>` validada por `Test-GeneXusImportFileEnvelope.ps1` na mesma rodada
   - `-ImportKbInformation` e tri-state: omitido ou `false` significam não emitir o atributo na task `Import`; apenas `true` emite o atributo e exige que a task carregada exponha a propriedade

A verificacao 3 e leitura documental, não auditoria de comportamento do script — auditar comportamento de `Invoke-GeneXusXpzImport.ps1` continua proibido para esta skill (ver 8.g6.iii).

Regra de comportamento conforme dependencia da tarefa corrente:

- Tarefa corrente **depende** de importação real (preview/import via MSBuild solicitado, gravacao de pacote para importação imediata, etc.) **e** alguma verificacao acima falhou: classificar a dimensao `importacao_msbuild` como `IMPORTACAO_HEADLESS_PENDENTE`, **bloquear** a importação real, declarar nominalmente no handoff o que está ausente ou defasado (script faltando, regra documental não localizada na skill de import/export) e encaminhar para `xpz-msbuild-import-export` antes de qualquer tentativa.
- Tarefa corrente **não depende** de importação real: registrar a pendencia como observação consultiva no handoff e prosseguir, desde que os demais gates obrigatórios estejam OK; não usar essa pendencia consultiva como bloqueio adicional fora do escopo.

Esta verificacao e declarativa e barata: presenca de arquivo e leitura curta do `SKILL.md` de `xpz-msbuild-import-export`. Não deve substituir, sobrepor nem antecipar nenhum sub-estado dessa skill.

---

## ESTADOS DE CONCLUSAO DO SETUP

Ao fechar um setup ou handoff de pasta paralela da KB, usar um estado operacional explicito, sem promover o status por inferencia:

- `estrutura_criada`: pastas e documentos basicos existem, mas wrappers locais, materialização ou índice ainda não foram validados.
- `bootstrap_incompleto`: a estrutura existe, mas falta camada mínima de wrappers locais para o fluxo oficial adotado, ou falta compatibilidade obrigatória com `KbIntelligence`.
- `pronto_para_primeira_materializacao`: estrutura, documentos e wrappers locais minimos foram criados ou validados, sem placeholders sanitizados pendentes em configuração efetiva dos wrappers, mas `ObjetosDaKbEmXml` ainda não recebeu materialização oficial.
- `materializado_e_indice_validado`: houve materialização oficial bem-sucedida e, quando `KbIntelligence` for adotado, o índice derivado foi regenerado/validado com `last_index_build_run_at >= last_xpz_materialization_run_at` e `inventory_validation_status=OK`; a memoria declarativa local está limpa (`declarativo/timestamps=OK` na saida de `Test-*KbSetupAudit.ps1`).
- `wrappers_atualizados`: pasta já em producao recebeu scripts ausentes previstos pela base metodologica; scripts com personalizacao foram preservados ou substituidos com aprovacao explicita do usuário; `ObjetosDaKbEmXml`, `kb-source-metadata.md` e `kb-intelligence.sqlite` intactos; a memoria declarativa local está limpa (`declarativo/timestamps=OK`). Nenhum wrapper obrigatório para o cenário adotado pode permanecer no estado AUSENTE sem decisão explicita do usuário para declarar este estado — wrapper AUSENTE sem decisão equivale a `bootstrap_incompleto`, não a `wrappers_atualizados`.
- `atualizacao_metodologica_pendente`: pasta em producao com fluxo operacional funcional, mas um ou mais scripts previstos pela versão atual da base metodologica ainda não foram incorporados, ou a memoria declarativa local (`AGENTS.md`/`README.md`) carrega timestamps literais de materializacao/indice em vez de ponteiros para a fonte autoritativa (`declarativo/timestamps=DRIFT_TIMESTAMPS_LITERAIS`). Os scripts existentes funcionam normalmente. Corrija incorporando os scripts ausentes via `atualizar_bootstrap_local` e/ou substituindo timestamps literais por ponteiros (conforme `examples/AGENTS.md.example`) para atingir `wrappers_atualizados`. Distinto de `bootstrap_incompleto`: aqui a pasta já opera — falta apenas atualizar o conjunto canonico ou a memoria declarativa.
- `auditoria_de_empacotamento_pendente`: `sync`, índice e estrutura podem estar OK, mas a pasta adota ou pode adotar empacotamento local e a aderencia dos wrappers/gates desse fluxo ainda não foi confirmada objetivamente.

Não usar `setup concluido`, `estrutura pronta` ou expressao equivalente sem dizer qual desses marcos já foi efetivamente cumprido. Criar pastas vazias ou gravar memoria local inicial não basta para declarar a pasta pronta para `sync` normal, pesquisa ampla ou geração de objetos.
No handoff final, usar literalmente um dos estados canonicos listados acima. Não inventar rotulos hibridos, reforcos livres ou variantes como `wrappers_atualizados completo`, `quase wrappers_atualizados`, `indice ok com pendencia`, `estrutura pronta com ressalva` ou equivalente.

---

## COMMUNICATION

- Responder na lingua do usuário
- Liderar com a diferenca entre pasta da KB e pasta paralela da KB
- Quando houver risco de ambiguidade, usar sempre a expressao completa `pasta paralela da KB`
- Se a estrutura não existir, dizer explicitamente o que falta
- Em setup inicial padrão bem delimitado, preferir fechamento curto e objetivo em vez de narrar exploracao desnecessaria
- Se o gate de compatibilidade falhar, explicar a falha como defasagem operacional da pasta paralela e oferecer atualizacao antes de responder a pergunta de negocio
- Quando `AUDIT_REQUIRED` tiver origem em metadata persistente ausente, defasado ou inconsistente e a auditoria completa seguida do gate passar, diferenciar no handoff: `GATE_OK` libera a tarefa atual, mas a pasta ainda tem pendencia de metadata que deve ser corrigida na mesma sessao (via `Set-*KbSetupAuditTimestamp.ps1` ou passo 34) para restaurar o caminho rápido das próximas sessoes; adiar para outra sessao só quando o usuário recusar ou adiar explicitamente
- Não tratar a estrutura da pasta nativa da KB como se fosse a mesma coisa que o repositório paralelo
- Ao fechar um setup inicial bem-sucedido, diferenciar explicitamente `estrutura pronta` de `snapshot oficial ainda nao materializado`
- No fechamento do setup inicial, apresentar `A)` e `B)` como opções de próximo passo e informar o tradeoff de tempo entre elas
- Se a existência da pasta nativa da KB foi verificada, declarar no fechamento se ela existe/acessou corretamente ou se ficou como ressalva operacional
- Ao fechar um `modo_atualizacao`, a resposta deve conter obrigatoriamente: classificação de cada script (EQUIVALENTE / AUSENTE / CUSTOMIZADO), resultado da verificacao de naming de cada diretório presente em `ObjetosDaKbEmXml` expresso como tabela ou lista estruturada com ao menos tres colunas — `Diretorio`, `Tipo real encontrado`, `Status` (conforme ou divergente) — mesmo que nenhuma divergencia seja encontrada; quando houver divergencia, incluir também a coluna `Nome canonico esperado`; estado operacional declarado e resultado do gate quando executado
- Ao fechar um `modo_atualizacao`, declarar separadamente no handoff: `sync/materializacao`, `indice/gate`, `indice/semantica`, `declarativo/timestamps`, `empacotamento local` e `importacao_msbuild`; quando existir `Test-*KbSetupAudit.ps1`, preferir as linhas consolidadas desse wrapper para essas dimensoes em vez de sintese manual; não colapsar tudo em "tudo certo" sem mostrar a situacao de cada dimensao adotada; `importacao_msbuild` segue as regras de 8.g6 e quando estiver `NAO_ADOTADO` deve aparecer no handoff com esse rotulo explicito — não omitir a dimensao para simplificar a saida
- Ao fechar um `modo_atualizacao`, usar literalmente o rotulo `indice/gate` para a dimensao do gate estrutural e de frescor; não substituir por variantes como `indice/frescor`, `frescor`, `indice` isolado ou equivalentes
- No handoff final, capturar o timestamp real imediatamente antes de responder e usá-lo na própria resposta; não usar placeholder, horario inventado, valor reaproveitado de mensagem anterior nem timestamp inferido do contexto
- Se a pasta tiver `PacotesGeradosParaImportacaoNaKbNoGenexus`, a resposta final de `modo_atualizacao` deve dizer explicitamente se o fluxo de empacotamento local foi classificado como `OK`, `NAO_ADOTADO` ou `PENDENTE`
- Se a pasta tiver `PacotesGeradosParaImportacaoNaKbNoGenexus`, o handoff final não pode resumir os wrappers como "scripts presentes", "parse OK" ou formula equivalente sem destacar a classificação explicita de `Test-*KbSourceSanity.ps1` e `Test-*KbPackageCollision.ps1`
- No handoff final, o `estado operacional` deve ser exatamente um dos estados canonicos desta skill; não anexar qualificadores livres ao nome do estado nem usar frase que pareca novo estado
- Quando existir `Test-*KbMetadataWrapper.ps1`, o handoff final não pode citar `kb_name`, `source_guid` ou classificar `Get-*KbMetadata.ps1` sem referenciar a evidencia produzida por esse gate; inspecao textual isolada não basta
- Se `Test-*KbObjetosDaKbNaming.ps1` ou `Test-*KbSetupAudit.ps1` reportar `NAMING_DIVERGENT` ou `naming/objetos-da-kb: DIVERGENT`, incluir na resposta ao usuário — independente da pergunta original — o aviso explicito de quais diretórios estao com nome divergente e a oferta de correcao via `xpz-kb-parallel-setup`; não suprimir esse aviso mesmo quando a pergunta de negocio já foi respondida
- Se `AGENTS.md` local ou `README.md` local gravarem timestamps literais de materialização ou índice, tratar isso como drift documental mesmo que o valor ainda pareca coerente com `kb-source-metadata.md`, `-Query index-metadata` ou com o gate efetivo; não declarar a pasta "tudo certo" sem antes apontar a divergencia e oferecer substituicao por ponteiros para as fontes autoritativas
- Em `auditar_setup`, quando `Test-*KbSetupAudit.ps1` existir, o handoff deve citar nominalmente os blocos consolidados produzidos por esse wrapper (`powershell/runtime`, `sync/materializacao`, `naming/objetos-da-kb`, `indice/gate`, `indice/semantica`, `metadata wrapper`, `metadata/deploy`, `empacotamento local`, `declarativo/timestamps`, `wrappers/inventario`, `estado_operacional_sugerido`) em vez de sintetizar essas dimensoes manualmente; a sintese manual só e aceitavel quando o wrapper estiver ausente
- Após toda auditoria mínima desta skill (`auditar_setup`, BLOCO DE ATUALIZACAO ou PRE-CONDICAO com auditoria completa), o handoff deve incluir o **plano consolidado de correcoes** quando existir ao menos um item corrigivel; se não houver nenhum, declarar explicitamente "plano de correcoes: nenhum item corrigivel nesta pasta nesta rodada"
- O plano consolidado deve ser lista estruturada (tabela ou bullets numerados) com colunas ou campos minimos: `Item`, `Evidencia`, `Acao proposta`, `Aprovacao necessaria` (sim/nao), `Intencao` (`atualizar_bootstrap_local` / `corrigir_wrapper_local` / passo 34 / fora de escopo)
- O campo `estado_operacional_sugerido` reportado pelo wrapper deve ser confrontado com o estado canonico declarado pela skill; se o wrapper sugerir um estado diferente do estado canonico que a evidencia objetiva da auditoria sustenta, o agente deve declarar o estado canonico correto e explicitar a divergencia — não silenciar nem adotar o sugerido pelo wrapper sem verificacao
- No fechamento do setup inicial, informar que `nexa` não e verificada por esta skill (pertence a outro repositório) e recomendar `xpz-skills-setup` para auditoria do ecossistema completo

---

## WORKFLOW

0. **Catálogo XPZ (cada sessão na pasta paralela):** executar `Test-XpzCatalogOverrideSessionReminder.ps1 -ParallelKbRoot <raiz> -AsJson`. Se `reminderRequired=true`, exibir a mensagem ao usuário antes de sync ou materialização — override local e paliativo; falta alinhar GeneXus-XPZ-Skills.
1. Confirmar se o usuário está falando da pasta nativa da KB ou da pasta paralela da KB
2. Se o caminho da pasta nativa da KB não vier informado, pedir esse caminho ao usuário antes de concluir o setup inicial
3. Se o caminho da pasta nativa da KB vier informado, verificar existencia/acesso quando isso for seguro e barato; se não existir ou não estiver acessivel, não gravar nem tentar corrigir a pasta nativa, apenas registrar a ressalva no handoff
4. Se o usuário não informar nomes alternativos, assumir as subpastas padrão
5. Se o usuário informar nomes alternativos, registrar o mapeamento entre nome real e função da pasta em `AGENTS.md` da pasta paralela da KB e, quando ajudar humanos, também em `README.md`
6. Registrar em `AGENTS.md` da pasta paralela o caminho confirmado da pasta nativa da KB e a regra de que essa pasta e somente leitura para agentes, com gravacao proibida
7. Quando houver `README.md` local na pasta paralela, registrar ali também a identificacao da pasta nativa da KB e a regra de somente leitura em linguagem clara
7a. Se a pasta paralela adota `KbIntelligence`, incluir obrigatoriamente no `AGENTS.md` local a seção `## Triagem Por Indice` com:
    - Roteamento: perguntas de existencia/localizacao/impacto tecnico/relacoes/investigacao funcional curta → `xpz-index-triage`
    - Gate: `Test-*KbIndexGate.ps1` como única porta de entrada; gate bloqueado impede pesquisa ampla, triagem substantiva e varredura de XMLs
    - Regra explicita: não compensar gate bloqueado com leitura manual de SQLite, JSON de validação, `kb-source-metadata.md` ou XML oficial
    - Fonte normativa: `ObjetosDaKbEmXml` para confirmacao somente após gate liberado
  Esta seção e pre-requisito para declarar o setup como concluido; sem ela, agentes podem rotear perguntas de triagem para `nexa` (regra genérica "tarefa GeneXus → nexa") em vez de `xpz-index-triage`, furando o gate. Em `modo_criacao`, criar a seção junto com o restante do `AGENTS.md`. Em `modo_atualizacao`, verificar e adicionar se ausente (ver passo 8.g).
7b. Verificar se o gatilho estrutural global está presente nas configuracoes das ferramentas de agente instaladas:
    - Identificar a ferramenta em uso na sessao atual e verificar seu arquivo de configuração global primeiro; em seguida, verificar os arquivos das demais ferramentas instaladas
    - Arquivos de configuração a verificar (somente se existirem):
      - Claude Code: `Join-Path $env:USERPROFILE '.claude\CLAUDE.md'`
      - Codex: `Join-Path $env:USERPROFILE '.codex\AGENTS.md'`
      - Cursor: verificar MCP global `xpz-global-instructions` em `Join-Path $env:USERPROFILE '.cursor\mcp.json'` e `agentsPath` em `Join-Path $env:USERPROFILE '.cursor\xpz-global-instructions-mcp\config.json'` (fonte efetiva conforme ferramentas instaladas — ver `xpz-skills-setup`, seção `## CURSOR — INSTRUCIONAIS GLOBAIS VIA MCP`); seguir referencia do arquivo fonte quando aplicavel
      - OpenCode: `Join-Path $env:USERPROFILE '.config\opencode\AGENTS.md'`; se existir `Join-Path $env:USERPROFILE '.config\opencode\opencode.json'` ou `.jsonc`, ler campo `instructions[]` e verificar cada arquivo listado
    - Para cada arquivo encontrado, aplicar verificacao em dois níveis:
      - Nível 1: o próprio arquivo contem `## Pasta paralela de KB GeneXus`? Se sim → coberto, nenhuma ação
      - Nível 2: o arquivo referencia outro arquivo de instrucoes (ex: linha `@~/.codex/AGENTS.md` em arquivo Markdown, campo `instructions` no `opencode.json` ou `agentsPath` no `config.json` do MCP do Cursor)? Se sim → seguir a referencia e verificar o arquivo apontado; se esse contiver a seção → coberto, nenhuma ação
    - Propor adicao apenas quando nem o arquivo direto nem os arquivos referenciados contiverem a seção
    - A adicao deve ir no arquivo centralizado já referenciado quando houver um; caso contrario, no próprio arquivo de configuração da ferramenta
    - Apresentar ao usuário qual arquivo sera alterado e o bloco exato a adicionar; aguardar aprovacao explicita antes de gravar:
      ```
      ## Pasta paralela de KB GeneXus

      Ao identificar que a pasta de trabalho ou qualquer pasta referenciada na conversa contem `ObjetosDaKbEmXml/` ou `KbIntelligence/`, invocar `xpz-kb-parallel-setup` uma vez na sessao antes de qualquer triagem, consulta ou geracao de objetos — mesmo que o AGENTS.md local nao instrua isso explicitamente.
      ```
    - Esta verificacao e não bloqueante: recusa ou pulo pelo usuário não impede a conclusao do setup
7c. Quando a frente detectar risco operacional recorrente de edicao textual fora do padrão esperado do repositório, como `line ending` misto em arquivo de texto coberto por `.gitattributes`, o agente pode propor reforco opcional no arquivo global de instrucoes da ferramenta:
    - Tratar isso como recomendacao geral de higiene editorial, não como gate de setup da KB
    - Verificar primeiro se o arquivo global centralizado da ferramenta já contem instrucao equivalente sobre preservar `eol` e validar `line ending`
    - Só propor adicao quando essa orientacao ainda estiver ausente no arquivo direto ou no arquivo centralizado por ele referenciado
    - A proposta deve mostrar ao usuário qual arquivo global sera alterado, explicar que a regra vale para outras frentes além de GeneXus e aguardar aprovacao explicita antes de gravar
    - Bloco sugerido:
      ```
      ## Line Endings Em Arquivos De Texto

      - Em arquivos de texto cobertos por `.gitattributes`, preservar o `eol` esperado pelo repositorio ao gravar.
      - Se houver aviso de `line ending`, suspeita de arquivo `mixed` ou politica `eol` explicita no repositorio, validar antes de concluir que o arquivo salvo ficou no formato esperado.
      ```
    - Esta verificacao também e não bloqueante: recusa ou pulo pelo usuário não impede a conclusao do setup
8. Detectar o contexto operacional da pasta paralela antes de qualquer escrita:
   - `modo_criacao`: pasta inexistente, vazia, sem `ObjetosDaKbEmXml` materializado e sem `kb-source-metadata.md` com timestamps reais → criar primeiro a estrutura base e só aprofundar exploracao se surgir bloqueio concreto; prosseguir para o passo 9
   - `modo_atualizacao`: pasta com histórico real — qualquer combinacao de `ObjetosDaKbEmXml` materializado, `kb-source-metadata.md` com timestamps reais ou `kb-intelligence.sqlite` com dados → executar o BLOCO DE ATUALIZACAO a seguir antes de prosseguir para o passo 9
   - Se o usuário usou qualquer linguagem que sugira setup e a pasta tem sinais de histórico real: assumir `modo_atualizacao`, informar brevemente ao usuário que a pasta tem histórico e que o agente vai incorporar apenas o que esta faltando preservando tudo que já existe, e pedir confirmacao antes de gravar
   - Se o usuário pedir explicitamente para apagar tudo, recriar do zero ou equivalente e a pasta tem histórico real: recusar, explicar que dados existentes não serao destruidos e oferecer `modo_atualizacao` como único caminho disponível

8.z Classificar a intencao operacional dentro do contexto detectado antes de escolher a profundidade da execução:
   - `auditar_setup`: usar quando o pedido central for conferir, revisar, validar, diagnosticar ou responder se "está tudo certo"; o fluxo deve priorizar evidencia, classificação, **plano consolidado de correcoes** e handoff com registro da decisão do usuário sobre esse plano
   - `corrigir_wrapper_local`: usar quando a própria evidencia do gate ou do bloco de atualizacao apontar um wrapper específico como defasado, ou quando o usuário pedir para corrigir wrapper/script local; o fluxo deve priorizar editar o wrapper, rerodar o gate afetado e só depois consolidar o estado final
   - `atualizar_bootstrap_local`: usar quando a pasta com histórico real estiver sem wrappers previstos, sem seções documentais obrigatórias ou sem parte do bootstrap metodologico; o fluxo deve priorizar incorporar esses faltantes
   - Em pedido genérico de auditoria, comecar por `auditar_setup`; se a auditoria encontrar um caso deterministico de wrapper defasado que esta skill manda corrigir, trocar explicitamente para `corrigir_wrapper_local` e comunicar ao usuário antes da escrita usando a formula: "a auditoria encontrou um caso deterministico de correcao; vou mudar explicitamente para `corrigir_wrapper_local` antes da escrita"
   - Conta como caso deterministico de correcao para fins dessa transicao:
     - `Get-*KbMetadata.ps1` defasado contra o formato real de `kb-source-metadata.md` já coberto pelo example atual, com `Test-*KbMetadataWrapper.ps1` bloqueando por esse motivo específico — fluxo obrigatório definido em 8.a.iii
     - qualquer outro wrapper bloqueado por `Test-*KbMetadataWrapper.ps1` ou `Test-*KbIndexGate.ps1` por razão funcional conhecida e inequivoca, com example atual que já cobre o formato real do dado local; critério: a correcao e local, observavel no próprio wrapper e não depende de decisão editorial do usuário sobre o que preservar
   - Não conta como caso deterministico — a transicao não deve ocorrer quando:
     - a auditoria mínima ainda não foi concluida: gate ainda não rodou, wrappers de 8.a ainda não foram todos classificados ou naming de `ObjetosDaKbEmXml` (8.g2) ainda não foi encerrado
     - o wrapper e CUSTOMIZADO com diferenca de lógica ou parâmetros que exijam decisão explicita do usuário sobre o que preservar
     - o bloqueio do gate não tem causa inequivoca ou depende de dado externo a pasta paralela para ser diagnosticado
   - Não usar a mesma regra de interacao para todas as intencoes: `auditar_setup` fecha com diagnostico **e plano consolidado de correcoes oferecido** (execução na mesma sessao após aprovacao quando houver itens corrigiveis); `corrigir_wrapper_local` fecha com gate rerodado; `atualizar_bootstrap_local` fecha com lista do que foi incorporado
   - Quando `auditar_setup` encontrar itens corrigiveis, o agente deve oferecer executar o plano consolidado na mesma sessao; transitar para `corrigir_wrapper_local` ou `atualizar_bootstrap_local` conforme o item, comunicando a transicao ao usuário, sem exigir novo pedido genérico de "corrigir setup"
   - Em `atualizar_bootstrap_local`, ao gravar cada wrapper novo criado a partir de exemplo canonico, atualizar também a seção `## Wrappers locais` do `AGENTS.md` local para incluir a entrada do novo wrapper; não encerrar o fluxo sem esse sincronismo
--- BLOCO DE ATUALIZACAO (executar somente em modo_atualizacao) ---

Pre-condicao obrigatória: confirmar que o passo 7b foi executado nesta sessao antes de iniciar 8.a; se o gatilho global não foi verificado ainda, executar 7b agora antes de prosseguir com qualquer passo do bloco.

8.a Inspecionar `scripts/` e categorizar cada script previsto pela base metodologica em uma de tres classes. Quando a pasta adota `KbIntelligence`, os scripts obrigatórios canonicos a classificar são, no mínimo: `Test-*KbPowerShellRuntime.ps1`, `Update-*KbFromXpz.ps1`, `Test-*KbFullSnapshot.ps1`, `Test-*KbObjetosDaKbNaming.ps1`, `Query-*KbIntelligence.ps1`, `Rebuild-*KbIntelligenceIndex.ps1`, `Test-*KbIndexGate.ps1`, `Get-*KbMetadata.ps1`, `Test-*KbMetadataWrapper.ps1`, `Test-*KbStructure.ps1` e `Test-*KbSetupAudit.ps1`. Esta lista e normativa para a classificação em 8.a.ii independentemente do que a versão local de `Test-*KbStructure.ps1` verificar — o escopo do checklist do gate local pode estar defasado em relacao ao padrão atual, mas a obrigacao de classificar todos esses scripts não depende do gate.

8.a.i A validação de parse dos scripts esperados e executada automaticamente por `Test-*KbStructure.ps1`: o script roda `[System.Management.Automation.Language.Parser]::ParseFile()` sobre cada wrapper e adiciona entradas `PARSE_ERROR` ao relatório se houver erros. Se o gate retornou `GATE_OK` (que depende de `STRUCTURE_OK`), todos os scripts passaram o parser sem erros — nenhuma execução manual adicional e necessária para erros. Se o gate bloqueou com mensagem de parse, corrigir o script apontado antes de continuar. ATENÇÃO: `GATE_OK` e `STRUCTURE_OK` provam ausencia de erros de parse, mas NÃO cobrem warnings de parse — `[System.Management.Automation.Language.Parser]::ParseFile()` retorna warnings em parâmetro separado que o gate não inspeciona; warnings de parse (ex: interpolacao ambigua como `"$field: $value"` em vez de `"${field}: $value"`) indicam divergencia funcional real e classificam o script como CUSTOMIZADO em 8.a.ii mesmo quando o gate passou; GATE_OK prova exclusivamente que cada script passou o parser sem erros — isso e tudo que o gate prova em relacao a 8.a; a classificação EQUIVALENTE / AUSENTE / CUSTOMIZADO de cada script e determinada individualmente em 8.a.ii e GATE_OK não substitui, antecipa nem influencia essa classificação; em especial, scripts listados em `INVENTORY_SHORT_NAMING` não podem ser declarados EQUIVALENTE com base em GATE_OK mesmo que o gate tenha passado sem erros.

8.a.ii Classificar cada script que passou em 8.a.i em uma de tres classes:
    - AUSENTE: script previsto que ainda não existe localmente
    - EQUIVALENTE: script que passou em 8.a.i e cuja lógica e equivalente ao exemplo correspondente, incluindo a diretiva `#requires -Version` quando o exemplo canonico declarar essa diretiva; diferencas apenas de capitalizacao em `#requires -Version` (ex: `-version` vs `-Version`) não constituem divergencia, mas diferenca de versão (ex: `5.1` vs `7.4`) constitui divergencia metodologica; diferencas apenas de nome KB no sentido de prefixo KB presente no nome local mas ausente no exemplo (ex: `Test-FabricaBrasilKbIndexGate.ps1` no lugar de `Test-KbIndexGate.example.ps1`) são toleradas e não constituem divergencia; essa tolerancia NÃO se aplica ao sentido inverso — script cujo nome NÃO contem o prefixo KB quando deveria conter (ex: `Test-KbIndexGate.ps1` em vez de `Test-wsEducacaoSpTesteKbIndexGate.ps1`) não pode ser classificado como EQUIVALENTE mesmo que o conteúdo seja identico ao exemplo; esse caso e detectado pelo `INVENTORY_SHORT_NAMING` e classifica o script como CUSTOMIZADO com ação obrigatória de renome; para ser EQUIVALENTE, nenhum parâmetro pode ter default hardcoded apontando para arquivo que não existe no disco e o caminho de engine inferido no corpo do script — tipicamente `Join-Path $SharedSkillsRoot 'scripts\<nome>.ps1'` — deve apontar para arquivo que existe no motor compartilhado; engine path apontando para arquivo inexistente classifica o script como CUSTOMIZADO; adicionalmente, para o papel específico de `Test-*KbStructure.ps1`, o script deve emitir `STRUCTURE_OK` via `Write-Output`, não via `Write-Host` — a diferenca e funcional porque o gate filtra `$_ -is [string]` no output redirecionado via `*>&1` e `Write-Host` emite `InformationRecord` (não `string`), quebrando o gate silenciosamente; para qualquer script, a ausencia de warnings de parse e critério adicional de EQUIVALENTE — warnings retornados pelo segundo parâmetro de `[System.Management.Automation.Language.Parser]::ParseFile()` não são capturados pelo gate e devem ser verificados manualmente quando houver suspeita; script com warning de parse confirmado e CUSTOMIZADO, não EQUIVALENTE. Exceção: `Test-*KbPowerShellRuntime.ps1` pode divergir de `#requires -Version 7.4` ou omitir essa diretiva quando o exemplo canonico assim o fizer, para conseguir emitir `BLOCK:` em host antigo.
    - CUSTOMIZADO: script que existe com diferencas de lógica, parâmetros adicionais, fluxo alterado, divergencia de `#requires -Version` contra o exemplo canonico ou qualquer mudanca além da substituicao de nome KB; também e CUSTOMIZADO qualquer script com parâmetro cujo default hardcoded aponta para arquivo inexistente, mesmo que a lógica seja identica ao exemplo — o default quebrado e divergencia de configuração efetiva, não mera diferenca de nome; IMPORTANTE: para classificar como CUSTOMIZADO e obrigatório ler o exemplo canonico correspondente e identificar a divergencia concreta — observar que o script local tem implementação completa (em vez de ser thin wrapper) não e evidencia suficiente, pois o próprio exemplo canonico pode ser uma implementação completa; sem leitura do exemplo e identificacao de divergencia específica, o script deve ser classificado como EQUIVALENTE

8.a.iii Para o papel específico de `Get-*KbMetadata.ps1`, a equivalencia exige contrato funcional mínimo verificavel:
    - Quando houver wrapper local `Test-*KbMetadataWrapper.ps1`, executar esse gate obrigatoriamente antes de classificar `Get-*KbMetadata.ps1` ou mencionar `kb_name`/`source_guid` no handoff; usar a saida como evidencia deterministica primaria
    - O gate deve retornar `METADATA_WRAPPER_OK` quando `Get-*KbMetadata.ps1` expoe `last_xpz_materialization_run_at`, `kb_name` e `source_guid` existentes em `kb-source-metadata.md`
    - Antes de retornar OK, o gate também deve verificar completude dos campos criticos do metadata local: `kbGuid` presente e GUID valido, `kbName` presente, `versionGuid` presente e GUID valido, `versionName` presente; ausencia ou GUID invalido retorna `METADATA_WRAPPER_INCOMPLETE`, não `METADATA_WRAPPER_OK`
    - Se o gate retornar `BLOCK: ...`, classificar `Get-*KbMetadata.ps1` como `CUSTOMIZADO` e evidenciar a falha funcional apontada pelo gate
    - O example canonico atual `Get-KbMetadata.example.ps1` já cobre o formato real documentado de `kb-source-metadata.md`, incluindo `name` em `## Source/Version` e `kb (GUID)` em `## Source`; não presumir que o exemplo dependa apenas de linhas `kb_name:` ou `source_guid:` no topo
    - Se o gate bloquear apenas porque `kb_name` ou `source_guid` existem no metadata local em tabela Markdown documentada e saem como `(ausente)` no wrapper local, tratar isso como wrapper local defasado em relacao ao example atual; a correcao preferida e alinhar `Get-*KbMetadata.ps1` ao example atual, sem tocar `kb-source-metadata.md`
    - Gatilho típico deste caso deterministico: gravacao recente de campos de deploy (`deployment_environment_name`, `deployment_hosting_kind`, `kb_environment_count/names/output_dirs/web_dirs`) via `Set-*KbSourceMetadataDeployment.ps1`. Assim que esses campos passam a existir no metadata, o gate exige que `Get-*KbMetadata.ps1` tambem os exponha e bloqueia com `BLOCK: <campo> existente no metadata nao foi exposto pelo wrapper`; o example canonico atual já expoe esses campos, entao a correcao e alinhar o wrapper local ao example, sem tocar `kb-source-metadata.md`
    - Wrappers locais de leitura de `kb-source-metadata.md` devem seguir o padrão robusto a EOL do example atual (`ReadAllLines` + `split('|')` + `.Trim()`); evitar regex multiline terminada em `\|$`, fragil quando o arquivo tiver CRLF — mesmo após motores compartilhados preservarem EOL, wrappers legados ou edicao manual podem deixar o arquivo misto
    - Nesse caso específico de wrapper local defasado contra formato real já coberto pelo example atual, não abrir pergunta ao usuário entre "adaptar", "manter", "pular" ou equivalentes; a decisão e deterministica dentro desta skill
    - Fluxo obrigatório desse caso deterministico: `1)` alinhar `Get-*KbMetadata.ps1` ao example atual, preservando apenas customizacoes locais realmente necessárias; `2)` rerodar `Test-*KbMetadataWrapper.ps1`; `3)` só seguir para handoff ou classificação final depois que o gate deixar de bloquear por esse motivo específico
    - Enquanto esse rerun obrigatório não ocorrer, não encerrar diagnostico, não pedir decisão ao usuário sobre o destino do wrapper e não consolidar estado operacional final como se a auditoria de metadata estivesse concluida
    - Se o gate retornar `PENDENTE_DE_DADOS` para um campo realmente ausente no metadata local, registrar o campo como `PENDENTE_DE_DADOS`; nesse caso a ausencia do valor não torna o wrapper `CUSTOMIZADO` por si só
    - `PENDENTE_DE_DADOS` e `METADATA_WRAPPER_INCOMPLETE` validam o contrato funcional de saida contra dados disponíveis, mas não provam equivalencia metodologica de `Get-*KbMetadata.ps1` contra `Get-KbMetadata.example.ps1`; a equivalencia continua dependendo de 8.a.ii, incluindo `#requires -Version`
    - O inverso também vale: divergencia metodologica no wrapper local, como `#requires -Version` defasado, não deve ser confundida com ausencia de dados em `kb-source-metadata.md`
    - Se `Test-*KbMetadataWrapper.ps1` estiver ausente em pasta que adota `KbIntelligence`, tratar isso como wrapper previsto `AUSENTE` em `modo_atualizacao` e oferecer criacao a partir de `Test-KbMetadataWrapper.example.ps1`
    - Não concluir `Get-*KbMetadata.ps1 = EQUIVALENTE` e, no mesmo handoff, registrar que `kb_name` ou `source_guid` existem no metadata mas saem como `(ausente)`; isso e contradicao de auditoria

8.b Para cada script AUSENTE: preparar criacao a partir do exemplo correspondente; apresentar ao usuário o script que sera criado e aguardar aprovacao explicita antes de gravar. Após gravar, se o repositório tiver `.gitattributes` com politica explicita de EOL para `*.ps1` (ex: `*.ps1 text eol=crlf`), verificar se o arquivo salvo está no formato esperado antes de declara-lo criado e valido; inconsistencia de EOL nesse caso não e detalhe cosmetico — o arquivo deve ser normalizado antes do handoff

8.c Para cada script CUSTOMIZADO: evidenciar objetivamente a divergencia (quais seções diferem, quais parâmetros foram adicionados, qual lógica foi alterada) e apresentar ao usuário quatro opções claras; aguardar decisão explicita antes de qualquer escrita:
    - A) Manter versão local intacta — script customizado fica como está; nenhuma escrita
    - B) Substituir pelo exemplo atual — personalizacao local e descartada; script volta ao estado canonico
    - C) Revisar e incorporar seletivamente — usuário decide o que do exemplo incorporar; agente aplica apenas o que o usuário confirmar explicitamente
    - D) Pular este script por agora — nenhuma escrita; continuar com os demais scripts da lista
    Exceção 1: esta regra de quatro opções não se aplica ao caso deterministico definido em 8.a.iii para `Get-*KbMetadata.ps1` defasado contra formato real de `kb-source-metadata.md` já coberto pelo example atual; nesse caso o fluxo preferido e alinhar o wrapper local ao example atual.
    Exceção 2: esta regra de quatro opções não se aplica a scripts CUSTOMIZADO exclusivamente por SHORT_NAMING (nome sem prefixo KB quando o canonico exige prefixo); para esse subconjunto, "manter o nome curto" não e uma opção valida — o rename e correcao de conformidade, não preferencia editorial. O agente deve: listar todos os scripts SHORT_NAMING de uma vez, descrever o rename de cada um (nome atual → nome canonico), e pedir uma confirmacao em lote antes de executar qualquer rename; não abrir A/B/C/D por script.
    Quando dois ou mais scripts consecutivos receberem a mesma decisão, o agente pode perguntar ao usuário se deseja aplicar essa mesma decisão a todos os scripts CUSTOMIZADO ainda não revisados, evitando rounds repetitivos; aguardar resposta antes de prosseguir

8.d Não tocar campos de `kb-source-metadata.md` fora da autoridade da operacao corrente. Em `modo_atualizacao`, esta skill só pode gravar `last_setup_audit_run_at` e `setup_contract_signature_*` nos casos permitidos por esta skill (preferir `Set-*KbSetupAuditTimestamp.ps1`), ou atualizar campos de identidade estavel da KB quando a frente aprovada for explicitamente a reconciliacao de metadata a partir da KB nativa local; `last_xpz_materialization_run_at`, `source_xpz` e `source_refresh_status` pertencem ao fluxo `xpz-sync`. Essa exceção cobre tanto o passo 34 do WORKFLOW quanto o subestado `setup_apto_com_metadata_pendente` da PRE-CONDICAO, sempre preservando campos fora do escopo e respeitando regras locais de aprovacao antes da escrita.

8.e Para `.claude\settings.json` existente: ler entradas presentes e inserir apenas os padrões que ainda não constarem; não remover nem sobrescrever entradas já existentes

8.f Para cada script local cujo papel corresponde a um exemplo canonico da base metodologica: verificar se o prefixo verbal do nome local coincide com o do exemplo atual. Se o exemplo canonico mudou de prefixo em relacao a versão anterior da base (ex: o exemplo passou de `Update-KbIntelligenceIndex` para `Rebuild-KbIntelligenceIndex`), o nome local deve ser alinhado ao padrão atual. Esse caso específico deve ser tratado mesmo quando o conteúdo do script já foi corrigido e está funcional:
    - O agente deve detectar a divergencia de prefixo verbal e evidencia-la ao usuário de forma objetiva (ex: local `Update-FabricaBrasilKbIntelligenceIndex.ps1` vs exemplo canonico `Rebuild-KbIntelligenceIndex.example.ps1`)
    - Oferecer renome do script local para refletir o prefixo canonico (ex: `Rebuild-FabricaBrasilKbIntelligenceIndex.ps1`)
    - Após renomear, atualizar referencias ao nome antigo nos demais scripts locais:
      - `Update-KbFromXpz.ps1` (ou equivalente local) → ajustar o default de `IndexUpdateScriptPath` e qualquer mencao ao nome antigo
      - `Test-KbStructure.ps1` (ou equivalente local) → ajustar a lista de scripts esperados para usar o nome novo
      - `Test-KbIndexGate.ps1` → se referenciar o nome antigo, ajustar
    - Atualizar entradas correspondentes em `.claude\settings.json` (remover entrada antiga, adicionar entrada nova)
    - Aguardar aprovacao explicita do usuário antes de renomear ou alterar qualquer script por este motivo

8.f.1 Detectar também arquivo legado persistindo lado a lado com o canonico atual. Esse caso e diferente de `INVENTORY_SHORT_NAMING`: o script canonico já existe, mas o nome antigo continua em `scripts/` e pode ser chamado por allowlist, documentação local ou agentes futuros. Quando `Test-*KbSetupAudit.ps1` emitir `INVENTORY_LEGACY_ORPHANS`, o agente deve:
    - Evidenciar cada par `canonico(legacy=antigo)` ao usuário
    - Verificar referencias ao nome antigo em `.claude\settings.json`, `AGENTS.md`, `README.md` e scripts locais da pasta paralela
    - Oferecer remocao do arquivo legado e atualizacao das referencias para o canonico atual
    - Aguardar aprovacao explicita antes de apagar o legado ou alterar referencias
    - Rerodar a auditoria após a limpeza aprovada

8.f.2 Quando `Test-*KbSetupAudit.ps1` emitir `INVENTORY_RECOMMENDED_MISSING`, o agente deve tratar o sinal como recomendacao de ergonomia operacional, não como falha estrutural. Oferecer criar os wrappers listados a partir dos `.example.ps1` da própria skill quando o usuário quiser reduzir comandos compostos e entradas ad hoc de allowlist; se o usuário adiar, registrar a recomendacao no handoff sem rebaixar o estado operacional.

8.g Para pastas que adotam `KbIntelligence`: verificar se o `AGENTS.md` local contem a seção `## Triagem Por Indice` com roteamento explicito para `xpz-index-triage`. Se a seção estiver ausente:
    - O agente deve evidenciar a ausencia ao usuário: "O AGENTS.md não tem a seção de triagem por índice — tarefas de existencia/localizacao/impacto podem ser roteadas para `nexa` em vez de `xpz-index-triage`, furando o gate."
    - Oferecer adicionar o bloco padrão de triagem (conforme template do `modo_criacao`)
    - Aguardar aprovacao explicita do usuário antes de gravar
    - O bloco padrão deve incluir no mínimo:
      - Roteamento: perguntas de existencia/localizacao/impacto → `xpz-index-triage`
      - Gate: não compensar gate bloqueado com leitura manual de SQLite, JSON ou XML
      - Fonte normativa: `ObjetosDaKbEmXml` como confirmacao só depois do gate liberado

8.g2 OBRIGATÓRIO ANTES DE 8.h — Verificacao de naming de `ObjetosDaKbEmXml` (só pular se a pasta não existir ou estiver completamente vazia):

8.g2.0 Mecanismo preferencial: executar o wrapper local `Test-*KbObjetosDaKbNaming.ps1`, quando existir. O wrapper deve delegar ao motor compartilhado `scripts\Test-XpzObjetosDaKbNaming.ps1`, que aplica esta regra de forma deterministica e somente leitura. Se o wrapper estiver ausente ou indisponivel, seguir os passos 8.g2.i a 8.g2.vii manualmente como fallback documental e registrar o wrapper como AUSENTE na classificação de 8.a.

8.g2.i  Identificar todos os diretórios presentes em `ObjetosDaKbEmXml`. Amostragem representativa não e substituto aceito — todos os diretórios presentes devem ser cobertos sem exceção.

8.g2.ii Para cada diretório presente, ler pelo menos um XML e extrair o tipo canonico:
    - Em auditoria focal ou curta, quando o objetivo estiver limitado a diretórios específicos, localizar diretamente um XML dentro de cada diretorio-alvo, ler esse XML e classificar; não introduzir uma etapa exploratoria separada só para redescobrir se ha arquivos no diretório quando a própria amostragem direta já resolve
    - Para `Folder`, `Module`, `PackagedModule` e `Attribute`, um único XML por diretório e evidencia suficiente, salvo se o primeiro arquivo lido estiver corrompido, ilegivel ou sem o trecho mínimo necessário para classificação
    - Se o elemento raiz for `<Attribute>`, o tipo canonico e `Attribute`
    - Caso contrario, extrair o GUID de `Object/@type` e mapear para o nome canonico usando o catalogo efetivo (`GeneXus-XPZ-Skills/scripts/gx-object-type-catalog.json` mesclado com `scripts/gx-object-type-catalog.override.json` local quando existir); `01a-catalogo-e-padroes-empiricos.md` permanece referencia editorial upstream quando surgir tipo novo na base compartilhada
    - O GUID encontrado no XML e sempre a fonte autoritativa; o nome do diretório e convencao local e pode divergir
    - Nota: o motor `Build-KbIntelligenceIndex.py` já usa esse mesmo mapeamento por GUID — o campo `object_type` no índice estara correto independente do nome da pasta; a auditoria aqui serve a legibilidade e consistencia do acervo para humanos

8.g2.iii Se o nome do diretório divergir do nome canonico esperado para o GUID encontrado, declarar a divergencia explicitamente ao usuário: qual diretório está com qual tipo real, qual seria o nome canonico segundo a convencao, e qual foi a causa provavel quando conhecida. Divergencia de naming não resolvida impede declarar `wrappers_atualizados` ou `materializado_e_indice_validado` como estado final limpo — o estado operacional deve registrar a pendencia de naming explicitamente ate que o renome seja aprovado e executado ou descartado com ciencia do usuário.

8.g2.iv Antes de propor qualquer renome, verificar:
    - Se o `AGENTS.md` local referencia os nomes de diretório em risco de ser renomeados
    - Se existe índice `KbIntelligence`: o campo `object_type` no SQLite já estara correto (o motor le o GUID do XML, não o nome da pasta), mas o campo `path` dos registros refletira o nome antigo da pasta — após o renome, o path ficara desatualizado ate o próximo rebuild

8.g2.v Propor a sequência de renome segura e aguardar aprovacao explicita do usuário antes de qualquer escrita no disco:
    1. Diretório A → `_tmp_<nome>/` (nome temporario para evitar colisao)
    2. Diretório B → nome que era de A
    3. `_tmp_<nome>/` → nome que era de B
    - Nunca tentar renomear A diretamente para B quando B já existe

8.g2.vi Após renome aprovado e executado:
    - Atualizar referencias ao nome antigo no `AGENTS.md` local se houver
    - Informar ao usuário que o índice `KbIntelligence`, se existente, deve ser regenerado: o tipo dos objetos já estava correto, mas o campo `path` dos registros ainda reflete o nome antigo da pasta e ficara desatualizado ate o rebuild

8.g2.vii Critério de parada por evidencia suficiente na verificacao de naming:
    - Se `Test-*KbStructure.ps1` retornou `STRUCTURE_OK`, `Test-*KbIndexGate.ps1` retornou `GATE_OK` e a verificacao de naming concluiu cada diretório presente como conforme ou divergente com base no próprio XML local, considerar a verificacao de naming encerrada — não prolongar procurando catalogos externos, caminhos fora da pasta paralela ou amostras extras apenas para reconfirmar tipos já identificados
    - Este critério fecha a verificacao de naming (8.g2); não fecha o diagnostico completo de `auditar_setup`. O fechamento completo exige ainda que o passo 8.a tenha classificado todos os wrappers canonicos obrigatórios para o cenário adotado e que nenhum permaneca AUSENTE sem decisão explicita do usuário — `STRUCTURE_OK + GATE_OK` sem essa classificação completa não autoriza declarar `wrappers_atualizados`
    - Falha de uma tentativa intermediaria de glob, listagem ou busca não autoriza expandir o escopo; apenas trocar para uma leitura local mais simples e direta do XML do diretório em teste
    - Exceção operacional: se o XML local já permitir identificar o tipo canonico pela própria estrutura — por exemplo, raiz `<Attribute>` — isso basta; não exigir `Object/@type` nem consulta adicional externa para fechar a auditoria
    - Se houver divergencia real, relatar a divergencia e propor a ação segura; se não houver divergencia, seguir para 8.h e declarar o estado sem exploracao extra

8.g3 Auditoria de aderencia do fluxo de empacotamento local (executar antes de 8.h quando existir `PacotesGeradosParaImportacaoNaKbNoGenexus`):

8.g3.i Determinar se ha evidencia objetiva de empacotamento local adotado ou esperado na pasta paralela:
    - considerar como evidencia suficiente qualquer uma das seguintes:
      - existência da pasta `PacotesGeradosParaImportacaoNaKbNoGenexus`
      - existência de wrapper local `Test-*KbSourceSanity.ps1`
      - existência de wrapper local `Test-*KbPackageCollision.ps1`
      - existência de wrapper local `New-*KbImportPackage.ps1`
      - documentação local (`AGENTS.md`, `README.md`) mencionando `import_file.xml`, pacote local ou importação manual na IDE

8.g3.ii Se não houver nenhuma dessas evidencias, declarar `empacotamento local = NAO_ADOTADO` e seguir

8.g3.iii Se houver evidencia objetiva, auditar explicitamente os wrappers locais ligados a empacotamento:
    - `Test-*KbSourceSanity.ps1`
    - `Test-*KbPackageCollision.ps1`
    - `New-*KbImportPackage.ps1`, quando existir ou quando a KB declarar que precisa de comando curto/allowlist para empacotamento recorrente
    Para cada um, classificar como `EQUIVALENTE`, `AUSENTE` ou `CUSTOMIZADO` sob o mesmo critério de 8.a.ii
    Para os wrappers que delegam a um motor compartilhado (`Test-*KbSourceSanity.ps1`, `New-*KbImportPackage.ps1`), a classificação `EQUIVALENTE` exige comparar a linha de chamada do motor contra o exemplo canonico: um parâmetro encaminhado que o motor não declara — por exemplo `-AsJson` em wrapper que delega a `Test-GeneXusSourceSanity.ps1` — e erro de binding invisivel ao parse e ao critério de parada curta de 8.g3.vii, e classifica o wrapper como `CUSTOMIZADO`; não declarar `EQUIVALENTE` por inspecao apenas estrutural nem por wrapper "já operacional pelo contexto local" sem essa comparacao

8.g3.iv Se a pasta adota ou pode adotar empacotamento local e `Test-*KbPackageCollision.ps1` estiver `AUSENTE` ou `CUSTOMIZADO`, não concluir `wrappers_atualizados` como estado global suficiente; declarar `empacotamento local = PENDENTE` e usar estado operacional compativel com essa pendencia, preferindo `auditoria_de_empacotamento_pendente` quando `sync`, índice e estrutura estiverem OK

8.g3.v Se a pasta adota ou pode adotar empacotamento local e os wrappers `Test-*KbSourceSanity.ps1` e `Test-*KbPackageCollision.ps1` estiverem `EQUIVALENTE` ou conscientemente `NAO_ADOTADO` por regra local explicitada ao usuário, declarar `empacotamento local = OK`; `New-*KbImportPackage.ps1` ausente não bloqueia esse estado enquanto o motor compartilhado puder ser chamado diretamente com `-RepoRoot`

8.g3.vi No handoff final de `modo_atualizacao`, quando 8.g3 foi executado, listar separadamente a classificação de `Test-*KbSourceSanity.ps1`, `Test-*KbPackageCollision.ps1` e, se aplicavel, `New-*KbImportPackage.ps1`; não substituir esse detalhe por resumo agregado como "9 scripts presentes", "scripts parseados" ou equivalente

8.g3.vii Critério de parada curta por pendencia isolada de empacotamento:
    - Se `Test-*KbStructure.ps1` retornou `STRUCTURE_OK`, `Test-*KbIndexGate.ps1` retornou `GATE_OK`, a verificacao de naming já fechou sem divergencia e a única lacuna objetiva remanescente do fluxo de empacotamento local for `Test-*KbPackageCollision.ps1 = AUSENTE`, autorizar fechamento curto do diagnostico
    - Nessa situacao, não prolongar a sessao com reinspecao extensa dos wrappers já estabilizados, comparacoes repetitivas contra exemplos canonicos ou leitura manual extra de scripts que já estao operacionais pelo contexto local
    - Basta declarar explicitamente: `sync/materializacao = OK`, `indice/gate = OK`, `empacotamento local = PENDENTE`, `Test-*KbSourceSanity.ps1 = <classe apurada>`, `Test-*KbPackageCollision.ps1 = AUSENTE` e oferecer a criacao do wrapper faltante
    - Essa saida curta não autoriza mascarar `CUSTOMIZADO`, `AUSENTE` adicional ou memoria local desatualizada; se surgir qualquer outra lacuna objetiva além do wrapper de colisao ausente, retomar o fluxo normal de auditoria
    - Quando existir wrapper local `Test-*KbSetupAudit.ps1`, o agente deve executa-lo e usar sua saida como consolidacao do handoff de `auditar_setup`; isso vale para o critério de parada curta e para qualquer outro fechamento de `auditar_setup`; ainda assim, `Test-*KbPowerShellRuntime.ps1`, `Test-*KbIndexGate.ps1`, `Test-*KbMetadataWrapper.ps1` e os wrappers de empacotamento permanecem como evidencia primaria e o estado canonico declarado no handoff deve ser um dos estados desta skill, não apenas o `estado_operacional_sugerido` do wrapper

8.g4 Consolidacao de handoff via `Test-*KbSetupAudit.ps1` (executar imediatamente antes de 8.h quando a intencao for `auditar_setup`):
    - Verificar se `Test-*KbSetupAudit.ps1` existe na pasta `scripts` local
    - Se existir: executa-lo e reproduzir na resposta ao usuário todas as linhas de saida do wrapper — em especial todas as linhas `wrappers/inventario:` exatamente como emitidas (se ha duas linhas `wrappers/inventario:`, ambas devem aparecer; nunca resumir, omitir ou parafrasear essas linhas); citar nominalmente os blocos consolidados (`powershell/runtime`, `sync/materializacao`, `naming/objetos-da-kb`, `indice/gate`, `indice/semantica`, `metadata wrapper`, `metadata/deploy`, `empacotamento local`, `declarativo/timestamps`, `wrappers/inventario`, `estado_operacional_sugerido`); comparar `estado_operacional_sugerido` com o estado canonico que a evidencia objetiva da auditoria sustenta; se houver divergencia, declarar o estado canonico correto e explicitar a divergencia ao usuário; não adotar o sugerido pelo wrapper sem verificacao; a saida do wrapper consolida dimensoes operacionais mas NÃO substitui a classificação individual dos scripts — 8.a.ii e a tabela de 8.h continuam obrigatórios mesmo quando `Test-*KbSetupAudit.ps1` existe e passou
    - Limite explicito: `metadata wrapper: OK`, `metadata/deploy: OK` e `wrappers/inventario: INVENTORY_OK` provam apenas que o metadata local está completo, legivel, que os campos de deploy são plausiveis quando presentes e que os wrappers esperados pelo inventario atual não apresentam gaps/customizacoes detectadas; não provam que `Source/kb (GUID)`, `Source/Version/guid`, `username` ou `UNCPath` ainda correspondem à KB nativa local atual. Confronto contra a KB nativa exige resolvedor/atualizador em frente aprovada ou gate futuro dedicado; não inferir essa prova a partir do inventario.
    - Se não existir: sintetizar as dimensoes manualmente conforme as regras de 8.h; registrar o wrapper como AUSENTE na tabela de scripts de 8.h
    - Quando a saida incluir `wrappers/inventario: INVENTORY_GAPS: <lista>`: o `estado_operacional_sugerido` emitido pelo motor sera `atualizacao_metodologica_pendente` — isso e esperado e correto para este caso; classificar cada wrapper listado como AUSENTE na tabela de scripts de 8.h e oferecer `atualizar_bootstrap_local` como próximo passo imediato antes de encerrar o handoff; não tratar `INVENTORY_GAPS` como observação informativa nem como item opcional para "incorporacao futura"
    - Quando a saida incluir `wrappers/inventario: INVENTORY_SHORT_NAMING: <lista>`: os scripts existem com naming curto (ex: `Test-KbIndexGate.ps1`) em vez do naming canonico com prefixo KB (ex: `Test-wsEducacaoSpTesteKbIndexGate.ps1`); classificar cada wrapper listado como CUSTOMIZADO na tabela de scripts de 8.h com ação "renomear para naming canonico"; oferecer `atualizar_bootstrap_local` para executar os renomes; o rename envolve: criar o arquivo com o nome canonico (conteúdo identico mas com referencias internas a scripts irmaos atualizadas para o nome canonico), validar parse, excluir o arquivo de nome curto; atualizar `AGENTS.md` com os nomes canonicos; não encerrar sem propor essa correcao
    - Quando a saida incluir `wrappers/inventario: INVENTORY_CUSTOMIZED: <lista>`: classificar cada wrapper listado como CUSTOMIZADO na tabela de scripts de 8.h; para `requires_version_mismatch`, a ação recomendada e alinhar a diretiva `#requires -Version` ao exemplo canonico, salvo exceção documentada do wrapper de runtime; `GATE_OK`, `STRUCTURE_OK` e execução funcional do wrapper não neutralizam essa classificação
    - Quando a saida incluir `wrappers/inventario: INVENTORY_LEGACY_ORPHANS: <lista>`: classificar cada arquivo legado listado como CUSTOMIZADO/legado na tabela de scripts de 8.h; a ação recomendada e remover o arquivo antigo e atualizar referencias locais para o nome canonico atual, incluindo `.claude\settings.json` quando houver entrada antiga; o `estado_operacional_sugerido` deve ser `atualizacao_metodologica_pendente` enquanto o legado persistir
    - Quando a saida incluir `wrappers/inventario: INVENTORY_RECOMMENDED_MISSING: <lista>`: oferecer criacao dos wrappers recomendados ausentes a partir dos `.example.ps1` publicados pela skill; esse sinal e consultivo e não impede `materializado_e_indice_validado` quando as demais dimensoes estiverem OK, mas deve aparecer no handoff para evitar que o agente volte a usar comandos compostos ou motores compartilhados diretos sem necessidade
    - Quando a saida incluir combinacoes de `INVENTORY_SHORT_NAMING`, `INVENTORY_CUSTOMIZED`, `INVENTORY_LEGACY_ORPHANS`, `INVENTORY_GAPS` e `INVENTORY_RECOMMENDED_MISSING`: o script de auditoria os emite como linhas `wrappers/inventario:` separadas — tratar cada linha de forma independente; SHORT_NAMING → CUSTOMIZADO com rename, CUSTOMIZED → CUSTOMIZADO com correcao metodologica, LEGACY_ORPHANS → CUSTOMIZADO/legado com limpeza aprovada, GAPS → AUSENTE com criacao, RECOMMENDED_MISSING → recomendacao consultiva com oferta de criacao; ignorar qualquer linha e proibido e invalida a tabela de 8.h
    - Quando a saida incluir `declarativo/timestamps: DRIFT_TIMESTAMPS_LITERAIS`: o `AGENTS.md` e/ou `README.md` local da pasta paralela contem timestamps literais de `last_xpz_materialization_run_at` e/ou `last_index_build_run_at` gravados como espelho de fonte autoritativa. Isso e divergencia metodologica objetiva: nenhum wrapper mantem esses espelhos coerentes com o `kb-source-metadata.md` ou com o `-Query index-metadata`, e o drift se acumula silenciosamente. O `estado_operacional_sugerido` emitido pelo motor sera `atualizacao_metodologica_pendente` — isso e esperado e correto. A correcao NÃO e atualizar os valores literais antigos; e remover os literais e substitui-los por ponteiros para as fontes autoritativas. A ação desta skill e: (1) reproduzir a evidencia (`declarativo/timestamps.evidencia` aponta arquivo e campo); (2) propor ao usuário substituir o bloco "Estado operacional" pelo formato de ponteiros descrito em `examples/AGENTS.md.example` desta skill — sem timestamps literais, apenas referenciando `kb-source-metadata.md`, `Query-*KbIntelligence.ps1 -Query index-metadata` e `Test-*KbSetupAudit.ps1` como fontes vivas; (3) aguardar aprovacao explicita do usuário da pasta paralela antes de editar; (4) executar a correcao editorial via `atualizar_bootstrap_local`. Não tratar essa linha como observação informativa; impede declarar `wrappers_atualizados` ou `materializado_e_indice_validado` como estado final limpo enquanto o drift persistir.
    - Mini-runbook específico para `DRIFT_TIMESTAMPS_LITERAIS`: localizar os literais em `AGENTS.md` e/ou `README.md`; substituir por texto estavel que aponte para `kb-source-metadata.md` (`last_xpz_materialization_run_at`, preferencialmente via `Get-*KbMetadata.ps1`), para `Query-*KbIntelligence.ps1 -Query index-metadata` (`last_index_build_run_at`) e para `Test-*KbIndexGate.ps1` (`GATE_OK` como liberacao operacional); rerodar `Test-*KbSetupAudit.ps1`; se `estado_operacional_sugerido` voltar para `materializado_e_indice_validado` ou outro estado canonico bem-sucedido permitido, executar `Set-*KbSetupAuditTimestamp.ps1` (ou gravar manualmente conforme passo 34) com o horario real da auditoria bem-sucedida; rerodar `Test-*KbSetupFreshness.ps1` e esperar `GATE_ONLY`; rerodar `Test-*KbIndexGate.ps1` e esperar `GATE_OK`.
    - Exemplo ruim em `AGENTS.md`/`README.md`: ``last_index_build_run_at: 2026-05-23T10:00:00-03:00``. Exemplo correto: "Timestamp efetivo do índice: consultar `last_index_build_run_at` via `scripts\Query-<NomeKb>KbIntelligence.ps1 -Query index-metadata`." O mesmo critério vale para `last_xpz_materialization_run_at`: o valor efetivo fica em `kb-source-metadata.md`, não em memoria declarativa duplicada.

8.g5 Verificar se o `AGENTS.md` local contem regra irrestrita de invocacao de `nexa` para qualquer tarefa GeneXus:
    - Buscar no `AGENTS.md` local ocorrências de `nexa` e verificar o escopo da instrucao associada
    - Se o texto instrui acionar `nexa` para "qualquer tarefa GeneXus" ou equivalente sem restringir a um tipo específico de tarefa: evidenciar ao usuário — "O `AGENTS.md` local instrui acionar `nexa` para qualquer tarefa GeneXus. Isso provoca carregamento desnecessario em tarefas já cobertas por skills `xpz-*` específicas (build, import/export, sync, leitura de XPZ), aumentando consumo de tokens sem beneficio operacional."
    - Oferecer correcao: substituir a regra irrestrita por uma versão com escopo delimitado — nexa para tarefas de modelagem, análise de objetos ou consulta de estrutura da KB; tarefas cobertas por skill `xpz-*` específica seguem apenas essa skill
    - Aguardar aprovacao explicita do usuário antes de alterar o `AGENTS.md`
    - Se a regra de nexa já estiver explicitamente restrita a modelagem/analise de objetos e excluir tarefas `xpz-*`, declarar conforme sem propor alteracao
    - Esta verificacao aplica-se a qualquer pasta paralela com referencia a nexa no `AGENTS.md` local, independentemente de usar `KbIntelligence`

8.g6 Auditoria de adocao do fluxo de importação via MSBuild (executar antes de 8.h):

8.g6.i Determinar se ha evidencia objetiva de uso do fluxo de importação via MSBuild — `Invoke-GeneXusXpzImport.ps1` da skill `xpz-msbuild-import-export` — pela pasta paralela:
    - considerar como evidencia suficiente qualquer uma das seguintes:
      - existência de `Temp\import.json`, `Temp\msbuild.stdout.log` ou outros artefatos nominais de execução de `Invoke-GeneXusXpzImport.ps1`
      - existência de wrapper local que delegue a `Invoke-GeneXusXpzImport.ps1` (ex: `Invoke-*KbXpzImport.ps1`)
      - documentação local (`AGENTS.md`, `README.md`) mencionando importação headless, MSBuild import ou a skill `xpz-msbuild-import-export` no fluxo operacional
      - `PacotesGeradosParaImportacaoNaKbNoGenexus` populado E referencia documental local ao caminho de importação headless (a mera existência da pasta não basta — empacotamento sem importação headless e cenário valido coberto por 8.g3)

8.g6.ii Se não houver nenhuma dessas evidencias, declarar `importacao_msbuild = NAO_ADOTADO` e seguir

8.g6.iii Se houver evidencia objetiva, esta skill não audita o conteúdo nem o comportamento de `Invoke-GeneXusXpzImport.ps1`. Esse script e do motor compartilhado e seu contrato (parâmetros, diagnostico JSON, resiliencia do pos-processamento, sub-estados de classificação) e governado pela skill `xpz-msbuild-import-export`. A ação desta skill e:
    - declarar `importacao_msbuild = ADOTADO` no handoff e roteamento explicito para `xpz-msbuild-import-export` quando houver qualquer suspeita de diagnostico degradado (ex: `import.json` ausente, vazio, com `postProcessingFailed=true`, com `diagnosticDegraded=true`, ou ausencia de `importedItems` apesar de `__IMPORTED_ITEM__` no log bruto)
    - não tentar corrigir o script localmente nem reinterpretar sub-estados de import dentro deste fluxo de setup
    - não confundir falha de pos-processamento do wrapper com falha de import: `__IMPORTED_ITEM__` no log bruto e evidencia de import real, mesmo quando o `import.json` estiver degradado — a classificação final do sub-estado pertence a `xpz-msbuild-import-export`
    - não tratar `diagnosticDegraded=true` com `postProcessingFailed=false` como sucesso limpo; essa combinacao indica diagnostico parcial e deve ser roteada para `xpz-msbuild-import-export` quando a decisão depender da classificação fina da rodada
    - se o diagnostico degradado expuser `executionEvidence.msBuildExitCode`, usar esse campo como fonte canonica do exit bruto do MSBuild; `msBuildExitCode` top-level, quando existir, e apenas compatibilidade transitoria

8.g6.iv No handoff final de `modo_atualizacao`, quando 8.g6 foi executado, listar separadamente a dimensao `importacao_msbuild` com um dos rotulos: `ADOTADO`, `NAO_ADOTADO`, `PENDENTE_DIAGNOSTICO` ou `IMPORTACAO_HEADLESS_PENDENTE`. `PENDENTE_DIAGNOSTICO` aplica-se quando houver evidencia de diagnostico degradado que o usuário deve resolver via `xpz-msbuild-import-export` antes de declarar a dimensao como `ADOTADO`. `IMPORTACAO_HEADLESS_PENDENTE` aplica-se quando a verificacao consultiva da seção `## CAPACIDADE DE IMPORTACAO HEADLESS` indicar capacidade defasada (motor compartilhado ausente, ou contrato documental da skill `xpz-msbuild-import-export` divergente das regras esperadas) — bloqueante quando a tarefa corrente depende de importação real; consultivo no handoff quando a tarefa não depende. Não colapsar essa dimensao em `empacotamento local`, `sync/materializacao` ou outra dimensao adjacente — são camadas distintas.

8.g6.v Quando 8.g6.i identificar evidencia de adocao do fluxo, ou quando a tarefa corrente envolver importação real via MSBuild ainda que a pasta não tenha histórico de import (pacote acabou de ser gerado, frente nova), executar a verificacao consultiva descrita na seção `## CAPACIDADE DE IMPORTACAO HEADLESS`. O resultado dessa verificacao alimenta o rotulo declarado em 8.g6.iv: `IMPORTACAO_HEADLESS_PENDENTE` quando alguma das verificacoes da seção falhar; não altera os demais rotulos quando a verificacao passar.

8.h Ao concluir o bloco de atualizacao, declarar o estado operacional compativel com a evidencia realmente fechada e apresentar a tabela de scripts com as colunas: Script | Classe (EQUIVALENTE / AUSENTE / CUSTOMIZADO) | Ação. A tabela deve incluir TODOS os scripts esperados — não apenas os que requerem ação; scripts EQUIVALENTE também devem ter uma linha na tabela. Uma lista de "scripts a atualizar", "scripts a criar" ou "pontos de atenção" NÃO substitui a tabela de classificação — são formatos diferentes; a tabela de classificação e obrigatória independentemente de qualquer resumo adicional. Scripts presentes em `INVENTORY_SHORT_NAMING` devem aparecer na tabela como CUSTOMIZADO com ação de renome — não como EQUIVALENTE e não omitidos. Arquivos presentes em `INVENTORY_LEGACY_ORPHANS` devem aparecer como CUSTOMIZADO/legado com ação de limpeza aprovada e atualizacao de referencias. Wrappers presentes em `INVENTORY_RECOMMENDED_MISSING` devem aparecer em bloco separado de recomendacoes consultivas ou na tabela como AUSENTE/recomendado, deixando claro que a ausencia isolada não bloqueia o estado limpo. Parse já está coberto pelo gate: `GATE_OK` prova que todos os scripts passaram o parser do PowerShell sem erros — não e necessário repetir o resultado de parse na tabela; a classificação EQUIVALENTE / AUSENTE / CUSTOMIZADO de cada script e obrigatória mesmo assim e não e substituida pelo gate. Listar explicitamente: scripts adicionados, scripts mantidos (EQUIVALENTES), scripts substituidos com aprovacao e scripts pulados. Quando houver `PacotesGeradosParaImportacaoNaKbNoGenexus`, a tabela ou o resumo deve incluir explicitamente `Test-*KbSourceSanity.ps1` e `Test-*KbPackageCollision.ps1`, mesmo que a conclusao seja "mantido" ou "ausente". Quando 8.g3.vii se aplicar, a saida pode ser curta e objetiva, sem reinspecao exaustiva dos wrappers já estabilizados; ainda assim, deve preservar a classificação explicita dos wrappers de empacotamento local e o estado canonico final. Alinhar a seção "Estado operacional" do `AGENTS.md` local ao formato de ponteiros de `examples/AGENTS.md.example` (sem estado canonico fixo nem timestamps literais de materializacao/indice). O estado canonico efetivo da pasta e declarado no handoff desta sessao e vem de `Test-*KbSetupAudit.ps1` (`estado_operacional_sugerido`) e dos gates específicos — não de texto estatico no markdown. Se o `AGENTS.md` ainda espelhar `materializado_e_indice_validado`, outros estados fixos ou timestamps literais enquanto a evidencia objetiva divergir, tratar isso como drift documental e corrigir via ponteiros antes de encerrar como conclusao limpa; não substituir um estado fixo antigo por outro estado fixo novo. Verificar também se a seção `## Wrappers locais` do `AGENTS.md` local lista todos os scripts atualmente presentes em `scripts/` com nomes e funções corretos; se estiver desatualizada — por listar scripts com nomes antigos ou omitir scripts recem-adicionados — propor atualizacao ao usuário antes de declarar o setup como concluido. Por fim, comparar a estrutura geral do `AGENTS.md` local contra o modelo canonico em `examples/AGENTS.md.example` desta skill; se houver seções canonicas ausentes além das já verificadas nos passos anteriores (`## Triagem Por Indice` em 8.g e `## Wrappers locais` acima), propor adicao ao usuário antes de declarar o setup como concluido.
    - Scripts presentes em `INVENTORY_CUSTOMIZED` devem aparecer na tabela como CUSTOMIZADO com o motivo emitido pelo inventario; quando o motivo for `requires_version_mismatch`, a ação deve apontar o alinhamento de `#requires -Version` ao exemplo canonico, salvo a exceção documentada do wrapper de runtime
    - Quando `README.md` ou `AGENTS.md` local gravarem estado operacional canonico fixo (ex: `materializado_e_indice_validado`), timestamps literais de materializacao/indice ou observação de frescor como espelho, tratar isso como drift documental — a correcao e substituir por ponteiros conforme `examples/AGENTS.md.example`, não harmonizar valores literais entre markdowns nem atualizar o espelho para um novo estado fixo
    - Se `declarativo/timestamps: DRIFT_TIMESTAMPS_LITERAIS` ou inspecao textual equivalente detectar literais/estado estatico, evidenciar ao usuário e propor alinhamento de `AGENTS.md` e `README.md` locais antes de encerrar o setup como "ok"
    - `GATE_OK` não neutraliza essa obrigacao: gate liberado prova compatibilidade operacional atual, mas não prova que a memoria declarativa local está no formato de ponteiros sem drift
    - `GATE_OK` e `STRUCTURE_OK` não bastam, sozinhos, para concluir "tudo certo" quando a aderencia do fluxo de empacotamento local ainda não tiver sido auditada
    - Divergencia de naming em `ObjetosDaKbEmXml` pendente de correcao ou descarte explicito impede declarar `wrappers_atualizados` ou `materializado_e_indice_validado` como estado final limpo; nenhum desses dois estados pode ser declarado sem que a verificacao de naming esteja encerrada — todos os diretórios conformes, ou divergencias registradas e descartadas conscientemente pelo usuário
    - Para efeito das regras acima: `AGENTS.md` e memoria operacional normativa para agentes — lista de wrappers ativos, regras de gate e roteamento; estado canonico efetivo e frescor operacional vivem na auditoria consolidada e nas fontes autoritativas, não em estado fixo na seção "Estado operacional". `README.md` e guia de uso humano — como operar a pasta, quais automacoes o humano executa diretamente, quais fluxos estao expostos. Essa distincao define quando atualizar só um ou ambos.
    - Gatilho obrigatório para `AGENTS.md`: quando qualquer wrapper mudar de classe nesta rodada (AUSENTE resolvido, CUSTOMIZADO corrigido, wrapper novo adicionado), atualizar `## Wrappers locais` e alinhar a seção "Estado operacional" ao formato de ponteiros de `examples/AGENTS.md.example` (sem estado/timestamp literal); etapa obrigatória antes de declarar qualquer estado de conclusao — não e proposta sujeita a pular.
    - Gatilho obrigatório para `README.md`: quando a mudanca de wrapper alterar o conjunto de automacoes expostas diretamente ao humano (novo script que o humano chama, script renomeado ou removido do fluxo normal), atualizar a seção correspondente do `README.md` também e obrigatório antes de declarar `wrappers_atualizados`.
    - O handoff final deve listar explicitamente o resultado de `Test-*KbMetadataWrapper.ps1` quando esse wrapper existir ou quando `Test-*KbSetupAudit.ps1` emitir a dimensao `metadata wrapper`. Não basta inferir metadata valido a partir de `estado_operacional_sugerido: materializado_e_indice_validado`; incluir uma linha própria, como `Test-<Kb>KbMetadataWrapper.ps1: METADATA_WRAPPER_OK` ou `metadata wrapper: OK`, e preservar `metadata wrapper.evidencia` quando houver pendencia.
    - `declarativo/timestamps` e a evidencia deterministica primaria sobre drift de memoria declarativa local (timestamps literais de `last_xpz_materialization_run_at`/`last_index_build_run_at` em `AGENTS.md` ou `README.md`); quando essa linha vier como `DRIFT_TIMESTAMPS_LITERAIS`, ela impede declarar `wrappers_atualizados` ou `materializado_e_indice_validado` como estado final limpo enquanto o drift persistir — a obrigacao de alinhamento declarativo descrita nas linhas anteriores não substitui o gate deterministico, e `GATE_OK` ou `STRUCTURE_OK` não neutralizam essa pendencia

--- FIM DO BLOCO DE ATUALIZACAO ---

--- BLOCO DE VERIFICACAO DE NAMING (execução isolada, fora de modo_atualizacao) ---

Quando acionado de forma isolada, seguir os mesmos passos de 8.g2.i a 8.g2.vii. Diferenca de contexto: não ha estado de conclusao de modo_atualizacao a declarar — a saida e apenas o resultado da verificacao de naming para cada diretório (conforme ou divergente) e, se houver divergencia, a oferta de correcao via a sequência de renome segura de 8.g2.v.

--- FIM DO BLOCO DE VERIFICACAO DE NAMING ---

9. Validar a existência da estrutura nesta ordem:
   - `scripts`
   - `Temp`
   - `XpzExportadosPelaIDE`
   - `ObjetosDaKbEmXml`
   - `KbIntelligence`
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
   - `PacotesGeradosParaImportacaoNaKbNoGenexus`
10. Criar `.gitignore` na raiz quando a pasta paralela estiver versionada em Git ou quando o usuário aceitar preparacao para versionamento futuro; o `.gitignore` deve cobrir: `Temp/*`, `KbIntelligence/kb-intelligence.sqlite`, `KbIntelligence/kb-intelligence-validation.json`, `ObjetosGeradosParaImportacaoNaKbNoGenexus/*`, `PacotesGeradosParaImportacaoNaKbNoGenexus/*` e `XpzExportadosPelaIDE/*`; para cada pasta coberta com o padrão `pasta/*`, criar também o arquivo `.gitkeep` correspondente nessa mesma pasta no mesmo passo; não gravar `.gitignore` que referencia `.gitkeep` sem criar o arquivo físico; `ObjetosDaKbEmXml` não deve ser ignorado
11. Se a pasta paralela ainda não estiver versionada em Git, o agente pode oferecer inicializar versionamento Git local; não executar `git init` sem aprovacao explicita do usuário
12. Se o usuário aceitar versionamento Git local e o Git não estiver funcional no ambiente, oferecer instalar ou orientar a instalacao antes do bootstrap Git
13. Se `kb-source-metadata.md` ainda não existir, criar com o campo nominal `last_xpz_materialization_run_at`, sem inventar formato paralelo desconectado do motor compartilhado. Quando a pasta nativa da KB estiver confirmada, executar `Resolve-GeneXusKbIdentity.ps1` antes da gravacao e preencher também os campos de identidade estavel (`Source/kb (GUID)`, `Source/username`, `Source/UNCPath`, `Source/Version/guid`, `Source/Version/name`); se a resolucao bloquear, criar no máximo metadata parcial e declarar o estado como pendente, nunca como metadata apto para empacotamento. Se `kb-source-metadata.md` já existir, não tocar em campos fora da autoridade corrente — para preencher ausentes ou tratar divergencias, usar frente aprovada de reconciliacao via `Update-XpzKbSourceMetadataIdentity.ps1`, preservando timestamps operacionais reais que o gate de frescor depende.
14. Não salvar memoria externa do agente fora da pasta paralela da KB sem autorizacao explicita do usuário
15. Explicar o papel de cada pasta:
   - `ObjetosDaKbEmXml` = snapshot oficial extraido via fluxo oficial do `.ps1`
   - `ObjetosDaKbEmXml` = materialização do `XPZ` completo ou parcial da IDE, quebrando `full.xml` em XMLs individuais por objeto
   - `ObjetosDaKbEmXml` = organizacao por subpastas de tipo amigavel e nomes amigaveis de objeto
   - `KbIntelligence` = índice SQLite derivado e regeneravel a partir de `ObjetosDaKbEmXml`
   - `XpzExportadosPelaIDE` = entrada dos `.xpz` gravados pelo usuário na IDE
   - `XpzExportadosPelaIDE` = arquivos já consumidos podem receber o prefixo `processado_` após sucesso no fluxo oficial
   - `Temp` = area local para temporarios, logs auxiliares e copias efemeras de SQLite
   - `scripts` = wrappers `.ps1` e utilitarios operacionais
   - `scripts` = quando a pasta paralela da KB for inicializada do zero, os wrappers locais devem ser reconstruidos a partir do fluxo oficial e dos exemplos sanitizados desta skill
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus` = XMLs temporarios gerados pelo agente para importação manual, organizados por frente em subpastas `NomeCurto_GUID_YYYYMMDD`
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus` = não recebe materialização do acervo vindo de `XPZ`
   - `PacotesGeradosParaImportacaoNaKbNoGenexus` = pacote final de importação pela IDE, mantido plano sem subpastas por frente
16. Se `ObjetosDaKbEmXml` ainda não existir, tratar o acervo como ainda não materializado
17. Se `ObjetosGeradosParaImportacaoNaKbNoGenexus` não estiver organizado por frentes em subpastas `NomeCurto_GUID_YYYYMMDD`, tratar isso como desvio operacional e orientar correcao
18. Se `XpzExportadosPelaIDE` estiver ausente e o fluxo depender de `XPZ`, pedir ao usuário o caminho pretendido ou criar a pasta padrão quando a politica do repositório permitir
19. Se a pasta `scripts` existir sem wrappers locais minimos, orientar a reconstruir:
   - wrapper de atualizacao diaria sobre o motor compartilhado
   - wrapper de conferencia full reaproveitando o wrapper diario
   - wrapper de consulta do índice derivado, se a KB local adotar `KbIntelligence`
   - wrapper de regeneracao e validação do índice derivado, se a KB local adotar `KbIntelligence`
   - `Test-*KbIndexGate.ps1`, se a KB local adotar `KbIntelligence`
   - `Get-*KbMetadata.ps1`, se a KB local adotar `KbIntelligence`
   - `Test-*KbMetadataWrapper.ps1`, se a KB local adotar `KbIntelligence`
   - `Test-*KbStructure.ps1`, se a KB local adotar `KbIntelligence`
   - `New-*KbFront.ps1`, recomendado se a KB local abrir frentes de XML gerado com frequência e precisar de comando curto/allowlist para criar ou reutilizar `NomeCurto_GUID_YYYYMMDD`
   - `Get-*KbLastUpdate.ps1`, recomendado se a KB local atualizar `lastUpdate` em XMLs locais com frequência e precisar de comando curto/allowlist para obter timestamp GeneXus
   - `New-*KbImportPackage.ps1`, recomendado se a KB local adotar empacotamento recorrente e precisar de comando curto/allowlist
   - helper local opcional de notificacao, se houver necessidade operacional
20. Sempre que um wrapper local `.ps1` previsto pela base metodologica for criado ou confirmado durante o setup ou atualizacao — qualquer wrapper obrigatório ou recomendado adotado nesta pasta, não apenas um subconjunto fixo —, registrar o padrão de allowlist correspondente em `.claude\settings.json` da pasta paralela da KB, salvo recusa explicita do usuário. Isso cobre os gates e leitores nucleares (`Test-*KbIndexGate.ps1`, `Get-*KbMetadata.ps1`, `Test-*KbMetadataWrapper.ps1`, `Test-*KbStructure.ps1`), os wrappers recomendados quando adotados (`New-*KbFront.ps1`, `Get-*KbLastUpdate.ps1`, `New-*KbImportPackage.ps1`) e tambem os wrappers de acervo e deploy (`Copy-*KbAcervoToFront.ps1`, `Register-*KbPostBuildEvents.ps1`, `Set-*KbSourceMetadataDeployment.ps1`); estes dois ultimos disparam MSBuild, então a entrada de allowlist e especialmente desejavel. Registrar os padrões correspondentes:
   - Para cada script, adicionar uma entrada no array `permissions.allow` no formato `PowerShell(& "<caminho-absoluto-do-script>" *)`
   - Usar o nome real do script no caminho (ex: `Test-FabricaBrasilKbIndexGate.ps1`), não o nome sanitizado do exemplo
   - Se `.claude\settings.json` ainda não existir, criar com estrutura mínima
   - Se `.claude\settings.json` já existir, ler o conteúdo atual, verificar quais padrões já estao presentes e inserir apenas os ausentes; não remover nem sobrescrever entradas já existentes
   - Tratar essa etapa como parte do bootstrap ou da atualizacao, não como pendencia manual posterior; o agente deve executar isso antes de declarar o estado de conclusao
20a. Quando o agente decidir chamar o motor compartilhado diretamente — sem wrapper local equivalente, tipicamente passando `-RepoRoot` para resolver pastas da pasta paralela da KB — verificar antes que `.claude\settings.json` da pasta paralela contem entrada de allowlist cobrindo a pasta `scripts` da base compartilhada:
    - Padrão esperado: `PowerShell(& "<caminho-absoluto-da-pasta-scripts-da-base-compartilhada>\*")` (ex: `PowerShell(& "C:\Dev\Knowledge\GeneXus-XPZ-Skills\scripts\*")`)
    - O caminho deve ser absoluto e literal; não usar placeholder como `<SharedSkillsRoot>` na entrada gravada
    - Se a entrada estiver ausente, oferecer ao usuário a criacao antes da primeira invocacao direta do motor; aguardar aprovacao explicita antes de gravar
    - Se `.claude\settings.json` ainda não existir, criar com estrutura mínima já contendo essa entrada
    - Tratar isso como parte do bootstrap quando o cenário for empacotamento local sem wrapper `New-*KbImportPackage.ps1`, ou como atualizacao quando a chamada direta ao motor for nova nesta pasta
21. Se `KbIntelligence` estiver ausente, orientar sua criacao como pasta de artefatos derivados antes de instalar wrappers de índice
22. Se `ObjetosDaKbEmXml` ainda não contiver snapshot materializado, não tentar gerar `kb-intelligence.sqlite`; preparar apenas a pasta e os wrappers locais
23. Se a pasta adotar `KbIntelligence`, validar o gate de compatibilidade operacional antes de permitir pesquisa ampla, triagem substantiva ou geração de objetos
24. Se o gate falhar, oferecer atualizacao da pasta paralela/wrappers/indice e não responder a pergunta de negocio por fallback manual
25. Antes de declarar o setup como concluido, validar se a camada mínima de wrappers locais esperados em `scripts` já existe para o fluxo oficial adotado por essa pasta paralela
26. Quando os wrappers locais forem derivados dos `.example.ps1`, validar que eles não mantem placeholders sanitizados em configuração efetiva antes de classifica-los como wrappers minimos existentes
27. Se `Test-*KbSourceSanity.ps1` for criado ou atualizado nesta frente, validar esse wrapper diretamente antes do fechamento:
   - no mínimo, confirmar parse do `.ps1`, existência do engine compartilhado apontado por ele e ausencia de placeholders sanitizados em configuração efetiva
   - parse, existência do engine e ausencia de placeholder NÃO provam que o wrapper invoca o motor com um conjunto de parâmetros valido: um parâmetro que o motor compartilhado não declara — por exemplo `-AsJson` passado a `Test-GeneXusSourceSanity.ps1`, que emite JSON por padrão e não expoe esse parâmetro — e erro de binding em runtime, sintaticamente valido e portanto invisivel ao parse e a `STRUCTURE_OK`/`GATE_OK`; comparar a linha de chamada do motor contra o exemplo canonico e obrigatório, e qualquer parâmetro encaminhado além dos que o motor declara classifica o wrapper como divergente
   - quando houver XML local seguro para teste, a execução consultiva controlada do próprio wrapper e exigida, não apenas preferida, porque e o único teste que expoe o erro de binding descrito acima; quando nenhum alvo seguro existir, declarar explicitamente que a execução foi adiada em vez de tratar o wrapper como validado
   - lembrete de contrato cruzado: motores compartilhados diferentes têm contratos de saida diferentes — `Test-GeneXusSourceSanity.ps1` emite JSON por padrão e NÃO recebe `-AsJson` (assim como o motor de empacotamento, ver 27a), enquanto `Get-*KbLastUpdate.ps1` recebe `-AsJson` (ver 27b); não carregar `-AsJson` de um wrapper para outro
   - não usar `STRUCTURE_OK` ou `GATE_OK` como evidencia suficiente desse wrapper, porque o checklist estrutural canonico não o trata como item mínimo universal
27a. Se `New-*KbImportPackage.ps1` for criado ou atualizado nesta frente, validar esse wrapper diretamente antes do fechamento:
   - no mínimo, confirmar parse do `.ps1`, existência do engine compartilhado apontado por ele e ausencia de placeholders sanitizados em configuração efetiva
   - quando houver frente local segura para teste, preferir execução controlada parseando o JSON padrão do stdout, sem `-AsJson`
   - não criar pacote real apenas para validar o wrapper sem autorizacao explicita do usuário
27b. Se `New-*KbFront.ps1` ou `Get-*KbLastUpdate.ps1` forem criados ou atualizados nesta frente, validar esses wrappers diretamente antes do fechamento:
   - no mínimo, confirmar parse do `.ps1`, existência do engine compartilhado apontado por ele e ausencia de placeholders sanitizados em configuração efetiva
   - para `Get-*KbLastUpdate.ps1`, preferir execução controlada com `-AsJson`
   - para `New-*KbFront.ps1`, testar em pasta temporaria ou em frente real somente quando isso fizer parte do escopo aprovado; não criar subpasta real de frente na KB apenas para validar o wrapper sem autorizacao explicita do usuário
28. Se a estrutura de pastas e documentos estiver pronta, mas a camada mínima de wrappers locais ainda não existir ou ainda mantiver placeholders sanitizados em configuração efetiva, reportar isso como `estrutura parcial` ou `bootstrap incompleto`, não como setup concluido
29. Ao concluir o setup inicial, deixar explicito que a estrutura está pronta, mas `ObjetosDaKbEmXml` ainda não foi materializada
30. Se a primeira materialização oficial ocorrer depois do setup, atualizar ou neutralizar a memoria local provisoria criada no setup que ainda afirme `ObjetosDaKbEmXml` não materializada, `aguardando primeiro XPZ` ou equivalente
31. Ao concluir o setup inicial, oferecer os próximos passos:
   - `A)` o usuário exporta o `.xpz` full pela IDE para `XpzExportadosPelaIDE`, e o agente materializa os XMLs depois
   - `B)` o agente tenta gerar o `.xpz` full a partir da pasta nativa da KB, grava esse `.xpz` em `XpzExportadosPelaIDE` e depois materializa os XMLs
32. Ao oferecer `A)` e `B)`, declarar que `A)` e o caminho preferencial e normalmente mais rápido, enquanto `B)` tende a demorar mais por depender da trilha via `MSBuild`
32a. No fechamento do setup inicial, informar ao usuário que esta skill não verifica a presenca de `nexa` nas ferramentas instaladas: `nexa` pertence a outro repositório e está fora do escopo desta skill. Recomendar invocar `xpz-skills-setup` para auditar o ecossistema completo de skills, incluindo `nexa`.
33. Se o usuário escolher `B)`, usar a skill `xpz-msbuild-import-export` e não improvisar fluxo alternativo de exportação
34. Ao declarar qualquer estado canonico de conclusao bem-sucedido (`pronto_para_primeira_materializacao`, `materializado_e_indice_validado` ou `wrappers_atualizados`), gravar `last_setup_audit_run_at` com o timestamp da auditoria bem-sucedida e gravar `setup_contract_signature_version`/`setup_contract_signature_hash` com a assinatura atual do contrato de setup no frontmatter de `kb-source-metadata.md`; não gravar quando o estado for `bootstrap_incompleto`, `auditoria_de_empacotamento_pendente` ou `atualizacao_metodologica_pendente`; o timestamp deve ser ISO 8601 com fuso horario, no mesmo formato de `last_xpz_materialization_run_at`. Preferir `Set-*KbSetupAuditTimestamp.ps1` (motor `scripts/Set-XpzSetupAuditTimestamp.ps1`), que atualiza somente esses campos e preserva o restante do arquivo; edicao manual só quando o wrapper estiver ausente e a frente aprovada permitir gravacao local. Esses campos registram a auditoria de setup bem-sucedida; não substituem nem espelham `last_xpz_materialization_run_at` ou `last_index_build_run_at`. No subestado `setup_apto_com_metadata_pendente` da PRE-CONDICAO, esta mesma gravacao aplica-se quando a auditoria completa acabou de passar com estado canonico bem-sucedido compativel — não adiar por padrão para outra sessao.

---

## EXEMPLO CURTO DE ESTRUTURA MATERIALIZADA

```text
PastaParalelaDaKb/
  scripts/
    Update-KbFromXpz.ps1
    Test-KbFullSnapshot.ps1
    Test-KbObjetosDaKbNaming.ps1
    Query-KbIntelligence.ps1
    Rebuild-KbIntelligenceIndex.ps1
    Test-KbIndexGate.ps1
    Get-KbMetadata.ps1
    Test-KbMetadataWrapper.ps1
    Test-KbStructure.ps1
  Temp/
  XpzExportadosPelaIDE/
    KBCompleta_20260413.xpz
    processado_AjustesFinanceiro_20260413.xpz
  ObjetosDaKbEmXml/
    Transaction/
      Cliente.xml
      Pedido.xml
    Procedure/
      GeraBoleto.xml
    WebPanel/
      WPClienteConsulta.xml
  KbIntelligence/
    kb-intelligence.sqlite
    kb-intelligence-validation.json
  ObjetosGeradosParaImportacaoNaKbNoGenexus/
    AjusteVolumes_12345678-1234-1234-1234-123456789abc_20260414/
      ClienteNovo.xml
      PedidoAjustado.xml
  PacotesGeradosParaImportacaoNaKbNoGenexus/
    AjusteVolumes_12345678-1234-1234-1234-123456789abc_20260414_01.import_file.xml
```

---

## CONSTRAINTS

- NUNCA assumir que o nome de qualquer diretório em `ObjetosDaKbEmXml` corresponde ao tipo GeneXus correto sem verificar o GUID em pelo menos um XML daquele diretório; o nome do diretório e convencao local e pode divergir do tipo real
- NUNCA renomear diretórios em `ObjetosDaKbEmXml` sem aprovacao explicita do usuário e sem seguir a sequência segura com nome temporario (A→tmp, B→A, tmp→B)
- NUNCA declarar estado de conclusao em `modo_atualizacao` (passo 8.h) sem ter executado a verificacao de naming inline (passos 8.g2.i a 8.g2.vi) quando `ObjetosDaKbEmXml` contiver diretórios com XMLs; a auditoria de naming e obrigatória e não pode ser omitida mesmo quando todos os scripts forem EQUIVALENTE e nenhuma outra correcao for necessária
- NUNCA declarar "tudo certo", `wrappers_atualizados` ou equivalente global em `modo_atualizacao` quando existir `PacotesGeradosParaImportacaoNaKbNoGenexus` e a aderencia do fluxo de empacotamento local ainda não tiver sido auditada explicitamente, incluindo `Test-*KbPackageCollision.ps1`
- NUNCA confundir a pasta nativa da KB com a pasta paralela da KB
- NUNCA gravar na pasta nativa da KB; essa pasta e somente leitura para agentes, salvo leitura operacional controlada quando realmente necessária
- NUNCA gravar manualmente em `ObjetosDaKbEmXml`
- NUNCA tratar `XpzExportadosPelaIDE` como area de saida de pacotes ou XMLs gerados
- NUNCA aplicar o prefixo `processado_` antes de sucesso claro no processamento do `.xpz`
- NUNCA manter o lote ativo diretamente na raiz de `ObjetosGeradosParaImportacaoNaKbNoGenexus`; usar a subpasta da frente `NomeCurto_GUID_YYYYMMDD`
- NUNCA tratar XML de referencia, exemplo ou template salvo dentro da frente ativa como objeto importavel; esse arquivo indica uso indevido da area gerenciada e deve bloquear o empacotamento
- NUNCA criar subpastas por frente em `PacotesGeradosParaImportacaoNaKbNoGenexus`; essa area deve permanecer plana
- NUNCA materializar `XPZ` completo ou parcial da IDE dentro da pasta de geração para importação
- NUNCA usar GUID como nome principal de pasta ou arquivo do acervo materializado
- NUNCA usar `guid`, `parentGuid`, `parentType` ou `moduleGuid` como eixo principal de navegacao da pasta paralela da KB
- NUNCA tratar `KbIntelligence` como fonte normativa; o índice e derivado de `ObjetosDaKbEmXml`
- NUNCA gerar `kb-intelligence.sqlite` antes de existir snapshot oficial materializado em `ObjetosDaKbEmXml`
- NUNCA criar script novo se já houver fluxo oficial previsto nas skills ou em `scripts/` do repositório
- NUNCA presumir que a ausencia de `ObjetosDaKbEmXml` significa snapshot vazio; significa estrutura ainda não materializada
- NUNCA esconder do usuário quando a estrutura padrão foi assumida por falta de nomes alternativos
- NUNCA sobrescrever script existente em `scripts/` sem antes comparar com o exemplo correspondente, evidenciar objetivamente a divergencia ao usuário e obter aprovacao explicita para substituicao
- NUNCA gravar campos de `kb-source-metadata.md` fora da autoridade da operacao corrente; após a primeira materialização oficial, `last_xpz_materialization_run_at`, `source_xpz` e `source_refresh_status` continuam pertencendo apenas ao fluxo `xpz-sync`, enquanto esta skill só pode gravar `last_setup_audit_run_at` e `setup_contract_signature_*` nos casos permitidos ou reconciliar identidade estavel quando essa for a frente explicitamente aprovada
- NUNCA propor novo campo em `kb-source-metadata.md` para registrar estado ou frescor do índice; `last_index_build_run_at` na tabela `metadata` do SQLite já e a fonte autoritativa desse estado — campo espelho no markdown seria redundante e quebraria a unicidade da fonte de verdade
- NUNCA gravar timestamps literais de `last_xpz_materialization_run_at` ou `last_index_build_run_at` em `AGENTS.md` ou `README.md` da pasta paralela; esses campos só vivem em suas fontes autoritativas (`kb-source-metadata.md` para materialização, tabela `metadata` do SQLite para índice). Espelho declarativo em markdown envelhece silenciosamente porque nenhum wrapper o mantem coerente — exatamente o anti-padrao da regra anterior, aplicado aos demais markdowns. `AGENTS.md`/`README.md` locais devem usar ponteiros (referencias aos comandos/arquivos canonicos), nunca valores literais. O detector dessa divergencia e a linha `declarativo/timestamps` na saida de `Test-*KbSetupAudit.ps1`
- NUNCA classificar uma pasta como `bootstrap_incompleto` por ausencia de um script novo quando os scripts existentes já funcionam e a pasta tem histórico de uso real; a ausencia de script novo e caso de `modo_atualizacao`, não de bootstrap incompleto
- NUNCA confundir `bootstrap_incompleto` com `atualizacao_metodologica_pendente`: `bootstrap_incompleto` indica pasta sem camada mínima de wrappers funcionais para o fluxo adotado; `atualizacao_metodologica_pendente` indica pasta em producao cujos wrappers existentes funcionam, mas scripts adicionados pela versão atual da base metodologica ainda não foram incorporados — são casos distintos com tratamento distinto
- NUNCA assumir `modo_criacao` em pasta com histórico real, qualquer que seja o pedido do usuário
- NUNCA oferecer recriacao do zero como opção em pasta com histórico real; `modo_atualizacao` e o único caminho disponível
- NUNCA, quando o wrapper de regeneracao do índice falhar com "file not found" em um `$ValidationCasesPath` default, tratar isso como ausencia de casos de validação nem propor workarounds como passar `-ValidationCasesPath ""` ou apontar para casos de outra KB; tratar como default hardcoded quebrado no wrapper (classificação `CUSTOMIZADO`), evidenciar a divergencia ao usuário e oferecer correcao via esta skill (remover ou corrigir o default para que o parâmetro fique opcional sem valor fixo)
- NUNCA ignorar divergencia de prefixo verbal entre o nome do script local e o exemplo canonico correspondente quando o exemplo mudou de nome em relacao a versão anterior da base (ex: `Update-` → `Rebuild-`). Corrigir o conteúdo sem alinhar o nome mascara a divergencia do `Test-KbStructure` e deixa a pasta paralela com nome defasado invisivel para o gate
- NUNCA tratar declaracao de estado em `AGENTS.md` local (ex: `materializado_e_indice_validado`) como verdade absoluta quando a inspecao objetiva da pasta paralela mostrar scripts ausentes, wrappers defasados ou gate quebrado. O `AGENTS.md` e memoria auxiliar e pode estar desatualizado; a evidencia estrutural (presenca/ausencia de scripts, resultado do gate, linha `declarativo/timestamps` do setup audit) prevalece sobre declaracao de estado estatica. Ao concluir qualquer atualizacao bem-sucedida, alinhar a seção "Estado operacional" do `AGENTS.md` local ao formato de ponteiros de `examples/AGENTS.md.example` (sem timestamps literais nem espelho estatico de estado operacional); o estado canonico efetivo vem da auditoria consolidada (`Test-*KbSetupAudit.ps1` e gates específicos), não de texto fixo na memoria auxiliar.
- NUNCA deixar uma pasta paralela que adota `KbIntelligence` sem a seção `## Triagem Por Indice` no `AGENTS.md` local. A ausencia dessa seção faz com que a regra genérica "tarefa GeneXus → nexa" capture perguntas de existencia/localizacao/impacto, desviando o agente do `xpz-index-triage` e furando o gate. Tanto em `modo_criacao` quanto em `modo_atualizacao`, verificar e garantir essa seção.
- NUNCA usar no handoff final timestamp placeholder, fixo, reaproveitado de outra mensagem ou obviamente não obtido do relogio local no momento da resposta; isso invalida a conformidade formal do diagnostico.
- NUNCA classificar `Get-*KbMetadata.ps1` como `EQUIVALENTE` se `kb-source-metadata.md` contem `kb_name` ou `source_guid` em formato documentado e o wrapper retorna esses campos como ausentes; isso e falha funcional do wrapper, não ressalva informativa.
- NUNCA, no caso deterministico em que `Test-*KbMetadataWrapper.ps1` bloqueia apenas porque `kb_name` ou `source_guid` existem em tabela Markdown documentada e o wrapper local os retorna como ausentes, abrir pergunta `A/B/C/D`, enquete equivalente ou pedido de preferencia ao usuário antes de alinhar o wrapper local ao example atual e rerodar o gate.
- NUNCA declarar wrapper `.ps1` recem-criado ou reescrito como valido quando o repositório tiver `.gitattributes` com politica explicita de EOL para `*.ps1` e o arquivo salvo estiver fora desse padrão; normalizar o EOL e parte obrigatória do encerramento da criacao ou correcao do wrapper, não retrabalho posterior.
- NUNCA ignorar `INVENTORY_SHORT_NAMING` na saida de `wrappers/inventario`; cada script listado deve aparecer na tabela de 8.h como CUSTOMIZADO com ação de renome — omitir esses scripts da tabela e proibido e impede declarar `wrappers_atualizados`; quando a saida tiver duas linhas `wrappers/inventario:` separadas, processar obrigatoriamente as duas.
- NUNCA ignorar `INVENTORY_CUSTOMIZED` na saida de `wrappers/inventario`; cada script listado deve aparecer na tabela de 8.h como CUSTOMIZADO com o motivo emitido pelo inventario. Quando o motivo for `requires_version_mismatch`, alinhar `#requires -Version` ao exemplo canonico e a ação recomendada, salvo a exceção documentada de `Test-*KbPowerShellRuntime.ps1`.
- NUNCA ignorar `INVENTORY_LEGACY_ORPHANS` na saida de `wrappers/inventario`; cada arquivo legado listado deve aparecer no handoff como pendencia de limpeza com seu canonico correspondente, e a auditoria não pode declarar estado limpo enquanto o legado persistir sem decisão explicita do usuário.
- NUNCA ignorar `metadata/deploy: BLOCK` ou `metadata/deploy: PENDENTE` na saida de `Test-*KbSetupAudit.ps1`; incluir `metadata/deploy.evidencia` no handoff, perguntar nomes e diretórios de output ao usuário e rerodar `Set-*KbSourceMetadataDeployment.ps1` com `-KbEnvironmentNames` + `-KbEnvironmentOutputDirs` + validação MSBuild antes de declarar estado limpo.
- NUNCA omitir `INVENTORY_RECOMMENDED_MISSING` do handoff; mesmo sendo consultivo, ele existe para evitar que agentes sigam chamando motores compartilhados diretamente quando a própria skill já recomenda wrapper fino local para o cenário observado.
- NUNCA propor alterar campos existentes de `kb-source-metadata.md` em `modo_atualizacao` apenas para satisfazer wrapper defasado; quando um wrapper local retornar campos errados ou ausentes, corrigir o wrapper para ler o formato real do arquivo. Alteracao de metadata só entra em pauta quando pertencer a autoridade da operacao corrente (`last_setup_audit_run_at` e `setup_contract_signature_*` desta skill, campos de materialização do `xpz-sync`, ou identidade estavel em frente explicitamente aprovada de reconciliacao com a KB nativa local).
- NUNCA propor criacao de wrapper, renome de script, atualizacao de `AGENTS.md`, escrita em `kb-source-metadata.md` ou qualquer outra ação de escrita em `modo_atualizacao` antes de ter apresentado ao usuário a tabela de classificação completa de 8.h com todos os scripts esperados; a tabela e pre-requisito obrigatório da proposta de ação, não consequência dela.
- NUNCA omitir ou resumir as linhas `wrappers/inventario:` da saida de `Test-*KbSetupAudit.ps1` ao reportar ao usuário; todas as linhas devem aparecer na resposta exatamente como emitidas pelo script.
- NUNCA declarar em prosa que "todos os scripts são EQUIVALENTE", "todos os scripts estao presentes e funcionais" ou qualquer afirmacao global equivalente quando a saida de `wrappers/inventario:` contiver `INVENTORY_SHORT_NAMING`; a afirmacao global em prosa não substitui a classificação individual de 8.a.ii e invalida a tabela de 8.h — cada script SHORT_NAMING deve aparecer na tabela como CUSTOMIZADO com ação de renome, independentemente do resultado do gate ou de qualquer outra dimensao da auditoria.
- NUNCA ignorar regra irrestrita de nexa ("qualquer tarefa GeneXus → nexa") no `AGENTS.md` local sem evidenciar ao usuário o risco de carregamento desnecessario em tarefas já cobertas por skills `xpz-*` específicas e sem oferecer a correcao de escopo prevista em 8.g5.
- NUNCA encerrar auditoria mínima, PRE-CONDICAO com auditoria completa ou `auditar_setup` apenas com diagnostico quando a evidencia objetiva indicar ao menos um item corrigivel listado na seção PLANO DE CORRECOES POS-AUDITORIA; apresentar o plano consolidado e oferecer execução na mesma sessao e obrigatório
- NUNCA recomendar "rodada separada", "corrigir depois" ou equivalente como resposta-padrao a pendencias de setup corrigiveis nesta skill; adiar só quando o usuário recusar ou adiar explicitamente o plano ou itens dele
- NUNCA retomar silenciosamente a tarefa original do usuário após `GATE_OK` sem ter apresentado o plano consolidado quando houver pendencia de setup corrigivel, mesmo que a tarefa esteja liberada pelo gate
