# KB Intelligence Scripts

## Papel do documento
guia operacional

## Escopo atual

Estes scripts implementam o indice tecnico KB Intelligence com suporte a inventario, relacoes semanticas e triagem funcional assistida por agentes.

O comando `impact-basic` resume dependentes e dependencias diretas do objeto. O comando `functional-trace-basic` monta trilha funcional inicial para perguntas curtas, mas nao produz conclusao funcional automatica.

Catalogo tecnico canonico de tipos:

- `scripts/gx-object-type-catalog.json`
- `Regra operacional`: catalogo **efetivo** = base compartilhada + `scripts/gx-object-type-catalog.override.json` na pasta paralela quando existir (override prevalece por tipo canonico); `Build-KbIntelligenceIndex.py` e `Query-KbIntelligenceIndex.py` mesclam via `scripts/GeneXusObjectTypeCatalogCore.py`, com `--parallel-kb-root` / `--catalog-override-path` (build: deteccao automatica quando `--source-root` termina em `ObjetosDaKbEmXml`; query: deteccao quando o SQLite esta em `KbIntelligence/`)
- `Regra operacional`: esse JSON e a fonte tecnica canonica para `Object/@type`, `rootKind`, pasta esperada e elegibilidade de inventario; os `.md` seguem como explicacao editorial e historica
- `Regra operacional`: `Attribute` so deve ser classificado como tipo canonico do arquivo quando a raiz real for `<Attribute ...>`; ocorrencias inline de `<Attribute>` dentro de `Transaction`, `Table` ou outros XMLs nao redefinem o tipo do objeto

### Flags `inventoryEligible` e `queryableByKbIntelligence`

- `inventoryEligible=true`: o tipo entra no inventario do indice (objeto listavel em `object-info`, `search-objects`, `list-by-type`) quando houver XML em subpasta de `ObjetosDaKbEmXml`.
- `queryableByKbIntelligence=true`: consultas semânticas do indice (`who-uses`, `what-uses`, `impact-basic`, `functional-trace-basic`) sao **aptas** para o tipo com o extrator atual — o grafo tende a refletir dependencias tecnicas reais no acervo.
- `queryableByKbIntelligence=false`: o objeto pode estar no inventario, mas **nao** usar as consultas semânticas acima como prova de impacto ou dependencia; o motor atual nao extrai relacoes desse tipo (respostas vazias parecem “sem impacto”). Preferir `object-info`, `search-objects` ou leitura pontual do XML. Lista canônica: cada entrada em `scripts/gx-object-type-catalog.json` (amostra multi-KB: `scripts/Invoke-ParallelKbEnvelopeScan.ps1`; grafo zero: consulta a `kb-intelligence.sqlite`).
- `Query-KbIntelligenceIndex.py` recusa `who-uses`, `what-uses`, `impact-basic` e `functional-trace-basic` quando o tipo tem `queryableByKbIntelligence=false` no **catalogo efetivo** (base + override): JSON com `blocked=true`, `reason=QUERY_NOT_SEMANTIC_FOR_TYPE`, exit `11`. Wrappers devem repassar `-ParallelKbRoot` / `-CatalogOverridePath` como no build.

### Tipos com grafo assimétrico (`queryableByKbIntelligence=true`)

Estes tipos **permanecem** aptos a consultas semânticas; o grafo pode ser só de saída, só de entrada ou esparso — **nao** reclassificar como `false` só porque `incoming_relations=0` ou `outgoing_relations=0` em um lado.

| Tipo | Comportamento típico no índice atual | Uso de `impact-basic` |
| --- | --- | --- |
| `API` | Quase sempre **origem** (chamadas em `Source`); raramente destino | Informa o que o API dispara |
| `DataSelector` | Idem `API`, volume menor | Idem |
| `WorkWithForWeb` | Forte **origem** (actions, links, transação); quase nunca `target_type` WorkWith | Informa dependências que o WW referencia |
| `ExternalObject` | Pode receber entrada via `ATTCUSTOMTYPE` resolvido; esparsa por KB | `who-uses` pode achar referências; grafo vazio em KB pequena nao prova ausência global |

Nao confundir com tipos `false` (ex.: `Image`, `Theme`, `SubTypeGroup`), em que o extrator **nunca** cria arestas para esse `target_type`.

Escopo de inventario atual:

- todos os tipos marcados como `inventoryEligible=true` no catalogo tecnico e presentes com XML em subpastas imediatas de `ObjetosDaKbEmXml`

Escopo de extracao de relacoes atual:

- origens por `Source` efetivo: `Procedure`, `WebPanel`, `DataProvider`, `Transaction`, `API` e `DataSelector`
- destinos por `Source` efetivo: `Procedure`, `WebPanel` e `DataProvider`
- a varredura de `Source` cobre tambem `Source` serializado em XML estruturado (ex: `<Property><Name>ControlWhere</Name><Value>procXxx(...)</Value></Property>` em layouts de WebPanel), nao apenas `Source` em CDATA com codigo GeneXus livre
- criacao de WebComponent em `Source` efetivo: `Procedure`, `WebPanel`, `DataProvider`, `Transaction`, `API` e `DataSelector` para `WebPanel` a partir de `<WebPanel>.Create(...)`, quando o alvo existir no inventario local de `WebPanel`
- origem por action: `WorkWithForWeb`
- destino por action: `Procedure` ou `WebPanel`
- vinculacao explicita: `WorkWithForWeb` para `Transaction`
- link explicito: `WorkWithForWeb` para `WebPanel`
- prompt explicito: `WorkWithForWeb` para `WebPanel`
- condicao explicita: `WorkWithForWeb` para `Procedure`
- atributo de condicao: `WorkWithForWeb` para `Procedure`
- alvo literal por propriedade: `CustomType:<valor>` a partir de `ATTCUSTOMTYPE`
- alvo resolvido por propriedade: `SDT`, `Domain` ou `ExternalObject` a partir de `ATTCUSTOMTYPE`, quando o objeto existir no inventario e a regra aprovada resolver o prefixo com seguranca
- origem atual de `ATTCUSTOMTYPE` indexado: `Procedure`, `WebPanel`, `DataProvider`, `API`, `DataSelector`, `Domain`, `SDT`, `WorkWithForWeb` e `Transaction`
- dominio base de atributo: `Attribute` para `Domain` a partir de `idBasedOn`, quando o dominio existir no inventario local
- atributo estrutural de transacao: `Transaction` para `Attribute` a partir de `<Level>/<Attribute>`, quando o atributo existir no inventario local
- tabela estrutural de transacao: `Transaction` para `Table` a partir de `Type` em `<Level>`, quando a tabela existir no inventario local
- atributo chave de tabela: `Table` para `Attribute` a partir de `<Key>/<Item>`, quando o atributo existir no inventario local
- atributo membro de indice de tabela: `Table` para `Attribute` a partir de `<Index>/<Part>/<Members>/<Member>`, quando o atributo existir no inventario local
- tipo de item de SDT: `SDT` para `SDT` a partir de `ATTCUSTOMTYPE` em `<Item>`, quando o valor tiver prefixo `sdt:` e o SDT existir no inventario local
- tabela navegada explicitamente: `Procedure` e `WebPanel` para `Table` a partir de `for each <Nome>` em `Source` efetivo, quando a tabela existir no inventario local
- prefixo de tabela em navegacao qualificada: `Procedure` e `WebPanel` para `Table` a partir de `for each <Nome>.<Membro>` em `Source` efetivo, quando `<Nome>` existir como tabela no inventario local
- carga de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Load(...)` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- persistencia de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Save()` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- exclusao de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Delete()` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- validacao de Business Component: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Check()` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local
- insercao/atualizacao de Business Component simples: `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de `&Variavel.Insert()` ou `&Variavel.Update()` em `Source` efetivo, quando a variavel tiver `ATTCUSTOMTYPE` `bc:<Transaction>` resolvido no inventario local e nao tiver `AttCollection=True`
- relacoes: chamadas diretas em `Source efetivo`, criacao de WebComponent por `<WebPanel>.Create(...)`, actions `gxobject` resolvidas, vinculacoes explicitas de `Transaction`, links e prompts explicitos de `WebPanel` em `WorkWithForWeb`, condicoes por tag e atributo de `WorkWithForWeb` chamando `Procedure`, propriedades `ATTCUSTOMTYPE`, `idBasedOn` de `Attribute`, atributos e tabelas estruturais de `Transaction`, atributos chave e membros de indice de `Table`, tipos internos resolvidos de `SDT`, tabelas declaradas em `for each` explicito, prefixos de tabela em `for each` qualificado e chamadas `.Load(...)`/`.Save()`/`.Delete()`/`.Check()`/`.Insert()`/`.Update()` de BC resolvidas para `Transaction`
- artefato principal: SQLite derivado

A extracao basica cobre `DataProvider` como origem e como destino de chamada direta, `<WebPanel>.Create(...)` em `Source` efetivo, actions de `WorkWithForWeb` com `gxobject` resolvido para `Procedure` ou `WebPanel`, vinculacao explicita de `WorkWithForWeb` para `Transaction`, links e prompts explicitos de `WorkWithForWeb` para `WebPanel`, condicoes por tag e atributo de `WorkWithForWeb` chamando `Procedure`, e `ATTCUSTOMTYPE` como `CustomType` literal. Ela nao cobre semantica completa de `Transaction`, semantica de `WorkWithForWeb` alem dos recortes ja cobertos. A extracao semantica ampliou `for each`, `.Load(...)` e resolucao de `CustomType` para `SDT`, `Domain` e `ExternalObject`.

Eles nao substituem o acervo XML em `ObjetosDaKbEmXml` e nao provam comportamento runtime.

## Pre-requisito Python

- rebuild do indice exige **Python 3.x utilizavel** no `PATH` (resolucao em `scripts/GeneXusPythonPrerequisite.ps1`, chamado por `Build-KbIntelligenceIndex.ps1`)
- stub `WindowsApps` da Microsoft Store nao conta; ausencia retorna exit `8` com mensagem `PREREQUISITO AUSENTE`
- falha do motor Python propaga stderr/saida capturada no `throw` do wrapper PowerShell

## Gerar indice

```powershell
.\scripts\Build-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-extraction-basic.json" `
  -FailOnValidationFailure
```

Para outra KB, troque `-SourceRoot`, `-OutputPath` e, se aplicavel, `-ValidationCasesPath`.

Para validar extracao estendida em `KBExemplo`, use:

```powershell
.\scripts\Build-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-extraction-extended.json" `
  -FailOnValidationFailure
```

O local operacional padrao dentro da pasta paralela da KB e `KbIntelligence\kb-intelligence.sqlite`. Este banco e derivado e regeneravel; a fonte normativa continua sendo `ObjetosDaKbEmXml`.

## Frescor operacional do indice

O indice so deve ser usado para triagem ampla quando estiver em dia com a ultima materializacao XPZ/XML do acervo oficial.

- `last_xpz_materialization_run_at` fica no `kb-source-metadata.md` da raiz da pasta paralela da KB
- `last_index_build_run_at` fica na tabela `metadata` de `KbIntelligence\kb-intelligence.sqlite`
- `last_index_build_run_at` tambem e espelhado em `KbIntelligence\kb-intelligence-validation.json` quando o relatorio de validacao e gerado
- `inventory_validation_status` fica na tabela `metadata` do SQLite e deve estar `OK`
- `generated_at` nao faz mais parte do contrato operacional do indice; se aparecer em artefato antigo, trate esse indice como legado/incompativel e regenere
- todo processamento bem-sucedido de `XPZ` exportado pela IDE que materialize ou atualize XMLs em `ObjetosDaKbEmXml` deve chamar a regeneracao/validacao do indice logo depois
- se `last_index_build_run_at >= last_xpz_materialization_run_at`, `inventory_validation_status=OK` e `extractor_signature_version`/`extractor_signature_hash` na metadata coincidirem com o motor atual em `scripts/Build-KbIntelligenceIndex.py` (via `scripts/GeneXusKbIntelligenceExtractorContract.ps1`), o indice esta apto para triagem inicial
- ausencia de `extractor_signature_version` ou `extractor_signature_hash` na metadata, ou divergencia em relacao ao motor compartilhado, significa indice gerado por extrator antigo mesmo quando os timestamps parecem frescos — `Test-*KbIndexGate.ps1` bloqueia com `BLOCK:` e a resposta correta e rebuild do indice
- se o indice estiver ausente, sem metadado, mais antigo que a ultima materializacao ou se `kb-source-metadata.md` nao expuser literalmente `last_xpz_materialization_run_at`, o agente nao deve consultar o acervo oficial de objetos para responder pergunta de negocio, nem por varredura ampla nem por caminho pontual deduzido, e tambem nao deve gerar objetos para importacao na KB pela IDE
- se `inventory_validation_status` estiver ausente, `BLOCK` ou diferente de `OK`, tratar o indice como semanticamente incompativel com o snapshot oficial e oferecer rebuild/atualizacao antes da triagem ampla
- nesse estado defasado, o agente deve tratar a situacao como excecao operacional, oferecer regeneracao/validacao do indice ao usuario e nao seguir para varredura ampla, triagem substantiva, caminho pontual deduzido, leitura de XML oficial de objeto ou geracao
- leitura pontual com gate bloqueado so deve ocorrer para diagnostico minimo da incompatibilidade em documentacao local, estrutura, wrappers e metadados operacionais; nao montar, testar existencia, listar ou abrir caminho de XML oficial de objeto como fallback para responder pergunta de negocio
- o gate deve ser sequencial e atomico; nao testar caminho filho antes da camada pai, por exemplo `KbIntelligence\kb-intelligence.sqlite` antes de `KbIntelligence`
- se o wrapper local documentado de consulta do indice estiver ausente, nao listar `scripts` nem procurar wrappers alternativos, backups ou nomes parecidos; tratar como defasagem da pasta paralela e oferecer atualizacao via setup
- nao substituir `last_xpz_materialization_run_at` por data do arquivo, `updated`, `generated_at`, `source_xpz`, data de relatorio ou outro metadado aproximado

Para ler os metadados do indice pelo wrapper:

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query index-metadata `
  -Format text
```

Se `index-metadata` falhar, retornar vazio ou nao expor `last_index_build_run_at` ou `inventory_validation_status`, trate o indice como legado/incompativel ou sem metadado valido. Nao siga para triagem substantiva, pesquisa ampla, caminho pontual deduzido em `ObjetosDaKbEmXml`, leitura de XML oficial de objeto ou geracao de objetos; ofereca regeneracao/validacao do indice ao usuario.

Quando a validacao do indice for parte relevante da resposta ou handoff, registre a decisao de forma curta. Em caso apto, informe `last_index_build_run_at >= last_xpz_materialization_run_at`, `inventory_validation_status=OK` e assinatura do extrator alinhada; em caso bloqueado, informe o campo/capacidade ausente, qual timestamp ficou defasado, assinatura do extrator ausente/defasada ou qual incompatibilidade semantica de inventario foi detectada.

## Assinatura do extrator (`extractor_signature_*`)

O motor `Build-KbIntelligenceIndex.py` grava na tabela `metadata`:

- `extractor_signature_version` — incrementada quando a cobertura ou regras do indexador mudam de forma material
- `extractor_signature_hash` — SHA-256 dos bytes do proprio `Build-KbIntelligenceIndex.py` usado no build

Contrato compartilhado: `scripts/GeneXusKbIntelligenceExtractorContract.ps1`. Verificacao: `scripts/Test-GeneXusKbIntelligenceExtractorSignatureSelfTest.ps1` (sentinela `KB_INTELLIGENCE_EXTRACTOR_SIGNATURE_SELFTEST_OK`).

O gate `Test-*KbIndexGate.ps1` (molde em `xpz-kb-parallel-setup/examples/Test-KbIndexGate.example.ps1`) compara a metadata do indice com o motor do repositorio ativo. Indices antigos sem esses campos passam no teste de timestamp mas falham neste passo — comportamento esperado apos evolucoes como ampliacao de `INDEXED_SOURCE_TYPES`.

## Schema e versionamento

O indice armazena `schema_version` na tabela `metadata`. O valor atual e `"1"`.

O design e deliberado: o indice e artefato derivado e sempre regeneravel. Por isso nao existe caminho de migracao de schema — qualquer mudanca estrutural no motor exige rebuild completo.

Consequencias operacionais:

- todo indice gerado antes da introducao de `schema_version` e tratado automaticamente como incompativel e bloqueia qualquer consulta com mensagem explicita de rebuild
- quando o motor evoluir para schema `"2"`, todo indice `"1"` bloqueia da mesma forma — comportamento esperado, nao bug
- o erro de schema version e detectado pelo proprio `Query-KbIntelligenceIndex.py` antes de qualquer query, incluindo `index-metadata`; portanto o gate `Test-*KbIndexGate.ps1` tambem falha com `BLOCK:` em indices incompativeis
- a resposta correta a qualquer bloqueio por schema e rebuild via `Build-KbIntelligenceIndex.ps1`, nunca contorno por leitura direta do SQLite ou dos XMLs

## Triagem exploratoria no PowerShell

Use consultas curtas e auditaveis quando precisar medir massa de padrao antes de propor novo incremento. Em Windows, prefira etapas pequenas a um one-liner longo.

Ordem sugerida de triagem:

1. contar ocorrencias brutas
2. agrupar por valor ou prefixo relevante
3. abrir amostra curta de casos reais positivos e negativos
4. medir quantos casos realmente resolvem contra o inventario local

Se um agrupamento ou regex retornar zero de forma inesperada, nao concluir ausencia de sinal de imediato. Primeiro abra uma ocorrencia real no XML da KB para conferir o formato efetivo da propriedade e so depois ajuste o extrator.

Depois de separar por prefixo, nao tratar prefixo promissor como relacao resolvida. Antes de propor incremento, medir quantos casos daquele prefixo realmente apontam para objeto existente no inventario local. Prefixos textual ou semanticamente proximos, como `exo:` e `ext:`, podem ter comportamentos metodologicos diferentes e nao devem ser fundidos por intuicao.

Contar ocorrencias textuais de `ATTCUSTOMTYPE` no acervo:

```powershell
Get-ChildItem -Path "C:\KB\KBExemplo\ObjetosDaKbEmXml" -Recurse -File |
  Select-String -Pattern 'ATTCUSTOMTYPE' |
  Measure-Object
```

Agrupar valores de `ATTCUSTOMTYPE` por prefixo observavel:

```powershell
Get-ChildItem -Path "C:\KB\KBExemplo\ObjetosDaKbEmXml" -Recurse -File |
  Select-String -Pattern 'ATTCUSTOMTYPE="([^"]+)"' -AllMatches |
  ForEach-Object { $_.Matches } |
  ForEach-Object { ($_.Groups[1].Value -split ':', 2)[0].ToLower() } |
  Group-Object |
  Sort-Object Count -Descending
```

Abrir amostra curta de valores reais antes de decidir contrato:

```powershell
Get-ChildItem -Path "C:\KB\KBExemplo\ObjetosDaKbEmXml" -Recurse -File |
  Select-String -Pattern 'ATTCUSTOMTYPE="([^"]+)"' -AllMatches |
  ForEach-Object { $_.Matches } |
  ForEach-Object { $_.Groups[1].Value } |
  Select-Object -First 30
```

Evitar:

- one-liner longo com muitas interpolacoes, `:` e subexpressoes na mesma linha
- decidir incremento novo apenas por ocorrencia textual bruta
- pular da contagem direta para alteracao de contrato sem amostra real

## Buscar objetos por nome

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query search-objects `
  -ObjectName "*PlanilhaVolume*" `
  -Limit 10 `
  -Format text
```

## Localizar um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query object-info `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Format text
```

## Consultar atributo e gravabilidade transacional

Para consulta leve de atributo, sem varrer XMLs em massa:

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query attribute-info `
  -ObjectName ClienteTotal `
  -Format text
```

Para listar atributos de uma Transaction com sinais basicos de gravabilidade:

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query transaction-writable-attributes `
  -ObjectName Cliente `
  -Format text
```

Essa consulta usa o indice para localizar a `Transaction` e os `Attribute` pontuais. Ela cobre sinais leves (`key`, `isRedundant`, `Formula`, atributo ausente). Para classificacao completa de subtipo e FK recursiva antes de gerar atribuicoes, use `Test-GeneXusTransactionWritability.ps1` ou `Test-GeneXusNewWritableTargets.ps1`.

As consultas `attribute-info`, `transaction-attributes` e `transaction-writable-attributes` dependem do `source_root` gravado no `index-metadata` e leem no disco os XMLs apontados pelo indice. Se o snapshot materializado foi movido, apagado ou regenerado fora desse caminho, a consulta pode falhar com `Indexed XML file not found`; nesse caso, restaurar o snapshot no caminho esperado ou regenerar o indice a partir do `ObjetosDaKbEmXml` atual antes de repetir a consulta.

## Validar consultas leves de atributo e gravabilidade

Depois de gerar ou localizar um indice SQLite com `source_root` valido e snapshot materializado no caminho esperado, valide `attribute-info`, `transaction-attributes` e `transaction-writable-attributes` com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-queries-writability.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation-queries-writability.json" `
  -FailOnValidationFailure
```

Esses casos conferem dispatch, inexistencia e leitura file-backed pontual. Eles nao substituem `Test-GeneXusTransactionWritability.ps1` nem `Test-GeneXusNewWritableTargets.ps1` para classificacao completa antes de gerar atribuicoes.

Como esses casos validam consultas e trazem `query`, eles pertencem ao executor `Test-KbIntelligenceQueries.ps1`, nao ao fluxo de regeneracao via `Build-KbIntelligenceIndex.ps1`.

## Consultar quem usa um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query who-uses `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Limit 10 `
  -Format text
```

## Consultar o que um objeto usa

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query what-uses `
  -ObjectType WebPanel `
  -ObjectName wpRelatoriosDeMovimentosDeVolumes `
  -Limit 10 `
  -Format text
```

## Consultar evidencia

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query show-evidence `
  -SourceType WebPanel `
  -SourceName wpRelatoriosDeMovimentosDeVolumes `
  -TargetType Procedure `
  -TargetName procPlanilhaVolumeMovimento `
  -Format text
```

## Triagem de impacto basico

O comando `impact-basic` resume dependentes diretos e dependencias diretas do objeto, ainda sem alterar o escopo de extracao.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query impact-basic `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Limit 10 `
  -Format text
```

Para auditar uma relacao especifica retornada por `impact-basic`, use `show-evidence`.

Essa consulta representa impacto tecnico direto baseado no indice. Ela nao prova impacto runtime completo.

## Triagem funcional basica

O comando `functional-trace-basic` monta uma trilha inicial para perguntas funcionais curtas:

- localiza o objeto principal
- combina dependentes e dependencias diretas
- prioriza objetos resolvidos e locais antes de literais `CustomType`
- oculta literais `CustomType` redundantes quando houver relacao resolvida equivalente na mesma linha
- indica XMLs oficiais que o agente deve abrir
- devolve trilha estruturada para resposta funcional curta

Ele nao abre XML automaticamente, nao interpreta regra de negocio e nao substitui a leitura do XML oficial.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query functional-trace-basic `
  -ObjectType Procedure `
  -ObjectName procAjustaCompraGadoIdDeAnimais `
  -Limit 20 `
  -Format text
```

## Validar consultas de impacto basico

Depois de gerar ou localizar um indice SQLite, valide o comportamento operacional de `impact-basic` com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-queries-impact.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation-queries-impact.json" `
  -FailOnValidationFailure
```

Esses casos conferem comportamento de consulta. Eles nao regeneram o indice nem substituem as baterias de extracao.

Escolha o executor pelo formato do caso. Casos com campo `query` pertencem a validacao de consultas; casos com `source`, `target` e `expected_rule` pertencem a validacao de extracao/geracao.

## Cuidado com validacoes SQLite no Windows

Depois de gerar um SQLite temporario novo, prefira executar validacoes em sequencia contra esse arquivo. Evite rodar validacoes paralelas contra o mesmo banco recem-gerado.

Se houver necessidade real de paralelizar, use copias temporarias independentes do SQLite para cada validacao.

Falhas transitorias de acesso, lock ou tabela ainda nao visivel no Windows devem ser reexecutadas primeiro em sequencia antes de serem tratadas como falha real de contrato ou regressao do indice.

## Validar inventario ampliado de tipos

Depois de regenerar o indice, valide a presenca de tipos ampliados com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-inventory-extended.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation-inventory-extended.json" `
  -FailOnValidationFailure
```

Esses casos conferem inventario de objetos e comportamento conservador de `impact-basic` para tipos sem relacoes extraidas.

Cobertura minima adicional recomendada para evitar falso verde de inventario:

- pelo menos um caso positivo de `Transaction` em `object-info`
- um caso de tipo com envelope proprio, como `Attribute`
- um caso de tipo recentemente acrescentado ao catalogo, quando houver

## Validar relacoes semanticas

Depois de regenerar o indice, valide a resolucao semantica aprovada com:

```powershell
.\scripts\Build-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-extraction-semantic.json" `
  -FailOnValidationFailure
```

Esses casos conferem relacoes semanticas. Eles devem ser executados junto com as baterias de extracao quando houver rodada oficial.

Para validar especificamente a extracao de criacao de WebComponent por `<WebPanel>.Create(...)`, use a bateria dedicada da KB paralela que tiver esse caso real. Exemplo em FabricaBrasil:

```powershell
.\scripts\Build-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-fabricabrasil-webcomponent-create.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-fabricabrasil-webcomponent-create-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.validation-extraction-webcomponent-create.json" `
  -FailOnValidationFailure
```

Essa bateria cobre `webpanel_dot_create` e deve ser tratada como validacao de extracao/geracao, nao como validacao de consulta.

Esses casos usam `source`, `target` e `expected_rule`, entao devem rodar no gerador/indexador. Se forem enviados por engano para `Test-KbIntelligenceQueries.ps1`, o resultado deve ser tratado primeiro como executor incompativel, nao como regressao real da regra.

## Validar triagem funcional basica

Depois de localizar ou regenerar o indice canonico, valide `functional-trace-basic` com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.validation-queries-functional-trace.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation-queries-functional-trace.json" `
  -FailOnValidationFailure
```

Esses casos conferem apenas a montagem da trilha funcional basica. Eles nao provam comportamento runtime nem substituem leitura do XML oficial.

Como esses casos validam consultas e trazem `query`, eles pertencem ao executor `Test-KbIntelligenceQueries.ps1`, nao ao fluxo de regeneracao via `Build-KbIntelligenceIndex.ps1`.

### Amostra de envelope XML (Properties vs Part)

- `scripts/Invoke-ParallelKbEnvelopeScan.ps1`: varre pastas paralelas com `ObjetosDaKbEmXml` sob `C:\Dev\Test` e `C:\Dev\Prod` (ou `-KbRoots` explicitos) e classifica amostra por tipo (`only_properties_in_sample`, `has_part_in_sample`, `absent`). Uso tipico antes de alterar `queryableByKbIntelligence` no catalogo.

## Saidas

- `json`: formato padrao para consumo por agentes e automacoes
- `text`: formato curto para leitura rapida em conversa ou terminal

## Regras de uso por agente

- consultar por `tipo + nome`, nunca apenas nome
- procurar primeiro por `KbIntelligence\kb-intelligence.sqlite` na pasta paralela da KB
- ignorar pastas `ArquivoMorto`, salvo pedido explicito do usuario para analise historica
- tratar o SQLite como derivado e regeneravel
- manter o XML oficial como fonte normativa
- antes de alterar objeto GeneXus coberto pelo indice, executar `impact-basic` apenas quando o tipo tiver `queryableByKbIntelligence=true`; para tipos com flag `false`, usar `object-info` e leitura XML (o query semantico retorna exit `11`)
- tratar `impact-basic` como impacto tecnico direto, nao como prova funcional completa
- para perguntas funcionais curtas, `functional-trace-basic` pode reduzir a coleta inicial, mas a resposta final ainda deve separar `Evidencia direta`, `Leitura adicional do XML`, `Inferencia forte` e `Hipotese`
- usar a linha e o `snippet` apenas como evidencia tecnica, nao como prova funcional completa
- quando a mudanca exigir semantica GeneXus, abrir o XML e revisar o `Source` efetivo
