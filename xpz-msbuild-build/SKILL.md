---
name: xpz-msbuild-build
description: Skill para validação de build pós-import via MSBuild, com execução sem interface gráfica, parâmetros explícitos, classificação de resultado e gates de segurança contra reorg não autorizada
---

# xpz-msbuild-build

Skill para execução do pipeline de build do GeneXus por `MSBuild`, em execução sem
interface gráfica. Destina-se a validação pós-import: detectar erros de especificação,
geração e compilação sem abrir a IDE.

Esta skill não executa reorg por padrão, não substitui o fluxo oficial da trilha paralela
da KB e não trata sucesso operacional como evidência suficiente de sucesso funcional.

Depende da mesma infraestrutura de `xpz-msbuild-import-export`: `MSBuild.exe`,
instalação do GeneXus e `Genexus.Tasks.targets`.

## Decisões de design registradas

Tasks avaliadas e descartadas nesta skill estão documentadas em
`998-ideias-descartadas-e-porque.md`: `Compile` (isolado), `BuildOne`, `Run`,
`RebuildArtifacts`, `CustomBuild`, `SpecifyOneOnly`, `SpecifyOpenAPI`,
`GenerateChatbot`, `GenerateOpenAPI`, `IdeWebBuildAndDeploy`, `IdeWebCreateDB`,
`IdeWebImpactDB`.

---

## GUIDELINE

Orquestre o pipeline de build do GeneXus via `MSBuild` com parâmetros explícitos,
classificação rastreável de resultado e bloqueio de reorg por padrão. Use
`Invoke-GeneXusKbSpecifyGenerate.ps1` para verificação pós-import — menos invasiva que
`BuildAll` quando não há alterações estruturais pendentes no banco, mas **capaz de
disparar reorg real** quando o modelo as contém. Use `Invoke-GeneXusKbBuildAll.ps1`
para BuildAll incremental (equivalente à opção `Build All` do menu Build da IDE
GeneXus — compila apenas objetos alterados desde o último build, fluxo costumeiro
pós-edição/pós-import). `-ForceRebuild=true` é uma operação distinta: equivale a
`Rebuild All` da IDE — regenera **TODOS** os objetos da KB, podendo durar horas em KB
grande; só pode ser habilitado via `-AllowWideRebuild` com confirmação explícita do
usuário por frase exata. Nunca execute reorg sem autorização explícita do usuário.
Quando houver evidência de alteração estrutural de atributo no import recente, exigir
confirmação explícita do usuário antes de chamar `Invoke-GeneXusKbSpecifyGenerate.ps1`.
`BuildAll` sem watcher visível não é fluxo válido. Use `-StartWatcher` ao chamar
`Invoke-GeneXusKbBuildAll.ps1` — o wrapper garante o lançamento automático em janela
visível e registra evidência auditável no JSON (`watcherContext.watcherLaunched`). A
única exceção permitida é quando há justificativa operacional explícita e documentada
(ex.: ambiente sem `pwsh` no PATH, CI headless sem terminal) — nesse caso declarar
explicitamente ao usuário e registrar `watcherContext.watcherLaunched: false` como
evidência de ausência. Seguir a seção **ORQUESTRAÇÃO — PASSO A PASSO EXECUTÁVEL**.

## PATH RESOLUTION

- Este `SKILL.md` fica em uma subpasta de skill sob a raiz do repositório.
- Resolva referências `../arquivo.md` relativas à pasta desta skill, não ao diretório corrente.
- Se a skill estiver publicada por symlink, junction ou outro reparse point, resolva
  primeiro a pasta real da skill e só então interprete referências relativas.
- Na prática, `../` aponta para a base metodológica compartilhada da raiz.

---

## TRIGGERS

Use esta skill para:
- executar verificação leve pós-import (specify + generate, sem compile)
- executar build completo pós-import (specify + generate + compile)
- detectar se há reorg pendente após import, sem executá-la
- inspecionar o que a reorg alteraria no banco sem executar (`ImpactDatabaseOnly`)
- executar reorg a partir de script de impacto já inspecionado (`ReorganizeOnly`)
- configurar o modo de build antes de `BuildAll` via `SetConfiguration` (valores: `Release`, `Debug`, `Performance Test`)
- classificar resultado de build em categorias operacionais explícitas
- apoiar decisão do usuário sobre o próximo passo após import
- resolver sub-estado `importação real efetiva provada, geração de runtime pendente` declarado por `xpz-msbuild-import-export` — quando import está provado mas artefatos de runtime ainda refletem versão anterior, executar build é o passo que atualiza os artefatos gerados; `specify e generate concluídos` ou `compilou limpo` confirmam que o runtime passou a refletir a versão importada; quando persistir dúvida após build confirmado, `Test-GeneXusRuntimeFreshness.ps1` (base compartilhada) pode ser usado como confirmação adicional somente leitura — verifica `nav_objs.xml` e timestamps dos artefatos gerados sem abrir KB ou invocar MSBuild

Do NOT use esta skill para:
- executar reorg sem autorização explícita do usuário
- substituir o fluxo oficial da trilha paralela da KB
- cenários que dependam de `GeneXus Server` como requisito operacional
- KB de produção ou homologação compartilhada sem janela clara para experimento
- inferir silenciosamente `KbPath`, versão, `Environment` ou parâmetros sensíveis
- afirmar sucesso funcional apenas porque o build terminou sem erro operacional

---

## RESPONSIBILITIES

- Usar [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md)
  como base de infraestrutura compartilhada com `xpz-msbuild-import-export`
- Antes de chamar `Invoke-GeneXusKbSpecifyGenerate.ps1`, avaliar o contexto do import
  recente em busca de sinais de alteração estrutural com impacto em banco:
  - qualquer objeto do tipo `Attribute:` presente em `importedItems` do log de import
  - mudança de tamanho, tipo, precisão ou subtipo de atributo mencionada pelo usuário
  - resultado `reorg detectada ou executada` em execução anterior desta sessão
  Se qualquer sinal estiver presente, exibir aviso explícito e exigir a frase de
  confirmação `entendo que haverá reorg e concordo que prossiga` antes de executar
- Tratar `C:\Program Files (x86)` como estritamente somente leitura
- Garantir que logs, temporários, `.msbuild` e artefatos sejam gerados fora de
  `C:\Program Files (x86)`
- Usar `FailIfReorg=true` como default de `BuildAll` — nunca alterar sem instrução explícita
- Nunca emitir `DoNotExecuteReorg=false` implicitamente: reorg só executa quando o
  usuário pedir explicitamente com plena ciência do efeito
- Tratar `-ForceRebuild=true` como operação ampla análoga a reorg autorizada: bloqueada
  por default e habilitada apenas via `-AllowWideRebuild` com confirmação explícita do
  usuário por frase exata (modo interativo) ou `-AllowWideRebuild -ConfirmWideRebuild`
  apos confirmar com o usuário humano (modo não-interativo). Nunca emitir `ForceRebuild=true`
  implicitamente em fluxo pós-import nem em validação cotidiana — `BuildAll` incremental
  é o suficiente
- Distinguir claramente:
  - sucesso operacional da chamada MSBuild
  - efeito funcional observado depois no GeneXus
- Classificar o resultado de cada execução em uma das categorias definidas em WORKFLOW
- Registrar `stdout`, `stderr`, `exitCode`, caminho do `.msbuild` temporário e log
- Recomendar reabertura da KB na IDE somente quando houver warning ou efeito colateral
  detectado no build (ex: extensão ausente, `Access denied`, stderr não vazio), ou quando
  o contexto da solicitação indicar que o objetivo é validar a aplicação em execução —
  não mencionar IDE nem URL em builds sem warning onde apenas "faça um build" foi pedido;
  quando a condição estiver presente (ex: stderr não vazio), formular a recomendação como
  consequência determinística da evidência encontrada — citar o padrão específico detectado
  e recomendar explicitamente (ex: "stderr não estava vazio: [padrão]; recomendo reabrir
  a KB na IDE para conferência funcional antes de tratar o build como validado"); não
  enquadrar como sugestão condicional ao interesse do usuário
- Exigir confirmação explícita antes de qualquer execução de reorg
- Tratar `ImpactDatabaseOnly` como pré-requisito de inspeção antes de autorizar `ReorganizeOnly` explícito
- Exigir confirmação interativa obrigatória antes de `ReorganizeOnly`, mesmo quando `ImpactDatabaseOnly` já foi executado na mesma sessão
- Tratar `SetConfiguration` como operação auxiliar opcional de pré-build: só emitir
  quando explicitamente solicitado pelo usuário, com valor validado (`Release`, `Debug`,
  `Performance Test`)
- Nunca inferir ou alterar configuração sem instrução explícita
- Validar explicitamente `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory`,
  `LogPath` e `Genexus.Tasks.targets` antes de qualquer build
- Quando `SetActiveVersion` ou `SetActiveEnvironment` falhar, tratar como bloqueio
  operacional explícito: a versão ou o `Environment` solicitado não existe na KB. O
  diagnóstico deve orientar omitir `-VersionName` ou `-EnvironmentName` para usar o
  contexto ativo, quando esse for o objetivo.

---

## COMMUNICATION

- Responda no idioma do usuário
- Declare sempre a categoria de resultado (ver WORKFLOW) de forma explícita
- Quando o resultado for `reorg necessária detectada`, apresente isso como informação,
  não como falha — e pergunte como o usuário quer proceder
- Quando houver timeout em KB grande, não interprete automaticamente como falha
- Não use linguagem otimista para sugerir segurança que ainda não foi validada
- Quando houver ambiguidade de contexto, interrompa e peça definição explícita

---

## STRUCTURE

Arquivos de referência e quando carregar:

| Referência | Carregar quando |
|---|---|
| [README.md](../README.md) | Sempre — regras editoriais e posicionamento da base |
| [10-base-operacional-msbuild-headless.md](../10-base-operacional-msbuild-headless.md) | Sempre — base de infraestrutura MSBuild compartilhada |
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Regras operacionais e restrições da trilha XPZ |

Skills externas não listadas nesta tabela não devem ser carregadas durante a execução desta skill sem necessidade concreta derivada do contexto específico da tarefa.

---

## EXPECTED INTERFACE

Dois scripts PowerShell, seguindo o mesmo padrão de `xpz-msbuild-import-export`.

### Invoke-GeneXusKbSpecifyGenerate.ps1

Executa `SpecifyAll` seguido de `GenerateOnly`. Sem compilação explícita. Mais rápido
que `BuildAll` para o primeiro check após import cirúrgico — mas **pode disparar
reorganização real de banco de dados** quando a KB tem alterações estruturais pendentes,
pois `SpecifyAll` executa reorg internamente nesse caso. Ver gate pré-execução em
WORKFLOW e nota de comportamento crítico abaixo.

**Parâmetros transversais:**

- `-KbPath` (obrigatório)
- `-GeneXusDir` (opcional — fallback automático)
- `-MsBuildPath` (opcional — fallback automático)
- `-VersionName` (opcional)
- `-EnvironmentName` (opcional)
- `-WorkingDirectory` (obrigatório)
- `-LogPath` (obrigatório)
- `-VerboseLog` (opcional)

Se `-VersionName` ou `-EnvironmentName` for informado com valor inválido para a KB, o
wrapper deve detectar a falha de `SetActiveVersion`/`SetActiveEnvironment`, emitir
`blockingReasons` específico e orientar omitir o parâmetro para usar o contexto ativo.

**Parâmetros específicos:**

- `-ForceRebuild` (Boolean, default `false` — quando `true`, equivale a `Rebuild All`
  da IDE: muda `SpecifyAll`/`GenerateOnly` de incremental para regeneração total de
  TODOS os objetos da KB; em KB grande pode levar horas; **só pode ser habilitado via
  `-AllowWideRebuild`** — tentativa sem essa autorização é bloqueada por política
  com exit 46)
- `-DetailedNavigation` (Boolean, default `false`)
- `-AllowWideRebuild` (switch — único caminho autorizado para habilitar
  `-ForceRebuild true`; em modo interativo exige que o usuário digite a frase exata
  `entendo que isto pode regerar a KB inteira e aceito o custo`; em modo não-interativo
  requer `-ConfirmWideRebuild`; com `ForceRebuild=false`, o switch é redundante: o
  wrapper registra warning em `warnings`, não pede a frase exata e mantém
  `AllowWideRebuildConfirmed=false`)
- `-ConfirmWideRebuild` (switch — usado em conjunto com `-AllowWideRebuild` para
  dispensar o `Read-Host` interativo da frase de confirmação; destina-se a processos
  desanexados onde não há terminal disponível; proibido sem `-AllowWideRebuild`; o
  chamador é responsável por confirmar com o usuário humano antes de passar este
  parâmetro)

**Categorias de resultado:**

- `specify e generate concluídos` — ambas as etapas passaram com exitCode 0, stdout sem padrões de alerta após filtro de ruído estrutural conhecido em stdout (ver padrões abaixo) e sem conteúdo real em stderr após filtro de ruído estrutural conhecido
- `reorg detectada ou executada` — padrão `Reorganiza` encontrado em stdout; `SpecifyAll` disparou reorganização real de banco de dados; não declarar sucesso; apresentar ao usuário e aguardar instrução explícita
- `operação concluída, pendente de confirmação funcional` — exitCode 0, mas impedimentos detectados: stderr não vazio, padrões de alerta (`Access denied`) ou eventos pós-build em stdout
- `erro de specify` — `SpecifyAll` falhou; objetos com referências inválidas ou inconsistência
- `erro de generate` — `GenerateOnly` falhou após specify bem-sucedido
- `KB inacessível` — `OpenKnowledgeBase` falhou antes de qualquer etapa de build

> **Comportamento crítico conhecido — SpecifyAll não é leve quando há alterações estruturais pendentes:**
> A task `SpecifyAll` do GeneXus executa internamente: Database Impact Analysis,
> geração de `ReorganizationScript.txt` e `bldReorganization.cs`, **reorganização real
> do banco** (`gxexec bldReorganization.cs`), especificação, segunda geração e
> **eventos pós-build** configurados na KB (ex.: `start cmd`, deploy automático).
> Esse comportamento é intrínseco à task quando o modelo tem alterações estruturais
> pendentes e independe de qualquer parâmetro do wrapper. `SpecifyAll` não expõe
> `FailIfReorg` nem equivalente — ao contrário de `BuildAll`. A classificação
> `reorg detectada ou executada` sinaliza este cenário como bloqueante.

> **Padrão conhecido — ruído estrutural do `dotnet publish` em `GAM\Platforms\NetCore*` (stdout):**
> Mesmo padrão e mesma lógica de filtro documentados em detalhe na seção
> `Invoke-GeneXusKbBuildAll.ps1` (assinaturas: `MSB3491` ou `NuGet.targets(...): error :`,
> sempre com mensagem de acesso negado e caminho contendo `\GeneXus\...\Library\GAM\Platforms\`).
> `Invoke-GeneXusKbSpecifyGenerate.ps1`
> aplica o mesmo filtro e popula `stdoutFilteredNoise` no diagnóstico.
>
> **Cobertura empírica:** a evidência da matriz 2×2 foi coletada via `BuildAll`. Não foi
> verificado empiricamente se `SpecifyAll` puro (sem compile) também dispara a fase de
> `Inicialização Integrada de Segurança` que origina o ruído. O filtro é seguro de qualquer
> forma: se o ruído não aparecer no fluxo `SpecifyGenerate`, o filtro é idempotente (não
> remove nada que não esteja lá); se aparecer, é removido com a mesma assinatura precisa.
> Quando houver primeira execução real que confirme presença ou ausência do ruído neste
> fluxo, atualizar a evidência empírica acima.

> **Padrão conhecido — ruído estrutural do GeneXus 18 em stderr:**
> O GeneXus 18 escreve exatamente 3 linhas `context [anonymous] 1:12 attribute component
> isn't defined` no stderr durante o `SpecifyAll`. `Invoke-GeneXusKbSpecifyGenerate.ps1`
> filtra esse padrão antes de classificar o status — uma execução bem-sucedida cujo stderr
> contenha apenas esse ruído é classificada como `specify e generate concluídos`. Ver nota
> expandida com evidência técnica completa na seção `Invoke-GeneXusKbBuildAll.ps1`.

### Invoke-GeneXusKbBuildAll.ps1

Equivalente à opção `Build All` do menu Build da IDE GeneXus: executa `BuildAll`, que
faz specify + generate + compile dos objetos alterados desde o último build (build
incremental). Detecta — mas não executa por padrão — reorg necessária. Esta é a etapa
cotidiana após import/edição. Para `Rebuild All` (regeneração total de TODOS os
objetos), ver `-ForceRebuild` abaixo, que **só pode ser usado com `-AllowWideRebuild`
e confirmação explícita** por frase exata.

**Parâmetros transversais:** mesmos do `Invoke-GeneXusKbSpecifyGenerate.ps1`.

**Parâmetros específicos:**

- `-ForceRebuild` (Boolean, default `false` — quando `true`, equivale a `Rebuild All`
  da IDE: muda a semântica de `BuildAll` incremental para regeneração total de TODOS
  os objetos da KB, independentemente de mudança; em KB grande pode levar horas e
  regenerar centenas/milhares de objetos, incluindo subtype groups; **só pode ser
  habilitado via `-AllowWideRebuild`** — tentativa sem essa autorização é bloqueada
  por política com exit 46)
- `-CompileMains` (Boolean, default `false` — compila apenas Developer Menu)
- `-DetailedNavigation` (Boolean, default `false`)
- `-FailIfReorg` (Boolean, default `true` — bloqueia build se houver reorg pendente)
- `-DoNotExecuteReorg` (Boolean, default `false`)
- `-AllowReorg` (switch — quando presente, define `FailIfReorg=false` e
  `DoNotExecuteReorg=false`; em modo interativo exige que o usuário digite `sim` no
  terminal; em modo não-interativo requer `-ConfirmReorg`)
- `-ConfirmReorg` (switch — usado em conjunto com `-AllowReorg` para dispensar o
  `Read-Host` interativo; destina-se a processos desanexados onde não há terminal
  disponível, como quando `Watch-GeneXusMsBuildLog.ps1` roda em paralelo; proibido
  sem `-AllowReorg`; o chamador é responsável por confirmar com o usuário humano
  antes de passar este parâmetro)
- `-AllowWideRebuild` (switch — único caminho autorizado para habilitar
  `-ForceRebuild true`; em modo interativo exige que o usuário digite no terminal
  a frase exata `entendo que isto pode regerar a KB inteira e aceito o custo`; em
  modo não-interativo requer `-ConfirmWideRebuild`; gate independente do gate de
  reorg — `-AllowReorg` não autoriza regeneração ampla, e `-AllowWideRebuild` não
  autoriza reorg; com `ForceRebuild=false`, o switch é redundante: o wrapper registra
  warning em `warnings`, não pede a frase exata e mantém `AllowWideRebuildConfirmed=false`)
- `-ConfirmWideRebuild` (switch — usado em conjunto com `-AllowWideRebuild` para
  dispensar o `Read-Host` interativo da frase de confirmação; destina-se a processos
  desanexados onde não há terminal disponível; proibido sem `-AllowWideRebuild`; o
  chamador é responsável por confirmar com o usuário humano com a frase exata antes
  de passar este parâmetro)
- `-Configuration` (String, opcional — valores válidos: `Release`, `Debug`,
  `Performance Test`; quando informado, emite `SetConfiguration` imediatamente antes
  do `BuildAll`; quando omitido, a configuração ativa da KB é mantida sem alteração)
- `-MonitorLogPath` (String, opcional — caminho do arquivo gravado pelo parâmetro
  `-MonitorLog` de `Watch-GeneXusMsBuildLog.ps1`; quando fornecido e o arquivo existir
  após o build, o script extrai os timestamps das fases internas (`iniciado`/`terminado`)
  e popula `timing.phases` no JSON de resultado; sem este parâmetro, `timing.phases`
  fica vazio mas `timing.probeDurationSeconds`, `timing.msbuildDurationSeconds` e
  `timing.totalDurationSeconds` são sempre gravados; obrigatório quando `-StartWatcher`
  for passado — bloqueado por política com exit 46 se ausente)
- `-StartWatcher` (switch — quando presente, o próprio wrapper dispara
  `Watch-GeneXusMsBuildLog.ps1` em janela visível com `Start-Process pwsh` antes de
  iniciar o MSBuild; requer `-MonitorLogPath`; o watcher recebe o PID do processo
  wrapper como alvo de monitoramento; o resultado JSON inclui `watcherContext` com
  `watcherLaunched`, `watcherPid`, `watcherScriptPath`, `watcherMonitorLogPath` e
  `watcherLaunchError`; se o watcher falhar ao iniciar, o build prossegue com warning —
  não bloqueia a execução)
- `-WatcherIntervalSeconds` (Int, default `5` — intervalo de polling em segundos
  repassado ao watcher; usado apenas quando `-StartWatcher` está presente;
  intervalo válido: 1-60)
- `-WatcherSilenceThresholdSeconds` (Int, default `120` — segundos sem nova linha
  no log antes de o watcher emitir alerta de silêncio; repassado ao watcher; usado
  apenas quando `-StartWatcher` está presente; intervalo válido: 30-3600)

  > **Limitação conhecida de `timing.phases`:** somente fases com par completo
  > (`iniciado` + `terminado`) aparecem na lista. Fases cujo `terminado` nunca é
  > emitido — por erro ou abort — são silenciosamente omitidas (ex.: `Atualização
  > de configuração da web` quando o GeneXus falha antes de concluí-la). Pares com
  > grafia inconsistente entre `iniciado` e `terminado` (ex.: `Get Active Version`
  > vs `GetActiveVersion`) são normalizados e fechados corretamente; o campo `name`
  > no JSON usa a grafia do `terminado`.

**Categorias de resultado:**

- `compilou limpo` — `BuildAll` concluiu com exitCode 0, sem reorg detectada, stderr vazio após filtro de ruído estrutural conhecido e stdout sem padrões de erro após filtro de ruído estrutural conhecido em stdout (ver padrões abaixo)
- `compilou com erros` — `BuildAll` falhou por erro de compilação
- `reorg necessária detectada` — `FailIfReorg=true` bloqueou o build; reorg gerada mas
  não executada; usuário deve decidir o próximo passo
- `timeout em KB grande` — wrapper encerrou por timeout mas MSBuild pode ainda estar
  executando; distinguir timeout do invocador de falha real do MSBuild antes de concluir;
  usar `Watch-GeneXusMsBuildLog.ps1` com o PID do processo e o caminho do log para
  acompanhar a execução em andamento sem depender do chat

> **Padrão de orquestração para builds longos com monitor em paralelo:**
> Quando `Watch-GeneXusMsBuildLog.ps1` for usado em paralelo com um build de KB grande,
> o chamador deve iniciar `Invoke-GeneXusKbBuildAll.ps1` como processo desanexado via
> `Start-Process pwsh`. Nesse caso, `Read-Host` não tem terminal disponível. Use
> `-AllowReorg -ConfirmReorg` juntos — nunca redirecione stdin como workaround.
> O chamador é responsável por confirmar com o usuário humano antes de lançar o processo.
>
> Para obter timing por fase no JSON de resultado, defina um caminho para o log do
> monitor e conecte os dois scripts: passe `-MonitorLog <caminho>` ao Watch e o mesmo
> `<caminho>` como `-MonitorLogPath` ao build. O build parseia esse arquivo após
> terminar e popula `timing.phases` com os timestamps de cada fase interna.
- `KB inacessível` — `OpenKnowledgeBase` falhou antes do build
- `operação concluída, pendente de confirmação funcional` — exitCode 0, reorg não
  detectada, mas stderr não vazio após filtro de ruído estrutural, ou marcador de
  conclusão não detectado; validação funcional depende de inspeção na IDE

> **Padrão conhecido — ruído estrutural do `dotnet publish` em `GAM\Platforms\NetCore*` (stdout):**
> O `BuildAll` em environments .NET Core (NETPostgreSQL, NETCoreSQLServer e similares)
> dispara, na fase `Inicialização Integrada de Segurança`, o comando:
> ```
> dotnet publish -nologo -v q -p:GenInit=false
>   "C:\Program Files (x86)\GeneXus\GeneXus18\Library\GAM\Platforms\<NetCore*>\GxDeps.csproj"
>   -o "C:\Program Files (x86)\GeneXus\GeneXus18\Library\GAM\Platforms\<NetCore*>"
> ```
> Quando o processo não roda elevado (ver Restrição Operacional de Leitura em
> `10-base-operacional-msbuild-headless.md`), o `dotnet publish` pode falhar com
> `error MSB3491` ao tentar gravar `PublishOutputs.<hash>.txt` em
> `\Library\GAM\Platforms\build\GxDeps\obj\net*\`, ou com a variante
> `NuGet.targets(...): error : Access to the path ... is denied` ao tentar gravar
> temporários sob `\Library\GAM\Platforms\<NetCore*>\obj\`. Esses caminhos ficam sob
> `C:\Program Files (x86)\` — área tratada como estritamente somente leitura pela skill
> por política explícita. Apesar do erro, a fase reporta `Sucesso`, o GAM permanece
> registrado normalmente e o build prossegue sem efeito funcional na KB.
>
> `Invoke-GeneXusKbBuildAll.ps1` filtra esse padrão antes de classificar o status. As
> linhas removidas ficam em `stdoutFilteredNoise` do diagnóstico. Uma execução bem-sucedida
> cujo único padrão bloqueante em stdout seja esse ruído é classificada como `compilou limpo`.
>
> **Assinaturas do filtro:**
> - assinatura 1: linha contém `error MSB3491`, `is denied` (EN) **ou** `acesso negado`
>   (PT-BR), e caminho contendo `\GeneXus\` **e** `\Library\GAM\Platforms\`
> - assinatura 2: linha contém `NuGet.targets(...): error :`, `is denied` (EN) **ou**
>   `acesso negado` (PT-BR), e caminho contendo `\GeneXus\` **e** `\Library\GAM\Platforms\`
>
> Linhas que casem apenas alguns dos critérios (ex.: `MSB3491` em projeto da KB,
> `NuGet.targets` fora da árvore de instalação do GeneXus ou `Access denied` fora de
> `\Library\GAM\Platforms\`) **não são filtradas** — são
> diagnósticos legítimos.

> **Evidência empírica acumulada (ruído GAM/NetCore):**
> Coleta controlada em 2026-05-12, GeneXus 18 Up 14, em duas KBs distintas e dois
> environments cada (matriz 2×2):
>
> | KB | Environment | Generator | `MSB3491` em stdout |
> |---|---|---|---|
> | `wsEducacaoSpTeste` | `NETPostgreSQL` | .NET Core | presente |
> | `wsEducacaoSpTeste` | `NETFrameworkSQLServer` | .NET Framework | ausente |
> | `FabricaBrasil18` | `NETPostgreSQL` | .NET Core | presente |
> | `FabricaBrasil18` | `.Net Environment` | .NET Framework | ausente |
>
> O arquivo target `PublishOutputs.<hash>.txt` é literalmente o mesmo entre KBs distintas
> — é asset compartilhado da instalação do GeneXus, não da KB. A versão GAM no banco
> (`4.1.5` em ambas) permanece idêntica antes e depois, com ou sem elevação. Comparação
> elevado vs não-elevado em `wsEducacaoSpTeste/NETPostgreSQL` confirmou que a falha do
> `dotnet publish` não tem efeito funcional observável: stdout difere em uma única linha
> (a do `MSB3491`); todo o resto — versão GAM, warnings, fases, artefatos gerados em
> `C:\KBs\<kb>\<env>\web\` — é idêntico.
>
> Conclusão: o ruído é determinístico, originário da política de leitura-apenas da
> skill aplicada sobre `C:\Program Files (x86)\GeneXus\GeneXus18\Library\GAM\Platforms\`,
> e sem consequência funcional. O filtro é seguro porque cada assinatura é ancorada
> simultaneamente no formato do erro, na mensagem de acesso negado e no caminho de
> instalação do GeneXus, não no padrão genérico `Access denied`.
>
> **Observação sobre cobertura desta matriz (atualização 2026-05-20):** os builds
> da matriz 2×2 acima foram limpos em modo headless sem PATH enriquecido — porque
> nenhum deles atingiu a fase `Atualização de configuração da web` ou
> `DeveloperMenu Compilação`. Quando essas fases são atingidas, builds headless sem
> PATH enriquecido com subdirs do GeneXus 18 falham com mensagem genérica
> `O sistema não pode encontrar o arquivo especificado` (ou, em .NET Framework, a
> versão verbose `gxexec ... Não foi possível encontrar uma parte do caminho`).
> Ver nota "Padrão conhecido — subdirs do GeneXus 18 e PATH herdado em headless"
> abaixo. A política de enriquecimento aplicada pelos wrappers elimina esse modo
> de falha; a matriz histórica é preservada como evidência do estado das KBs em
> 2026-05-12.

> **Padrão conhecido — subdirs do GeneXus 18 e PATH herdado em headless:**
> Tasks internas do MSBuild GeneXus invocam binários auxiliares (`gxexec`,
> `UpdConfigWeb`, `BuildService`, `Reor.exe`) por nome, sem caminho absoluto,
> esperando subdirs do install já presentes em `$env:PATH`. A IDE GeneXus enriquece
> esse PATH implicitamente; um MSBuild lançado por wrapper externo herda apenas o
> PATH do shell do agente, que tipicamente não inclui esses subdirs. Sintomas:
> falha em `DeveloperMenu Compilação para Default (.NET Framework)` ou
> `Atualização de configuração da web`, com `Build All Task falhou` e
> `MsBuildExitCode=1`.
>
> Os wrappers `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1`
> aplicam enriquecimento automático de `$env:PATH` após resolver `$resolvedGeneXusDir`,
> com lista fixa: raiz `GeneXus18\`, `gxnet\`, `gxnet\bin\`, `gxnetcore\`. Filtro por
> `Test-Path` tolera instalações não-padrão. O resultado é registrado em
> `observedContext.pathEnrichment` do JSON, com `applied` (booleano), `subdirsAdded`
> e `subdirsSkipped`. Subdirs esperados ausentes geram warning em `warnings[]`.
>
> **Evidência empírica (FabricaBrasil18, GeneXus 18 Up 14, 2026-05-20):**
>
> | Rodada | PATH | Status | exit | MsBuildExitCode | BuildAllDone | Duração |
> |---|---|---|---|---|---|---|
> | baseline | default (sem GeneXus) | `compilou com erros` | 45 | 1 | false | 90 s |
> | manual | enriquecido pelo invocador | `compilou limpo` | 0 | 0 | true | 261 s |
> | pós-fix | enriquecido pelo próprio wrapper | `compilou limpo` | 0 | 0 | true | (idem) |
>
> Detalhes técnicos em `10-base-operacional-msbuild-headless.md`, seção "Achado
> Empírico Sobre Subdirs Do GeneXus E PATH Em Headless".

> **Padrão conhecido — ruído estrutural do GeneXus 18 em stderr:**
> O GeneXus 18 escreve exatamente 3 linhas `context [anonymous] 1:12 attribute component
> isn't defined` no stderr durante o `SpecifyAll` — task executada internamente pelo
> `BuildAll` e diretamente por `Invoke-GeneXusKbSpecifyGenerate.ps1`. O próprio GeneXus
> não conta isso como erro: stdout reporta "0 avisos, 0 erros". Evidência empírica
> acumulada: FabricaBrasil18 e wsEducacaoSpTeste em 2026-05-10, environments
> `.Net Environment`, `NETFrameworkSQLServer` e `NETPostgreSQL`, sempre 3 ocorrências,
> mesma posição `1:12`, independente do conteúdo ou de alterações recentes na KB.
> Origem técnica rastreada: `SpecifyAll` invoca `Genexus.MsBuild.Tasks.dll`, que
> referencia `Artech.Genexus.Common` e `Antlr4.StringTemplate`; o warning vaza do
> runtime de templates StringTemplate durante a montagem da changed objects list, antes
> de qualquer especificação real. A IDE absorve essa saída sem registrá-la no `Build.log`;
> artefatos gerados em modo headless são equivalentes aos gerados pela IDE. Ambos os
> scripts filtram esse padrão antes de classificar o status — uma execução bem-sucedida
> cujo stderr contenha apenas esse ruído é classificada como `compilou limpo` /
> `specify e generate concluídos`.

### Invoke-GeneXusDbImpact.ps1

Gera o script de impacto de banco (`ImpactDatabaseOnly`) sem executar a reorganização.
Equivalente ao `PreviewMode` de importação: mostra o que mudaria no banco antes de
qualquer decisão de execução. Usar quando `BuildAll` reportar `reorg necessária detectada`
e o usuário quiser inspecionar antes de autorizar.

**Parâmetros transversais:** mesmos dos scripts anteriores.

**Parâmetros específicos:**

- `-Force` (Boolean, default `false` — força geração do script mesmo que GeneXus ache desnecessário)
- `-EnvironmentName` (String, opcional — Environment a usar; se omitido, usa o ativo)

> `FromModel` e `Model` são propriedades públicas da task confirmadas por reflexão do
> assembly, mas sua semântica exata não foi validada empiricamente. Não emitir sem
> teste controlado que confirme o comportamento esperado.

**Categorias de resultado:**

- `impacto gerado` — script de impacto produzido; caminho do artefato disponível para inspeção
- `nada a reorganizar` — task concluiu sem gerar script de alteração
- `KB inacessível` — `OpenKnowledgeBase` falhou antes da task
- `operação concluída, pendente de confirmação funcional` — exitCode 0, mas o script de impacto ainda precisa ser inspecionado antes de qualquer decisão

**Status:** a implementar.

### Invoke-GeneXusDbReorg.ps1

Executa o script de reorg já gerado (`ReorganizeOnly`), sem repetir o ciclo completo de
`BuildAll`. Usar quando `ImpactDatabaseOnly` já foi executado e inspecionado e o usuário
autoriza explicitamente a execução. Exige confirmação interativa obrigatória.

**Parâmetros transversais:** mesmos dos scripts anteriores.

**Parâmetros específicos:**

- `-DoCreate` (Boolean, default `false` — se `true`, cria também os objetos novos além de alterar os existentes)

**Categorias de resultado:**

- `reorg executada` — script de impacto executado; banco alterado
- `nada a reorganizar` — nenhum script pendente para executar
- `KB inacessível` — `OpenKnowledgeBase` falhou antes da task
- `falha de reorg` — execução do script falhou; banco pode estar em estado parcial

**Status:** a implementar após `Invoke-GeneXusDbImpact.ps1` validado empiricamente.

---

## ORQUESTRAÇÃO — PASSO A PASSO EXECUTÁVEL

Esta seção descreve o fluxo completo para executar `Invoke-GeneXusKbBuildAll.ps1`
com `Watch-GeneXusMsBuildLog.ps1` em paralelo, sem bloquear a conversa com o usuário.

### Por que processo desanexado

`Invoke-GeneXusKbBuildAll.ps1` usa `Start-Process` internamente para o MSBuild e
`Wait-Process` para aguardar o resultado. Se chamado diretamente pelo agente via
PowerShell tool, bloqueia o agente durante todo o build — que pode durar minutos.
A solução é lançar o script como processo filho desanexado e usar `run_in_background: true`
no `Wait-Process` externo, liberando o agente para conversar com o usuário enquanto
o build corre.

### Passo 1 — Preparar pastas e caminhos

```powershell
$testDir    = "C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\xpz-build-<nome-descritivo>"
New-Item -Path $testDir -ItemType Directory -Force | Out-Null

$monitorLog  = "$testDir\monitor.log"
$buildLog    = "$testDir\build-all.log"
$buildStdout = "$testDir\build-proc-stdout.txt"
$buildStderr = "$testDir\build-proc-stderr.txt"
```

- `$testDir` fica sob `Temp\` do repositório da skill — processos filhos têm permissão de escrita aqui.
- Nunca usar `C:\Temp\` ou pastas fora do repositório — processos desanexados não têm acesso.
- Escolher um nome descritivo que identifique o build (ex.: `xpz-build-20260508-pos-import`).

### Passo 2 — Capturar dirs existentes antes de iniciar

```powershell
$artifactBase = "C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\xpz-msbuild-build"
$dirsBefore   = @([System.IO.Directory]::GetDirectories($artifactBase))
```

O script cria um dir com GUID aleatório em `$artifactBase`. Capturar a lista antes
do início permite identificar o dir novo por diferença — sem depender de timestamp.

### Passo 3 — Iniciar o build como processo desanexado

```powershell
$scriptPath = "C:\Dev\Knowledge\GeneXus-XPZ-Skills\scripts\Invoke-GeneXusKbBuildAll.ps1"

$buildArgs = @(
    '-NonInteractive', '-NoProfile', '-File', $scriptPath,
    '-KbPath',         'C:\KBs\<nome-da-kb>',
    '-WorkingDirectory', $testDir,        # obrigatório — pasta já criada no passo 1
    '-LogPath',          $buildLog,       # onde o JSON de resultado será gravado
    '-MonitorLogPath',   $monitorLog,     # conecta com Watch para timing.phases
    '-StartWatcher'                       # wrapper lança o watcher automaticamente
    # adicionar '-AllowReorg', '-ConfirmReorg' apenas se reorg foi autorizada pelo usuário
)

$buildProc = Start-Process pwsh -ArgumentList $buildArgs `
    -RedirectStandardOutput $buildStdout `
    -RedirectStandardError  $buildStderr `
    -NoNewWindow -PassThru
```

- `-WorkingDirectory`: pasta criada no passo 1 — não inventar outro caminho.
- `-LogPath`: onde o JSON de resultado será gravado ao final do build.
- `-MonitorLogPath`: mesmo caminho do log do monitor — obrigatório quando `-StartWatcher` está presente.
- `-StartWatcher`: o wrapper dispara `Watch-GeneXusMsBuildLog.ps1` automaticamente antes do MSBuild; elimina o passo 5 do fluxo externo quando usado.
- `-NoNewWindow`: build roda invisível em segundo plano.
- `-PassThru`: retorna o objeto de processo com o PID.

> **Com `-StartWatcher`, o Passo 5 (Watch externo) pode ser omitido** — o wrapper já cuidou do lançamento. O Passo 4 (aguardar artifact dir) ainda é necessário quando se quer o `msbuildLog` para fins de diagnose, mas não para o watcher em si.

### Passo 4 — Aguardar o artifact dir aparecer

```powershell
$artifactDir = $null
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 500
    $newDirs = @([System.IO.Directory]::GetDirectories($artifactBase) |
                 Where-Object { $dirsBefore -notcontains $_ })
    if ($newDirs.Count -gt 0) { $artifactDir = $newDirs[0]; break }
}
if ($null -eq $artifactDir) {
    # build falhou antes de criar o dir — ler stderr para diagnose
    return
}
$msbuildLog = Join-Path $artifactDir "msbuild.stdout.log"
```

- O loop aguarda até 20 s (40 × 500 ms). Em hardware lento pode ser necessário aumentar.
- **Usar diff de arrays** (`$dirsBefore -notcontains $_`), nunca indexar `[0]` diretamente
  no resultado do `Where-Object` — quando há um único resultado, indexar retorna o primeiro
  **caractere** da string, não o item.

### Passo 5 — Abrir Watch em janela visível

```powershell
$watchScript = "C:\Dev\Knowledge\GeneXus-XPZ-Skills\scripts\Watch-GeneXusMsBuildLog.ps1"

Start-Process pwsh -ArgumentList @(
    '-NoExit',                            # janela permanece aberta após o Watch terminar
    '-NoProfile',
    '-File',    $watchScript,
    '-ProcessId',   $buildProc.Id,
    '-LogPath',     $msbuildLog,          # msbuild.stdout.log dentro do artifact dir
    '-MonitorLog',  $monitorLog,          # mesmo caminho que -MonitorLogPath do build
    '-IntervalSeconds', '5'               # default; diminuir só em testes curtos
)
```

- Sem `-NoNewWindow` e sem redirect: Watch abre em janela nova visível ao usuário.
- `-NoExit`: a janela permanece aberta após Watch encerrar, para o usuário ler com calma e fechar manualmente.
- Watch exibe o contador de silêncio in-place (sem scroll) e imprime uma nova linha apenas quando há conteúdo real (fase, alerta, início/fim).
- O arquivo `$monitorLog` recebe apenas linhas reais — não o contador de silêncio.

### Passo 6 — Aguardar em background sem bloquear a conversa

```powershell
# Este bloco deve ser executado com run_in_background: true no PowerShell tool.
# O agente fica disponível para conversar com o usuário enquanto o build corre.
# Quando Wait-Process retornar, o runtime notifica o agente automaticamente.

Write-Host "Build PID=$($buildProc.Id) | Watch aberto | aguardando..."
$buildProc | Wait-Process -Timeout 600    # 10 min; ajustar para KBs grandes
Write-Host "BUILD CONCLUIDO | exit=$($buildProc.ExitCode) | log=$buildLog"
```

**Importante:** o bloco inteiro (incluindo `Wait-Process`) deve estar em um único
comando com `run_in_background: true`. Não dividir em dois comandos separados.

### Passo 7 — Ler o resultado quando notificado

Quando a notificação de conclusão chegar, ler o JSON com o `Read` tool (sem prompt de permissão):

```
Read tool → $buildLog (build-all.log)
```

Campos relevantes:
- `status` — categoria de resultado (ver EXPECTED INTERFACE)
- `exitCode` — código de saída classificado pelo wrapper (0 quando `compilou limpo`/`specify e generate concluídos`, valor não nulo quando há impedimento ou falha); também é o exit code do processo. O valor bruto da task MSBuild aparece canonicamente em `executionEvidence.msBuildExitCode`. `observedContext.MsBuildExitCode` (PascalCase, dentro do contexto observado), quando presente, é contexto observado/compatibilidade e não substitui o campo canônico; `msBuildExitCode` top-level, quando existir por compatibilidade transitória em algum wrapper, deve duplicar o valor canônico.
- `executionEvidence` — evidência bruta da execução (`msBuildExitCode`, `msBuildFailed`, `wrapperExitCode`, logs brutos); `blockingReasons` deve priorizar causas acionáveis e não repetir o exit code bruto quando uma causa específica já existir
- `summary` — descrição legível do resultado
- `timing.msbuildDurationSeconds` — duração do MSBuild em segundos
- `timing.phases` — lista de fases com `name`, `start`, `end`, `durationSeconds`
- `observedContext.ReorgDetected` — se reorg foi detectada
- `stdoutSignals` — sinais estruturados de stdout: `blockingPattern` (primeiro padrão bloqueante detectado APÓS filtro de ruído estrutural, ou `null`), `postBuildEvents` (linhas `start c:` / `start cmd`, com prefixo `(commented) ` quando o GeneXus encenou o comando como comentado), `buildWarnings` (linhas de warning com posição; warnings `pmm00xx` de versão de módulo são adicionalmente promovidos a `warnings` top-level — ver nota abaixo)
- `stdoutFilteredNoise` — ruído estrutural removido de stdout antes de classificar (ex: linhas `error MSB3491` ou `NuGet.targets(...): error :` do `dotnet publish` em `GAM\Platforms\NetCore*` quando rodando sem elevação); quando o único conteúdo bloqueante em stdout for ruído filtrado, o build é classificado como limpo
- `stderrContent` — linhas reais de stderr após remoção do ruído estrutural do GeneXus 18
- `stderrFilteredNoise` — ruído estrutural removido de stderr; quando `stderrContent` está vazio e `stderrFilteredNoise` tem conteúdo, o build é limpo e nenhuma recomendação de IDE deve ser emitida

> **Promoção de warnings `pmm00xx` (versão de módulo) a `warnings` top-level:**
> Warnings GeneXus de família `pmm00xx` (ex.: `pmm0003` "módulo deve ser atualizado para versão N", `pmm0045` "version conflict") sinalizam estado da KB que precisa de atenção do usuário — tipicamente resolvido via `Update Modules` na IDE. Como `buildWarnings` é lista interna que o usuário raramente inspeciona, esses warnings são adicionalmente surfacados em `warnings` (top-level) do diagnóstico, com texto orientativo:
>
> - Caso geral: `Alerta de versao de modulo (pmm00xx): <mensagem original>. Resolver via 'Update Modules' na IDE.`
> - Caso `pmm0045` (inversão de versão — módulo satélite exige versão MAIS NOVA do módulo principal do que a instalada): texto adicional explicando que pode exigir update do GeneXus instalado ou downgrade de módulos da KB; inspecionar via `Update Modules` na IDE.
>
> A promoção é **somente para visibilidade** — não muda classificação de status (warnings continuam sendo warnings, não viram erros). O build pode ser `compilou limpo` ou `specify e generate concluídos` mesmo com `pmm00xx` presentes.

### Observações críticas

- **Não usar `C:\Temp\`** para nenhum arquivo: processos filhos desanexados não têm acesso.
- **Não bloquear** a conversa com `Wait-Process` sem `run_in_background: true`.
- **`-ConfirmReorg` sem `-AllowReorg`** é bloqueado pelo script (exit 46) — nunca passar um sem o outro.
- **`-ConfirmReorg`** substitui o `Read-Host` interativo, mas não dispensa a confirmação do usuário humano — obtê-la antes de lançar o processo.
- **Ler resultado com `Read` tool**, não com `PowerShell(Get-Content ...)` — evita prompt desnecessário.
- **Lançamento elevado (`Start-Process -Verb RunAs`):** quando o build for disparado com elevação UAC para experimento controlado, **não confiar em `Wait-Process`** sobre o objeto retornado por `Start-Process -PassThru` — esse PID pode ser o broker/launcher do UAC, não o `pwsh` elevado real. `Wait-Process` retorna prematuramente quando o broker termina, deixando o build ainda em execução. Estratégia confiável: **polling do `LogPath` (arquivo final do wrapper)** — esse arquivo só aparece quando o script termina, tanto no caminho de sucesso quanto no de falha (`status: falha operacional`); aguardar a existência **e** a estabilidade do tamanho do arquivo. Cenário válido apenas para experimentos controlados — `-Verb RunAs` não é fluxo regular da skill.

---

## WORKFLOW

1. Reler [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md)
   como referência de infraestrutura antes de qualquer operação
2. Confirmar que o ambiente já passou por probe (`Test-GeneXusMsBuildSetup.ps1`) ou
   realizar o probe agora — esta skill não substitui a validação de ambiente
3. Confirmar que `C:\Program Files (x86)` será tratada como somente leitura
4. Identificar o objetivo:
   - verificação pós-import cirúrgico → `Invoke-GeneXusKbSpecifyGenerate.ps1`
   - validação completa incluindo compilação → `Invoke-GeneXusKbBuildAll.ps1`
4a. Se o objetivo for `Invoke-GeneXusKbSpecifyGenerate.ps1`, avaliar sinais de alteração
    estrutural no contexto do import recente:
    - `importedItems` do log de import contém qualquer objeto `Attribute:` → sinal presente
    - usuário mencionou mudança de tamanho, tipo, precisão ou subtipo de atributo → sinal presente
    - execução anterior nesta sessão retornou `reorg detectada ou executada` → sinal presente
    Se qualquer sinal estiver presente:
    - exibir aviso: "Esta execução pode disparar reorganização real de banco de dados,
      pois o import recente contém alterações estruturais em atributo. A task SpecifyAll
      do GeneXus executa reorg internamente quando o modelo tem mudanças estruturais
      pendentes. Para prosseguir, confirme com a frase exata:"
    - `entendo que haverá reorg e concordo que prossiga`
    - aguardar a frase exata do usuário — não aceitar paráfrases ou confirmações genéricas
    - só então executar o script
4b. Se o usuário informar `-Configuration`:
    - confirmar que o valor é `Release`, `Debug` ou `Performance Test`
    - emitir `SetConfiguration` como step imediatamente anterior ao `BuildAll`
    - registrar o valor emitido no log e no diagnóstico
5. Validar explicitamente `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory`,
   `LogPath` e existência de `Genexus.Tasks.targets`
6. Resolver `GeneXusDir` e `MsBuildPath` por ordem explícita de precedência e fallback,
   registrando origem e descarte de candidatos
7. Se o objetivo for `BuildAll` com reorg autorizada (`-AllowReorg`):
   - apresentar ao usuário o que reorg significa neste contexto
   - exigir confirmação explícita antes de prosseguir
   - só então emitir `FailIfReorg=false` e `DoNotExecuteReorg=false`
7a. Se o objetivo envolver `-ForceRebuild=true` (em `BuildAll` ou `SpecifyGenerate`):
    - apresentar ao usuário o que isso significa neste contexto: equivale a
      `Rebuild All` da IDE, regenera TODOS os objetos da KB independentemente de
      mudança, pode levar horas e regenerar centenas/milhares de objetos em KB grande
    - exigir a frase exata `entendo que isto pode regerar a KB inteira e aceito o custo`
      — não aceitar paráfrases ou confirmações genéricas
    - só então passar `-AllowWideRebuild` (e `-ConfirmWideRebuild` se em processo
      desanexado, após obter a frase do usuário humano)
    - gate independente do gate de reorg: `-AllowReorg` não autoriza `-ForceRebuild=true`,
      e `-AllowWideRebuild` não autoriza reorg
8. Executar o script escolhido seguindo a seção **ORQUESTRAÇÃO — PASSO A PASSO EXECUTÁVEL**
   (para `BuildAll`: processo desanexado + Watch em janela visível + `run_in_background`) e capturar:
   - `exitCode`
   - resumo de `stdout`
   - resumo de `stderr`
   - caminho do `.msbuild` temporário
   - caminho do log
9. Escanear stdout e stderr por padrões de erro e risco antes de classificar, mesmo quando exitCode = 0:
   - padrão bloqueante máximo: `Reorganiza` em stdout → status `reorg detectada ou executada`; não declarar sucesso; informar ao usuário e aguardar instrução
   - eventos pós-build: linhas `start c:` ou `start cmd` em stdout → registrar como warning de processos externos disparados
   - stderr não vazio: qualquer conteúdo → registrar como warning; impede `specify e generate concluídos`
   - demais padrões relevantes: `Access denied`, `error MSB`, `: error `, `FAILED`, stack traces de exceção
   - **carve-out para ruído estrutural GAM/NetCore:** linhas que casam uma das assinaturas conhecidas (`error MSB3491` ou `NuGet.targets(...): error :`) junto com `is denied`/`acesso negado` e caminho contendo `\GeneXus\` e `\Library\GAM\Platforms\` são removidas de stdout antes desta varredura e listadas em `stdoutFilteredNoise`; padrões legítimos de `Access denied` em qualquer outro contexto **permanecem** bloqueantes
   - se encontrados: registrar no diagnóstico e usar `operação concluída, pendente de confirmação funcional` em lugar de `compilou limpo`
   Classificar então o resultado em uma das categorias definidas em EXPECTED INTERFACE
10. Quando o resultado for `reorg necessária detectada`:
    - informar ao usuário sem dramatizar
    - apresentar as três opções:
      a. inspecionar primeiro com `Invoke-GeneXusDbImpact.ps1` — gera o script de impacto para o usuário ver o que mudaria no banco
      b. autorizar reorg diretamente: via `-AllowReorg` em `BuildAll` ou via `Invoke-GeneXusDbReorg.ps1` após inspeção prévia
      c. abrir na IDE para decidir
    - aguardar instrução explícita
    - se o usuário escolher `Invoke-GeneXusDbImpact.ps1`: executar, apresentar resultado e caminho do script; só prosseguir para reorg após nova instrução explícita do usuário
    - se o usuário escolher `Invoke-GeneXusDbReorg.ps1`: exigir confirmação interativa mesmo que `ImpactDatabaseOnly` já tenha rodado na mesma sessão
11. Recomendar reabertura da KB na IDE somente se houver warning ou efeito colateral
    detectado no build (ex: extensão ausente, `Access denied`, stderr não vazio), ou se
    o contexto indicar que o objetivo é validar a aplicação em execução; não mencionar
    IDE nem URL quando o pedido foi apenas "faça um build" e o resultado foi limpo
12. Não declarar sucesso funcional apenas por `exitCode = 0`

---

## QUALITY CHECKLIST

- [ ] A skill foi tratada como capacidade operacional validada, com uso controlado
- [ ] `C:\Program Files (x86)` permaneceu estritamente somente leitura
- [ ] Ambiente validado por probe antes do build
- [ ] `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory` e `LogPath` foram
      explicitados
- [ ] Quando o objetivo era `Invoke-GeneXusKbSpecifyGenerate.ps1`, os sinais de alteração estrutural do import recente foram avaliados antes de executar
- [ ] Quando havia sinal de alteração estrutural, a confirmação com a frase exata foi exigida e obtida antes de executar
- [ ] `FailIfReorg=true` foi mantido como default em `BuildAll`, salvo instrução explícita
- [ ] Reorg só foi autorizada após confirmação explícita do usuário
- [ ] `-ForceRebuild=true` (equivalente a `Rebuild All`) só foi usado mediante pedido
      explícito do usuário, com aviso do custo apresentado e frase exata
      `entendo que isto pode regerar a KB inteira e aceito o custo` obtida antes de
      passar `-AllowWideRebuild`
- [ ] Quando `reorg necessária detectada`, as três opções foram apresentadas ao usuário
- [ ] Quando `reorg detectada ou executada` (pós-SpecifyAll), o resultado foi apresentado ao usuário sem ser classificado como sucesso
- [ ] `Invoke-GeneXusDbImpact.ps1` foi executado antes de `Invoke-GeneXusDbReorg.ps1` quando o objetivo era inspecionar o impacto
- [ ] `Invoke-GeneXusDbReorg.ps1` recebeu confirmação interativa explícita, mesmo quando precedida de `ImpactDatabaseOnly`
- [ ] `stdout`, `stderr`, `exitCode`, `.msbuild` e log foram registrados
- [ ] `executionEvidence.msBuildExitCode` foi registrado como local canônico do valor bruto da task MSBuild; `msBuildExitCode` top-level, quando existir, foi tratado apenas como compatibilidade transitória e duplicação do valor canônico
- [ ] `observedContext.pathEnrichment` registrou o enriquecimento preventivo do `PATH` (`applied`, `subdirsAdded`, `subdirsSkipped`)
- [ ] O resultado foi classificado em categoria explícita
- [ ] Sucesso operacional foi separado de confirmação funcional
- [ ] Quando a frente foi descrita por fluxo funcional ("o objeto que X", "a tela que abre ao Y", "o objeto chamado quando Z") em vez de referência direta ao nome, foi confirmado que o objeto em `importedItems` é o alvo executado pelo fluxo descrito antes de declarar a frente encerrada — independente do tipo de objeto
- [ ] `watcherContext.watcherLaunched` foi verificado no JSON de resultado; se `false`, a ausência foi documentada e justificada explicitamente

---

## CONSTRAINTS

- NEVER gravar qualquer artefato em `C:\Program Files (x86)`
- NEVER executar `BuildAll` sem watcher sem justificativa operacional explícita e documentada — usar `-StartWatcher` é o fluxo padrão; ausência de watcher deve ser declarada ao usuário com base em `watcherContext.watcherLaunched: false` no JSON
- NEVER executar reorg sem autorização explícita do usuário
- NEVER emitir `FailIfReorg=false` implicitamente — sempre explicitar quando e por quê
- NEVER passar `-ConfirmReorg` sem `-AllowReorg` — combinação bloqueada por política (exit 46)
- NEVER usar `-ConfirmReorg` sem ter obtido confirmação explícita do usuário humano antes
  de lançar o processo — o parâmetro muda o canal de confirmação, não dispensa a confirmação
- NEVER passar `-ForceRebuild true` sem `-AllowWideRebuild` — combinação bloqueada por
  política (exit 46) tanto em `Invoke-GeneXusKbBuildAll.ps1` quanto em
  `Invoke-GeneXusKbSpecifyGenerate.ps1`
- NEVER passar `-ConfirmWideRebuild` sem `-AllowWideRebuild` — combinação bloqueada por
  política (exit 46)
- NEVER passar `-ForceRebuild true` em fluxo pós-import cotidiano nem como "validação
  completa automática" — `BuildAll` incremental (sem `-ForceRebuild`) é o passo correto
- NEVER usar `-ConfirmWideRebuild` sem ter obtido a frase exata
  `entendo que isto pode regerar a KB inteira e aceito o custo` do usuário humano antes
  de lançar o processo — o parâmetro muda o canal de confirmação, não dispensa a
  confirmação
- NEVER aceitar paráfrases ou confirmações genéricas no lugar da frase exata de
  confirmação de regeneração ampla
- NEVER depender de `GeneXus Server` como base operacional desta skill
- NEVER tratar `exitCode = 0` isolado como confirmação funcional
- NEVER classificar como `compilou limpo` quando stdout ou stderr contiver padrões de erro (`Access denied`, `error MSB`, `: error `, `FAILED`, stack traces) fora do ruído estrutural GAM/NetCore documentado, mesmo que exitCode = 0
- NEVER classificar como `specify e generate concluídos` quando stdout contiver padrão `Reorganiza` — o status correto é `reorg detectada ou executada`
- NEVER tratar stderr não vazio como irrelevante — qualquer conteúdo em stderr deve ser registrado como warning e impede classificação como `specify e generate concluídos`
- NEVER chamar `Invoke-GeneXusKbSpecifyGenerate.ps1` quando houver sinal de alteração estrutural de atributo no import recente sem a confirmação explícita do usuário com a frase `entendo que haverá reorg e concordo que prossiga`
- NEVER aceitar paráfrases ou confirmações genéricas no lugar da frase exata de confirmação de reorg
- NEVER executar `Invoke-GeneXusDbReorg.ps1` sem confirmação interativa explícita do usuário, mesmo quando `ImpactDatabaseOnly` já foi executado na mesma sessão
- NEVER emitir `FromModel` ou `Model` em `ImpactDatabaseOnly` sem validação empírica prévia do comportamento desses parâmetros nesta instalação
- NEVER emitir `SetConfiguration` implicitamente ou inferir o valor de configuração desejado
- ABORT se `KbPath`, versão, `Environment` ou destino de logs estiverem ambíguos
- ABORT se não houver ambiente controlado compatível com a fase solicitada
