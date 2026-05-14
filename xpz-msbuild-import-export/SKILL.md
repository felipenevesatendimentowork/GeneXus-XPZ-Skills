---
name: xpz-msbuild-import-export
description: Skill para importação e exportação de XPZ via MSBuild, com execução sem interface gráfica, parâmetros explícitos, rastreabilidade e gates (pontos de liberação ou bloqueio) de segurança
---

# xpz-msbuild-import-export

Skill para operações de importação e exportação de `XPZ` do GeneXus por `MSBuild`, em execução sem interface gráfica.

Esta skill não substitui o fluxo oficial atual da trilha paralela da KB, não depende de `GeneXus Server` e não trata sucesso operacional como evidência suficiente de sucesso funcional.

No estado atual, o mecanismo central desta skill já foi validado operacionalmente em múltiplas KBs. O próximo passo desta frente não é mais provar exportação, `PreviewMode` e importação real como capacidade basal, e sim deixar explícitos:

- o que conta como prontidão operacional estável
- quais limites conhecidos ainda exigem uso controlado
- como classificar exceções sem confundi-las com defeito central do wrapper

Exceções já mapeadas que a skill deve tratar explicitamente:

- conteúdo inconsistente da KB/`XPZ`, como `KB_Teste_A`
- validação funcional incompleta por `GeneXus Server` ou licença, como `KB_Teste_E`
- execução longa em KB grande, como `KB_Teste_Grande_A`
- warning estrutural por extensão ausente, como `WebPanelDesigner`/`K2B Object Designer`

Critério atual de prontidão operacional desta skill:

- probe (sondagem técnica inicial), abertura headless, exportação, `PreviewMode` e importação real já validados em KBs de teste controladas
- classificação explícita entre sucesso operacional, validação funcional incompleta e problema de conteúdo da KB/`XPZ`
- logs, artefatos e parâmetros sensíveis rastreáveis
- limites conhecidos já documentados e não tratados como surpresa operacional

Uso mais amplo desta skill ainda depende de:

- critério estável para KBs com dependência externa, licença ou extensão ausente
- interpretação madura de execução longa em KB grande
- confiança suficiente para uso fora de ambiente de experimento controlado

---

## GUIDELINE

Orquestre operações de `XPZ` via `MSBuild` com parâmetros explícitos, coleta rastreável de evidências e aborto seguro antes de operações sensíveis. Priorize descoberta de ambiente, `PreviewMode`, `UpdateFile` quando suportado pela task carregada, `IncludeItems`/`ExcludeItems` para recortes controlados e validação posterior. Nunca trate importação real como padrão.

## PATH RESOLUTION

- Este `SKILL.md` fica em uma subpasta de skill sob a raiz do repositório.
- Resolva referências `../arquivo.md` relativas à pasta desta skill, não ao diretório corrente.
- Se a skill estiver publicada por symlink, junction ou outro reparse point, resolva primeiro a pasta real da skill e só então interprete referências relativas como `../arquivo.md`.
- Na prática, `../` aponta para a base metodológica compartilhada da raiz.

---

## TRIGGERS

Use esta skill para:
- planejar ou executar validação de ambiente para GeneXus via `MSBuild`
- abrir a `Knowledge Base` por `OpenKnowledgeBase`
- confirmar versão ativa e `Environment` ativo
- executar preview de importação com `PreviewMode`
- gerar `UpdateFile`, quando suportado pela task carregada, para análise prévia de impacto
- exportar `XPZ` com parâmetros explícitos
- importar `XPZ` apenas em fase explicitamente autorizada de teste controlado
- classificar resultado em sucesso operacional versus confirmação funcional pendente
- inspecionar propriedades da KB, Version, Environment, Generator, DataStore ou Object
  para diagnóstico pré-operação via `Get*Property`

Do NOT use esta skill para:
- substituir o fluxo oficial atual da trilha paralela da KB
- cenários que dependam de `GeneXus Server` como requisito operacional
- KB de produção ou homologação compartilhada sem janela clara para experimento
- inferir silenciosamente `KbPath`, versão, `Environment` ou parâmetros sensíveis
- afirmar sucesso funcional apenas porque a chamada via `MSBuild` terminou sem erro

---

## RESPONSIBILITIES

- Usar [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md) como base principal desta frente
- Validar explicitamente `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory`, `LogPath` e `Genexus.Tasks.targets`
- Tratar `Test-GeneXusMsBuildSetup.ps1` como probe (sondagem técnica inicial) não invasivo, anterior a qualquer abertura de KB
- Tratar `C:\Program Files (x86)` como estritamente somente leitura
- Garantir que logs, temporários, `.msbuild` e artefatos sejam gerados fora de `C:\Program Files (x86)`
- Permitir auto-criação apenas do `WorkingDirectory` explicitamente informado, depois de validado como seguro e fora das áreas proibidas
- Preferir `Temp` como destino de artefatos efêmeros de execução e manter `scripts` como pasta de wrappers permanentes
- Distinguir claramente:
  - sucesso operacional da chamada
  - efeito funcional observado depois no GeneXus
- Classificar explicitamente quando a rodada for `ensaio metodológico/experimental`, especialmente em casos de serialização, roundtrip controlado, prova de wrapper, prova de envelope, exportação headless, `PreviewMode` ou importação de teste sem validação funcional posterior
- Em `ensaio metodológico/experimental`, não narrar o resultado como mudança funcional validada; limitar a conclusão ao que a evidência realmente cobriu
- Quando a estratégia segura exigir mais de uma fase, tratar cada rodada como incremento controlado e validar build/import antes da fase seguinte
- Sucesso operacional de uma fase não autoriza recompor automaticamente pacote acumulado para a fase seguinte; a próxima rodada deve preferir o delta novo ainda não validado
- Exigir que o probe (sondagem técnica inicial) devolva diagnóstico estruturado com `status`, `summary`, `resolvedPaths`, `checks`, `blockingReasons`, `warnings` e `strategyTrace`
- Preferir `JSON` como formato canônico inicial desse diagnóstico
- Registrar `stdoutSignals` (campos semânticos por domínio), `stderrContent`, `stderrFilteredNoise`, `exitCode`, caminho do `.msbuild` temporário e caminho do log
- Validar a assinatura efetiva do wrapper e da task antes de assumir formato de parâmetro sensível de exportação ou importação
- Em exportação full da KB, preferir o atalho ergonômico `-FullExport` do wrapper local quando ele existir; manter `ExportAll='true'` apenas como compatibilidade com contratos antigos
- Privilegiar `PreviewMode` e, quando suportado pela task carregada, `UpdateFile` antes de importação real
- Distinguir explicitamente `operação na KB` de `atualização do acervo oficial`
- Sucesso de preview ou importação não autoriza atualização manual de `ObjetosDaKbEmXml`
- Quando houver retorno oficial da KB em `XPZ`, a atualização de `ObjetosDaKbEmXml` deve ocorrer depois, pelo fluxo de `xpz-sync`
- Tratar `ImportKBInformation`, `UpdateFile` e defaults internos de importação/exportação como sensíveis e dependentes da assinatura efetiva da task `Import`
- Normalizar recortes multiplos de `IncludeItems` e `ExcludeItems` como lista antes de serializar para a task carregada
- Preservar `importedItems` como lista em qualquer diagnóstico JSON, mesmo quando houver apenas um item
- Declarar `importação real efetiva provada` apenas quando `importedItems` contiver explicitamente o objeto esperado; `exitCode=0` com `importedItems` ausente ou vazio classifica como `sucesso operacional sem prova de import efetivo` — nunca como import concluído
- Quando o `Invoke-GeneXusXpzImport.ps1` lançar exceção interna durante o pós-processamento (ex: `Exception calling Join`, falha de serialização do `import.json`, qualquer falha posterior à conclusão da task `Import` do MSBuild) mas o log bruto (`msbuild.stdout.log` ou stdout capturado) contiver `__IMPORTED_ITEM__` ou marca equivalente para o objeto esperado, classificar como `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)` — nunca como `falha operacional` nem como `sucesso operacional sem prova de import efetivo`; a importação real aconteceu de fato, o que falhou foi a montagem do diagnóstico estruturado pelo wrapper; declarar explicitamente que `importedItems` veio do log bruto e que o `import.json` está degradado ou ausente; registrar a exceção do wrapper como degradação de diagnóstico separada, não como causa de falha de import
- Quando a task carregada não expuser `UpdateFile` nem `ImportKBInformation`, o wrapper de preview deve bloquear esses parâmetros cedo
- Tratar `Get*Property` como operação de leitura segura, sem efeito sobre a KB
- Não usar o valor retornado por `GetVersionProperty -Name Name` como `-VersionName` em exportação ou importação; esse valor é o nome descritivo da versão (ex: `"Design"`), não o identificador aceito por `SetActiveVersion` (ex: `"wsEducacaoSpTeste"`); para obter o identificador compatível, usar `GetActiveVersion`
- Não usar o valor retornado por `GetEnvironmentProperty -Name Name` como `-EnvironmentName` pelo mesmo motivo; usar `GetActiveEnvironment` para obter o identificador ativo compatível
- Validar `-Level` e `-Name` explicitamente antes de emitir a task; exigir `-Target`
  quando `-Level` for `Generator`, `DataStore` ou `Object`
- Nunca inferir o nome da propriedade; sempre exigir `-Name` explícito
- Quando recortes sucessivos isolarem erro residual de `Source`, `Specification` ou referência não resolvida em objeto importado, tratar a continuação como frente de conteúdo da KB/`XPZ`, não como ajuste adicional presumido do wrapper
- Quando um teste controlado com `Source` global preenchido e outro teste controlado com ajuste isolado de `Pattern Settings` não mudarem o padrão principal do log, registrar explicitamente que essas diferenças deixaram de ser suspeitas fortes e estreitar a hipótese para conteúdo da KB/`XPZ`
- Exigir confirmação explícita antes de importação real
- Recomendar reabertura da KB na IDE oficial após testes relevantes para observar warning, marca de versão ou outro efeito colateral

---

## COMMUNICATION

- Responda no idioma do usuário
- Seja direto sobre estado operacional, riscos e limites
- Declare quando o resultado é apenas operacional e ainda depende de confirmação funcional
- Em operações de import, declare o sub-estado explicitamente pelo nome (`importação real efetiva provada`, `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)`, `sucesso operacional sem prova de import efetivo`, `importação real efetiva provada, efeito não confirmado na IDE`, `importação real efetiva provada, geração de runtime pendente`, `importação real falhou por source`, etc.) — não deixe o leitor inferir o nível de prova a partir do relato narrativo
- Quando o usuário quiser evidência complementar além de `importedItems`, apresentar as duas opções em paralelo: acionar `xpz-msbuild-build` (headless) ou abrir a KB na IDE e executar o build por lá — ambas são opcionais e o resultado do build não reescreve nem substitui o sub-estado de import já declarado
- Quando o sub-estado for `importação real efetiva provada`, build tiver sido executado e o usuário reportar que o comportamento ainda não mudou, oferecer explicitamente a `checagem de frescor de runtime` como próximo passo nomeado antes de sugerir nova edição; declarar nominalmente o que será verificado: `nav_objs.xml` (`ObjStatus=genreq` indica geração pendente; `ObjStatus=nogenreq` indica gerado) e timestamps dos artefatos gerados (`.cs`, `.aspx` ou equivalente); NVG excluído por não ser acessível sem abrir a IDE; se a checagem indicar artefatos de versão anterior, classificar como `importação real efetiva provada, geração de runtime pendente` e propor reabertura + rebuild antes de qualquer nova edição
- Quando a rodada for `ensaio metodológico/experimental`, declarar isso nominalmente no resumo e separar:
  - objetivo metodológico da rodada
  - resultado operacional observado
  - confirmação funcional ainda não coberta
- Quando a rodada envolver iteração sobre objeto único, consolidar o resultado no seguinte template antes de recomendar próximo passo:

  ```
  Rodada N — <NomeDoObjeto> (<TipoObjeto>)
  - XML local atualizado: sim / não
  - XML bem-formado: sim / não
  - Sanity: limpo / warnings / bloqueante
  - Preview: reconhecido / não reconhecido / não executado
  - Import real: <sub-estado nomeado>
  - Warnings conhecidos: <lista ou "nenhum">
  ```

- Quando houver ambiguidade de contexto, interrompa a execução e peça definição explícita
- Não use linguagem otimista para sugerir segurança que ainda não foi validada empiricamente
- Quando a exportação headless gerar um `.xpz` para alimentar a pasta paralela da KB, declarar explicitamente o marco `XPZ gerado`
- Se a geração do `.xpz` fizer parte do caminho `B` do setup inicial, diferenciar explicitamente a fase `exportação headless concluída` da fase posterior `materialização em ObjetosDaKbEmXml`
- Se o pedido do usuário for apenas gerar o `.xpz`, parar no artefato gerado; só prosseguir para materialização quando o pedido for seguir com o setup ou com a materialização

---

## STRUCTURE

Arquivos de referência e quando carregar:

| Referência | Carregar quando |
|-----------|-----------------|
| [README.md](../README.md) | Sempre - regras editoriais e posicionamento da base |
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Regras operacionais, precedência e restrições da trilha XPZ |
| [10-base-operacional-msbuild-headless.md](../10-base-operacional-msbuild-headless.md) | Sempre - base operacional, riscos conhecidos e interface vigente |

---

## EXPECTED INTERFACE

Esta skill assume, como interface operacional, scripts pequenos e explicitamente parametrizados. `Test-GeneXusMsBuildSetup.ps1`, `Open-GeneXusKbHeadless.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzExport.ps1`, `Invoke-GeneXusXpzImport.ps1`, `Test-GeneXusKbConsistency.ps1`, `Test-GeneXusImportFileEnvelope.ps1`, `Watch-GeneXusMsBuildLog.ps1` e `Test-GeneXusRuntimeFreshness.ps1` já foram materializados nesta fase; os demais não devem ser tratados como já implementados sem confirmação explícita.

Estado atual da materialização:

- `Test-GeneXusMsBuildSetup.ps1`: implementado como probe (sondagem técnica inicial) não invasivo
- `Open-GeneXusKbHeadless.ps1`: implementado para abertura e fechamento controlados da KB, com contexto ativo e sem import/export
- `Test-GeneXusXpzImportPreview.ps1`: implementado para `PreviewMode` de importação e já validado nesta conversa com XPZ real
- `Invoke-GeneXusXpzExport.ps1`: implementado para exportação headless de XPZ com parâmetros explícitos e diagnóstico JSON
- `Invoke-GeneXusXpzImport.ps1`: implementado para importação real de XPZ com parâmetros explícitos e diagnóstico JSON
- `Test-GeneXusKbConsistency.ps1`: implementado como wrapper de `CheckKnowledgeBase` com diagnóstico JSON, classificação das categorias empíricas documentadas e confirmação interativa obrigatória para `Fix="true"`
- `Test-GeneXusImportFileEnvelope.ps1`: implementado para validação estrutural estática do `import_file.xml` antes de qualquer chamada ao MSBuild; não invasivo, não abre KB
- `Watch-GeneXusMsBuildLog.ps1`: implementado como monitor incremental de execução headless; usar quando o invocador encerrar por timeout em KB grande para acompanhar o MSBuild ainda em execução sem depender do chat
- `Test-GeneXusRuntimeFreshness.ps1`: implementado como diagnóstico somente leitura de frescor de runtime; usar quando o sub-estado for `importação real efetiva provada, geração de runtime pendente` para confirmar se artefatos de runtime já refletem a versão importada

Scripts nesta frente:

- `Test-GeneXusMsBuildSetup.ps1`
  - status atual: implementado como probe (sondagem técnica inicial) não invasivo
- `Open-GeneXusKbHeadless.ps1`
  - status atual: implementado para abertura e fechamento controlados da KB
- `Test-GeneXusXpzImportPreview.ps1`
  - status atual: implementado para `PreviewMode` sem importação real, com `IncludeItems` e `ExcludeItems` validados nesta instalação
- `Invoke-GeneXusXpzExport.ps1`
  - status atual: implementado para exportação headless de XPZ com parâmetros explícitos e validação da task carregada
- `Invoke-GeneXusXpzImport.ps1`
  - status atual: implementado para importação real de XPZ com parâmetros explícitos e diagnóstico JSON
  - contrato de resiliência do pós-processamento: o bloco que faz parse do stdout, monta `importedItems` e serializa o diagnóstico JSON deve ser envolvido em `try/catch`; em caso de exceção interna (ex: `Exception calling Join` por entrada inesperada, falha de serialização, qualquer erro posterior à conclusão da task `Import` do MSBuild), o script não deve perder a evidência já coletada — deve emitir um diagnóstico parcial contendo no mínimo: `exitCode` real do MSBuild, caminho do `msbuild.stdout.log`, lista de marcas `__IMPORTED_ITEM__` extraídas diretamente do log bruto antes da exceção (quando disponível), marca explícita `postProcessingFailed=true`, mensagem da exceção e indicação de que `importedItems` deve ser confirmado por leitura do log bruto; o agente que consumir esse diagnóstico parcial aplica o sub-estado `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)` quando o log bruto contiver evidência do objeto esperado, conforme regra em RESPONSIBILITIES; nunca substituir o `exitCode` real por código de exceção do PowerShell — o `exitCode` do MSBuild é evidência primária de que a task de import concluiu
- `Test-GeneXusKbConsistency.ps1`
  - status atual: implementado; classifica KB consistente, inconsistências detectadas, check parcial por timeout da Etapa 3 e KB inacessível; `Fix="true"` exige confirmação interativa
- `Test-GeneXusImportFileEnvelope.ps1`
  - status atual: implementado
  - objetivo: validação estrutural estática do `import_file.xml` antes de qualquer chamada ao MSBuild; não invasivo, não abre KB, não requer GeneXus instalado
  - parâmetros obrigatórios: `-InputPath` (caminho do `import_file.xml`)
  - parâmetros opcionais: `-AsJson`
  - saída esperada: `status` (`apto para prosseguir` | `apto com ressalvas` | `não apto para prosseguir`), `checks` (mapa de verificações individuais), `objectCount`, `blockingReasons`, `warnings`
  - verificações realizadas: XML bem-formado; raiz `<ExportFile>`; blocos obrigatórios `<KMW>`, `<Source>`, `<Objects>`, `<Dependencies>`; ausência de declaração XML interna dentro de `<Objects>`; ausência de texto solto ou placeholder literal em `<Objects>`; GUIDs válidos por objeto; `Source/@kb` e `Source/Version/@guid` em formato GUID
- `Watch-GeneXusMsBuildLog.ps1`
  - status atual: implementado
  - objetivo: monitorar incrementalmente o log de uma execução headless em andamento; encerra sozinho quando o processo termina; usar especialmente em importações de KB grande onde o invocador pode encerrar por timeout antes do MSBuild concluir
  - parâmetros obrigatórios: `-Pid`, `-LogPath`
  - parâmetros opcionais: `-MonitorLog`, `-IntervalSeconds` (default 5), `-SilenceThresholdSeconds` (default 120)
- `Test-GeneXusRuntimeFreshness.ps1`
  - status atual: implementado
  - objetivo: diagnosticar se o runtime GeneXus reflete a versão mais recente de um objeto após import+build; somente leitura, não abre KB, não invoca MSBuild
  - parâmetros obrigatórios: `-KbPath`, `-ObjectName`, `-ImportedAt`
  - parâmetros opcionais: `-ObjectType` (reservado para uso futuro), `-GeneratorOutputPath` (se omitido, deriva como `<KbPath>\CSharpModel\web`), `-AsJson`
  - saída esperada: `runtime-fresh` (nogenreq + artefatos posteriores ao import), `runtime-stale` (genreq ou artefatos anteriores), `runtime-unknown` (objeto não encontrado em `nav_objs.xml` ou artefatos não localizados)
- `Get-GeneXusKbProperty.ps1`
  - status atual: implementado
  - objetivo: leitura de propriedade em qualquer nível da KB sem alterar nenhum dado
  - parâmetros obrigatórios: `-KbPath`, `-Level` (KB | Version | Environment | Generator | DataStore | Object), `-Name`, `-WorkingDirectory`, `-LogPath`
  - parâmetros opcionais: `-Target` (obrigatório quando `-Level` for `Generator`, `DataStore` ou `Object`; nome do generator, datastore ou objeto), `-GeneXusDir`, `-MsBuildPath`, `-VersionName`, `-EnvironmentName`, `-VerboseLog`
  - saída esperada: `status` (`leitura concluída` | `falha de leitura`), `level`, `target` (quando aplicável), `propertyName`, `propertyValue`, `exitCode`, caminho do log
  - tasks confirmadas no assembly: `GetKnowledgeBaseProperty`, `GetVersionProperty`, `GetEnvironmentProperty`, `GetGeneratorProperty` (parâmetro opcional `Generator`), `GetDataStoreProperty` (parâmetro opcional `DataStore`), `GetObjectProperty` (parâmetro `Object` obrigatório); todas expõem `Name` e `PropertyValue` como interface comum
  - incompatibilidade conhecida e verificada empiricamente: `GetVersionProperty -Name Name` retorna o nome descritivo da versão (ex: `"Design"`), não o identificador aceito por `SetActiveVersion` (ex: `"wsEducacaoSpTeste"`); `GetEnvironmentProperty -Name Name` tem a mesma incompatibilidade com `SetActiveEnvironment`; para obter o identificador compatível com essas tasks de posicionamento, usar `GetActiveVersion` e `GetActiveEnvironment`

Contrato inicial específico de `Test-GeneXusMsBuildSetup.ps1`:

- obrigatórios: `-WorkingDirectory`, `-LogPath`
- opcionais: `-GeneXusDir`, `-MsBuildPath`, `-KbPath`, `-VerboseLog`
- regra de contrato: `-WorkingDirectory` continua explícito; quando o caminho seguro ainda não existir, o probe pode criar exatamente essa pasta e registrar isso no diagnóstico
- códigos de saída contratuais:
  - `0` para `apto para prosseguir`
  - `10` a `16` para bloqueios operacionais esperados com diagnóstico estruturado
  - `90` para falha interna do script antes de diagnóstico completo

Parâmetros transversais esperados:

- `-KbPath`
- `-GeneXusDir`
- `-MsBuildPath`
- `-VersionName`
- `-EnvironmentName`
- `-WorkingDirectory`
- `-LogPath`
- `-VerboseLog`

Parâmetros específicos de exportação:

- `-XpzPath`
- `-ObjectList` — lista de objetos para exportação seletiva; para múltiplos objetos, separar entradas com ponto-e-vírgula (`;`) no formato `Tipo:Nome`; exemplo: `Procedure:ProcA;WebPanel:WPB;Transaction:TrC`; após a exportação, **inspecionar o `.xpz` por completo**: (1) confirmar que todos os objetos solicitados estão presentes; (2) **listar todos os objetos** que o pacote efetivamente contém e confrontar com a intenção da rodada — a exportação parcial pode incluir **dependências, referências ou objetos ligados** consoante `DependencyType`, `ReferenceType` e defaults da task; **nunca** assumir que o pacote tem só os itens da lista sem ler o artefato; quando exportar um único objeto, o formato `Tipo:Nome` continua válido sem separador
- `-DependencyType`
- `-ReferenceType`
- `-ExportKbInfo`
- `-ExportAll`

Parâmetros específicos de importação:

- `-XpzPath`
- `-PreviewMode`
- `-UpdateFilePath`
- `-IncludeItems`
- `-ExcludeItems`
- `-AutomaticBackup`
- `-ImportType`
- `-ImportKbInformation`

---

## INVENTÁRIO DO PACOTE ANTES DO IMPORT REAL

- O gate `Test-GeneXusImportFileEnvelope.ps1` valida estrutura do envelope; **não substitui** a verificação do **conjunto de objetos** que efetivamente seria aplicado à KB na importação.
- **Checklist obrigatório** antes de **importação real** quando o pacote **não** foi montado na mesma rodada pelo fluxo `xpz-builder` com manifesto explícito na conversa (objetos + intenção do lote):
  - Extrair a lista completa de objetos no `<ExportFile>` (por exemplo todos os `<Object` sob `<Objects>`, ou conteúdo equivalente dentro do `.xpz`).
  - Confrontar com o **delta declarado** / pedido do utilizador (tipo e nome de cada objeto em foco). Cada objeto **extra** deve ser classificado no espírito de `xpz-builder` como mudança pedida, auxiliar necessária ou **extra não pedida**; se for **extra não pedida** num pacote que o utilizador descreveu como correção pontual ou cirúrgica → **ABORT** salvo confirmação explícita.
  - Se aparecer **módulo de sistema / plataforma** GeneXus (por exemplo `Module:GeneXus`, ou outro `Module` claramente de plataforma segundo o catálogo operacional em `xpz-builder` / `06-padroes-de-objeto-e-nomenclatura.md`) num pacote tratado como delta mínimo → **ABORT** salvo pedido explícito desse conteúdo.
- **Recomendado** executar o mesmo inventário antes de `PreviewMode` quando o pacote veio de **export MSBuild**, **reempacotamento manual** ou qualquer fluxo em que o agente não controlou fecho do lote na conversa.
- **Exportação com lista explícita (`-ObjectList` / `Objects`) não garante** pacote com um único objeto nem equivalência “lista nominal = conteúdo do zip”. **Nunca** tratar tudo o que veio no pacote como intencional sem esse confronto.

### Anti-padrão (nomeado): export MSBuild como “casca” + patch + import

- **Evitar:** exportar da KB só para obter um `.xpz`, substituir manualmente o nó de um `<Object>` pelo XML da pasta paralela, reempacotar e importar **sem** inventário completo e **sem** alinhamento ao manifesto / delta.
- Quando o XML autoritativo já está na pasta paralela (`ObjetosDaKbEmXml` ou área de geração local), o caminho preferido para import headless é montar **`import_file.xml`** com motor estruturado compartilhado: `Build-GeneXusImportFileEnvelope.ps1` para montagem direta a partir de XMLs de objeto e template válido, ou `New-XpzImportPackage.ps1`/`.py` para montagem por frente em `ObjetosGeradosParaImportacaoNaKbNoGenexus` usando `kb-source-metadata.md` ou `-TemplatePackagePath` (skill `xpz-builder`, metadados em `kb-source-metadata.md` quando aplicável), em vez de fabricar `.xpz` por export só para servir de envelope.

### Exportação headless e alinhamento ao pedido

- **Não** iniciar exportação headless da KB como passo próprio quando o utilizador pediu **apenas** importar alterações já existentes na pasta paralela, **salvo** pedido explícito de exportação ou **confirmação explícita** de que a exportação é indispensável (por exemplo impossibilidade documentada de obter `KMW`/`Source`/identidade de envelope por outro meio).

---

## WORKFLOW (fluxo de trabalho)

1. Reler a documentação local aplicável e usar [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md) como referência principal
2. Validar se o cenário é compatível com uso controlado e ambiente controlado
3. Confirmar que `C:\Program Files (x86)` será tratada como somente leitura
4. Executar primeiro um probe (sondagem técnica inicial) não invasivo para validar:
   - `KbPath`
   - `GeneXusDir`
   - `MsBuildPath`
   - `WorkingDirectory`
   - `LogPath`
   - existência de `Genexus.Tasks.targets`
   Se `WorkingDirectory` estiver em caminho seguro e ainda não existir, o probe pode auto-criar exatamente essa pasta.
5. Resolver `GeneXusDir` e `MsBuildPath` por ordem explícita de precedência e fallback, registrando origem e descarte de candidatos quando aplicável
6. Classificar o resultado do probe (sondagem técnica inicial) como `apto para prosseguir` ou `não apto para prosseguir`
   O diagnóstico deve incluir `status`, `summary`, `resolvedPaths`, `checks`, `blockingReasons`, `warnings` e `strategyTrace`.
   O diagnóstico deve distinguir `WorkingDirectory` já existente de `WorkingDirectory` auto-criado no caminho explícito e seguro.
   Preferir `JSON` como formato canônico inicial.
6b. Quando o objetivo for importação (preview ou real), executar o gate de validação do envelope **antes de qualquer chamada ao MSBuild**:
   - Chamar `Test-GeneXusImportFileEnvelope.ps1 -InputPath <caminho> -AsJson`
   - Interpretar o resultado:
     - `não apto para prosseguir` → **ABORT**; apresentar `blockingReasons` ao usuário antes de prosseguir; não chamar MSBuild
     - `apto com ressalvas` → apresentar `warnings`; exigir confirmação explícita do usuário antes de prosseguir para preview ou import real
     - `apto para prosseguir` → prosseguir normalmente
   - Este gate é não invasivo: lê apenas o arquivo local, não abre KB, não requer GeneXus instalado
   - Aplicar mesmo quando o arquivo vier de geração anterior já validada — o gate é obrigatório por rodada, não por sessão
6c. Antes de **importação real**: executar o **inventário do pacote** (lista completa de objetos no envelope) e confrontá-lo com o delta declarado, conforme a secção **Inventário do pacote antes do import real**. Se o pacote contiver extras não conciliados ou módulo de sistema não pedido num pacote cirúrgico, **ABORT** salvo confirmação explícita do utilizador. Omitir este passo apenas quando o pacote foi gerado na mesma rodada pelo fluxo `xpz-builder` com manifesto na conversa que já feche o lote esperado.
7. Só depois abrir a KB e confirmar versão ativa e `Environment` ativo quando aplicável
   Quando o objetivo for confirmar versão e Environment para usar em `-VersionName`/`-EnvironmentName`, usar `GetActiveVersion` e `GetActiveEnvironment` — nunca `GetVersionProperty -Name Name` nem `GetEnvironmentProperty -Name Name`, pois esses retornam propriedades de metadados incompatíveis com o identificador aceito por `SetActiveVersion`/`SetActiveEnvironment` (verificado empiricamente: `GetVersionProperty -Name Name` retornou `"Design"` enquanto `GetActiveVersion` retornou `"wsEducacaoSpTeste"` na mesma KB)
8. Se o objetivo for inspeção, priorizar:
   - `PreviewMode`
   - `UpdateFile`, quando suportado pela task carregada
9. Se o objetivo for exportação, executar com parâmetros explícitos e conferir o artefato gerado
   Antes de emitir parâmetro sensível de exportação, validar a assinatura efetiva do wrapper e da task carregada para evitar sintaxe presumida incorreta.
   Em exportação full, preferir `-FullExport` quando o wrapper expuser esse atalho.
10. Se o objetivo for importação real, exigir autorização explícita e ambiente controlado
11. Capturar e relatar:
   - `exitCode`
   - `stdoutSignals` com campos semânticos do domínio (ex: `importWarnings`, `exportMarkerFound`/`gxWarnings`) — presente nos scripts de import/export; omitido nos scripts cujos sinais de domínio já fluem por campos próprios (`observedContext`, `propertyValue`, `consistencyResult`)
   - `stderrContent` — linhas reais de stderr após filtrar ruído GeneXus 18; pode conter o padrão lateral `mismatched input ']' expecting 'default'`, documentado em `10-base-operacional-msbuild-headless.md` como ruído de runtime não bloqueante — não confundir com falha operacional
   - `stderrFilteredNoise` — linhas filtradas do ruído GeneXus 18 (`context [anonymous] N:N attribute component isn't defined`)
   - caminho do `.msbuild`
   - caminho do log
   - artefatos gerados ou consumidos
12. Classificar o resultado como:
   - `não apto para prosseguir`
   - `importação real efetiva provada` — `importedItems` contém explicitamente o objeto esperado
   - `importação real efetiva provada, efeito não confirmado na IDE` — `importedItems` contém o objeto esperado, mas build ou execução na IDE ainda exibe comportamento da versão anterior; verificar se KB foi reaberta e se build foi executado após reabertura antes de suspeitar de falha de import
   - `importação real efetiva provada, geração de runtime pendente` — `importedItems` contém o objeto esperado, build foi executado após reabertura, mas artefatos de runtime ainda refletem versão anterior; indicadores: objeto em `nav_objs.xml` (raiz da KB nativa) com `ObjStatus=genreq` (GeneXus marcou o objeto como pendente de geração), timestamp dos artefatos gerados (`.cs`, `.aspx` ou equivalente) anterior ao timestamp do import; NVG não integra o diagnóstico somente leitura — é gerado ao abrir a KB na IDE e não é um arquivo estático; tratar como camada de diagnóstico separada do sub-estado de import e do diagnóstico de IDE desatualizada; diagnosticar pela checagem de frescor de runtime (somente leitura) antes de propor nova edição
   - `sucesso operacional sem prova de import efetivo` — `exitCode=0` mas `importedItems` ausente ou não contém o objeto esperado
   - `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)` — o log bruto (`msbuild.stdout.log` ou stdout capturado) contém `__IMPORTED_ITEM__` ou marca equivalente para o objeto esperado, mas o wrapper lançou exceção interna durante o pós-processamento (ex: `Exception calling Join`, falha de serialização do `import.json`) impedindo que `importedItems` fosse populado no diagnóstico estruturado; a importação real aconteceu — o que falhou foi a camada de diagnóstico do wrapper; declarar nominalmente a origem da evidência (log bruto) e a exceção do wrapper como degradação de diagnóstico separada
   - `importação real falhou por source` — erro rastreável ao conteúdo do objeto importado
   - `importação real falhou por envelope` — erro na estrutura ou envelope do XPZ
   - `importação real falhou sem importedItems` — falha sem trilha de `importedItems` no log
   - `falha operacional` — falha na camada do wrapper ou do MSBuild antes de atingir a task de import
   - `preview reconheceu o objeto` — objeto esperado apareceu no retorno do preview
   - `preview apenas` — preview concluído sem evidência de reconhecimento do objeto esperado
   - `operação concluída, porém pendente de confirmação funcional`
   - quando aplicável, acumular também o marcador narrativo `ensaio metodológico/experimental`, sem substituir a classificação operacional principal
13. Recomendar o próximo passo seguro; quando o sub-estado for `importação real efetiva provada` e o usuário quiser evidência complementar, apresentar as duas opções em paralelo:
   - acionar `xpz-msbuild-build` (headless) — `compilou limpo` ou `specify e generate concluídos` reforçam o handoff sem alterar o sub-estado de import declarado
   - abrir a KB na IDE e executar o build por lá
   Recomendar reabertura da KB na IDE quando o teste exigir observação posterior, independentemente da opção de build escolhida
   Se o sub-estado for `importação real efetiva provada` e o usuário não observar o efeito esperado na IDE, diferenciar explicitamente as hipóteses:
   - IDE ainda carregando versão anterior: KB não foi reaberta desde o import, ou foi reaberta mas build não foi executado depois
   - Sintomas concretos de IDE desatualizada: mesmo erro persiste após reabertura + rebuild, propriedades do objeto exibem data/versão anterior ao import, output gerado é idêntico ao da rodada anterior
   - Nenhum desses sintomas invalida o sub-estado de import já declarado — o diagnóstico de IDE desatualizada é camada separada
   Quando o sub-estado for `importação real efetiva provada`, build tiver sido executado após reabertura da KB e o usuário reportar que o comportamento ainda não mudou, oferecer a `checagem de frescor de runtime` como trilha de diagnóstico nomeada antes de sugerir nova edição:
   Executar `scripts\Test-GeneXusRuntimeFreshness.ps1 -KbPath <caminho> -ObjectName <nome> -ImportedAt <timestamp-do-import> -AsJson` para verificar automaticamente os dois indicadores; a saída JSON indica `runtime-fresh`, `runtime-stale` ou `runtime-unknown`.
   - Verificar `nav_objs.xml` (raiz da KB nativa): confirmar se o objeto aparece com `ObjStatus=nogenreq`; `ObjStatus=genreq` indica que a geração está pendente após o import
   - NVG excluído da checagem somente leitura: é gerado ao abrir a KB na IDE e não é um arquivo estático acessível sem abertura
   - Comparar timestamps dos artefatos gerados (`.cs`, `.aspx`, ou equivalente da instalação) com o timestamp do import
   - Se qualquer indicador mostrar artefato de versão anterior: classificar como `importação real efetiva provada, geração de runtime pendente` e propor reabertura da KB seguida de novo build antes de qualquer nova edição
   - Essa checagem é somente leitura, não invasiva e não altera o sub-estado de import já declarado
14. Se a exportação gerou um `.xpz` full para a pasta paralela da KB, declarar explicitamente:
   - caminho do artefato gerado
   - status operacional da exportação
   - warnings estruturais relevantes
   - se a execução para no `.xpz` gerado ou se seguirá para materialização
15. Se o pedido do usuário for seguir com o setup depois da exportação full, anunciar a mudança de fase para materialização em `ObjetosDaKbEmXml` antes de sair da trilha `MSBuild`

---

## WWP IMPORT ORDER

Aplica-se quando os pacotes a importar contêm objetos WorkWithPlus. Siga fases separadas para evitar erros de referência e não misture estrutura base com instâncias de pattern.

### Sequência de importação

1. Importar `SEM_WWP` (preferir dry-run via `PreviewMode` primeiro)
2. Validar log de conflito/import
3. Importar `COM_WWP` ou aplicar pattern na IDE
4. Importar pacote de instâncias/custom (`WorkWithPluswc*`, `wp*`, etc.)
5. Importar pacote(s) de correção cirúrgica
6. Build + Reorganizer em ambiente de teste

### Limpeza pós-import

`import_file` não remove objetos antigos automaticamente. Planejar limpeza manual na IDE para:

- Transactions antigas substituídas
- SubtypeGroups obsoletos
- PatternInstances antigas que serão regeneradas
- Procedures/WebPanels gerados automaticamente e já substituídos

Após a limpeza, reaplicar WWP na Transaction final para regenerar base consistente.

### Ciclo de validação

1. Build após cada fase de import
2. Classificar erros por categoria:
   - Referência ausente (`non-defined object`)
   - Duplicidade em metadata/pattern
   - Incompatibilidade de assinatura em procedures/calls
3. Corrigir no menor pacote possível (cirúrgico)
4. Rebuild até zerar regressão introduzida por aquela fase

---

## QUALITY CHECKLIST

- [ ] A skill foi tratada como capacidade operacional validada, com uso controlado
- [ ] `C:\Program Files (x86)` permaneceu estritamente somente leitura
- [ ] O probe (sondagem técnica inicial) não invasivo ocorreu antes de qualquer abertura de KB
- [ ] O probe (sondagem técnica inicial) devolveu diagnóstico estruturado completo
- [ ] O probe (sondagem técnica inicial) respeitou o contrato de parâmetros obrigatórios, opcionais e `exitCode`
- [ ] `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory` e `LogPath` foram explicitados
- [ ] O probe só auto-criou `WorkingDirectory` quando o caminho explícito era seguro e permaneceu bloqueando caminhos proibidos, inválidos ou ambíguos
- [ ] `GeneXusDir` e `MsBuildPath` foram resolvidos por precedência e fallback rastreáveis
- [ ] `Genexus.Tasks.targets` foi validado
- [ ] `PreviewMode` foi priorizado quando a intenção era inspeção
- [ ] Quando o objetivo era importação (preview ou real): `Test-GeneXusImportFileEnvelope.ps1` foi executado antes de qualquer chamada ao MSBuild
- [ ] O gate de envelope retornou `apto para prosseguir` ou `apto com ressalvas` com confirmação explícita do usuário
- [ ] O gate de envelope não foi ignorado por presunção de que o arquivo já havia sido validado anteriormente
- [ ] Importação real só ocorreu com autorização explícita
- [ ] `stdoutSignals`, `stderrContent`, `stderrFilteredNoise`, `exitCode`, `.msbuild` e log foram registrados
- [ ] O resultado foi separado entre sucesso operacional e confirmação funcional
- [ ] O resultado de import foi classificado com sub-estado explícito: `importação real efetiva provada`, `sucesso operacional sem prova de import efetivo` ou sub-estado de falha com causa nomeada — nunca apenas `sucesso operacional` ou `falha operacional` para operações de import
- [ ] Quando o wrapper lançou exceção interna durante o pós-processamento mas o log bruto contém `__IMPORTED_ITEM__` para o objeto esperado, o sub-estado declarado foi `importação real efetiva provada por evidência de stdout (falha no pós-processamento do wrapper)` — nunca `falha operacional` nem `sucesso operacional sem prova de import efetivo`; a origem da evidência (log bruto) e a exceção do wrapper foram declaradas explicitamente como camadas separadas
- [ ] O script `Invoke-GeneXusXpzImport.ps1` em uso tem o pós-processamento envolvido em `try/catch` e emite diagnóstico parcial com `exitCode` real, marcas brutas extraídas do log e `postProcessingFailed=true` em caso de exceção — não perde toda a evidência por falha de serialização
- [ ] Quando o sub-estado for `importação real efetiva provada` e o usuário não observar o efeito na IDE, o diagnóstico de IDE desatualizada foi tratado como camada separada — não como revisão do sub-estado de import
- [ ] Quando o sub-estado for `importação real efetiva provada`, build tiver sido executado e o usuário reportar que o comportamento ainda não mudou, a `checagem de frescor de runtime` foi oferecida como próximo passo nomeado antes de sugerir nova edição
- [ ] O sub-estado `importação real efetiva provada, geração de runtime pendente` foi aplicado quando artefatos de runtime (`nav_objs.xml` com `ObjStatus=genreq` ou timestamps de artefatos gerados anteriores ao import) ainda refletiam versão anterior após build confirmado; NVG pode ser consultado manualmente como indicador complementar, mas não integra a checagem somente leitura automatizada
- [ ] Quando `-ObjectList` foi usado (um ou mais objetos), o formato `Tipo:Nome` e separadores foram validados; o `.xpz` foi inspecionado para confirmar presença dos solicitados **e** listar **todos** os objetos do pacote (extras por dependência não são intencionais por defeito)
- [ ] Quando `-VersionName` ou `-EnvironmentName` foram informados explicitamente, confirmar que o valor veio de `GetActiveVersion`/`GetActiveEnvironment` ou de fonte comprovadamente compatível com `SetActiveVersion`/`SetActiveEnvironment` — nunca de `GetVersionProperty -Name Name` nem de `GetEnvironmentProperty -Name Name`
- [ ] Quando a frente foi descrita por fluxo funcional e o usuário reportar "não mudou no navegador" após import confirmado, foi verificado primeiro (1) se o objeto importado é o alvo executado pelo fluxo real, antes de (2) checar frescor de runtime ou (3) propor nova edição
- [ ] Antes de importação real, o inventário completo de objetos no pacote foi confrontado com o delta declarado (ou o pacote veio da mesma rodada `xpz-builder` com manifesto que fecha o lote)
- [ ] Quando o pacote veio de export MSBuild ou reempacotamento manual, não se assumiu que o conteúdo coincide com a lista nominal nem que extras eram intencionais sem confirmação
- [ ] Exportação headless não foi executada sem pedido ou confirmação explícita quando o objetivo do utilizador era apenas importar XML já existente na pasta paralela

---

## CONSTRAINTS

- NEVER gravar qualquer artefato em `C:\Program Files (x86)`
- NEVER assumir defaults internos de importação ou exportação como seguros sem validação prática
- NEVER tratar importação real como comportamento implícito
- NEVER depender de `GeneXus Server` como base operacional desta skill
- NEVER chamar MSBuild para preview ou import sem antes executar `Test-GeneXusImportFileEnvelope.ps1` no arquivo alvo
- NEVER usar o valor retornado por `GetVersionProperty -Name Name` como `-VersionName`; para exportar da versão ativa, omitir `-VersionName`; se for necessário posicionar versão explicitamente, obter o identificador via `GetActiveVersion`, não via `GetVersionProperty`
- ABORT se `KbPath`, versão, `Environment`, pacote ou destino de logs estiverem ambíguos
- ABORT se não houver ambiente controlado compatível com a fase solicitada
- ABORT se a operação não puder produzir trilha rastreável de logs e artefatos
- ABORT se `Test-GeneXusImportFileEnvelope.ps1` retornar `não apto para prosseguir`
- NEVER prosseguir para **importação real** com pacote montado como export MSBuild + substituição manual de conteúdo + reempacotamento **sem** inventário completo dos objetos no pacote e conciliação explícita com o delta
- NEVER assumir que `-ObjectList` (ou lista equivalente) com uma única entrada produz `.xpz` contendo **apenas** esse objeto
- NEVER invocar exportação headless da KB quando o utilizador pediu **somente** importar alterações já existentes na pasta paralela, salvo pedido explícito de exportação ou confirmação explícita de que a exportação é indispensável para obter envelope/metadata utilizável
- NEVER incluir em pacote tratado como **delta cirúrgico** objetos de módulo de sistema ou plataforma GeneXus (por exemplo `Module:GeneXus`) salvo pedido explícito do utilizador
