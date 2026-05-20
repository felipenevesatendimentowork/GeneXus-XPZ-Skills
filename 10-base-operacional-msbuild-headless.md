# 10 - Base Operacional MSBuild Headless

## Status

Documento base de uso operacional compartilhado da trilha MSBuild headless, usado pelas skills `xpz-msbuild-import-export` e `xpz-msbuild-build`.

Já existe um `SKILL.md` materializado em `xpz-msbuild-import-export/SKILL.md`, apto para uso sob demanda em pasta paralela de KB GeneXus, com operação controlada e limites explícitos.

Também já existe uma implementação controlada de `scripts/Test-GeneXusMsBuildSetup.ps1`, restrita ao probe (sondagem técnica inicial) de ambiente, sem abertura de KB, sem `.msbuild` operacional e sem importação ou exportação.

Também já existe uma implementação inicial de `scripts/Open-GeneXusKbHeadless.ps1`, restrita à abertura e ao fechamento controlados da KB, com posicionamento opcional de versão e `Environment`, captura de saída e leitura do contexto ativo, ainda sem importação ou exportação.

Também já existe uma implementação inicial de `scripts/Test-GeneXusXpzImportPreview.ps1`, restrita ao `PreviewMode` de importação com saída em `JSON`, sem alteração real da KB e já validada nesta conversa com `XPZ` real.

Também já existe uma implementação inicial de `scripts/Invoke-GeneXusXpzExport.ps1`, restrita à exportação headless de `XPZ` com parâmetros explícitos, diagnóstico em `JSON` e validação da task carregada.

Também já existe uma implementação inicial de `scripts/Invoke-GeneXusXpzImport.ps1`, restrita à importação real de `XPZ` com parâmetros explícitos, diagnóstico em `JSON` e validação da task carregada.

Também já existe uma implementação inicial de `scripts/Read-MsBuildImportSignals.ps1`, restrita à leitura compacta de `msbuild.stdout.log`/`msbuild.stderr.log`, sem abrir KB e sem depender de GeneXus instalado.

Também já existem utilitários compactos de leitura de pacote/objeto (`scripts/Extract-XpzObject.ps1`, `scripts/Get-GeneXusObjectSummary.ps1`, `scripts/Compare-GeneXusPanelShape.ps1`), restritos a extração e comparação sem despejar XML/CDATA inteiro.

Esta base não substitui o fluxo oficial atual da trilha paralela da KB, não altera o comportamento das demais skills `xpz-*` e não trata sucesso operacional como evidência suficiente de sucesso funcional.

Este documento é par de `02-regras-operacionais-e-runtime.md`, não downstream dele. Achados empíricos de scripts MSBuild — incompatibilidades de tasks, comportamento verificado de API, evidências de execução em KB real — pertencem aqui. Regras transversais sobre estrutura XPZ/XML e runtime GeneXus pertencem a `02-regras`.

## Objetivo

Consolidar as diretrizes operacionais, restrições, riscos conhecidos e evidências de validação da trilha MSBuild headless: importação/exportação de `XPZ` e build/geração do GeneXus por automação baseada em `MSBuild`, sem depender da operação manual pela IDE.

## Escopo Operacional Atual

- abrir a `Knowledge Base` por `MSBuild` em cenário controlado
- validar seleção de versão e `Environment`
- exportar `XPZ` de forma headless com parâmetros explícitos
- executar preview de importação e importação real de `XPZ` em cenário controlado
- registrar evidências operacionais, logs, códigos de saída e limitações

## Fora De Escopo Atual

- alterar qualquer uma das skills `xpz-*` atuais
- promover esta skill a dependência automática das demais
- substituir o fluxo oficial atual da trilha paralela da KB
- depender de GeneXus Server como requisito operacional da skill
- prometer sucesso funcional de importação, build, reorg ou consistência sem validação externa
- transformar importação real em comportamento implícito ou sem autorização explícita

## Princípios De Segurança

- tratar a skill como capacidade operacional validada, com uso controlado e limites explícitos
- não inferir automaticamente caminhos, versão ativa, `Environment` ou comportamento da KB
- exigir parametrização explícita para cada operação relevante
- separar sucesso operacional da chamada de `MSBuild` de sucesso funcional dentro do GeneXus
- registrar logs e artefatos de forma rastreável
- manter possibilidade clara de aborto antes de operações sensíveis, em especial importação real

### Riscos Operacionais Descobertos

- `ImportKBInformation` está documentado como capaz de importar propriedades de `KB`, `Version` e `Environment`, com default documentado `true`
- `AllowCreateParentObjects` e `AllowCreateModuleObject` aparecem nas definições internas de importação como possibilidades de criação implícita
- a skill não deve assumir que defaults internos do GeneXus são seguros para esta frente; parâmetros sensíveis devem ser tratados explicitamente
- a instalação do host `MSBuild` sugere rastros laterais de log e trace, o que reforça a necessidade de controlar diretório de trabalho, captura de saída e destino dos logs
- a skill deve tratar qualquer efeito colateral fora dos artefatos esperados como risco operacional relevante, mesmo quando a chamada principal reportar sucesso
- em importacao real validada nesta frente, fechar a KB antes da nova rodada nao eliminou nem o `stderr` lateral com `mismatched input ']' expecting 'default'` nem o acesso negado a `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json`; esse ruido persistente nao deve ser confundido com falha operacional da chamada
- os wrappers de preview e importacao real precisaram normalizar recortes multiplos de `IncludeItems` e `ExcludeItems` para que a task carregada aceitasse a lista de itens de forma confiavel
- depois dessa correcao, recortes combinados passaram a funcionar e a reduzir o ruido lateral; o bloqueio remanescente mais relevante desta frente passou a ser de conteudo da KB/`XPZ`, com referencia nao resolvida em `Source` (`procStrZERO`) durante a importacao de `procCarregaSDTsDaNFe`
- um teste controlado preenchendo o `Source` global do pacote headless com os valores do pacote full nao alterou esse bloqueio remanescente
- um teste controlado trocando apenas `Pattern Settings` de `Padrões GeneXus` para `GeneXus Patterns` no pacote headless tambem nao alterou esse bloqueio remanescente
- com isso, as duas diferencas remanescentes observadas entre o pacote full e o export headless deixaram de ser suspeitas fortes para o ruido principal desta frente
- em uma segunda KB de teste sanitizada (`KB_Teste_B`), a bateria de exportacao full headless, preview de importacao e importacao real do pacote exportado concluiu com sucesso operacional; o `stderr` residual ficou limitado ao mesmo padrao lateral de `mismatched input ']' expecting 'default'`, sem reaparecimento do bloqueio de conteudo observado na `KB_Teste_A`
- isso reforca que a trilha central da skill funciona em mais de uma KB e que o caso `procCarregaSDTsDaNFe`/`procStrZERO` deve ser tratado como problema de conteudo da `KB_Teste_A`, nao como defeito central do fluxo headless via `MSBuild`
- em uma terceira KB de teste sanitizada (`KB_Teste_C`), a mesma bateria tambem concluiu com sucesso operacional; a falha inicial de `XpzPath inválido` apareceu apenas quando `preview` e importacao foram disparados antes do termino do export, e desapareceu quando a execucao passou a respeitar a sequencia correta de artefatos
- em uma quarta KB de teste sanitizada (`KB_Teste_D`), a abertura headless confirmou contexto ativo coerente, e a bateria de exportacao full headless, preview de importacao e importacao real do pacote exportado tambem concluiu com sucesso operacional
- nas rodadas bem-sucedidas de `KB_Teste_C` e `KB_Teste_D`, o `stderr` residual da importacao real permaneceu restrito ao mesmo padrao lateral de `mismatched input ']' expecting 'default'`, sem bloqueio de conteudo equivalente ao da `KB_Teste_A`
- em uma quinta KB de teste sanitizada (`KB_Teste_E`), a bateria tambem fechou com `exitCode = 0`, mas o preview registrou no `stdout` tentativa de contato com `GeneXus Server`, exigencia de credenciais e ausencia de licenca `GXtest` valida
- na `KB_Teste_E`, `importedItems` veio vazio tanto no preview quanto na importacao real; esse padrao deve ser tratado como validacao funcional incompleta, mesmo com sucesso operacional do wrapper
- com isso, a frente ganhou uma nova regra empirica: `exitCode = 0` isolado nao basta para promover uma rodada como sucesso funcional quando a KB aciona dependencia externa de `GeneXus Server` ou restricao de licenca
- em `KB_Teste_F`, `KB_Teste_G` e `KB_Teste_H`, a bateria completa voltou a confirmar o perfil das KBs favoraveis: exportacao, preview e importacao real com sucesso operacional, `importedItems` preenchido e apenas o `stderr` lateral de `mismatched input ']' expecting 'default'`
- em `KB_Teste_Grande_A`, a abertura, o export e o preview tambem concluiram com sucesso operacional, mas com warning recorrente sobre item desconhecido `WebPanelDesigner` de extensao ausente `K2B Object Designer`
- na `KB_Teste_Grande_A`, a importacao real tambem concluiu, porem em escala muito superior: o wrapper inicial estourou timeout, o `MSBuild` seguiu trabalhando por longo periodo com progresso visivel, inclusive em geracao de padroes `WorkWith`, e o `stdout` final terminou com `Close Knowledge Base Task Sucesso`
- com isso, a frente ganhou outra regra empirica: em KBs muito grandes, timeout curto do wrapper nao deve ser interpretado automaticamente como falha da importacao; primeiro e preciso distinguir timeout do invocador de conclusao tardia do `MSBuild`
- ainda assim, com evidência operacional repetida em nove KBs, a skill ja demonstrou repetibilidade suficiente no mecanismo central de exportacao, preview e importacao via `MSBuild`; o foco remanescente desta frente passa a ser refinamento do criterio operacional de uso, classificacao explicita de validacao incompleta e tratamento de execucao de longa duracao

## Restrição Operacional De Leitura

Para esta frente de trabalho, a árvore `C:\Program Files (x86)` deve ser tratada pelo agente como estritamente somente leitura.

Isso inclui explicitamente `C:\Program Files (x86)\GeneXus\GeneXus18` e qualquer subpasta dessa instalação oficial.

Regras aplicáveis:

- leitura técnica é permitida quando útil à frente
- é proibido incluir arquivos nessa árvore
- é proibido alterar arquivos nessa árvore
- é proibido excluir arquivos nessa árvore
- é proibido sobrescrever arquivos nessa árvore
- é proibido gerar temporários, logs, cache, saídas intermediárias ou qualquer outra gravação nessa árvore

## Camadas De Validação

### 1. Descoberta De Ambiente

- localizar instalação do GeneXus
- localizar `MSBuild`
- validar existência dos arquivos `Genexus.Tasks.targets` e equivalentes necessários
- validar caminhos de KB informados

### 1A. Probe (sondagem técnica inicial) Não Invasivo

Antes de qualquer abertura de `Knowledge Base`, a frente passa a assumir um probe (sondagem técnica inicial) exclusivamente de descoberta de ambiente.

Objetivo do probe (sondagem técnica inicial):

- confirmar que a instalação do GeneXus foi localizada
- confirmar que `MSBuild.exe` foi localizado por estratégia explícita de fallback
- confirmar a existência de `Genexus.Tasks.targets`
- confirmar que `WorkingDirectory` e `LogPath` apontam para fora de `C:\Program Files (x86)`
- confirmar que `WorkingDirectory`, quando informado explicitamente em caminho seguro, possa ser auto-criado sem inferência adicional
- confirmar que os demais caminhos informados existem e são coerentes com a fase pedida

Saída mínima esperada do probe (sondagem técnica inicial):

- classificação `apto para prosseguir` ou `não apto para prosseguir`
- motivo explícito em caso de bloqueio
- caminhos efetivamente resolvidos para `GeneXusDir`, `MsBuildPath`, `WorkingDirectory` e `LogPath`
- distinção explícita entre `WorkingDirectory` validado já existente e `WorkingDirectory` ausente, seguro e auto-criado

O probe (sondagem técnica inicial) não deve:

- abrir a KB
- gerar `.msbuild` operacional
- executar `OpenKnowledgeBase`, `Export` ou `Import`
- criar arquivos em `C:\Program Files (x86)`
- tratar ausência de caminho explícito como autorização para inferência silenciosa

### 2. Acesso À KB

- abrir a `Knowledge Base`
- validar seleção de versão
- validar seleção de `Environment`

### 2A. Capacidades Oficiais Úteis Para Validação

- usar `GetActiveVersion` para confirmar a versão ativa antes de operar
- usar `GetActiveEnvironment` para confirmar o `Environment` ativo antes de operar
- usar `CaptureOutput` quando útil para processar programaticamente a saída das tasks
- privilegiar `PreviewMode` em importação quando o objetivo for inspeção e não alteração real
- considerar `UpdateFile` como artefato útil para análise de impacto antes de importação efetiva
- considerar `IncludeItems` e `ExcludeItems` como mecanismos de recorte fino para cenários controlados

### 3. Operações Headless

- exportar `XPZ` simples
- importar `XPZ` simples em ambiente controlado

### 4. Resultado Operacional

- código de saída
- log gerado
- artefato esperado produzido ou consumido

### 5. Resultado Funcional

- confirmação posterior em ambiente de teste controlado
- sem extrapolar sucesso operacional para sucesso funcional global

## Estratégia Inicial De Testes

- começar por cenários de menor risco
- teste 1: abrir a KB com captura de saída e validar sucesso operacional mínimo
- teste 2: ler versão ativa e `Environment` ativo antes de qualquer operação sensível
- teste 3: validar `PreviewMode` de importação com pacote simples e controlado
- teste 4: gerar `UpdateFile` para inspecionar impacto esperado antes de importação efetiva
- teste 5: validar exportação simples com parâmetros explícitos e artefato conferível
- teste 6: só depois validar importação simples real em ambiente controlado
- teste 7: reabrir a KB na IDE após os testes para observar warning, marca de versão ou outro efeito colateral
- deixar cenários mais complexos para fases posteriores

## Definição De Ambiente Controlado

Para esta frente, "ambiente controlado" não significa apenas uma KB disponível. Significa um contexto em que o risco está limitado, a observação posterior é viável e a reversão operacional não depende de improviso.

Condições mínimas:

- KB de teste explicitamente destinada a experimentos desta frente, e não KB de trabalho cotidiano sem isolamento
- conhecimento explícito de qual versão e qual `Environment` devem estar ativos antes do teste
- pacote `XPZ` simples, conhecido e de baixo impacto para os primeiros experimentos
- possibilidade real de reabrir a KB na IDE oficial logo após o teste
- possibilidade de comparar o estado antes e depois, nem que seja por observação dirigida e logs
- ausência de dependência de `GeneXus Server` para viabilizar o fluxo
- diretório de trabalho e destino dos artefatos de teste definidos fora de `C:\Program Files (x86)`

Condições desejáveis:

- KB descartável, cópia de laboratório ou cenário que aceite repetição
- objeto de teste com escopo reduzido e facilmente verificável
- possibilidade de repetir o mesmo teste mais de uma vez
- trilha clara de logs e artefatos produzidos

Condições que descaracterizam ambiente controlado:

- KB de produção
- KB de homologação compartilhada sem janela clara para experimento
- dúvida sobre versão ativa ou `Environment` ativo
- pacote `XPZ` grande ou mal compreendido como primeiro caso de teste
- impossibilidade de reabrir rapidamente na IDE para inspeção
- ausência de clareza sobre onde a execução pode gerar arquivos auxiliares ou logs

## Protocolo De Testes Por Fase

### Teste 1. Abrir KB Com Captura De Saída

- pré-condições:
  - caminho da KB informado explicitamente
  - instalação do GeneXus localizada
  - `MSBuild` localizado
  - `Genexus.Tasks.targets` validado
- ação prevista:
  - abrir a KB por `OpenKnowledgeBase`
  - habilitar `CaptureOutput`
- evidência a coletar:
  - `exitCode`
  - saída capturada da task
  - log principal da execução
- critério de aprovação:
  - KB abre sem erro operacional
  - saída capturada indica sucesso coerente com a abertura
- critério de aborto:
  - falha de host
  - falha de autenticação
  - falha de abertura da KB

### Teste 2. Ler Versão E Environment Ativos

- pré-condições:
  - teste 1 aprovado
- ação prevista:
  - consultar `GetActiveVersion`
  - consultar `GetActiveEnvironment`
- evidência a coletar:
  - nomes retornados
  - saída capturada
  - consistência com o que o usuário esperava para o ambiente de teste
- critério de aprovação:
  - valores retornados são legíveis e coerentes
- critério de aborto:
  - task retorna vazio inesperado
  - task falha
  - contexto ativo diverge de forma insegura do esperado

### Teste 3. Preview De Importação

- pré-condições:
  - testes 1 e 2 aprovados
  - `XPZ` de teste simples disponível
- ação prevista:
  - executar `Import` com `PreviewMode`
  - evitar importação real
- evidência a coletar:
  - lista de itens candidatos
  - mensagens, warnings e erros reportados
  - artefatos auxiliares produzidos, se houver
- critério de aprovação:
  - preview executa sem alterar a KB
  - resultado permite entender o que seria importado
- critério de aborto:
  - tentativa de alteração real fora do esperado
  - erros estruturais graves no pacote

### Teste 4. Gerar UpdateFile

- pré-condições:
  - teste 3 aprovado
- ação prevista:
  - executar fluxo que produza `UpdateFile`
- evidência a coletar:
  - caminho do `UpdateFile`
  - existência física do arquivo
  - conteúdo suficiente para análise de impacto
- critério de aprovação:
  - `UpdateFile` é gerado e pode ser inspecionado
- critério de aborto:
  - arquivo não é gerado
  - arquivo é gerado em local inadequado
  - conteúdo não ajuda a discriminar impacto

### Teste 5. Exportação Simples

- pré-condições:
  - testes 1 e 2 aprovados
  - objeto simples escolhido explicitamente
- ação prevista:
  - executar `Export` com parâmetros explícitos
- evidência a coletar:
  - `XPZ` gerado
  - tamanho do arquivo
  - log da execução
  - parâmetros usados
- critério de aprovação:
  - arquivo `XPZ` é gerado de forma conferível
  - execução fecha sem erro operacional
- critério de aborto:
  - arquivo ausente
  - erro operacional
  - exportação com escopo inesperado

### Teste 6. Importação Simples Real

- pré-condições:
  - testes 1 a 5 aprovados
  - ambiente controlado explicitamente confirmado para teste real
- ação prevista:
  - executar `Import` real em pacote simples
- evidência a coletar:
  - `exitCode`
  - log
  - mensagens, warnings e erros
  - evidência mínima de efeito observado depois
- critério de aprovação:
  - importação conclui com sucesso operacional
  - efeito esperado mínimo pode ser conferido
- critério de aborto:
  - warnings ou erros que indiquem risco alto
  - sinais de alteração fora do escopo previsto
  - qualquer comportamento inesperado na KB

### Teste 7. Reabertura Na IDE

- pré-condições:
  - pelo menos um teste operacional relevante executado
- ação prevista:
  - reabrir a KB na IDE oficial
  - observar warnings, marcas de versão e comportamento geral
- evidência a coletar:
  - relato do comportamento observado
  - warning ou ausência de warning
  - qualquer indício de efeito colateral de host
- critério de aprovação:
  - KB reabre normalmente
  - não há warning novo relevante
- critério de aborto:
  - warning novo relevante
  - comportamento anômalo após a execução headless

## Critério Operacional De Confiança Da Skill

A skill já pode ser tratada como operacionalmente validada quando houver, de forma repetível e documentada:

- pré-requisitos validados por probe (sondagem técnica inicial) e resolução explícita de caminhos
- abertura headless da KB com contexto ativo coerente
- exportação headless validada com artefato gerado e log consistente
- `PreviewMode` validado com `importedItems` preservado quando aplicável
- importação real validada ao menos em KBs de teste controladas, com separação clara entre sucesso operacional e confirmação funcional
- limitações conhecidas documentadas por classe de exceção, e não misturadas com defeito central do wrapper

A skill deve ser tratada como operacionalmente apta quando, além da validação basal do mecanismo central, houver registro suficiente de:

- repetibilidade em KBs de perfis distintos, inclusive sem depender de `GeneXus Server`
- critério claro para interpretar `exitCode`, `stdout`, `stderr`, `importedItems` e warnings estruturais
- janela segura e bem entendida para KBs grandes, sem confundir timeout do invocador com falha do `MSBuild`
- reabertura e observação posterior na IDE oficial em casos relevantes, sem efeito colateral novo

## Síntese Da Fonte Externa Lida

A leitura filtrada de uma fonte externa de referência, ignorando a arquitetura de `MCP` como solução-alvo desta frente, reforçou o seguinte:

- o caminho mais seguro para automação operacional do GeneXus não é hospedar o SDK em executável arbitrário como base principal
- `MSBuild` aparece como host suportado e pragmaticamente mais estável para operações sobre a `Knowledge Base`
- a estratégia prática observada é:
  - localizar `MSBuild.exe`
  - gerar arquivo `.msbuild` temporário por execução
  - importar `Genexus.Tasks.targets`
  - abrir a `Knowledge Base`
  - executar a task desejada
  - fechar a `Knowledge Base`
  - capturar `stdout`, `stderr` e `exitCode`
- a fonte lida reforça a necessidade de separar:
  - sucesso operacional da chamada
  - sucesso funcional observado depois no GeneXus
- a leitura integral também sugere um risco adicional de contexto de execução:
  - um host inadequado pode deixar efeitos colaterais de versão ou instalação percebida pela KB
  - isso pode aparecer depois como warning ou comportamento incômodo ao reabrir a KB na IDE
- a fonte lida não entregou, até este ponto, um fluxo pronto e validado de `ExportXPZ` e `ImportXPZ`
- o valor principal da fonte, portanto, está na validação da arquitetura de execução e não em uma receita final já concluída para `XPZ`

## Refinamento Do Plano A Partir Da Nova Fonte

Com base nessa leitura, este plano passa a assumir explicitamente que:

- a skill deve ter como fundamento principal `PowerShell` orquestrando `MSBuild`
- a skill não deve depender, como base metodológica principal, de carregar o SDK do GeneXus em host arbitrário
- a skill deve tratar projeto temporário `.msbuild`, parâmetros explícitos, captura de saída e validação de artefatos como elementos centrais do fluxo
- a skill deve continuar separada das demais skills `xpz-*` como capacidade especializada, sem virar dependência automática

## Aprendizados Metodológicos De Fonte Externa

Uma leitura adicional de commits recentes de uma fonte externa não trouxe evidência nova direta sobre `MSBuild` para `XPZ`, mas trouxe padrões metodológicos reaproveitáveis para esta frente:

- distinguir claramente alteração apenas encenada em memória de alteração efetivamente persistida e verificada
- não confiar apenas no sucesso nominal da operação; fazer leitura posterior do estado persistido
- admitir retries curtos de verificação quando o GeneXus puder refletir mudanças com atraso
- tratar fallback de persistência como evento explícito de diagnóstico, e não como detalhe silencioso
- invalidar ou desconsiderar cache de leitura antes da etapa de verificação posterior
- devolver erros estruturados por categoria, em vez de concentrar tudo em uma mensagem genérica de falha
- exigir coerência entre a chamada executada, o artefato gerado e o efeito observável depois

Consequências para esta frente:

- a skill de `XPZ` headless deve distinguir "execução concluída" de "efeito confirmado"
- `exitCode` isolado não deve ser tratado como evidência suficiente de sucesso funcional
- a fase de verificação deve reler artefatos e estado observável em vez de depender de memória de execução
- quando houver comportamento tardio ou ambíguo, a estratégia preferida deve ser retry curto com leitura posterior, e não inferência otimista

## Decisões Operacionais Dos Wrappers

### WorkingDirectory Do Start-Process

Todos os wrappers desta frente invocam `MSBuild.exe` via `Start-Process` com `-WorkingDirectory` apontando para o **diretório de artefatos** da execução corrente (`Split-Path -Parent $MsBuildFilePath`), não para o diretório de instalação do GeneXus.

Motivação:

- os arquivos `.msbuild` gerados dinamicamente usam **caminhos absolutos** para todos os recursos críticos: caminho de `Genexus.Tasks.targets`, `KBPath`, `XPZPath` e demais parâmetros; o `MSBuild` não depende do diretório de trabalho para resolver esses caminhos
- o diretório de artefatos já está sob controle do wrapper: é criado na mesma execução, fica fora da árvore de `Program Files` e é rastreado no diagnóstico JSON como artefato da operação
- usar o diretório de instalação do GeneXus como `WorkingDirectory` introduziria risco de escrita não intencional nesse local caso uma task interna gravasse arquivos usando caminho relativo ao diretório de trabalho

Consequência prática:

- o `WorkingDirectory` do `Start-Process` não deve ser confundido com o parâmetro `-WorkingDirectory` dos wrappers (que é o diretório informado pelo chamador para artefatos e log)
- não alterar esse padrão sem evidência empírica concreta de falha causada por ele

### Flags MSBuild: /nodeReuse:false, /m e Verbosidade

**`/nodeReuse:false` — adotado**

Todos os wrappers passam `/nodeReuse:false` ao invocar `MSBuild.exe`. Sem essa flag, o MSBuild pode manter um nó de worker process vivo entre chamadas consecutivas. Como os assemblies GeneXus (`Genexus.MsBuild.Tasks.dll`) são carregados com `Architecture="x86"` dentro desse nó, um processo residual de uma execução anterior pode carregar estado interno de uma KB diferente ou de uma sessão já encerrada. `/nodeReuse:false` garante que cada invocação começa com processo limpo, sem herança de contexto.

O custo operacional é apenas o overhead de subir um novo processo a cada chamada, irrelevante dado o tempo dominante das tasks GeneXus.

**`/m` — descartado**

A flag `/m` habilita build multi-processador. O modelo de arquivo `.msbuild` temporário contém um único target sequencial (`OpenKnowledgeBase → operação → CloseKnowledgeBase`). Não há targets independentes paralelizáveis. `/m` não traz benefício e foi descartado.

**Verbosidade — mantida em `minimal`**

`/verbosity:minimal` mostra mensagens de task e erros/warnings do MSBuild sem poluir o stdout com estrutura interna de targets. `quiet` suprimiria mensagens de alta importância úteis ao diagnóstico; `normal` adicionaria saída de estrutura de targets sem ganho funcional.

### Gate De Regeneração Ampla (`ForceRebuild=true`)

`BuildAll` via MSBuild com `ForceRebuild=true` **não** é equivalente operacional de `Build All` da IDE: corresponde a `Rebuild All` da IDE — regenera **todos** os objetos da KB independentemente de mudança desde o último build, e em KB grande pode durar horas e regenerar centenas/milhares de objetos (incluindo subtype groups). O mesmo vale para `SpecifyGenerate` com `ForceRebuild=true`.

Por essa assimetria de custo, os wrappers `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` bloqueiam `ForceRebuild=true` por padrão (exit 46). A habilitação exige `-AllowWideRebuild` com confirmação explícita do usuário pela frase exata `entendo que isto pode regerar a KB inteira e aceito o custo` (em modo não-interativo, a confirmação chega via `-ConfirmWideRebuild` após o chamador obter a frase do usuário humano).

Esse gate é **independente** do gate de reorg (`-AllowReorg`): autorizar um não autoriza o outro. Cada operação ampla exige sua própria confirmação por frase exata específica.

O workflow completo, parâmetros e interface estruturada estão documentados na skill `xpz-msbuild-build`; esta seção registra apenas a salvaguarda como parte da realidade operacional MSBuild headless.

## Restrição De Escopo Sobre GeneXus Server

O público-alvo destas skills de `XPZ` não dispõe de `GeneXus Server`, portanto a skill desta frente não deve assumir `GeneXus Server` como componente disponível nem como trilha operacional pretendida.

Regras aplicáveis:

- `Genexus.Server.Tasks.targets` não é base operacional da skill
- tasks de `GeneXus Server` não devem virar pré-requisito de uso
- referências a `GeneXus Server` podem ser aproveitadas apenas como aprendizado indireto sobre convenções, mensagens, padrões de `MSBuild` ou comportamento de importação/exportação
- quando houver alternativa entre trilha local e trilha dependente de `GeneXus Server`, a trilha local deve prevalecer

## Evidências Da Instalação Oficial Do GeneXus 18

A leitura da instalação oficial em `C:\Program Files (x86)\GeneXus\GeneXus18`, em modo estritamente somente leitura, confirmou evidências diretas relevantes para esta frente:

- `Genexus.Tasks.targets` expõe oficialmente as tasks:
  - `OpenKnowledgeBase`
  - `CloseKnowledgeBase`
  - `Export`
  - `Import`
  - `SetActiveVersion`
  - `SetActiveEnvironment`
  - `CheckKnowledgeBase`
- essas tasks são carregadas com `Architecture="x86"`
- a instalação inclui exemplos reais de `.msbuild` usando esse modelo, como:
  - `Genexus.msbuild`
  - `CompressKB.msbuild`
  - `GXtest.msbuild`
- a documentação offline instalada confirma a superfície suportada:
  - `3908.html`: índice de `MSBuild Tasks`, incluindo `Export`, `SetActiveVersion` e `SetActiveEnvironment`
  - `35599.html`: `Import MSBuild Task`
  - `35862.html`: `OpenKnowledgeBase MSBuild Task`
  - `35636.html`: sintaxe de lista de itens para `IncludeItems` e `ExcludeItems`
  - `1922.html`: definição de `XPZ`

## Parâmetros Oficiais Confirmados Na Instalação

Com base na documentação offline da instalação oficial, ficam confirmados para esta frente:

- `Export`
  - `File`
  - `Objects`
  - `DependencyType`
  - `ReferenceType`
  - `IncludeGXMessages`
  - `IncludeUntranslatedMessages`
  - `OnlyStructuresForTransactions`
  - `ExportKBInfo`
  - `ExportAll`
- `Import`
  - `File`
  - `AutomaticBackup`
  - `ImportType`
  - `LanguageTranslations`
  - `RedefineExternalPrograms`
  - `ImportKBInformation`
  - `IncludeItems`
  - `ExcludeItems`
  - `PreviewMode`
  - `UpdateFile`
- `OpenKnowledgeBase`
  - `Directory`
  - `MDFPath`
  - `TargetModelId`
  - `DatabaseUser`
  - `DatabasePassword`
  - `CaptureOutput`
- `SetActiveVersion`
  - `VersionName`
- `SetActiveEnvironment`
  - `EnvironmentName`

## Pontos Abertos Que Exigem Experimento Controlado

- não assumir sem teste a relação exata entre `ExportKBInfo` documentado e `ExportKBProperties` exposto na definição interna
- não assumir que os defaults internos de importação e exportação são adequados para esta frente sem validação prática
- verificar em ambiente controlado o efeito real de `ImportKBInformation` sobre propriedades de `KB`, `Version` e `Environment`
- verificar se `PreviewMode` e `UpdateFile` entregam evidência suficiente para uma fase segura de inspeção antes de importação real
- verificar se a execução via `MSBuild` deixa rastros laterais relevantes no diretório de trabalho ou em arquivos de log associados ao host
- verificar se a KB continua abrindo normalmente na IDE após operações headless, sem warning ou marcas indesejadas de host

## Achado Empírico Da Instalação Atual

Na instalação validada nesta conversa, a reflexão do assembly `Genexus.MsBuild.Tasks.dll` mostrou que a task `Genexus.MsBuild.Tasks.Import` expõe publicamente `PreviewMode`, `IncludeItems` e `ExcludeItems`, mas não expõe `UpdateFile` nem `ImportKBInformation` como propriedades públicas configuráveis.

Consequências práticas imediatas:

- o wrapper de preview não deve emitir `UpdateFile` por padrão nesta instalação
- `ImportKBInformation` não deve ser emitido por padrão nesta instalação
- `ImportKbInformation=false` solicitado pelo agente deve ser tratado como valor neutro: o wrapper deve omitir o atributo, não bloquear; apenas `ImportKbInformation=true` em instalação sem suporte dispara `preview bloqueado por assinatura da task` ou `import bloqueado por assinatura da task`
- quando o usuário pedir `UpdateFile` ou `ImportKBInformation` em valor não neutro, a frente deve tratar isso como capacidade dependente da assinatura efetiva da task carregada, não apenas da documentação offline
- o teste 4 do plano permanece metodologicamente válido, mas nesta instalação ficou bloqueado por incompatibilidade observada da task carregada
- `IncludeItems` e `ExcludeItems` tiveram efeito operacional confirmado em `PreviewMode` nesta instalação
- o contrato do diagnóstico do wrapper deve preservar `importedItems` sempre como lista, inclusive quando houver apenas um item retornado

## Achado Empírico Sobre Filtro De Data Na Exportação

Na KB de teste sanitizada `KB_Teste_Paralela_A`, a IDE do GeneXus exportou um `XPZ` parcial usando o filtro visual `Modified = After Date/time` com `Date/time = 24/03/2026 23:59`.

O `XPZ` gerado pela IDE continha somente os objetos resultantes da seleção:

- `Domain:DomainExemploCodigoLongoA`, com `lastUpdate="2026-04-18T01:52:00.0000000Z"`
- `Domain:DomainExemploDescricaoLongaA`, com `lastUpdate="2026-04-18T12:59:55.0000000Z"`
- `Domain:DomainExemploTipoCorteA`, com `lastUpdate="2026-04-18T13:27:27.0000000Z"`

O pacote não preservou a condição do filtro; buscas no XML interno não encontraram `After Date`, `Date/time`, `24/03/2026`, `2026-03-24`, `ExportAtTimestamp` ou `Modified`. Isso indica que a IDE aplica o filtro antes de montar o `XPZ`; o artefato final contém apenas o resultado da seleção e o `lastUpdate` de cada objeto exportado.

Na mesma instalação, a reflexão da task `Genexus.MsBuild.Tasks.Export` mostrou uma propriedade pública `ExportAtTimestamp` do tipo `System.DateTime`, porém os testes headless não validaram esse parâmetro como equivalente ao filtro da IDE:

- `ExportAtTimestamp="2026-03-24T23:59:00"` foi aceito pelo `MSBuild`, abriu a KB, mas a task `Export` falhou internamente com `Referência de objeto não definida para uma instância de um objeto`.
- `ExportAtTimestamp="24/03/2026 23:59:00"` foi rejeitado pelo `MSBuild` como valor inválido para `System.DateTime`.
- `ExportAtTimestamp` também falhou quando usado junto com `Objects` explícito.
- a exportação sem `ExportAtTimestamp`, usando `Objects="Domain:DomainExemploCodigoLongoA,DomainExemploDescricaoLongaA,DomainExemploTipoCorteA"`, concluiu com sucesso e gerou um `XPZ` com os mesmos objetos, `lastUpdate` e checksums observados no pacote parcial da IDE.

Conclusão operacional desta frente:

- a exportação headless via `MSBuild` não deve ser tratada como tendo filtro funcional por data de modificação
- o caminho headless validado para exportação parcial é fornecer explicitamente a lista de objetos em `Objects`/`ObjectList`
- quando o usuário precisar selecionar objetos por data e não houver lista prévia, a seleção por data permanece dependente da IDE ou de outra fonte externa autorizada que produza a lista de objetos

**Advertência sobre exportação parcial com lista explícita:** mesmo quando `Objects`/`ObjectList` nomeia objetos concretos, o GeneXus pode incluir no `.xpz` **objetos adicionais** (dependências, referências, módulos organizacionais) conforme parâmetros da task (`DependencyType`, `ReferenceType`) e comportamento padrão. **Não** concluir que o pacote coincide com a lista nominal **sem** abrir o artefato e inventariar todo o conteúdo antes de importar. Para o artefato cotidiano `import_file.xml`, o motor compartilhado `scripts/Get-GeneXusImportPackageObjectInventory.ps1` produz esse inventário de forma determinística e pode confrontar o conteúdo com um delta declarado em texto `Tipo:Nome`. A skill `xpz-msbuild-import-export` documenta checklist de inventário e o anti-padrão “export como casca + patch + import”.

## Checklist Inicial De Requisitos Da Skill

- usar `MSBuild` como host principal da execução operacional
- gerar arquivo `.msbuild` temporário por execução
- localizar `MSBuild.exe` por estratégia explícita de fallback e registrar qual caminho foi usado
- validar a existência da instalação do GeneXus e de `Genexus.Tasks.targets`
- validar previamente o caminho da `Knowledge Base`
- separar claramente as operações de:
  - abrir KB
  - selecionar versão
  - selecionar `Environment`
  - exportar `XPZ`
  - importar `XPZ`
  - fechar KB
- tratar importação real como operação sensível e nunca implícita
- capturar `stdout`, `stderr`, `exitCode`, caminho do `.msbuild` gerado e caminho do log
- distinguir no resultado:
  - sucesso operacional da chamada
  - sucesso funcional posterior no GeneXus
- incluir verificação pós-teste de reabertura da KB na IDE para detectar warning, marca de versão ou efeito colateral de host
- evitar placeholders esquecidos, caminhos hardcoded como regra e valores presumidos silenciosamente
- começar os testes por descoberta de ambiente e abertura da KB
- validar exportação simples antes de validar importação simples
- manter a skill com uso controlado, sem prometer sucesso funcional além da evidência observada

## Interface Proposta Dos Futuros Scripts `.ps1`

Nesta fase, a proposta é evitar um script monolítico e trabalhar com operações pequenas, explicitamente parametrizadas.

Scripts propostos:

- `Test-GeneXusMsBuildSetup.ps1`
  - objetivo: validar host, instalação, paths e pré-requisitos sem alterar a KB
- `Open-GeneXusKbHeadless.ps1`
  - objetivo: abrir KB, posicionar versão e `Environment`, capturar saída e confirmar contexto ativo
- `Test-GeneXusXpzImportPreview.ps1`
  - objetivo: executar preview de importação e, quando aplicável, gerar `UpdateFile`
- `Invoke-GeneXusXpzExport.ps1`
  - objetivo: exportar `XPZ` com parâmetros explícitos
- `Invoke-GeneXusXpzImport.ps1`
  - objetivo: executar importação real apenas em fase já autorizada de teste controlado
- `Read-MsBuildImportSignals.ps1`
  - objetivo: produzir JSON compacto de logs brutos de preview/import, com itens importados, warnings, erros, versão/Environment ativos, sucesso da task Import e warnings de layout agrupados por Panel
- `Extract-XpzObject.ps1`, `Get-GeneXusObjectSummary.ps1`, `Compare-GeneXusPanelShape.ps1`
  - objetivo: extrair, resumir e comparar objetos GeneXus em XML/XPZ sem imprimir pacote completo nem CDATA extenso
- `Watch-GeneXusMsBuildLog.ps1`
  - objetivo: monitorar incrementalmente o log de uma execução headless em andamento, sem depender do chat para polling; encerra sozinho quando o processo termina
  - parâmetros obrigatórios: `-Pid`, `-LogPath`
  - parâmetros opcionais: `-MonitorLog`, `-IntervalSeconds` (default 5), `-SilenceThresholdSeconds` (default 120)
- `Test-GeneXusRuntimeFreshness.ps1`
  - objetivo: diagnosticar se o runtime GeneXus reflete a versão mais recente de um objeto após import+build; somente leitura, não abre KB, não invoca MSBuild
  - parâmetros obrigatórios: `-KbPath`, `-ObjectName`, `-ImportedAt`
  - parâmetros opcionais: `-ObjectType` (reservado para uso futuro), `-GeneratorOutputPath` (se omitido, deriva como `<KbPath>\CSharpModel\web`), `-AsJson`

Estado atual da materialização adicional:

- `Invoke-GeneXusXpzExport.ps1`: implementado para exportação headless de `XPZ` com parâmetros explícitos e diagnóstico em `JSON`
- `Read-MsBuildImportSignals.ps1`: implementado para reduzir consumo de tokens na leitura de logs MSBuild; os wrappers de preview/import gravam `msbuild.import.signals.json` ao lado dos logs brutos quando a leitura compacta consegue executar
- `Extract-XpzObject.ps1`, `Get-GeneXusObjectSummary.ps1`, `Compare-GeneXusPanelShape.ps1`: implementados para reduzir consumo de tokens em analise de XML/XPZ e diagnostico de Panel; devem ser preferidos a buscas que imprimam linhas grandes de `CDATA`
- `Watch-GeneXusMsBuildLog.ps1`: implementado como monitor incremental de execução headless; destaca fases do GeneXus (Open, Specify, Generate, Compile, BuildAll, Reorg, Validating subtype group, Close), detecta silêncio prolongado e encerra sozinho quando o processo termina; exibe contador de silêncio in-place (sem gerar nova linha a cada poll); quando `-MonitorLog` é passado com o mesmo caminho de `-MonitorLogPath` em `Invoke-GeneXusKbBuildAll.ps1`, o JSON de resultado inclui `timing.phases` com duração de cada fase interna; iniciar com `-NoExit` para a janela permanecer aberta após o build
- `Test-GeneXusRuntimeFreshness.ps1`: implementado como diagnóstico somente leitura de frescor de runtime; verifica `nav_objs.xml` e timestamps dos artefatos gerados; saída JSON com `runtime-fresh`, `runtime-stale` ou `runtime-unknown`

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
- `-ObjectList`
- `-DependencyType`
- `-ReferenceType`
- `-ExportKbInfo`
- `-ExportAll`

Parâmetros específicos de importação:

- `-XpzPath` (aceita `.xpz`, `.xml` e `.import_file.xml` quando o envelope foi validado por `Test-GeneXusImportFileEnvelope.ps1`; nome do parâmetro é histórico e não restringe a extensão)
- `-PreviewMode`
- `-UpdateFilePath`
- `-IncludeItems`
- `-ExcludeItems`
- `-AutomaticBackup`
- `-ImportType`
- `-ImportKbInformation` (tri-state: omitido ou `false` equivalem a não emitir o atributo; apenas `true` emite e exige suporte na task carregada)

Saídas esperadas dos scripts:

- código de saída confiável
- resumo objetivo da operação
- caminho do log gerado
- caminho do `.msbuild` temporário gerado
- artefatos produzidos, quando houver
- `importedItems` deve sair sempre como lista no JSON, inclusive quando houver apenas um item
- indicação explícita de:
  - sucesso operacional
  - falha operacional
  - operação apenas em preview
  - sucesso operacional com falha no pos-processamento — `executionEvidence.msBuildExitCode=0`, evidência primária do log bruto presente (`__IMPORTED_ITEM__` ou `__EXPORTED_FILE__` mais arquivo XPZ existente), mas pos-processamento local do wrapper falhou e o JSON saiu com `postProcessingFailed=true`; não é `falha operacional`
  - preview apenas com falha no pos-processamento — análogo ao anterior na fase de preview: `executionEvidence.msBuildExitCode=0` sem alterar a KB, evidência primária preservada no log bruto, pos-processamento local falhou; não é `falha operacional`
  - operação concluída, porém ainda pendente de confirmação funcional
- no diagnóstico JSON, distinguir `exitCode` (valor classificado pelo wrapper — 0/32/41/42/... — e também exit code do processo) de `executionEvidence.msBuildExitCode` (local canônico do valor bruto da task MSBuild); `msBuildExitCode` top-level, quando existir, é compatibilidade transitória e deve duplicar o valor canônico; ambos devem aparecer no diagnóstico parcial em caso de falha no pos-processamento

### Contrato Transversal De Diagnóstico JSON Dos Wrappers MSBuild

Este contrato aplica-se aos wrappers que já chamaram `MSBuild` ou processaram seus logs. Ele não pertence ao probe `Test-GeneXusMsBuildSetup.ps1`, que não abre KB nem invoca tasks operacionais.

- `exitCode`
  - valor classificado pelo wrapper e também exit code do processo
- `executionEvidence`
  - registro objetivo da execução quando o wrapper já chamou `MSBuild`: `msBuildExitCode`, `msBuildFailed`, `wrapperExitCode` e caminhos dos logs brutos quando disponíveis
  - quando o `MSBuild` falhar sem causa acionável classificada, `blockingReasons` deve conter fallback explícito apontando para `executionEvidence` e logs
  - `executionEvidence.msBuildExitCode` é o local canônico do código bruto retornado pela task `MSBuild`; `msBuildExitCode` top-level, quando existir por compatibilidade, deve duplicar esse valor e não deve ser usado como padrão novo
  - `observedContext.MsBuildExitCode`, quando existir em wrappers da família build, é contexto observado/compatibilidade e não substitui `executionEvidence.msBuildExitCode` como fonte canônica
  - em falha de pós-processamento do wrapper, o diagnóstico degradado deve preservar `executionEvidence` com os dados brutos já coletados antes da falha
- `postProcessingFailed` / `postProcessingError`
  - `postProcessingFailed=true` sinaliza falha local do wrapper depois que o `MSBuild` já rodou, como parse de stdout, montagem do diagnóstico, serialização JSON ou gravação do log
  - `postProcessingError` deve carregar a mensagem curta da falha local quando disponível
  - em exportação, `postProcessingFailed=true` pode aparecer sem `diagnosticDegraded`; nessa família, o sub-estado é decidido por `executionEvidence`, marcas do log bruto e existência do XPZ gerado
- `diagnosticDegraded` / `diagnosticDegradedReason`
  - `diagnosticDegraded` (booleano) sinaliza que o pós-processamento local do wrapper ficou parcial ou falhou após o `MSBuild` já ter concluído; `diagnosticDegradedReason` (string) carrega a causa textual curta
  - hoje contratado e emitido em `scripts/Invoke-GeneXusXpzImport.ps1` e `scripts/Test-GeneXusXpzImportPreview.ps1`; o contrato completo de resiliência do pós-processamento está em `xpz-msbuild-import-export/SKILL.md`
  - `diagnosticDegraded=true` pode coexistir com `postProcessingFailed=false`, por exemplo quando a task concluiu e o diagnóstico principal foi montado, mas a leitura compacta de `msbuild.import.signals.json` falhou ou ficou parcial
  - semântica: **não** reclassifica a task `MSBuild` — a evidência primária de conclusão da task permanece em `executionEvidence` e nos marcadores do log bruto (`__IMPORTED_ITEM__`, `__EXPORTED_FILE__`)
  - quando `diagnosticDegraded=true` coexistir com `executionEvidence.msBuildExitCode=0` e evidência de marca no log bruto, o sub-estado correto é `concluído com diagnóstico degradado` ou o sub-estado mais específico definido pela skill consumidora; não é `falha operacional` por si só
- `observedContext`
  - registra contexto técnico observado pelo wrapper, como versão ativa, `Environment` ativo, `OpenOutput`, `pathEnrichment` e, em wrappers de build, campos legados como `MsBuildExitCode`
  - `observedContext.pathEnrichment` registra o enriquecimento preventivo de `PATH` (`applied`, `subdirsAdded`, `subdirsSkipped`) quando o wrapper aplica essa política

### Contrato Inicial De `Test-GeneXusMsBuildSetup.ps1`

Nesta fase, o primeiro script da trilha deve ser apenas um probe (sondagem técnica inicial) de ambiente.

Escopo permitido:

- resolver `GeneXusDir`
- resolver `MsBuildPath`
- validar presença de `Genexus.Tasks.targets`
- validar existência de `KbPath`, quando ele for informado para fases posteriores
- validar que `WorkingDirectory` e `LogPath` ficam fora de `C:\Program Files (x86)`
- auto-criar exatamente o `WorkingDirectory` explicitamente informado quando ele for seguro e ainda não existir
- devolver diagnóstico estruturado e abortar cedo quando houver ambiguidade

Escopo proibido:

- abrir ou fechar `Knowledge Base`
- selecionar versão ou `Environment`
- gerar arquivo `.msbuild` para execução operacional
- invocar tasks de importação ou exportação
- produzir artefato persistente além do log explicitamente solicitado fora de `C:\Program Files (x86)`

Parâmetros mínimos esperados neste probe (sondagem técnica inicial):

- `-GeneXusDir`
- `-MsBuildPath`
- `-KbPath`
- `-WorkingDirectory`
- `-LogPath`
- `-VerboseLog`

Assinatura contratual inicial do futuro script:

Parâmetros obrigatórios:

- `-WorkingDirectory`
- `-LogPath`

Parâmetros opcionais:

- `-GeneXusDir`
- `-MsBuildPath`
- `-KbPath`
- `-VerboseLog`

Critério de obrigatoriedade nesta fase:

- `WorkingDirectory` e `LogPath` são obrigatórios porque o probe precisa validar diretórios seguros e rastreabilidade mínima
- `WorkingDirectory` continua explícito; o probe pode criar somente esse caminho, nunca inferir outro
- `GeneXusDir` e `MsBuildPath` podem ser omitidos apenas porque esta fase já define fallback explícito
- `KbPath` pode ser omitido quando o objetivo for apenas validar host e instalação antes de amarrar uma KB específica
- `VerboseLog` é opcional e deve afetar detalhamento, não o resultado lógico do probe

Códigos de saída contratuais iniciais:

- `0`
  - probe concluído com `status = apto para prosseguir`
- `10`
  - probe concluído com `status = não apto para prosseguir` por ausência ou invalidez de `GeneXusDir`
- `11`
  - probe concluído com `status = não apto para prosseguir` por ausência ou invalidez de `MsBuildPath`
- `12`
  - probe concluído com `status = não apto para prosseguir` por ausência de `Genexus.Tasks.targets`
- `13`
  - probe concluído com `status = não apto para prosseguir` por `WorkingDirectory` inseguro
- `14`
  - probe concluído com `status = não apto para prosseguir` por `LogPath` inseguro
- `15`
  - probe concluído com `status = não apto para prosseguir` por `KbPath` inválido, quando informado
- `16`
  - probe concluído com `status = não apto para prosseguir` por ambiguidade não resolvida em fallback
- `90`
  - falha interna do próprio script antes de gerar diagnóstico completo

Regra de uso dos códigos de saída:

- códigos `10` a `16` representam bloqueio operacional esperado e devem vir acompanhados de diagnóstico estruturado
- código `90` representa falha do script como ferramenta, não apenas bloqueio do ambiente
- não reutilizar `0` para cenários bloqueados só porque o script conseguiu escrever log
- o campo `status` do diagnóstico e o `exitCode` precisam ser coerentes entre si

Resultado esperado:

- `apto para prosseguir` quando todos os pré-requisitos mínimos estiverem válidos
- `não apto para prosseguir` quando faltar host, target, diretório seguro ou caminho coerente
- sem qualquer inferência de sucesso funcional, pois o probe (sondagem técnica inicial) ainda não toca a KB

Formato esperado do diagnóstico estruturado:

- `status`
  - valores esperados: `apto para prosseguir` ou `não apto para prosseguir`
- `summary`
  - resumo curto e legível do resultado
- `resolvedPaths`
  - deve listar pelo menos `GeneXusDir`, `MsBuildPath`, `KbPath`, `WorkingDirectory` e `LogPath`
- `checks`
  - coleção de verificações com nome, resultado e observação curta
  - verificações mínimas:
    - localização da instalação do GeneXus
    - localização do `MSBuild.exe`
    - presença de `Genexus.Tasks.targets`
    - existência de `KbPath`, quando informado
    - confirmação de que `WorkingDirectory` está fora de `C:\Program Files (x86)`
    - confirmação de que `LogPath` está fora de `C:\Program Files (x86)`
- `blockingReasons`
  - lista explícita dos motivos acionáveis que impediram prosseguir, quando houver
- `warnings`
  - lista de alertas não bloqueantes, quando houver
- `strategyTrace`
  - registro curto do fallback adotado para resolver `MsBuildPath` e caminhos sensíveis

Forma de uso do diagnóstico:

- se `status` for `não apto para prosseguir`, a trilha para antes de qualquer abertura de KB
- se `status` for `apto para prosseguir`, o diagnóstico vira evidência de entrada para a fase seguinte
- ausência de campo crítico deve ser tratada como diagnóstico incompleto, não como sucesso implícito

Ordem de resolução e fallback de `GeneXusDir`:

1. usar `-GeneXusDir` quando informado explicitamente
2. se não vier informado, tentar localizar instalação oficial em caminhos conhecidos do GeneXus 18
3. validar nesse diretório a existência de `Genexus.Tasks.targets`
4. abortar se houver mais de uma instalação plausível e nenhuma regra explícita para desempate
5. abortar se o diretório encontrado não contiver os artefatos mínimos esperados

Regras adicionais para `GeneXusDir`:

- não inferir uma instalação alternativa só porque existe um nome parecido
- não tratar documentação offline isolada como evidência suficiente de instalação válida
- registrar no `strategyTrace` se o valor veio de parâmetro explícito ou de fallback

Ordem de resolução e fallback de `MsBuildPath`:

1. usar `-MsBuildPath` quando informado explicitamente
2. se não vier informado, tentar caminhos conhecidos de `MSBuild.exe` em instalações compatíveis do Visual Studio ou Build Tools
3. se houver mais de um caminho válido, preferir o host mais específico e atual que permaneça compatível com a trilha
4. registrar qual caminho foi escolhido e quais candidatos foram descartados
5. abortar se nenhum caminho válido for encontrado

Regras adicionais para `MsBuildPath`:

- não considerar `dotnet msbuild` como substituto implícito nesta fase
- não promover shell alias ou comando parcial a caminho validado
- o caminho final precisa apontar para executável real verificável pelo probe
- registrar no `strategyTrace` a ordem dos fallbacks tentados

Exemplo canônico inicial em `JSON`:

```json
{
  "status": "apto para prosseguir",
  "summary": "GeneXus, MSBuild e diretórios seguros validados; WorkingDirectory explícito ausente foi auto-criado com segurança.",
  "resolvedPaths": {
    "GeneXusDir": "C:\\GeneXus\\GeneXus18",
    "MsBuildPath": "C:\\Program Files\\Microsoft Visual Studio\\2022\\BuildTools\\MSBuild\\Current\\Bin\\MSBuild.exe",
    "KbPath": "D:\\GX\\KbLaboratorio",
    "WorkingDirectory": "D:\\GX\\HeadlessProbe\\work",
    "LogPath": "D:\\GX\\HeadlessProbe\\logs\\probe.log"
  },
  "pathActions": {
    "WorkingDirectory": "validated-and-created"
  },
  "checks": [
    {
      "name": "GeneXus installation",
      "result": "ok",
      "detail": "Diretório informado encontrado."
    },
    {
      "name": "MSBuild host",
      "result": "ok",
      "detail": "MSBuild localizado por fallback em Visual Studio Build Tools."
    },
    {
      "name": "Genexus.Tasks.targets",
      "result": "ok",
      "detail": "Arquivo localizado dentro da instalação do GeneXus."
    },
    {
      "name": "KbPath",
      "result": "ok",
      "detail": "KB encontrada no caminho informado."
    },
    {
      "name": "WorkingDirectory outside Program Files x86",
      "result": "ok",
      "detail": "Diretório ausente no caminho seguro informado; pasta auto-criada."
    },
    {
      "name": "LogPath outside Program Files x86",
      "result": "ok",
      "detail": "Destino de log fora da árvore somente leitura."
    }
  ],
  "blockingReasons": [],
  "warnings": [
    "WorkingDirectory ausente foi criado automaticamente no caminho explícito e seguro: D:\\GX\\HeadlessProbe\\work"
  ],
  "strategyTrace": [
    "GeneXusDir usado conforme parâmetro explícito.",
    "MsBuildPath não informado; fallback aplicado em caminhos conhecidos do Visual Studio.",
    "WorkingDirectory explícito não existia; o script criou exatamente o diretório informado após validar segurança.",
    "KbPath validado apenas por existência de diretório nesta fase."
  ]
}
```

Exemplo canônico inicial em caso bloqueado:

```json
{
  "status": "não apto para prosseguir",
  "summary": "Probe bloqueado por host MSBuild ausente e LogPath inseguro.",
  "resolvedPaths": {
    "GeneXusDir": "C:\\GeneXus\\GeneXus18",
    "MsBuildPath": null,
    "KbPath": "D:\\GX\\KbLaboratorio",
    "WorkingDirectory": "D:\\GX\\HeadlessProbe\\work",
    "LogPath": "C:\\Program Files (x86)\\GeneXus\\GeneXus18\\probe.log"
  },
  "pathActions": {
    "WorkingDirectory": "validated-existing"
  },
  "checks": [
    {
      "name": "GeneXus installation",
      "result": "ok",
      "detail": "Diretório informado encontrado."
    },
    {
      "name": "MSBuild host",
      "result": "fail",
      "detail": "Nenhum caminho conhecido de MSBuild foi encontrado."
    },
    {
      "name": "LogPath outside Program Files x86",
      "result": "fail",
      "detail": "LogPath aponta para árvore estritamente somente leitura."
    }
  ],
  "blockingReasons": [
    "MSBuild.exe não localizado.",
    "LogPath dentro de C:\\Program Files (x86)."
  ],
  "warnings": [],
  "strategyTrace": [
    "GeneXusDir usado conforme parâmetro explícito.",
    "MsBuildPath não informado; fallback aplicado em caminhos conhecidos do Visual Studio sem sucesso."
  ]
}
```

Restrições de desenho:

- não gravar nada em `C:\Program Files (x86)`
- não depender de valores hardcoded como regra
- não inferir silenciosamente versão, `Environment` ou pacote
- não esconder fallback, retry ou mudança de estratégia durante a execução
- não tratar importação real como comportamento padrão

## Achado Empírico Sobre CheckKnowledgeBase

A reflexão do assembly `Genexus.MsBuild.Tasks.dll` confirmou que a task `Genexus.MsBuild.Tasks.CheckKnowledgeBase` expõe publicamente a propriedade `Fix` do tipo `Boolean`.

A bateria de testes executada em mais de 30 KBs (em `C:\KBs`, `C:\Models` e `C:\GxModels`) com `Fix="false"` revelou o seguinte comportamento empírico:

### Estrutura interna do check

A task executa até 7 etapas:

- `Etapa 1`: verifica fragmentação de índices SQL (problema de performance, não inconsistência lógica)
- `Etapa 2`: Check Model Entity Version
- `Etapa 3`: verificação de composição de versão de entidade — pode atingir timeout de SQL em KBs com índices altamente fragmentados (~3min08s)
- `Etapa 4`: verificação de redundância de informação entre `EntityVersionComposition` e `ModelEntityVersion` — onde inconsistências lógicas de objetos aparecem
- `Etapa 5`: verificação de herança de subtipo
- `Etapa 6`: redundância de propriedades de `ModelEntityProperty`
- `Etapa 7`: verificação de enumeradores `LastObjectId` e `LastVersionId`

### Categorias de resultado observadas

- `ExitCode = 0`, sem inconsistências: check completo, KB sem problemas detectados
- `ExitCode = 0`, com inconsistências: check completo, problemas lógicos detectados no stdout — a task não falha o build mesmo com inconsistências
- `ExitCode = 1` por timeout na Etapa 3: check parcial por limite de execução SQL (~3min08s fixos); as etapas seguintes ainda rodam e podem detectar inconsistências; `CheckKnowledgeBase falhou` aparece no stdout mas os achados das demais etapas são válidos
- `ExitCode = 1` por `OpenKnowledgeBase` bloqueado: versão incompatível (`needs conversion`), diretório inválido (`InvalidDirectory`) ou `.mdf` em estado anômalo no SQL Server — o check nunca chegou a rodar

### Regras empíricas para interpretação

- `ExitCode = 0` não basta para afirmar KB limpa — é obrigatório checar o stdout por linhas de inconsistência
- `ExitCode = 1` não significa KB quebrada — pode ser timeout da Etapa 3 em KB com índices fragmentados; distinguir lendo o stdout em busca de `Tempo Limite de Execução Expirado`
- quando `Fix` for omitido, a task emite dois warnings informativos mas se comporta igual a `Fix="false"`; o wrapper deve passar `Fix="false"` explicitamente para evitar ruído
- o warning de extensão ausente (`WebPanelDesigner` / `K2B Object Designer`) pode aparecer no `OpenKnowledgeBase` sem impedir o check de rodar

### Status desta frente

`Test-GeneXusKbConsistency.ps1` implementado em `scripts/Test-GeneXusKbConsistency.ps1`. O wrapper classifica o resultado nas quatro categorias empíricas documentadas (KB consistente, inconsistências detectadas, check parcial por timeout da Etapa 3, KB inacessível) e exige confirmação interativa obrigatória quando `-Fix` é ativado.

### Achado Empírico: Comportamento de Fix="true"

Teste executado em 2026-05-06 na KB `C:\KBs\OnlineShopSS` (GeneXus 18 Up 14), após bateria prévia com `Fix="false"` que havia detectado 8 inconsistências lógicas na Etapa 4. Resultado:

- `ExitCode = 0` — igual ao `Fix="false"` com inconsistências; exitCode isolado não permite distinguir se houve ou não correção
- Warning emitido no stdout: `Parâmetro "Fix" especificado. Executando verificações e corrigindo problemas.`
- Tempo total: ~1 minuto (00:01:00.25)

#### Comportamento por etapa com Fix="true"

**Etapa 1** (fragmentação de índices SQL):
- 39 índices altamente fragmentados detectados e reconstruídos (REBUILD) ou reorganizados (REORGANIZE)
- Mensagem adicional: `Versão de composição corrigida.`
- Duração: 1.09s
- Resumo: `39 problema(s) encontrado(s), 39 corrigido.`

**Etapa 2** (Check Model Entity Version):
- 0 problemas encontrados, 0 corrigidos
- Duração: 0.03s

**Etapa 3** (composição de versão de entidade):
- 0 problemas encontrados, 0 corrigidos
- Duração: 0.045s
- **Achado crítico: sem timeout.** Com `Fix="false"`, essa KB havia atingido o timeout de ~3min08s na Etapa 3 por conta dos índices altamente fragmentados. Com `Fix="true"`, a Etapa 1 reconstruiu os índices antes que a Etapa 3 rodasse, eliminando completamente o timeout. Isso confirma a relação causal: fragmentação alta de índices → timeout na Etapa 3; reconstrução dos índices na Etapa 1 → Etapa 3 completa em milissegundos.

**Etapa 4** (redundância lógica entre EntityVersionComposition e ModelEntityVersion):
- 8 inconsistências detectadas e corrigidas — as mesmas 8 detectadas com `Fix="false"` na KB (`Rules` e `Events` de `Transaction 'Product'`)
- Cada inconsistência gera agora dois registros no stdout: `Inconsistência encontrada...` seguido de `Parte '...' corrigida.`
- Duração: 4.26s
- Resumo: `8 problema(s) encontrado(s), 8 corrigido.`

**Etapa 5** (herança de subtipo):
- 0 problemas encontrados, 0 corrigidos
- Duração: 0.46s

**Etapa 6** (redundância de propriedades ModelEntityProperty):
- Para cada versão da KB, o stdout emite `Verificando problemas de redundância de propriedades na versão X` seguido de `Corrigindo redundâncias de propriedades em todos os objetos na versão X` — independentemente de haver ou não problemas reais
- `mismatched input ']' expecting 'default'` aparece intercalado nas versões com mais objetos, mesmo padrão lateral observado em outras operações headless; não é novo nem bloqueante
- Resumo: `0 problema(s) encontrado(s), 0 corrigido.`
- Duração: 48.58s (a etapa mais demorada desta execução)
- **Observação:** a mensagem `Corrigindo...` no stdout de Etapa 6 é o nome padrão do processo da etapa, não evidência de correção real; o resumo `0 corrigido` é o dado definitivo

**Etapa 7** (enumeradores LastObjectId e LastVersionId):
- 0 problemas encontrados, 0 corrigidos
- Duração: 0.015s

#### Regras empíricas adicionais para Fix="true"

- `ExitCode = 0` com `Fix="true"` não distingue "sem problemas" de "problemas corrigidos"; é obrigatório checar o stdout pelos resumos de cada etapa
- o warning `Parâmetro "Fix" especificado. Executando verificações e corrigindo problemas.` é o marcador confiável de que `Fix="true"` está ativo; com `Fix="false"`, esse warning não aparece
- `Fix="true"` na Etapa 1 elimina o timeout da Etapa 3 em execução subsequente da mesma rodada: a reconstrução dos índices SQL em Etapa 1 torna a query de Etapa 3 rápida, quebrando a relação causal de fragmentação → timeout
- a mensagem `Versão de composição corrigida.` em Etapa 1 aparece quando `Fix="true"` e a etapa efetua alguma reconstrução; ausente com `Fix="false"`
- nas etapas que corrigem inconsistências lógicas (Etapa 4), cada item gera par de linhas: detecção + confirmação de correção; com `Fix="false"` apenas a linha de detecção aparece
- a Etapa 6 emite `Corrigindo redundâncias de propriedades em todos os objetos na versão X` para todas as versões, mesmo quando não há problemas reais; esse padrão é o nome interno do processo, não evidência de correção — o resumo `0 corrigido` prevalece

## Próximo Marco Esperado

O próximo marco já não é provar o mecanismo básico do wrapper. Essa etapa ficou empiricamente validada em múltiplas KBs, inclusive com um caso de grande porte.

O próximo marco passa a ser fechar o critério explícito de uso estável da skill, com registro de:

- definição objetiva de prontidão operacional
- limites operacionais já conhecidos e como classificá-los no diagnóstico
- critérios de uso estável em cenários além do laboratório inicial
- exceções que não devem ser confundidas com defeito central do wrapper

Classificação mínima que a documentação da skill deve espelhar a partir daqui:

- problema de conteúdo da KB/`XPZ`, como `KB_Teste_A`
- validação funcional incompleta por dependência externa ou licença, como `KB_Teste_E`
- execução longa em KB grande, como `KB_Teste_Grande_A`
- warning estrutural por extensão ausente, como `WebPanelDesigner`/`K2B Object Designer`

Enquanto essa consolidação não estiver totalmente espelhada na skill e nos critérios de uso, o mecanismo central já deve ser tratado como validado, com operação controlada e classificação explícita dos limites remanescentes.

## Achado Empírico Sobre Tasks de Propriedades

Reflexão do assembly `Genexus.MsBuild.Tasks.dll` realizada em 2026-05-07 confirmou a acessibilidade de todas as tasks do domínio de gerenciamento de propriedades.

### Tasks confirmadas e acessíveis

**Get* (leitura segura, sem efeito sobre a KB):**

Todas as 6 tasks do domínio Get confirmadas. Interface comum: `Name` [String] (entrada), `PropertyValue` [String] (saída). Parâmetros de escopo por nível:

- `GetKnowledgeBaseProperty` — sem parâmetro adicional de escopo
- `GetVersionProperty` — sem parâmetro adicional de escopo
- `GetEnvironmentProperty` — sem parâmetro adicional de escopo
- `GetGeneratorProperty` — `Generator` [String] opcional (default "Default")
- `GetDataStoreProperty` — `DataStore` [String] opcional (default "Default")
- `GetObjectProperty` — `Object` [String] (nome do objeto, obrigatório)

Todas herdam de `BasePropertyTask` e expõem `CaptureOutput` e `TaskOutput` — o valor de `PropertyValue` pode ser capturado programaticamente via `TaskOutput`.

**SetConfiguration (escrita segura para pré-build):**

`SetConfiguration` confirmado com parâmetro `Configuration` [String]. Valores válidos documentados: `Release`, `Debug`, `Performance Test`. Não faz parte das famílias Set*/Reset* descartadas — é task de configuração de contexto de build, absorvida na skill `xpz-msbuild-build`.

### Tasks descartadas neste domínio

Set*/Reset* nos níveis KB/Version/Environment/Generator/DataStore, `SetObjectProperty`, `ResetObjectProperty`, `SetCredential`, `SetCatalog`, `SetProductInfo` e `SetConversationalFlowsProperty` foram avaliados e descartados. Motivos e condições de reavaliação registrados em `998-ideias-descartadas-e-porque.md`.

### Consequências operacionais

- `Get*Property` pode ser invocado de forma segura como diagnóstico pré-operação; o script `Get-GeneXusKbProperty.ps1` tem interface definida em `xpz-msbuild-import-export/SKILL.md`
- `SetConfiguration` deve ser emitido apenas mediante instrução explícita do usuário, antes do `BuildAll`, com valor validado
- `GetVersionProperty` e `GetKnowledgeBaseProperty` foram testadas em execução real na KB `wsEducacaoSpTeste` em 2026-05-10; as demais tasks `Get*` permanecem confirmadas apenas por acessibilidade no assembly

### Achado Empírico: Incompatibilidade GetVersionProperty Name vs SetActiveVersion

Testado em execução real em 2026-05-10 na KB `wsEducacaoSpTeste`:

- `GetVersionProperty -Name Name` → `"Design"` (nome descritivo da versão)
- `GetKnowledgeBaseProperty -Name Name` → `"wsEducacaoSpTeste"` (nome da KB)
- `SetActiveVersion` com `VersionName="Design"` → falha: `A versão 'Design' não existe`
- exportação sem `-VersionName` → sucesso; `GetActiveVersion` confirmou `"wsEducacaoSpTeste"` como identificador ativo

Conclusão: `GetVersionProperty -Name Name` retorna propriedade de metadados descritiva da versão, não o identificador aceito por `SetActiveVersion`. Para posicionar versão antes de exportação ou importação, usar `GetActiveVersion` como fonte do identificador — nunca `GetVersionProperty -Name Name`.

## Achado Empírico Sobre Subdirs Do GeneXus E PATH Em Headless

Tasks internas do MSBuild GeneXus invocam binários auxiliares (`gxexec`, `UpdConfigWeb`, `BuildService`, `Reor.exe`) por nome, sem caminho absoluto, esperando que o `$env:PATH` do processo já contenha os subdirs do install. A IDE GeneXus aplica esse enriquecimento implicitamente; um MSBuild lançado por wrapper externo (Claude Code, CI sem ambiente do GeneXus, qualquer orquestrador) herda apenas o `PATH` do shell do agente, que tipicamente não inclui esses subdirs.

### Sintoma

Build headless cuja KB atinja fases que invoquem essas tools falha com mensagens genéricas:

- `error : O sistema não pode encontrar o arquivo especificado`
- `error : Não foi possível executar o comando 'gxexec ...'. Não foi possível encontrar uma parte do caminho.` (.NET Framework — expõe o nome do binário)
- `> DeveloperMenu Compilação para Default (.NET Framework) falhou`
- `> Build All Task falhou`

Em environments .NET Core a mensagem é mais opaca porque a task `BuildAll` usa `CaptureOutput="true"` e a `Process.Start` interna falha sem propagar o nome do binário.

### Subdirs relevantes do GeneXus 18

Sob `C:\Program Files (x86)\GeneXus\GeneXus18\`:

- `GeneXus18\` (raiz) — `GeneXus.exe` e outros
- `gxnet\` — `GXExec.exe`, `UpdConfigWeb.exe`, `BuildService.exe`, `VirtualDir.exe` (.NET Framework)
- `gxnet\bin\` — `GxConfig.exe`, `GXDataInitialization.exe`, `GxSetFrm.exe`, `Reor.exe`, `Runx86.exe`
- `gxnetcore\` — `UpdConfigWeb.exe`, `BuildService.exe`, `VirtualDir.exe` (.NET Core)

A política da skill mantém `C:\Program Files (x86)` estritamente somente leitura; ler para incluir subdirs no `PATH` do processo é compatível com essa política, pois não escreve nada.

### Política dos wrappers

Os wrappers da família `xpz-msbuild-build` (`Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1`) enriquecem `$env:PATH` automaticamente após resolver `$resolvedGeneXusDir` e antes de invocar o MSBuild. O enriquecimento usa lista fixa dos quatro subdirs conhecidos, filtrada por `Test-Path` para tolerar instalações não-padrão. Subdirs ausentes são reportados em `warnings[]` e em `observedContext.pathEnrichment.subdirsSkipped` do JSON de resultado.

Os wrappers da família `xpz-msbuild-import-export` (`Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzImport.ps1` e `Invoke-GeneXusXpzExport.ps1`) aplicam o mesmo enriquecimento preventivo do `PATH` e registram o resultado em `observedContext.pathEnrichment`. A justificativa aqui é simetria e consistência do ambiente headless, não reprodução de falha em import/export puro.

### Evidência empírica (FabricaBrasil18, 2026-05-20)

Reprodução com `Invoke-GeneXusKbBuildAll.ps1` em `.Net Environment` (.NET Framework), GeneXus 18 Up 14:

| Rodada | PATH | Status | exit | MsBuildExitCode | BuildAllDone | Duração | Mensagem chave |
|---|---|---|---|---|---|---|---|
| 1d (baseline) | default (sem GeneXus) | `compilou com erros` | 45 | 1 | false | 90 s | `gxexec ... Não foi possível encontrar uma parte do caminho` |
| 2 (manual) | enriquecido pelo invocador | `compilou limpo` | 0 | 0 | true | 261 s | (sem erro) |
| 3 (pós-fix) | enriquecido pelo próprio wrapper | `compilou limpo` | 0 | 0 | true | (idem) | (sem erro) |

Artefatos preservados em `Temp\xpz-build-verify-path-20260520-r1d\` e `Temp\xpz-build-verify-path-20260520-r2\`.

### Evidência empírica complementar (OnlineShopSS, 2026-05-20)

Em `C:\KBs\OnlineShopSS`, uma importação real de alteração estrutural simples em atributo (`ShoppingCartItemQuantity`, `Length`/`AttMaxLen` 4→5) concluiu sem enriquecimento manual de `PATH`, com `importedItems` contendo o atributo esperado e sem sinais de `Database Impact Analysis`, `Reorganization`, `bldReorganization`, `gxexec`, `UpdConfigWeb`, `BuildService`, `Reor.exe` ou erro de resolução de caminho no stdout. A importação real inversa (5→4) também concluiu com sucesso quando o invocador enriqueceu manualmente o `PATH` antes da chamada.

Conclusão limitada: import/export puro não demonstrou dependência observável desses subdirs na rodada testada. O enriquecimento nos wrappers de `xpz-msbuild-import-export` permanece como defesa preventiva e alinhamento com o ambiente esperado pela IDE, enquanto a necessidade provada empiricamente continua pertencendo aos fluxos de build/specify/generate que atingem fases internas dependentes desses executáveis auxiliares.

### Observação sobre cobertura empírica anterior

A matriz 2×2 documentada em `xpz-msbuild-build/SKILL.md` (coleta de 2026-05-12) registra builds limpos em FabricaBrasil18/NETPostgreSQL sem PATH enriquecido. Hipótese de reconciliação: aqueles builds anteriores não atingiam a fase `Atualização de configuração da web` (a KB estava em estado que não disparava a fase). O sintoma é condicional à fase ser atingida, não universal a toda chamada headless. Mantida a matriz histórica como evidência do estado da KB naquela data.
