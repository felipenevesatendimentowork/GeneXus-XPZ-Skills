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
para validação completa. Nunca execute reorg sem autorização explícita do usuário.
Quando houver evidência de alteração estrutural de atributo no import recente, exigir
confirmação explícita do usuário antes de chamar `Invoke-GeneXusKbSpecifyGenerate.ps1`.

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
- Distinguir claramente:
  - sucesso operacional da chamada MSBuild
  - efeito funcional observado depois no GeneXus
- Classificar o resultado de cada execução em uma das categorias definidas em WORKFLOW
- Registrar `stdout`, `stderr`, `exitCode`, caminho do `.msbuild` temporário e log
- Recomendar reabertura da KB na IDE após builds relevantes para observar warning ou
  efeito colateral de host
- Exigir confirmação explícita antes de qualquer execução de reorg
- Tratar `ImpactDatabaseOnly` como pré-requisito de inspeção antes de autorizar `ReorganizeOnly` explícito
- Exigir confirmação interativa obrigatória antes de `ReorganizeOnly`, mesmo quando `ImpactDatabaseOnly` já foi executado na mesma sessão
- Tratar `SetConfiguration` como operação auxiliar opcional de pré-build: só emitir
  quando explicitamente solicitado pelo usuário, com valor validado (`Release`, `Debug`,
  `Performance Test`)
- Nunca inferir ou alterar configuração sem instrução explícita
- Validar explicitamente `KbPath`, `GeneXusDir`, `MsBuildPath`, `WorkingDirectory`,
  `LogPath` e `Genexus.Tasks.targets` antes de qualquer build

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

**Parâmetros específicos:**

- `-ForceRebuild` (Boolean, default `false`)
- `-DetailedNavigation` (Boolean, default `false`)

**Categorias de resultado:**

- `specify e generate concluídos` — ambas as etapas passaram com exitCode 0, stderr vazio e sem padrões de alerta em stdout
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

> **Padrão conhecido:** `dotnet publish` dentro de `GAM\Platforms\*` pode registrar
> `Access denied` em stdout com exitCode 0. Esse padrão não é erro de specify/generate,
> mas impede classificar como `specify e generate concluídos` — usar `operação concluída,
> pendente de confirmação funcional` e listar o padrão encontrado no diagnóstico.

### Invoke-GeneXusKbBuildAll.ps1

Build completo: executa `BuildAll`, que faz specify + generate + compile e detecta (mas
não executa por padrão) reorg necessária.

**Parâmetros transversais:** mesmos do `Invoke-GeneXusKbSpecifyGenerate.ps1`.

**Parâmetros específicos:**

- `-ForceRebuild` (Boolean, default `false`)
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
- `-Configuration` (String, opcional — valores válidos: `Release`, `Debug`,
  `Performance Test`; quando informado, emite `SetConfiguration` imediatamente antes
  do `BuildAll`; quando omitido, a configuração ativa da KB é mantida sem alteração)
- `-MonitorLogPath` (String, opcional — caminho do arquivo gravado pelo parâmetro
  `-MonitorLog` de `Watch-GeneXusMsBuildLog.ps1`; quando fornecido e o arquivo existir
  após o build, o script extrai os timestamps das fases internas (`iniciado`/`terminado`)
  e popula `timing.phases` no JSON de resultado; sem este parâmetro, `timing.phases`
  fica vazio mas `timing.probeDurationSeconds`, `timing.msbuildDurationSeconds` e
  `timing.totalDurationSeconds` são sempre gravados)

  > **Limitação conhecida de `timing.phases`:** somente fases com par completo
  > (`iniciado` + `terminado` com nome idêntico) aparecem na lista. Fases cujo
  > `terminado` nunca é emitido — por erro ou abort — são silenciosamente omitidas.
  > Adicionalmente, o GeneXus emite alguns marcadores com grafia inconsistente entre
  > `iniciado` e `terminado` (ex.: `Get Active Version iniciado` /
  > `GetActiveVersion terminado`); esses pares também ficam de fora. Isso é comportamento
  > do GeneXus, não da skill.

**Categorias de resultado:**

- `compilou limpo` — `BuildAll` concluiu com exitCode 0, sem reorg detectada e sem padrões de erro em stdout/stderr
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
  detectada, mas validação funcional real depende de inspeção na IDE

> **Padrão conhecido:** `dotnet publish` dentro de `GAM\Platforms\*` pode registrar
> `Access denied` em stdout com exitCode 0. Esse padrão não é erro de compilação GeneXus,
> mas impede classificar como `compilou limpo` — usar `operação concluída, pendente de
> confirmação funcional` e listar o padrão encontrado no diagnóstico.

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
8. Executar o script escolhido e capturar:
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
11. Recomendar reabertura da KB na IDE quando o build for relevante ou quando houver
    warning estrutural (ex: extensão ausente)
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
- [ ] Quando `reorg necessária detectada`, as três opções foram apresentadas ao usuário
- [ ] Quando `reorg detectada ou executada` (pós-SpecifyAll), o resultado foi apresentado ao usuário sem ser classificado como sucesso
- [ ] `Invoke-GeneXusDbImpact.ps1` foi executado antes de `Invoke-GeneXusDbReorg.ps1` quando o objetivo era inspecionar o impacto
- [ ] `Invoke-GeneXusDbReorg.ps1` recebeu confirmação interativa explícita, mesmo quando precedida de `ImpactDatabaseOnly`
- [ ] `stdout`, `stderr`, `exitCode`, `.msbuild` e log foram registrados
- [ ] O resultado foi classificado em categoria explícita
- [ ] Sucesso operacional foi separado de confirmação funcional

---

## CONSTRAINTS

- NEVER gravar qualquer artefato em `C:\Program Files (x86)`
- NEVER executar reorg sem autorização explícita do usuário
- NEVER emitir `FailIfReorg=false` implicitamente — sempre explicitar quando e por quê
- NEVER passar `-ConfirmReorg` sem `-AllowReorg` — combinação bloqueada por política (exit 46)
- NEVER usar `-ConfirmReorg` sem ter obtido confirmação explícita do usuário humano antes
  de lançar o processo — o parâmetro muda o canal de confirmação, não dispensa a confirmação
- NEVER depender de `GeneXus Server` como base operacional desta skill
- NEVER tratar `exitCode = 0` isolado como confirmação funcional
- NEVER classificar como `compilou limpo` quando stdout ou stderr contiver padrões de erro (`Access denied`, `error MSB`, `: error `, `FAILED`, stack traces), mesmo que exitCode = 0
- NEVER classificar como `specify e generate concluídos` quando stdout contiver padrão `Reorganiza` — o status correto é `reorg detectada ou executada`
- NEVER tratar stderr não vazio como irrelevante — qualquer conteúdo em stderr deve ser registrado como warning e impede classificação como `specify e generate concluídos`
- NEVER chamar `Invoke-GeneXusKbSpecifyGenerate.ps1` quando houver sinal de alteração estrutural de atributo no import recente sem a confirmação explícita do usuário com a frase `entendo que haverá reorg e concordo que prossiga`
- NEVER aceitar paráfrases ou confirmações genéricas no lugar da frase exata de confirmação de reorg
- NEVER executar `Invoke-GeneXusDbReorg.ps1` sem confirmação interativa explícita do usuário, mesmo quando `ImpactDatabaseOnly` já foi executado na mesma sessão
- NEVER emitir `FromModel` ou `Model` em `ImpactDatabaseOnly` sem validação empírica prévia do comportamento desses parâmetros nesta instalação
- NEVER emitir `SetConfiguration` implicitamente ou inferir o valor de configuração desejado
- ABORT se `KbPath`, versão, `Environment` ou destino de logs estiverem ambíguos
- ABORT se não houver ambiente controlado compatível com a fase solicitada
