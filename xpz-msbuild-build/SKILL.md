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
`Invoke-GeneXusKbSpecifyGenerate.ps1` para verificação leve pós-import e
`Invoke-GeneXusKbBuildAll.ps1` para validação completa. Nunca execute reorg sem
autorização explícita do usuário.

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
- classificar resultado de build em categorias operacionais explícitas
- apoiar decisão do usuário sobre o próximo passo após import

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

Verificação leve: executa `SpecifyAll` seguido de `GenerateOnly`. Sem compilação, sem
reorg. Mais rápido e mais seguro para o primeiro check após import cirúrgico.

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

- `specify e generate concluídos` — ambas as etapas passaram sem erro operacional
- `erro de specify` — `SpecifyAll` falhou; objetos com referências inválidas ou inconsistência
- `erro de generate` — `GenerateOnly` falhou após specify bem-sucedido
- `KB inacessível` — `OpenKnowledgeBase` falhou antes de qualquer etapa de build
- `operação concluída, pendente de confirmação funcional` — exitCode 0, mas validação
  funcional ainda depende de build completo ou inspeção na IDE

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
  `DoNotExecuteReorg=false`; exige confirmação interativa antes de prosseguir)

**Categorias de resultado:**

- `compilou limpo` — `BuildAll` concluiu sem erro e sem reorg detectada
- `compilou com erros` — `BuildAll` falhou por erro de compilação
- `reorg necessária detectada` — `FailIfReorg=true` bloqueou o build; reorg gerada mas
  não executada; usuário deve decidir o próximo passo
- `timeout em KB grande` — wrapper encerrou por timeout mas MSBuild pode ainda estar
  executando; distinguir timeout do invocador de falha real do MSBuild antes de concluir
- `KB inacessível` — `OpenKnowledgeBase` falhou antes do build
- `operação concluída, pendente de confirmação funcional` — exitCode 0, reorg não
  detectada, mas validação funcional real depende de inspeção na IDE

---

## WORKFLOW

1. Reler [10-base-operacional-msbuild-headless](../10-base-operacional-msbuild-headless.md)
   como referência de infraestrutura antes de qualquer operação
2. Confirmar que o ambiente já passou por probe (`Test-GeneXusMsBuildSetup.ps1`) ou
   realizar o probe agora — esta skill não substitui a validação de ambiente
3. Confirmar que `C:\Program Files (x86)` será tratada como somente leitura
4. Identificar o objetivo:
   - verificação leve pós-import cirúrgico → `Invoke-GeneXusKbSpecifyGenerate.ps1`
   - validação completa incluindo compilação → `Invoke-GeneXusKbBuildAll.ps1`
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
9. Classificar o resultado em uma das categorias definidas em EXPECTED INTERFACE
10. Quando o resultado for `reorg necessária detectada`:
    - informar ao usuário sem dramatizar
    - apresentar as opções: executar reorg com `-AllowReorg`, ou abrir na IDE para decidir
    - aguardar instrução explícita
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
- [ ] `FailIfReorg=true` foi mantido como default em `BuildAll`, salvo instrução explícita
- [ ] Reorg só foi autorizada após confirmação explícita do usuário
- [ ] `stdout`, `stderr`, `exitCode`, `.msbuild` e log foram registrados
- [ ] O resultado foi classificado em categoria explícita
- [ ] Sucesso operacional foi separado de confirmação funcional

---

## CONSTRAINTS

- NEVER gravar qualquer artefato em `C:\Program Files (x86)`
- NEVER executar reorg sem autorização explícita do usuário
- NEVER emitir `FailIfReorg=false` implicitamente — sempre explicitar quando e por quê
- NEVER depender de `GeneXus Server` como base operacional desta skill
- NEVER tratar `exitCode = 0` isolado como confirmação funcional
- ABORT se `KbPath`, versão, `Environment` ou destino de logs estiverem ambíguos
- ABORT se não houver ambiente controlado compatível com a fase solicitada
