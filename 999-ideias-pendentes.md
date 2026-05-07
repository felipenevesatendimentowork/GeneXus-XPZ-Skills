# Ideias Pendentes

## LlamaIndex / LangChain + vector store como alternativa ao indice SQLite atual

**Origem:** sugestao recebida em 2026-04-25 para exploracao futura.

### Problema concreto que motiva a ideia

Hoje o usuario GeneXus que trabalha com a pasta paralela via agente e obrigado a informar o nome exato do objeto que quer consultar. O custo de um agente varrer ate 15 mil arquivos XML do acervo em `ObjetosDaKbEmXml` sem um nome preciso e proibitivo — em tokens e em tempo. O indice SQLite mitiga isso com triagem estrutural, mas a busca continua dependendo de nome exato ou tipo conhecido.

O efeito pratico: o usuario que nao lembra o nome do objeto nao consegue explorar a KB de forma fluida; precisa saber o que procura antes de perguntar.

### Framework de orquestracao: LlamaIndex ou LangChain

Ambos resolvem o mesmo problema e suportam os mesmos vector stores (ChromaDB, Redis Stack). A escolha e de preferencia de ecossistema:

- **LlamaIndex**: especializado em indexacao e recuperacao de dados; API mais direta para RAG puro; escolha natural quando o unico objetivo e "indexar e buscar".
- **LangChain**: framework mais abrangente (agentes, chains, memoria, ferramentas, RAG); comunidade maior; util se o mesmo framework ja for usado em outras partes do projeto.

Para o caso especifico de indexar XMLs GeneXus e buscar por intencao funcional, ambos chegam no mesmo resultado.

### O que a camada vetorial resolveria

**Busca por intencao funcional**
Com embeddings vetoriais, uma pergunta como "qual procedure atualiza o saldo de estoque mensal?" localizaria o objeto correto mesmo sem o nome exato. O usuario descreveria o que precisa em linguagem natural e o agente encontraria os candidatos relevantes — invertendo a dependencia atual de nomenclatura precisa.

**Contexto recortado (chunking)**
Cada XML de objeto GeneXus pode ser extenso. Em vez de enviar o XML inteiro ao agente, o framework fatiaria em blocos logicos (`Source`, `Rules`, `Events`). A resposta usaria apenas os trechos realmente relevantes, reduzindo tokens e ruido.

**Custo de busca constante**
O vector store organiza vetores matematicamente. O custo de busca nao degrada com o crescimento do acervo.

### Opcoes de vector store

**ChromaDB**
Proposito unico, simples de instalar, disk-first por padrao. Boa opcao para comecar.

**Redis Stack**
Redis com modulo de busca vetorial (RediSearch / HNSW). Open source e gratuito. Nao tem versao nativa para Windows, mas roda sem custo via WSL2 ou Docker Desktop — ambos gratuitos e funcionais no Windows 11 Pro. Com 32 GB de RAM, o custo de memoria e irrelevante: os 15 mil XMLs da KB grande ocupam 180 MB em disco; os embeddings correspondentes ficam estimados em 200-300 MB de vetores (modelo de 1536 dimensoes, ~2,5 chunks por objeto). Redis tem vantagem em velocidade bruta por ser in-memory, e o LlamaIndex ja o suporta como backend nativo.

### Perguntas a responder antes de decidir

- Qual o custo de geracao dos embeddings para o acervo? Precisa de API externa ou modelo local funciona com qualidade suficiente?
- O ganho de descoberta por intencao compensa a complexidade de manter dois indices (SQLite estrutural + vetorial)?
- Adotar LlamaIndex/LangChain + vector store exigiria reescrever os wrappers locais (`Query-*KbIntelligence.ps1`, gate, etc.) em todas as pastas paralelas?
- O chunking por bloco logico do XML (`Source`, `Rules`, `Events`) e viavel dado o formato dos XMLs GeneXus?

## Baseline conhecido no sanity e na revisao de objeto legado

**Origem:** ideia discutida em 2026-04-29 e adiada para frente separada.

### Problema concreto que motiva a ideia

Hoje a trilha distingue bem `xmlWellFormed`, `sourceSanityStatus` e os gates minimos de `Source`, mas ainda nao expressa de forma curta e operacional a comparacao entre um delta novo e o XML oficial ja aceito do mesmo objeto.

Em objeto legado grande, isso gera ruido de decisao:

- warning antigo do baseline oficial pode ser lido como defeito novo do delta
- piora nova pode passar despercebida sob o argumento de que "o objeto ja era ruim"
- o agente pode misturar sanidade absoluta do XML com comparacao relativa contra o estado oficial anterior

### Ideia de melhoria

Adicionar, em frente separada, uma camada comparativa explicita e distinta do sanity absoluto, com saidas como:

- `same as official baseline`
- `worse than official baseline`
- `better than official baseline`
- `no official baseline compared`

Essa camada nao substituiria `xmlWellFormed`, `sourceSanityStatus` nem os gates metodologicos atuais. Ela serviria para comparar o delta com o baseline oficial quando houver XML oficial comparavel do mesmo objeto.

### Perguntas a responder antes de decidir

- O que exatamente conta como `official baseline` em cada fluxo: XML oficial atual em `ObjetosDaKbEmXml`, ultimo delta aceito, ou outro marco explicitamente documentado?
- A comparacao deve nascer primeiro como regra metodologica de handoff/revisao, ou ja como evolucao automatizada do `Test-GeneXusSourceSanity.ps1`?
- Como impedir que baseline ruim vire permissao implicita para aceitar piora nova?

## Wrapper compartilhado para auditoria de naming de `ObjetosDaKbEmXml`

**Origem:** avaliacao de sugestao de agente externo em 2026-05-01.

### Problema concreto que motiva a ideia

A verificacao de naming dos diretorios de container em `ObjetosDaKbEmXml` e executada hoje como procedimento narrado pelo agente seguindo o bloco `8.g2` da `xpz-kb-parallel-setup`. O fluxo esta bem especificado — cobre todos os diretorios sem excecao, exige leitura de pelo menos um XML por diretorio, mapeia o GUID de `Object/@type` para o nome canonico via catalogo e produz saida estruturada em tabela — mas depende de interpretacao local do agente a cada sessao.

O risco pratico nao e de ambiguidade na regra, mas de variancia entre execucoes: agentes distintos podem diferir na forma de localizar o XML, nomear as colunas da tabela ou reportar a evidencia, mesmo seguindo a mesma secao da skill.

### Ideia de melhoria

Adicionar ao motor compartilhado um script `Test-KbNamingAudit.ps1` que:

- receba como entrada o caminho de `ObjetosDaKbEmXml`
- liste todos os subdiretorios presentes
- leia pelo menos um XML por diretorio, extraia o elemento raiz ou `Object/@type`
- mapeie o GUID para o nome canonico usando o mesmo catalogo ja consumido por `Build-KbIntelligenceIndex.py`
- emita saida estruturada por diretorio com as colunas `Diretorio`, `Tipo real encontrado`, `Status` e, quando divergente, `Nome canonico esperado`
- retorne `NAMING_OK` quando todos os diretorios estiverem conformes ou `NAMING_DIVERGENTE: <lista>` quando houver inversao

O wrapper local de cada pasta paralela chamaria esse script e repassaria o resultado ao handoff, em vez de o agente executar o mapeamento inline.

### O que justificaria implementar agora vs. aguardar

O limiar de maturidade ainda nao foi atingido. O conjunto de tipos de container auditados e finito (Folder, Module, PackagedModule, Attribute) e o `8.g2.vii` ja tem criterio de parada curta bem definido. A implementacao faria sentido quando houver: (a) evidencia de handoffs superficiais recorrentes por variancia de execucao artesanal entre sessoes, ou (b) tres ou mais KBs paralelas ativas produzindo tabelas de naming inconsistentes.

### Perguntas a responder antes de decidir

- O catalogo de GUIDs em `01a-catalogo-e-padroes-empiricos.md` ja esta em formato consumivel por um script PowerShell, ou exigiria extracao adicional?
- O script deve ficar no motor compartilhado (ao lado de `Build-KbIntelligenceIndex.py`) ou como wrapper exemplo desta skill, seguindo o padrao dos `*.example.ps1`?
- A saida estruturada do script deve ser consumida diretamente pelo `Test-*KbSetupAudit.ps1` ou reportada separadamente no handoff?
- Como manter sincronia entre o catalogo de GUIDs e o mapeamento interno do script sem duplicar a fonte autoritativa?

## Rename de `kb-source-metadata.md` para `kb-parallel-state.md`

**Origem:** avaliacao de resultado de setup em 2026-05-03.

### Problema concreto que motiva a ideia

O arquivo `kb-source-metadata.md` acumula tres responsabilidades distintas: dados de envelope de importacao (blocos `KMW` e `Source` extraidos do XPZ), timestamps operacionais de materializacao (`last_xpz_materialization_run_at`) e, com a adicao de `last_setup_audit_run_at`, timestamps de auditoria de setup. O nome atual descreve apenas a primeira responsabilidade e induz leitura incorreta da funcao real do arquivo.

Nome proposto: `kb-parallel-state.md` — descreve o estado corrente da pasta paralela como um todo, independente de qual dado especifico estiver armazenado.

### Impacto do rename

Alto. O nome atual esta hardcoded em praticamente todos os wrappers locais de cada pasta paralela (`Update-*KbFromXpz.ps1`, `Get-*KbMetadata.ps1`, `Test-*KbGate.ps1`, `Test-*KbStructure.ps1`) e nos scripts do motor compartilhado (`Sync-GeneXusXpzToXml.ps1`, `Test-XpzKbMetadataWrapper.ps1` e outros). Um rename exige atualizar o motor compartilhado, todos os exemplos sanitizados da skill e cada wrapper local de cada pasta paralela existente.

### O que justificaria implementar agora vs. aguardar

Aguardar ate que haja uma frente de refatoracao maior no motor compartilhado ou nos exemplos sanitizados que justifique o custo de migracao em cascata. Nao implementar de forma isolada so por higiene de nomenclatura.

### Perguntas a responder antes de decidir

- Ha outras renomeclaturas de campo ou arquivo pendentes que pudessem ser agrupadas na mesma frente de migracao para amortizar o custo?
- O rename deve ser feito com compatibilidade retroativa (suporte temporario aos dois nomes) ou como corte limpo?

## CreateOfflineDatabase

**Origem:** avaliação de inventário de tasks MSBuild — domínio Database, 2026-05-06.

### Problema concreto que motiva a ideia

Em KBs GeneXus com aplicativos Native Mobile e `Connectivity Support = Offline` em Main Objects, o build headless do pipeline precisa gerar o banco SQLite local que será embutido no app do dispositivo. Sem `CreateOfflineDatabase` headless, essa etapa fica dependente da IDE.

### O que a task faz tecnicamente

- Registrada em `Genexus.Tasks.targets` e documentada em `3908.html` da instalação oficial.
- Parâmetro obrigatório: `OfflineObjectNames` — lista de nomes de objetos separada por `;`.
- Os objetos listados precisam ter `Connectivity Support = Offline` configurado.
- Quando um Main Object tem essa propriedade, o GeneXus cria automaticamente um objeto do tipo "Offline Database object" na KB. `CreateOfflineDatabase` gera e executa a criação do SQLite correspondente.
- **Não toca o banco de dados do servidor** (SQL Server, PostgreSQL, etc.) — cria apenas o arquivo SQLite local para o dispositivo.
- Geradores compatíveis: Android, Apple, Angular exclusivamente.

### Diferença de risco em relação às tasks de banco de servidor

Risco contido: o SQLite gerado é um artefato de app mobile, não o banco central da KB. Pode ser regenerado a qualquer momento sem impacto no servidor.

### Perguntas a responder antes de decidir

- A task `Genexus.MsBuild.Tasks.CreateOfflineDatabase` expõe `OfflineObjectNames` como propriedade pública na reflexão do assembly desta instalação?
- Em um pipeline headless de Native Mobile, `CreateOfflineDatabase` é chamada antes ou depois de `BuildAll`?
- Existe documentação ou uso empírico que mostre se a task exige gerador Android/Apple/Angular ativo no Environment, ou se opera apenas sobre o modelo da KB?
- O script adequado seria um novo `Invoke-GeneXusOfflineDb.ps1` ou uma extensão do pipeline de `xpz-msbuild-build`?

### Limiar para implementar

Implementar quando houver: (a) KB concreta com Native Mobile Offline no portfólio onde a automação headless do build seja requisito real, ou (b) solicitação explícita de cobertura desse pipeline.

## Tríade de diagnóstico de schema: WriteDatabaseSchema + WriteKnowledgeBaseSchema + CompareSchemas

**Origem:** avaliação de inventário de tasks MSBuild — domínio Database, 2026-05-06.

### Problema concreto que motiva a ideia

Quando uma KB apresenta reorgs inesperadas, erros de impacto ou comportamento anômalo após migração, o desenvolvedor precisa entender se o banco físico está em sincronia com o modelo definido pela KB. Hoje esse diagnóstico depende da IDE. As três tasks permitem fazer essa análise headless, gerando XMLs comparáveis e um arquivo de diferenças.

### Confirmação técnica

Todas as três confirmadas por reflexão do assembly e documentadas em `3908.html`:

- `WriteDatabaseSchema`: lê o banco físico real (via conexão do Environment) e grava um XML com o schema atual. Parâmetro obrigatório: `File` (String).
- `WriteKnowledgeBaseSchema`: lê o modelo da KB (sem acessar o banco) e grava um XML com o schema esperado. Parâmetros: `File` (obrigatório), `DesignModel` (Boolean — `true` = modelo de design, `false` = modelo alvo, default `false`), `SortByName` (Boolean, default `false`).
- `CompareSchemas`: compara os dois XMLs e grava as diferenças. Parâmetros: `DBFile` (obrigatório), `KBFile` (obrigatório), `DiffFile` (opcional — arquivo de saída das diferenças).

`CompareSchemas` **não exige KB aberta** — opera sobre arquivos já gerados. `WriteDatabaseSchema` e `WriteKnowledgeBaseSchema` exigem KB aberta.

### Distinção operacional importante

`WriteDatabaseSchema` conecta ao banco físico (SQL Server, LocalDB). Pode falhar se a conexão não estiver disponível no contexto headless — risco diferente de `WriteKnowledgeBaseSchema`, que opera apenas sobre o modelo da KB. Implementar os dois de forma independente, não acoplada.

### Enquadramento correto de uso

Não é um gate pré-import. Import trata de objetos GeneXus; o schema do banco é alterado por Reorg. O caso de uso real é diagnóstico de estado: "por que minha reorg falhou?", "o banco está alinhado com o que a KB espera?", "qual o impacto de uma migração recente no schema físico?"

### Perguntas a responder antes de decidir

- Um único script combinado (`Test-GeneXusSchemaSync.ps1`) que executa as três etapas em sequência é melhor do que três scripts separados?
- Onde esse script deve ficar: nova skill `xpz-msbuild-db`, ou adicionado como diagnóstico complementar na `xpz-msbuild-build`?
- `WriteDatabaseSchema` exige que o Environment tenha uma conexão de banco válida e acessível no contexto headless? Isso precisa de teste empírico.
- O `DiffFile` de `CompareSchemas` tem formato legível diretamente, ou exige parsing para ser útil ao usuário?

### Limiar para implementar

Implementar quando houver caso concreto de diagnóstico de drift DB-KB que a IDE não consiga resolver de forma conveniente, ou quando o fluxo de `Invoke-GeneXusDbImpact.ps1` precisar de contexto de schema para interpretar o script de impacto gerado.

## CheckAndInstallDatabase

**Origem:** referência encontrada em fonte externa de código como sinônimo de Reorg, avaliação de domínio Database, 2026-05-06.

### Problema concreto que motiva a ideia

A fonte externa utiliza `<CheckAndInstallDatabase />` sem parâmetros como equivalente headless da operação de Reorg, com semântica implícita de "verificar se o banco precisa de alterações e instalar somente se necessário" — o que seria mais seguro que um `Reorganize` puro, que executaria incondicionalmente.

### Achado empírico desta instalação

`Genexus.MsBuild.Tasks.CheckAndInstallDatabase` **não existe** no assembly `Genexus.MsBuild.Tasks.dll` da instalação GeneXus 18 local. A task não aparece nos `UsingTask` de `Genexus.Tasks.targets` nem na reflexão do assembly.

Hipóteses sobre a origem:
- Task definida em `Genexus.Server.Tasks.targets` (escopo de GeneXus Server — fora do escopo desta skill)
- Target MSBuild definido em algum `.targets` não inspecionado, e não uma task de DLL
- Específica de outra versão do GeneXus 18 (upgrade diferente) ou de extensão instalada
- Nome alternativo ou alias interno que mapeia para outro mecanismo

### Perguntas a responder antes de decidir

- Em qual arquivo ou assembly `CheckAndInstallDatabase` está definida nesta ou em outra instalação do GeneXus 18?
- É uma task de server (`Genexus.Server.Tasks.targets`)? Se sim, sai do escopo desta skill por definição.
- Se for um Target MSBuild (não task de DLL), quais tasks internas ele orquestra?
- O comportamento "verifica antes de executar" é real, ou o nome apenas sugere isso?

### Limiar para reavaliar

Reavaliar somente se: (a) for identificado que a task existe em caminho acessível sem GeneXus Server, e (b) a semântica "check before install" for confirmada empiricamente como diferente de `Reorganize` puro.

## DeleteObject — limpeza headless pós-import

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

A skill `xpz-msbuild-import-export` documenta explicitamente no bloco `WWP IMPORT ORDER` que `import_file` não remove objetos antigos automaticamente. A limpeza de Transactions antigas substituídas, SubtypeGroups obsoletos, PatternInstances antigas e Procedures/WebPanels gerados automaticamente é feita hoje de forma manual na IDE.

`DeleteObject` é a task MSBuild oficial que remove objetos da KB. Parâmetros documentados: `Objects` (obrigatório), `IncludeChildren` (true/false, para pastas e módulos), `FailWhenNone` (true/false). Não requer GeneXus Server e não pressupõe estrutura de Team Development.

### Posicionamento

Candidato prioritário entre as tasks do domínio de versionamento. Fecha gap concreto e documentado no fluxo atual da skill, sem exigir nova skill — caberia como extensão de `xpz-msbuild-import-export`.

### Condições antes de implementar

- Verificar empiricamente se `Genexus.MsBuild.Tasks.DeleteObject` está exposta no assembly `Genexus.MsBuild.Tasks.dll` com as propriedades documentadas (`Objects`, `IncludeChildren`, `FailWhenNone`)
- Definir gate de segurança alto: confirmação nominal por objeto (ou lista) + declaração explícita ao usuário de que não há rollback automático
- Avaliar se o usuário fornece a lista de objetos explicitamente ou se há mecanismo auxiliar para derivá-la (por comparação entre estado pré e pós-import)

### Perguntas a responder antes de decidir

- `Objects` aceita lista separada por vírgula no mesmo formato de `Export`/`Import`, ou tem sintaxe própria?
- `IncludeChildren` é seguro como default `false` ou deve ser proibido sem confirmação explícita adicional?
- O gate deve exigir confirmação por objeto individualmente ou basta confirmação da lista completa?

## CreateVersion — snapshot pré-import de baixo risco

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

Antes de uma importação de XPZ arriscada, criar uma versão frozen da KB serve como ponto de restauração. `CreateVersion` cria uma versão frozen a partir da versão ativa ou especificada. Parâmetros documentados: `VersionName` (obrigatório), `VersionDescription` (opcional), `Parent` (nome da versão pai; `*Trunk` ou nome da KB para raiz). Operação não-destrutiva: apenas cria, não altera nem remove nada.

A alternativa existente para o mesmo problema — cópia da pasta da KB (LocalDB) ou backup `.bak` via SQL Server — não exige task MSBuild, mas também não deixa rastreabilidade dentro da própria KB.

### Condições antes de implementar

- Verificar empiricamente se `CreateVersion` está exposta no assembly com os parâmetros documentados
- Avaliar se o público-alvo da skill usa estrutura de múltiplas versões — em KB local simples sem Team Development, criar versões frozen antes de cada import pode ser overhead sem benefício claro
- Se o public-alvo não usa versões, documentar `CreateVersion` como capacidade disponível mas não recomendar como passo padrão do fluxo

### Relacionamento com RevertToVersion

`CreateVersion` sozinha é de baixo risco. `RevertToVersion` como par de rollback é avaliada separadamente abaixo e depende de análise de perfil de versões da KB.

### Perguntas a responder antes de decidir

- O público-alvo desta skill usa estrutura de múltiplas versões de desenvolvimento (Team Development) ou KB local com versão única (Root)?
- `CreateVersion` com `Parent=*Trunk` cria versão diretamente de Root sem abrir fluxo de merge?

## RevertToVersion — rollback de snapshot, gate muito restritivo

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

Par com `CreateVersion` para o fluxo snapshot+rollback: se o import deu errado, reverter para a versão frozen criada antes. Parâmetro: `VersionName` (obrigatório).

### Risco crítico que bloqueia implementação imediata

A documentação oficial é explícita: `RevertToVersion` **sobrescreve a versão Root com a versão especificada**. Qualquer alteração feita na versão Root após o snapshot é perdida permanentemente. Isso é mais destrutivo que uma importação mal-sucedida.

Consequência para o fluxo XPZ: se o import foi feito diretamente na Root (cenário mais comum em KB local), `RevertToVersion` desfaz o import — mas também desfaz todo e qualquer outro trabalho feito na Root desde o snapshot. Se o import foi feito em versão de teste separada, `RevertToVersion` não desfaz aquela versão de teste — afeta Root.

### Condições antes de implementar

- Dependente de `CreateVersion` estar implementada e em uso real
- Dependente de evidência de que o público-alvo usa múltiplas versões com Root claramente separada do fluxo de trabalho cotidiano
- Gate precisa ser mais restritivo que os gates atuais de importação real: confirmação explícita + listagem das alterações que serão perdidas, se houver mecanismo para derivá-las
- Verificar empiricamente a task no assembly antes de qualquer implementação

### Perguntas a responder antes de decidir

- Há mecanismo headless para listar diferenças entre a versão Root atual e a versão frozen antes de executar o revert?
- O fluxo snapshot+rollback é mais seguro do que a alternativa já documentada (cópia da pasta da KB)?

## RestoreRevision — desfazer cirúrgico por objeto

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

`RestoreRevision` restaura um objeto específico para uma revisão específica de sua história. Parâmetros: `Object` (formato `"ObjectType:ObjectName"`), `RevisionId`. Mais cirúrgico que `RevertToVersion`: desfaz apenas o objeto indicado, sem afetar o restante da KB.

### Bloqueio atual

Para usar `RestoreRevision` é necessário saber o `RevisionId` concreto do estado anterior desejado. Não há task headless documentada para listar o histórico de revisões de um objeto. Sem esse mecanismo, o fluxo não é autônomo: o usuário precisaria obter o `RevisionId` manualmente pela IDE antes de invocar o wrapper.

### Condições antes de implementar

- Identificar task ou mecanismo headless que permita listar revisões de um objeto e seus IDs
- Sem esse mecanismo, `RestoreRevision` só seria utilizável como wrapper de conveniência para `RevisionId` já conhecido pelo usuário

### Perguntas a responder antes de decidir

- Existe task headless que liste o histórico de revisões de um objeto GeneXus?
- Se não houver, faz sentido implementar o wrapper mesmo exigindo que o usuário forneça o `RevisionId` explicitamente?

## Leitura da wiki 24612 (Team Development MSBuild Tasks)

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Motivação

A documentação offline instalada do GeneXus 18 indexa as tasks MSBuild em `3908.html`. O agente externo identificou que a wiki oficial tem página dedicada ao domínio Team Development (`id=24612`) com potencialmente mais tasks que as listadas no índice local.

As tasks avaliadas nesta frente (`CreateVersion`, `RevertToVersion`, `MergeVersions`, `RestoreRevision`, `DeleteObject`) foram analisadas com base nas informações disponíveis no prompt externo. A leitura da wiki 24612 pode revelar tasks adicionais, parâmetros não documentados na instalação local ou restrições de uso não identificadas até agora.

### Condições

- Pesquisa de inventário — não bloqueante para as decisões registradas acima
- Útil antes de qualquer implementação concreta de task deste domínio
- Não requer GeneXus Server: a wiki documenta também o uso local das tasks

### O que buscar na wiki 24612

- Tasks não listadas em `3908.html`
- Parâmetros adicionais de `CreateVersion`, `RevertToVersion`, `MergeVersions`, `RestoreRevision` e `DeleteObject`
- Restrições ou pré-condições de uso das tasks em contexto sem GeneXus Server
- Mecanismo de listagem de revisões de objetos (necessário para `RestoreRevision`)

## RestoreModule — pré-requisito de build para KBs com dependências de módulo

**Origem:** avaliação de prompt externo sobre domínio Módulos (MSBuild Tasks), 2026-05-07.
Documentação oficial confirmada em `46830.html` da instalação local. Task registrada em
`Genexus.Tasks.targets` e mapeada para `Genexus.MsBuild.Tasks.dll`.

### Problema concreto que motiva a ideia

A skill `xpz-msbuild-build` não trata o caso em que a KB tem módulos instalados (AWSCore,
AzureCore, etc.) e esses módulos precisam estar restaurados antes de o build ter sucesso. Sem
`RestoreModule`, o build falha com erro de referência não resolvida — mas o erro parece ser
do XPZ importado, não da ausência de módulo. O agente pode diagnosticar incorretamente a causa.

`RestoreModule` sem parâmetro `ModuleName` restaura a implementação de todos os módulos instalados
na KB a partir do cache local (`%USERPROFILE%\.gxmodules\.cache\`). É o equivalente de `npm install`
antes de `npm build`. Não requer GeneXus Server — funciona com o cache já populado pela IDE
ou pela instalação do GeneXus (servidor `Local`).

### Parâmetros documentados

- `ModuleName` (string, opcional): nome do módulo a restaurar. Se omitido, restaura todos.

### O que justificaria implementar agora vs. aguardar

Implementar quando houver KB concreta com módulos instalados no portfólio onde o build headless
falhe por ausência de restauração. O gate de adição ao pipeline da `xpz-msbuild-build` seria:
verificar antes do build se a KB tem módulos instalados e, em caso afirmativo, executar
`RestoreModule` automaticamente como etapa anterior ao `BuildAll`.

### Condições antes de implementar

- Verificar empiricamente se `Genexus.MsBuild.Tasks.RestoreModule` expõe `ModuleName` como
  propriedade pública no assembly desta instalação
- Confirmar que `RestoreModule` sem parâmetro opera sobre módulos referenciados pela KB aberta,
  não sobre o cache global
- Definir se deve ser etapa automática do pipeline ou gate explícito com confirmação do usuário

### Perguntas a responder antes de decidir

- `RestoreModule` sem `ModuleName` já é idempotente (não falha se não há módulos)? Ou exige
  que haja ao menos um módulo instalado?
- O cache `%USERPROFILE%\.gxmodules\.cache\` já existe numa instalação limpa com módulos
  instalados pela IDE? Ou precisa de pré-aquecimento headless?
- Qual o comportamento quando o servidor de origem do módulo não está acessível? `RestoreModule`
  falha ou usa o cache existente?

## InstallModule / UpdateModule / GetModulesServer / AddModulesServer — gestão de dependências headless

**Origem:** avaliação de prompt externo sobre domínio Módulos (MSBuild Tasks), 2026-05-07.
Documentação oficial confirmada em `46830.html` e `45933.html` da instalação local. Tasks
registradas em `Genexus.Tasks.targets`.

### Contexto

Módulos GeneXus não requerem GeneXus Server. Funcionam com três tipos de servidor:

- `Directory` — pasta local no sistema de arquivos (sem servidor de rede)
- `Nexus-Maven` / `Nexus-NuGet` — repositórios Maven ou NuGet genéricos (Nexus OSS)
- Servidores pré-configurados: `Local` (módulos da instalação GeneXus) e `Global Matrix`
  (repositório público da GeneXus, visível na IDE em "Manage Module References")

### O que cada task faz

- `InstallModule(ModuleName, Version?)` — instala módulo do servidor configurado na KB aberta
- `UpdateModule(ModuleName, Version?)` — atualiza módulo instalado para versão especificada
  ou mais recente
- `GetModulesServer` — lista servidores de módulo configurados (saída: `Servers`)
- `AddModulesServer(Type, Name, Source, Preserve?, OverwriteDefinition?, User?, Password?)` —
  registra novo servidor de módulos no ambiente headless

### Relevância para o fluxo de KB paralela

`GetModulesServer` é útil como diagnóstico: antes de um `RestoreModule` ou `InstallModule`,
confirmar quais servidores estão acessíveis no contexto headless. `AddModulesServer` com
`Type="Directory"` pode registrar um servidor local (pasta) sem acesso à rede.

`InstallModule` e `UpdateModule` abrem a possibilidade de um pipeline headless de atualização
de dependências: "instalar ou atualizar este módulo de terceiro na KB sem abrir a IDE".

### O que justificaria implementar agora vs. aguardar

Aguardar até que `RestoreModule` esteja implementado e validado. Só então avaliar se o caso
de uso de instalação/atualização headless de módulos aparece no portfólio. O cenário mais
provável de chegada não é importação de XPZ, mas setup inicial de KB de teste que precisa
das mesmas dependências de módulo que a KB de origem.

### Perguntas a responder antes de decidir

- `InstallModule` com `Version` vazio usa a versão mais recente disponível no servidor ou
  a versão especificada no arquivo de dependências da KB?
- `AddModulesServer` com `Preserve=true` persiste a configuração entre sessões MSBuild ou
  apenas para a sessão corrente?
- Em que arquivo ou estrutura o GeneXus armazena a lista de servidores configurados? É por
  KB ou por instalação?

## GetCategoryObjects — seleção de objetos por categoria para Export/Import

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Documentada no índice `3908.html` da instalação oficial.

### Problema concreto que motiva a ideia

Hoje, quando a skill `xpz-msbuild-import-export` faz export ou import com recorte, o
chamador precisa fornecer a lista de objetos explicitamente em `Objects`, `IncludeItems`
ou `ExcludeItems`. Em projetos que usam categorias GeneXus como convenção de organização
("todos os objetos da categoria `Faturamento`", "todos os da categoria `Integrações`"),
o usuário precisa enumerar os nomes manualmente ou extrair a lista de outra forma.

`GetCategoryObjects` retorna a lista de todos os objetos pertencentes a uma categoria.
O fluxo seria: chamar `GetCategoryObjects` com `CategoryName`, capturar a lista
resultante, usá-la diretamente como entrada de `Export` ou `IncludeItems` de `Import`.

### Parâmetros documentados

- `CategoryName` (obrigatório) — nome da categoria GeneXus
- Saída via `<Output TaskParameter="Objects" PropertyName="..."/>` — lista capturável
  em propriedade MSBuild nomeada pelo chamador

### Distinção importante

Categorias GeneXus são agrupamentos organizacionais criados manualmente pelo desenvolvedor
na IDE — diferentes de tipos (`Procedure`, `WebPanel`), módulos e pastas. A task opera
sobre essa classificação visual, não sobre a estrutura interna de tipos.

### Condições antes de implementar

- Verificar empiricamente se `Genexus.MsBuild.Tasks.GetCategoryObjects` está exposta no
  assembly com o parâmetro documentado
- Confirmar que o formato de saída é compatível com `IncludeItems`/`ExcludeItems` de `Import`
  sem transformação intermediária

### Perguntas a responder antes de decidir

- `Genexus.MsBuild.Tasks.GetCategoryObjects` aparece no assembly com `CategoryName`
  como propriedade pública?
- O formato de saída é lista plana de nomes de objeto no mesmo formato que `IncludeItems`
  aceita, ou exige transformação?
- O que a task retorna quando a categoria está vazia ou não existe — falha, lista vazia ou
  `exitCode` diferente?
- "Categoria" aqui corresponde exatamente ao conceito visual da IDE ou a outro agrupamento
  interno do GeneXus?

### Limiar para implementar

Implementar quando houver: (a) reflexão do assembly confirmando a task acessível com os
parâmetros documentados, e (b) caso concreto de projeto que usa categorias como convenção
de organização de objetos, tornando a seleção por categoria mais prática que a lista manual.

---

## CalculateChecksums + AreObjectsEqual — diagnóstico de integridade de objeto pré/pós-operação

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Tasks registradas em `Genexus.Tasks.targets`; **sem documentação oficial em `3908.html`**.

### Problema concreto que motiva a ideia

O fluxo de verificação pós-import hoje depende de `importedItems` (lista de o que entrou),
`exitCode` e varredura de stdout/stderr. Nenhum desses verifica se o objeto que entrou
é de fato diferente do que estava antes, nem se o objeto na KB de destino ficou idêntico
ao objeto da KB de origem. Há um gap de evidência objetiva entre "o import foi executado"
e "o objeto mudou da forma esperada".

### O que cada task faz (hipótese — sem documentação oficial confirmada)

`CalculateChecksums` — calcula checksums de um conjunto de objetos da KB. Potencial uso:
registrar o checksum dos objetos antes do import, recalcular depois, comparar para
confirmar quais mudaram e quais permaneceram inalterados.

`AreObjectsEqual` — compara dois objetos e retorna se são idênticos. Potencial uso:
comparar o estado de um objeto na KB de destino com o mesmo objeto na KB de origem,
ou comparar o estado antes e depois de uma operação dentro da mesma KB.

### Distinção entre as duas

São mecanismos complementares mas de granularidade diferente. `CalculateChecksums` opera
sobre um conjunto de objetos em lote; `AreObjectsEqual` opera sobre dois objetos
comparados par a par. Para o fluxo de verificação pós-import, `CalculateChecksums` seria
mais prático: calcula o checksum do conjunto importado antes e depois da operação.

### Risco adicional desta dupla

Diferente das tasks documentadas em `3908.html`, estas duas são registradas apenas em
`Genexus.Tasks.targets` sem documentação offline correspondente. O risco de comportamento
imprevisível ou interface não estável é maior. A investigação começa pela reflexão do
assembly antes de qualquer uso.

### Condições antes de implementar

- Verificar empiricamente se ambas estão expostas no assembly com propriedades acessíveis
- Para `CalculateChecksums`: qual é a granularidade do checksum? Objeto inteiro ou por
  part-type? A saída é capturável via `TaskOutput`/`CaptureOutput`?
- Para `AreObjectsEqual`: os dois objetos são da mesma KB aberta (dois estados) ou de
  duas KBs distintas? Como se passa o segundo objeto para comparação?

### Perguntas a responder antes de decidir

- `CalculateChecksums` e `AreObjectsEqual` aparecem no assembly com propriedades públicas
  acessíveis?
- `CalculateChecksums` opera sobre a KB aberta no contexto headless corrente ou precisa
  de parâmetro de escopo adicional?
- A saída de `CalculateChecksums` é legível e comparável entre duas execuções, ou é
  representação interna não determinística?
- `AreObjectsEqual` compara objetos da mesma KB ou permite comparar entre KBs distintas?
- O resultado de `AreObjectsEqual` é capturável programaticamente ou apenas emitido em
  stdout?

### Limiar para implementar

Implementar quando houver: (a) reflexão do assembly confirmando ambas as tasks acessíveis,
(b) formato de saída de `CalculateChecksums` legível e determinístico, e (c) caso concreto
de verificação pós-import em que a lista de `importedItems` não for evidência suficiente
de que o objeto mudou da forma esperada.

---

## CompressKB — manutenção da KB após importações de grande volume

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Arquivo `CompressKB.msbuild` confirmado como presente na instalação oficial do GeneXus 18,
idêntico em todas as instalações inspecionadas (21 linhas).

### Problema concreto que motiva a ideia

Importações de grande volume inserem e atualizam muitos registros no banco interno da KB
(SQL Server ou LocalDB). Com o tempo, o banco pode ficar fragmentado internamente. A operação
`CompressKB` abre a KB com o parâmetro `CompressData='true'` em `OpenKnowledgeBase` e a
fecha — possivelmente acionando compactação ou reorganização interna do banco da KB.

Diferente da reorg do GeneXus (que altera o banco da **aplicação**), `CompressKB` afeta
o banco **interno da KB** — o repositório de objetos, regras e metadados.

### Distinção técnica importante

`CompressData` não é uma task separada — é um parâmetro de `OpenKnowledgeBase`. O arquivo
`CompressKB.msbuild` já é o wrapper pronto entregue pela instalação oficial. A skill não
precisaria gerar um `.msbuild` dinamicamente: apenas invocaria `CompressKB.msbuild` com o
parâmetro `-p:kbLocation=<caminho>`, reusando o arquivo permanente da instalação.

### Condições antes de implementar

- Verificar empiricamente o que `CompressData='true'` faz de fato no banco interno da KB:
  compressão SQL Server (ROW/PAGE), compactação lógica interna do GeneXus ou outro mecanismo
- Verificar se é seguro executar sem confirmação interativa — a operação não importa nem
  exporta objetos, mas altera o banco interno da KB
- Medir o tempo de execução em KBs de médio e grande porte
- Verificar se há efeito colateral ao reabrir a KB na IDE depois da operação

### Perguntas a responder antes de decidir

- O que `CompressData='true'` faz exatamente no banco interno da KB? É seguro executar
  sem confirmação interativa?
- O `CompressKB.msbuild` existente aceita apenas `-p:kbLocation` ou há outros parâmetros?
- Qual o tempo de execução típico em KBs de médio porte (~5.000 objetos)?
- A KB reabre normalmente na IDE após `CompressKB`? Há warning ou efeito colateral observável?
- A operação é idempotente — executar duas vezes seguidas é seguro?

### Limiar para implementar

Implementar quando houver: (a) verificação empírica do efeito real de `CompressData='true'`
confirmando operação segura sem efeito colateral grave, e (b) caso concreto de KB com
degradação de performance pós-import que se beneficiaria da compactação.
