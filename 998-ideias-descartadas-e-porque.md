# Ideias Descartadas — e Por Quê

Registro de tasks, funcionalidades ou abordagens que foram avaliadas e descartadas
explicitamente, com o motivo documentado para evitar reavaliação desnecessária no futuro.

---

## BulkCopyKnowledgeBase

**Origem:** avaliação de inventário de tasks MSBuild do GeneXus 18, 2026-05-06.

**O que é:** task MSBuild que gera um arquivo no formato BCP (SQL Server Bulk Copy) com
os dados da KB. O GeneXus Server usa esse formato para transferir KBs entre instâncias.

**Por que foi descartada:**

O público-alvo desta skill não dispõe de GeneXus Server. O arquivo gerado por
`BulkCopyKnowledgeBase` é projetado para ser consumido pelo GeneXus Server no destino.
Sem ele, o caminho de restauração headless não está validado e provavelmente não é
trivial — exigiria conhecimento do esquema interno da KB do GeneXus, que não é
documentado publicamente.

Para o problema concreto que a task pretendia resolver (snapshot de segurança antes de
importação arriscada), alternativas mais simples já estão disponíveis sem implementação
adicional: cópia da pasta da KB (LocalDB) ou backup `.bak` via SQL Server (rede).

**Não reavaliar salvo** evidência de que o formato BCP pode ser restaurado sem GeneXus
Server por caminho documentado e testado.

---

## UpdateWorkingModel

**Origem:** avaliação de inventário de tasks MSBuild do GeneXus 18, 2026-05-06.

**O que é:** task MSBuild sem parâmetros que sincroniza o working model com o design
model. A documentação oficial avisa: uma vez executada, o GeneXus "esquece" todas as
alterações de design feitas; se essas alterações exigiam mudança no banco de dados,
elas não serão aplicadas.

**Por que foi descartada:**

Utilidade baixa demais para justificar implementação como script headless. Quando o
usuário precisa executar essa operação, a IDE do GeneXus já a expõe diretamente, com
feedback visual imediato. Embrulhar isso em wrapper MSBuild não adiciona valor prático
e ainda consumiria tokens em documentação e manutenção.

O risco documentado existe, mas o motivo principal do descarte é pragmático: a IDE
resolve sem custo de implementação nesta skill.

**Não reavaliar** — não há caso de uso em automação headless de XPZ que justifique
retomar.

---

## CreateKnowledgeBase

**Origem:** avaliação de inventário de tasks MSBuild do GeneXus 18, 2026-05-06.

**O que é:** task MSBuild oficial para criar KBs programaticamente, com parâmetros de
template, banco de dados e credenciais.

**Por que foi descartada:**

A IDE do GeneXus cria KBs sem dificuldade. Quando uma KB de teste é necessária, criar
pela IDE uma vez é barato e sem risco. Implementar um wrapper headless traria
complexidade de configuração SQL Server/LocalDB por ganho marginal.

**Não reavaliar** salvo surgimento de caso concreto em que criação de KB por script
seja requisito de automação, não apenas conveniência.

---

## ConvertKnowledgeBase

**Origem:** avaliação de inventário de tasks MSBuild do GeneXus 18, 2026-05-06.

**O que é:** task registrada na DLL do GeneXus MSBuild, ausente da documentação oficial.
Parâmetros e comportamento desconhecidos. Provavelmente converte KBs de versões
anteriores para a versão atual.

**Por que foi descartada:**

Quando uma KB precisa de conversão, a IDE do GeneXus conduz o processo com feedback
visual. Fazer isso headless traria risco de comportamento imprevisível em task sem
documentação oficial, por ganho marginal frente à alternativa simples de abrir pela IDE.

**Não reavaliar** salvo surgimento de caso concreto em que a conversão headless seja
requisito de automação e a task seja documentada oficialmente.

---

## Delay de estabilização pós-abertura da KB

**Origem:** avaliação feita durante construção da skill `xpz-msbuild-import-export`.

**O que era:** parâmetro de espera configurável entre `OpenKnowledgeBase` e a operação
seguinte, com a hipótese de que KBs grandes poderiam estar em estado transiente logo
após a abertura.

**Por que foi descartada:**

`OpenKnowledgeBase` não é chamado pelo PowerShell diretamente — é uma task dentro do
arquivo `.msbuild` gerado dinamicamente, rodando no mesmo processo MSBuild,
sequencialmente encadeada com a operação seguinte. Um `Start-Sleep` no PowerShell antes
de invocar o MSBuild atuaria na camada errada: o processo ainda não teria sido iniciado
e a KB ainda não teria sido aberta. O motor do MSBuild já garante a sequência
`OpenKnowledgeBase → operação → CloseKnowledgeBase` de forma síncrona e interna.

O cenário de KB grande e execução longa está coberto pela regra empírica de timeout do
invocador. Um parâmetro configurável de timeout no `Start-Process` seria
conceitualmente mais correto que um delay pré-chamada, mas não foi implementado por
ausência de caso concreto que o justifique.

**Não reavaliar** — a arquitetura MSBuild torna o delay pré-chamada estruturalmente
ineficaz.

---

## ExportAtTimestamp (parâmetro de Export)

**Origem:** investigação empírica durante construção da skill `xpz-msbuild-import-export`.

**O que é:** propriedade pública `ExportAtTimestamp` do tipo `System.DateTime` confirmada
por reflexão do assembly na task `Genexus.MsBuild.Tasks.Export`. Equivalente headless
ao filtro visual "Modified = After Date/time" da IDE.

**Por que foi descartado:**

Testado com dois formatos de data em chamadas headless:

- `ExportAtTimestamp="2026-03-24T23:59:00"` — aceito pelo MSBuild, KB abriu, mas a
  task `Export` falhou internamente com `Referência de objeto não definida para uma
  instância de um objeto` (NullReferenceException).
- `ExportAtTimestamp="24/03/2026 23:59:00"` — rejeitado pelo MSBuild como valor inválido
  para `System.DateTime`.
- Testado também combinado com `Objects` explícito — mesma falha.

Conclusão: filtro por data não é funcional via MSBuild headless nesta instalação.
O caminho validado para exportação parcial é fornecer a lista de objetos explicitamente
em `Objects`/`ObjectList`.

**Não reavaliar** salvo evidência de que o comportamento mudou em versão posterior do
GeneXus 18 ou que existe sintaxe de data alternativa não testada.

---

## UpdateFile (parâmetro de Import)

**Origem:** investigação empírica durante construção da skill `xpz-msbuild-import-export`.

**O que é:** parâmetro documentado oficialmente na task `Import` (`35599.html`). Gera um
arquivo de relatório descrevendo o que seria alterado na KB antes da importação real.

**Por que foi descartado:**

A reflexão do assembly `Genexus.MsBuild.Tasks.dll` nesta instalação mostrou que a task
`Genexus.MsBuild.Tasks.Import` não expõe `UpdateFile` como propriedade pública
configurável. O parâmetro existe na documentação offline mas não está acessível via
MSBuild headless na versão instalada.

**Não reavaliar** salvo confirmação empírica de que uma atualização do GeneXus 18 passou
a expor `UpdateFile` como propriedade pública da task carregada.

---

## ImportKBInformation (parâmetro de Import)

**Origem:** investigação empírica durante construção da skill `xpz-msbuild-import-export`.

**O que é:** parâmetro documentado oficialmente na task `Import`. Controla se propriedades
da KB, Version e Environment são importadas junto com os objetos do XPZ. Default
documentado: `true` — o que o torna potencialmente perigoso se não explicitado.

**Por que foi descartado:**

Mesma situação que `UpdateFile`: a reflexão do assembly nesta instalação mostrou que
`ImportKBInformation` não está exposto como propriedade pública da task carregada.
Parâmetro documentado mas inacessível via MSBuild headless na versão instalada.

**Não reavaliar** salvo confirmação empírica de exposição em versão posterior.

---

## ImportCSSOnTheme

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que importa um arquivo CSS para dentro de um objeto Tema existente na
KB. Parâmetros funcionais: `CSSFilePath` (obrigatório), `ObjectName` (obrigatório).

**Por que foi descartada:**

Cenário de uso restrito a customização visual de temas — situação rara no contexto da
skill XPZ, que trata de migração e sincronização de objetos GeneXus. Quando necessário,
a IDE do GeneXus executa essa operação com feedback visual imediato. Implementar wrapper
headless não adiciona valor prático para o caso de uso central desta skill.

**Não reavaliar** salvo surgimento de caso concreto em que importação de CSS em tema
seja requisito de automação recorrente neste contexto.

---

## ImportExternalObject

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que registra um objeto externo na KB. Parâmetros funcionais: `Name`,
`Type`, `URL` (nenhum marcado como obrigatório na reflexão).

**Por que foi descartada:**

Objetos externos são registros de integrações com sistemas de terceiros — cenário
específico e raro no fluxo de migração XPZ. A IDE do GeneXus gerencia esse registro
com validação visual. Semântica dos parâmetros não documentada oficialmente, o que
aumenta o risco de uso incorreto em automação headless.

**Não reavaliar** salvo surgimento de caso concreto documentado de automação de registro
de objetos externos.

---

## ImportTranslations

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que importa traduções de mensagens GeneXus a partir de arquivo externo.
Parâmetros funcionais: `FileName` (obrigatório), `AddNewMsg` (Boolean), `Override`
(Boolean).

**Por que foi descartada:**

Fluxo de tradução de mensagens é separado do fluxo principal de migração de objetos via
XPZ. Quando necessário, a IDE conduz a importação com validação e feedback. A superfície
técnica é simples, mas o caso de uso não se enquadra no escopo central da skill.

**Não reavaliar** salvo surgimento de caso concreto em que importação de traduções seja
requisito de automação recorrente neste contexto — especialmente em KBs multilíngues com
ciclo de tradução externo.

---

## ExportTranslations

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que exporta traduções de mensagens da KB para arquivo externo. Rica em
filtros: `FileName` (obrigatório), `FilterText`, `IncludeXRef`, `Languages`,
`OnlyReferencedMessages`, `OnlyUntranslatedMessages`, `OnlyUserMessages`, `UsedInObjects`.

**Por que foi descartada:**

Mesmo raciocínio de `ImportTranslations`: fora do escopo central da skill. A superfície
técnica é a mais rica das 6 tasks investigadas, com filtros granulares úteis em cenários
multilíngues. Porém, sem caso de uso concreto identificado neste contexto, implementar
wrapper headless não se justifica.

**Não reavaliar** salvo surgimento de caso concreto em que exportação de traduções com
filtro por idioma seja requisito de automação — aí a superfície desta task tem valor real.

---

## ConvertExportFile

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
e documentação offline (`60737.html`) confirmaram propósito e parâmetros.

**O que é:** task que converte um arquivo XPZ de versões anteriores do GeneXus para o
formato GeneXus 18. Requer KB aberta (usa a KB para converter referências a objetos
comuns como o SDT `Messages`). Disponível a partir do GeneXus 18 Upgrade 14.
Parâmetros: `File` (obrigatório), `OutputFile` (saída).

**Por que foi descartada:**

Cenário de uso limitado a migração pontual de XPZ legado — situação rara e de execução
única. Quando necessário, a IDE do GeneXus conduz a conversão. Implementar wrapper
headless para operação pontual de migração não justifica o custo de implementação e
manutenção.

**Não reavaliar** salvo surgimento de volume recorrente de conversões de XPZ legado que
torne a automação headless mais eficiente que a IDE.

---

## CreateExportForImages

**Origem:** inventário de tasks MSBuild do GeneXus 18, 2026-05-06. Reflexão do assembly
confirmou propriedades públicas.

**O que é:** task que exporta imagens da KB para um arquivo XPZ. Parâmetros funcionais:
`Folder` (obrigatório — pasta de origem das imagens), `OutputFile` (obrigatório — XPZ
de saída), `Filter`, `Parent`, `RenderingMode`.

**Por que foi descartada:**

Exportação de imagens é cenário separado do fluxo principal de migração de objetos via
XPZ. A IDE do GeneXus conduz essa exportação com seleção visual. Sem caso de uso
concreto identificado neste contexto.

**Não reavaliar** salvo surgimento de caso concreto em que exportação recorrente de
imagens em lote seja requisito de automação neste contexto.

## Book (parâmetro de OpenKnowledgeBase)

**Origem:** investigação empírica durante construção da skill `xpz-msbuild-import-export`.

**O que é:** atributo `Book=` observado em fonte externa de código como alternativa ao
parâmetro `Directory=` em `OpenKnowledgeBase`.

**Por que foi descartado:**

A investigação não encontrou `Book` em nenhuma superfície oficial da instalação do
GeneXus 18:

- ausente da documentação offline instalada (`35862.html` — OpenKnowledgeBase MSBuild Task)
- ausente do assembly `Genexus.MsBuild.Tasks.dll` (reflexão de propriedades públicas da task)
- ausente do arquivo `Genexus.Tasks.targets`
- ausente de qualquer `.targets` ou `.msbuild` da instalação oficial

Conclusão: `Book` é provável erro de digitação em fonte externa, sem correspondência na
superfície real da task. `Directory` e `MDFPath` são os únicos parâmetros de abertura
oficialmente confirmados.

**Não usar nos wrappers desta skill.**

---

## BuildOne

**Origem:** levantamento feito durante construção da skill `xpz-msbuild-import-export`.

**O que é:** task MSBuild oficial (`Genexus.Tasks.targets`, documentação `3908.html`).
Executa specify + generate + compile do objeto informado e de tudo que ele chama.
Reorg ocorre automaticamente se necessário — sem parâmetro para suprimir. É build real,
não simulação.

Propriedades públicas confirmadas por reflexão do assembly:

- `ObjectName` (`String`) — obrigatório
- `ForceRebuild` (`Boolean`) — default `false`
- `BuildCalled` (`Boolean`) — controla compilação dos objetos chamados
- `DetailedNavigation` (`Boolean`) — default `false`
- `CaptureOutput` (`Boolean`)
- `TaskOutput` (`String`)

**Por que foi descartada (sem wrapper implementado):**

`ObjectName` exige objeto com `Main = true`. A maioria dos objetos em um XPZ típico —
Procedures, Transactions auxiliares, SDTs, Domains — não tem `Main = true` e não pode
ser passada a `BuildOne`. Para XPZs cirúrgicos, que são o caso mais comum, `BuildOne`
é inaplicável. A confirmação funcional nesses casos depende de `BuildAll` headless ou
reabertura manual na IDE.

O reorg automático sem parâmetro de supressão também exigiria aviso explícito e
confirmação interativa antes de qualquer execução.

**Não reavaliar** salvo caso concreto em que o XPZ importado contém objeto `Main = true`
e o usuário precisa de smoke test de compilação sem abrir a IDE, combinado com
confirmação de que o reorg automático é aceitável naquele ambiente.
