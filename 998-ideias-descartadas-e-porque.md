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
