# AGENTS.md

## Ideias implementadas

- O registro de ideias implementadas deve usar arquivo mensal no formato `IdeiasImplementadas_YYYYMM.md`.
- Ao mudar o mes, criar um novo arquivo mensal em vez de continuar escrevendo no arquivo do mes anterior.
- Nao usar o nome antigo `IdeasImplementadas.md` para novas entradas.
- Antes de retirar uma entrada de `999-ideias-pendentes.md`, primeiro copiar ou mover a entrada completa para o arquivo mensal correspondente em `historico/` e validar a gravacao.
- Entradas novas em `IdeiasImplementadas_YYYYMM.md` devem incluir bloco `### Rastreabilidade` com pelo menos o hash e a mensagem curta do commit que materializou a frente, quando houver commit correspondente.
- Em `### Rastreabilidade`, registrar apenas commits **materiais** da frente: mudanca de comportamento, contrato JSON, scripts, docs normativos da mesma frente.
- Nao registrar commits puramente meta-documentais (ex.: alinhar rastreabilidade, corrigir redacao do historico). Isso evita cadeia artificial de commits que so listam commits.
- Commits de fechamento documental permanecem visiveis via `git log` ou `git blame` no arquivo mensal; a secao historica nao precisa espelhar o log completo.
- Na rotina pre-push, ausencia de commit meta-documental em `### Rastreabilidade` nao e gap — tratar como flag descartado com essa justificativa.
