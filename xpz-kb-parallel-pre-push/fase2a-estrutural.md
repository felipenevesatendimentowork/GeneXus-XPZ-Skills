# Fase 2a — estrutural (higiene de frente e pacote)

Satélite de [`SKILL.md`](SKILL.md). A Fase 2a é **parcial scriptada** (o que é mecanicamente verificável vira gate) **+ checklist de agente** (o resto). Nunca bloqueia push — emite `warn` para o usuário decidir.

## Motor: `Test-XpzKbFrenteHygiene.ps1`

Motor compartilhado, agnóstico de KB, **filesystem-only** (não usa git). Valida a higiene das pastas de geração e de pacotes de importação da pasta paralela.

```text
pwsh -File <repo-skills>\scripts\Test-XpzKbFrenteHygiene.ps1 -RepoRoot <pasta-paralela-da-KB>
```

- **`-RepoRoot`** *(default: diretório corrente)* — raiz da pasta paralela.
- **`-FrentesDirName`** *(default: `ObjetosGeradosParaImportacaoNaKbNoGenexus`)* — pasta de geração por frente.
- **`-PacotesDirName`** *(default: `PacotesGeradosParaImportacaoNaKbNoGenexus`)* — pasta de pacotes.
- **`-AsText`** saída humana; **`-AsJson`** é no-op (JSON é o default).

### Cheques

- **Cheque 1 — subpasta de frente** deve seguir `NomeCurto_GUID_YYYYMMDD` (regra de `xpz-kb-parallel-setup`). `NomeCurto` pode conter underscores (frentes derivadas como `CriaAnimalRefatora_..._20260520_ba03` são legítimas); o GUID e o `YYYYMMDD` ancoram o final. Severidade: **warn**.
- **Cheque 2 — pacote** `<frenteName>_<nn>.{import_file.xml,xpz}` deve ter `<frenteName>` existindo como subpasta-fonte de frente. Pacote **órfão** = sem subpasta-fonte rastreável. Severidade: **warn**.

Ambos são `warn` (não bloqueiam) porque podem ter justificativa legítima (frente deletada após import bem-sucedido; frente experimental fora do padrão). O usuário decide aceitar ou corrigir.

### Contrato de saída

JSON de máquina por padrão. Campos: `status` (`ok`|`warn`), `exitCode`, `repoRoot`, `frentesValidas`, `frentesNaoConformes[]`, `pacotesOk`, `pacotesOrfaos[]`, `pacotesNaoPadronizados[]`. **Exit: 0 ok, 2 warn.** Fase 2a nunca bloqueia push.

## Nuance cabeça-detalhe (vinda do F1)

O filtro F1 (`Compare-XpzChecksums`, ver [`fase2b-classificador-de-regime.md`](fase2b-classificador-de-regime.md)) descarta arquivos `SAME` (checksum inalterado). **Atenção:** `SAME` no **arquivo** X não implica que a **cabeça/objeto** associado a X esteja fora do raio de impacto. Um objeto cabeça pode ter checksum inalterado enquanto seu **detalhe** (outro arquivo) mudou e carrega dependentes. "Descartar SAME cedo" é correto para o **arquivo**, mas o analista **não** pode concluir, só do `SAME`, que a cabeça está fora de escopo — a triagem estrutural (esta fase) e o roteamento de regime (2b) tratam disso.

## Checklist de agente (parte não scriptada)

Além dos dois cheques mecânicos, antes de declarar a Fase 2a saneada:

- [ ] A frente ativa vive na própria subpasta `NomeCurto_GUID_YYYYMMDD` (não na raiz de `ObjetosGeradosParaImportacaoNaKbNoGenexus`).
- [ ] Não há XML de referência/exemplo/template/molde deixado na subpasta da frente como se fosse objeto a importar.
- [ ] A pasta de pacotes está **plana** (sem subpastas por frente).
- [ ] Pacotes órfãos reportados pelo motor têm justificativa explícita (frente já importada/removida) ou foram corrigidos.
- [ ] Frentes não-conformes reportadas têm justificativa (experimental) ou foram renomeadas para o padrão.

O resultado da Fase 2a entra no relatório da rodada (molde em `examples/`) como `warn` consolidável, nunca como bloqueio automático.
