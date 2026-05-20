# Ideias Implementadas

Registro de ideias que sairam de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Setup popula `kb-source-metadata.md` a partir da KB nativa, sem depender do XPZ

**Importancia original:** alta
**Status:** concluida em 2026-05-20

### Origem

Investigacao iniciada em 2026-05-17 a partir de relato da pasta paralela `C:\Dev\Test\Gx_wsEducacaoSpTeste`. A IDE GeneXus exportava `.xpz` com `<Source />` vazio em pelo menos dois caminhos de export, deixando `kb-source-metadata.md` sem `Source/@kb` e `Source/Version/@guid`. Como `Test-GeneXusImportFileEnvelope.ps1` bloqueia `Source` vazio, empacotamentos posteriores dependiam de workaround inadequado como `SkipGate`.

### Implementacao

- `scripts/Resolve-GeneXusKbIdentity.ps1`: motor compartilhado somente leitura para resolver identidade estavel da KB nativa local.
- `scripts/Update-XpzKbSourceMetadataIdentity.ps1`: atualizador conservador dos campos de identidade estavel em `kb-source-metadata.md`, preenchendo ausentes e bloqueando divergencias nao vazias sem aprovacao explicita.
- `xpz-kb-parallel-setup/examples/Resolve-KbIdentity.example.ps1`: wrapper sanitizado para reconstrucao local controlada.
- `xpz-kb-parallel-setup/SKILL.md`: setup inicial com KB nativa confirmada deve resolver identidade antes de declarar `kb-source-metadata.md` apto; metadata ausente, incompleto ou ilegivel e bloqueado pelos gates de metadata; divergencia preenchida contra a KB nativa ficou registrada como frente futura em `999-ideias-pendentes.md`; correcao de campos ausentes ou divergentes usa o atualizador somente em frente aprovada.
- `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `README.md`, `09-inventario-e-rastreabilidade-publica.md`, `xpz-builder/SKILL.md` e `xpz-msbuild-import-export/SKILL.md`: regras alinhadas para autoridade de campo, bloqueio cross-KB e rastreabilidade operacional.

### Decisao final

A frente do `Resolve` esta encerrada. O fluxo normal downstream continua lendo `kb-source-metadata.md`; `Resolve` nao vira fallback ad hoc de `xpz-sync`, `xpz-builder` ou import MSBuild. Se no futuro surgir necessidade de wrapper adicional ou automacao local especifica, isso deve ser tratado como nova frente: o agente deve estudar a documentacao vigente e propor o caminho aplicavel naquele contexto.

### Rastreabilidade privada

O exemplo sanitizado `xpz-kb-parallel-setup/examples/Resolve-KbIdentity.example.ps1` foi registrado no `GeneXus-XPZ-PrivateMap`, ligado ao alias privado `KB_Teste_Paralela_A`.

## Wrapper compartilhado para auditoria de naming de `ObjetosDaKbEmXml`

**Importância:** média
**Maturidade:** implementada em 2026-05-18

**Origem:** avaliacao de sugestao de agente externo em 2026-05-01.

**Status em 2026-05-18:** promovida para implementacao no motor compartilhado como `scripts/Test-XpzObjetosDaKbNaming.ps1`, com wrapper exemplo `xpz-kb-parallel-setup/examples/Test-KbObjetosDaKbNaming.example.ps1` e integracao em `scripts/Test-XpzSetupAudit.ps1`.

### Problema concreto que motiva a ideia

A verificacao de naming dos diretorios de container em `ObjetosDaKbEmXml` e executada hoje como procedimento narrado pelo agente seguindo o bloco `8.g2` da `xpz-kb-parallel-setup`. O fluxo esta bem especificado — cobre todos os diretorios sem excecao, exige leitura de pelo menos um XML por diretorio, mapeia o GUID de `Object/@type` para o nome canonico via catalogo e produz saida estruturada em tabela — mas depende de interpretacao local do agente a cada sessao.

O risco pratico nao e de ambiguidade na regra, mas de variancia entre execucoes: agentes distintos podem diferir na forma de localizar o XML, nomear as colunas da tabela ou reportar a evidencia, mesmo seguindo a mesma secao da skill.

### Ideia de melhoria implementada

Adicionar ao motor compartilhado um script `Test-XpzObjetosDaKbNaming.ps1` que:

- receba como entrada o caminho de `ObjetosDaKbEmXml`
- liste todos os subdiretorios presentes
- leia pelo menos um XML por diretorio, extraia o elemento raiz ou `Object/@type`
- mapeie o GUID para o nome canonico usando o mesmo catalogo ja consumido por `Build-KbIntelligenceIndex.py`
- emita saida estruturada por diretorio com as colunas `Diretorio`, `Tipo real encontrado`, `Status` e, quando divergente, `Nome canonico esperado`
- retorne `NAMING_OK` quando todos os diretorios estiverem conformes, `NAMING_DIVERGENT: <lista>` quando houver inversao ou `NAMING_INDETERMINADO: <lista>` quando houver diretorio sem XML classificavel ou GUID desconhecido

O wrapper local de cada pasta paralela chamaria esse script e repassaria o resultado ao handoff, em vez de o agente executar o mapeamento inline.

### Criterio que justificou implementar

O limiar de maturidade foi atingido apos novo relato operacional em 2026-05-18: loops PowerShell inline para naming em pastas paralelas estavam gerando atrito recorrente, parser fragil e necessidade de scripts temporarios em `Temp/`. A implementacao consolida a verificacao no motor compartilhado e permite que `Test-XpzSetupAudit.ps1` reporte `naming/objetos-da-kb` de forma deterministica.

### Perguntas a responder antes de decidir

- O catalogo de GUIDs em `01a-catalogo-e-padroes-empiricos.md` ja esta em formato consumivel por um script PowerShell, ou exigiria extracao adicional?
- O script deve ficar no motor compartilhado (ao lado de `Build-KbIntelligenceIndex.py`) ou como wrapper exemplo desta skill, seguindo o padrao dos `*.example.ps1`?
- A saida estruturada do script deve ser consumida diretamente pelo `Test-*KbSetupAudit.ps1` ou reportada separadamente no handoff?
- Como manter sincronia entre o catalogo de GUIDs e o mapeamento interno do script sem duplicar a fonte autoritativa?

## ENCERRADO — Gate 9-WW estruturalmente errado para WorkWithForWeb do acervo

**Status:** RESOLVIDO em 2026-05-15/16 em duas etapas.

**Etapa 1 (2026-05-15)** — a prosa do gate 9-WW em `xpz-builder/SKILL.md` foi corrigida para reconhecer ambos os formatos estruturais (Form A: Part `babfa2b2-...` no formato de empacotamento; Form B: Part `a51ced48-...` com `<Data Pattern="...">` no acervo materializado). CONSTRAINTS, QUALITY CHECKLIST e o caveat em 9-IDO também foram atualizados.

**Etapa 2 (2026-05-16)** — sub-fase 1.2 do refator estrutural concluída: o gate 9-WW foi extraído para `scripts/Test-GeneXusWorkWithWebApply.ps1` com 10 códigos de finding cobrindo detecção de forma, leitura de Apply (Form A) ou Apply implícito True (Form B), resolução de linked Transaction nos dois formatos, e verificação de `Apply:78cecefe-...=True` na Transaction em batch ou corpus. Validado contra `Gx_FabricaBrasil` (WorkWithWebCarga → Carga com Apply:GUID=True → pass).

**Pendência residual menor:** a detecção WorkWithForWeb → linked Transaction em `Test-GeneXusBatchDependencyOrdering.ps1` (gate 9-IDO) continua não-wired ao script, mesmo que o algoritmo agora exista em `Test-GeneXusWorkWithWebApply.ps1`. O caveat em 9-IDO do SKILL.md ainda exige que o agente verifique essa dimensão de ordenação manualmente quando o batch contém WorkWithForWeb e a Transaction linkada juntos. Pode ser fechado em frente futura reusando `Get-WorkWithForWebDetails` em 9-IDO.

**Importância:** alta
**Maturidade:** pesquisa feita

**Origem:** descoberta empírica em 2026-05-15 durante refator da Fase 1 do `xpz-builder` (sub-fase 1.2 da extração de gates determinísticos para scripts). O gate 9-WW foi suspenso da Fase 1 e a sub-fase 1.3 (9-PSM) tomou seu lugar até que esta correção seja decidida.

### Problema concreto que motiva a ideia

O gate 9-WW em `xpz-builder/SKILL.md` instrui localizar o Part `babfa2b2-19a0-4ef1-b5f4-81b7c7be79dc` dentro de cada `WorkWithForWeb` no batch ativo e ler `<Property><Name>Apply</Name>` em `<Source><Properties>`. Validação empírica contra a KB de teste `Gx_wsEducacaoSpTeste`: nenhum dos 10 WorkWithForWeb materializados em `ObjetosDaKbEmXml/WorkWithForWeb/` contém esse Part.

O Part `babfa2b2-...` é estrutura de **molde de empacotamento** documentada em `01e-moldes-sanitizados-core.md` (linha 1718), não de acervo materializado. WorkWithForWeb tem duas formas estruturais distintas conforme contexto:

- **acervo materializado** (`ObjetosDaKbEmXml/WorkWithForWeb/*.xml`): Part `a51ced48-7bee-0001-ab12-04e9e32123d1` com Data Pattern em CDATA; link com Transaction via `<transaction transaction="<guid>-<name>" />` dentro do CDATA.
- **pacote `import_file.xml`** ou XML gerado a partir de molde sanitizado: Part `babfa2b2-...` com `<Source><Properties><Property>Apply</Property>...`.

Implicação: o gate como está hoje aborta com falso-positivo `ww-apply-property-absent` (equivalente, na prosa atual) em qualquer batch que contenha WorkWithForWeb copiado ou extraído do acervo oficial. Casos cobertos legitimamente pelo gate (XML em formato de empacotamento) ficam misturados com casos cobertos errado (XML em formato de acervo) sem distinção.

### Direção técnica proposta

Antes de extrair o gate para script (continuação da Fase 1 do refator), o gate deve ser fortalecido para entender ambos os formatos:

- detectar a forma estrutural do WorkWithForWeb pelo Part presente:
  - se Part `babfa2b2-...` existe: ler `Apply` e `Transaction` de `<Source><Properties>` desse Part (lógica atual da prosa).
  - se Part `a51ced48-...` existe e contém `<Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b">`: ler o link Transaction de `<transaction transaction="<guid>-<name>" />` no CDATA; tratar `Apply` como implicitamente `True` (objeto materializado pelo pattern existe).
- continuar a verificação de `Apply:78cecefe-be7d-4980-86ce-8d6e91fba04b = True` na Transaction linkada — esse Property vive em `<Object>/<Properties>` e tem o mesmo padrão nos dois formatos.

### Decisões em aberto

- O agente pode confiar em "objeto materializado no acervo => pattern já aplicado por construção"? Há cenário em que o WorkWithForWeb do acervo tem `updateTransaction="Apply WW Style"` (visto em `WorkWithWebCarga.xml`) com semântica diferente do `Apply=True/False` do formato empacotamento?
- Quando o batch contém ambos os formatos para o mesmo objeto (raro mas possível em frente longa), qual prevalece para a verificação do gate?
- A correção é só do bloco 9-WW em `xpz-builder/SKILL.md`, ou também das CONSTRAINTS e do QUALITY CHECKLIST que se referenciam ao Part `babfa2b2-...` (linhas 691, 765, 766) usando a mesma premissa errada?

### Limiar para implementar

Implementar antes da retomada da sub-fase 1.2 do refator estrutural do `xpz-builder` (extração do gate 9-WW para `scripts/Test-GeneXusWorkWithWebApply.ps1` ou similar). Sem essa correção, o script extraído replicaria o bug em código e o problema ficaria mais difícil de tratar depois.

## ENCERRADO — Gate de parse AST para `scripts/*.ps1` e `.example.ps1` das skills

**Importância:** baixa
**Maturidade:** implementada

**Origem:** revisão pré-push de 2026-05-16 sobre os gates da Fase 9 do `xpz-builder`; sugestão original do agente revisor ("smoke de parse AST em CI seria útil"); discussão e fechamento de design na mesma sessão.

**Encerramento:** implementado em 2026-05-18 com `scripts/Test-PsScriptsParse.ps1`, workflow `.github/workflows/parse-ps-scripts.yml` e alinhamento documental do contrato `pwsh >= 7.4`.

### Objetivo

Pegar regressão sintática silenciosa em scripts PowerShell mantidos por esta raiz antes que ela apareça na próxima execução real do gate ou na próxima cópia de um `.example.ps1` para wrapper local de pasta paralela de KB.

### Design fechado

Combo de duas peças:

1. **Script local** `scripts/Test-PsScriptsParse.ps1`:
   - Varre `scripts/*.ps1` e `**/*.example.ps1` da raiz
   - Para cada arquivo, chama `[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errs)`
   - Reporta cada erro com path, linha e mensagem
   - Sai com código `0` se tudo limpo, `1` se houver pelo menos um erro de parse
   - Invocável manualmente e integrável na rotina de revisão pré-push descrita no `AGENTS.md`

2. **Workflow GitHub Actions** `.github/workflows/parse-ps-scripts.yml`:
   - Dispara em `push` e `pull_request` com filtro `paths: ['scripts/**/*.ps1', '**/*.example.ps1']`
   - Roda em `windows-latest` com shell explícito `pwsh`, validando o contrato operacional `PowerShell >= 7.4`
   - Único step relevante: invocar `scripts/Test-PsScriptsParse.ps1`
   - Não duplica lógica — o workflow é apenas o gatilho

### Contrato de runtime decidido em 2026-05-18

- Runtime mínimo suportado para os scripts desta raiz: `pwsh` com PowerShell 7.4 LTS ou superior.
- Runtime recomendado: versão LTS mais recente disponível.
- Premissa de parque: usuários das skills XPZ podem ter pelo menos Windows 10 nas máquinas.
- Windows PowerShell 5.1 (`powershell.exe`) não é runtime suportado para os scripts da base; parse ou execução em 5.1 pode falhar e não deve bloquear a evolução dos scripts.
- O workflow deve testar o contrato real (`pwsh >= 7.4`), não compatibilidade legada com 5.1.

### Escopo

- `scripts/*.ps1` — todos, não só `Test-GeneXus*.ps1`; cobre wrappers `Build-*`, `Invoke-*`, `Sync-*`, etc.
- `**/*.example.ps1` em qualquer skill — esses arquivos viram molde de wrapper local em pasta paralela de KB (regra explícita no `README.md` raiz: "exemplos metodológicos importantes para bootstrap técnico e reconstrução assistida de wrappers locais"); se quebrarem parse, viram fonte de cópia ruim
- Excluído: scripts dentro de `historico/`, se houver

### Limitações conhecidas

- Parse AST é puramente sintático. **Não pega** bugs sob `Set-StrictMode -Version Latest` em runtime (ex: `.Count` em null, `-split` retornando escalar quando não há separador, propriedade XML inexistente acessada por shorthand). Essa categoria continua coberta pela memória global do usuário (`feedback_*`) e por disciplina de teste pós-edição.
- **Não garante** comportamento funcional dos scripts; só garante que os arquivos carregam sintaticamente no runtime contratado.
- **Não cobre** Windows PowerShell 5.1, por decisão explícita de contrato operacional.

### Revisão de premissas em 2026-05-18

Durante a revisão da própria pendência, foi executado parse manual de 70 arquivos no escopo atual:

- Em `pwsh` 7.6.1: `FILES=70; ERRORS=0`.
- Em Windows PowerShell 5.1: foram reportados erros de parse em scripts que passam em `pwsh`; isso confirmou que 5.1 não deve ser usado como contrato de compatibilidade.

O bloqueio anterior ("não há gatilho concreto") deixou de valer porque a decisão de runtime foi fechada: validar automaticamente `pwsh >= 7.4` é uma melhoria pequena, objetiva e alinhada ao contrato da base.

### Correção aplicada

- Criado `scripts/Test-PsScriptsParse.ps1`, com `#requires -Version 7.4`, varredura de `scripts/*.ps1` e `**/*.example.ps1` fora de `historico/`, relatório textual/JSON e exit code `1` em erro de parse.
- Criado workflow `.github/workflows/parse-ps-scripts.yml`, usando `windows-latest` com shell explícito `pwsh`, checagem de versão mínima e chamada ao script local.
- Ajustado `.gitignore` com exceção estreita para versionar workflows `.github/workflows/*.yml`.
- Atualizado `xpz-builder/quality-checklist.md` para apontar para o script compartilhado e remover a premissa de Windows PowerShell 5.1.
- Registrado o contrato de runtime em `README.md`, `02-regras-operacionais-e-runtime.md` e `08-guia-para-agente-gpt.md`.

### Critério de aceite

- `scripts/Test-PsScriptsParse.ps1` executa em `pwsh` 7.4+ e reporta zero erros no escopo atual.
- O workflow delega a lógica ao script local, sem duplicar a varredura.
- A documentação correlata não contradiz mais o contrato de runtime.

### Relacionado

- `xpz-builder/quality-checklist.md` (seção *PowerShell script hygiene*) foi alinhado ao contrato `pwsh >= 7.4`.

## ENCERRADO — Atributo `[ordered]` inválido em declaração de parâmetro em `Test-GeneXusKbConsistency.ps1`

**Importância:** baixa
**Maturidade:** implementada

**Origem:** detectado em revisão pré-push de 2026-05-17 ao validar `Parser.ParseFile` no script após rename de campo JSON.

**Encerramento:** corrigido em 2026-05-18; as três declarações agora usam `[System.Collections.Specialized.OrderedDictionary]`.

### Problema concreto

Antes da correção, três funções de `scripts/Test-GeneXusKbConsistency.ps1` declaravam parâmetro com tipo `[ordered]`:

- linha 327: `Resolve-ScriptExitCode` — `param([int]$MsBuildExitCode, [ordered]$ConsistencyResult)`
- linha 338: `Resolve-StatusLabel` — `param([int]$ScriptExitCode, [ordered]$ConsistencyResult)`
- linha 350: `Resolve-SummaryText` — `param([int]$ScriptExitCode, [ordered]$ConsistencyResult, [bool]$FixMode)`

`[ordered]` é um atributo de literal hashtable (`[ordered]@{...}`), não um tipo válido para anotação de parâmetro. `Parser.ParseFile` reporta:

> The ordered attribute can be specified only on a hash literal node.

O teste de 2026-05-18 mostrou que o Windows PowerShell não era permissivo nesse caso: o script não carregava, mesmo com `-ExecutionPolicy Bypass`, porque o erro era de parse.

### Correção aplicada

Foi trocado `[ordered]$ConsistencyResult` por `[System.Collections.Specialized.OrderedDictionary]$ConsistencyResult` (tipo real) nas três funções.

### Critério de aceite

`ParseFile` retorna zero erros no script após o fix. Saída do script (JSON e exit codes) deve permanecer idêntica em rodada de fumaça de `KB consistente` e `inconsistências detectadas`.

### Relacionado

- Detecção feita durante a frente que normalizou `msbuildExitCode` → `msBuildExitCode` (commit `4531b14`); o flag foi diferido para esta entrada por estar fora do escopo daquela frente.
- Item de checklist em `xpz-builder/quality-checklist.md` (seção *PowerShell script hygiene*): "Every gate script edited in the round was re-parsed (...) and produced zero parse errors". Aplicar esse mesmo gate retroativamente neste script.
