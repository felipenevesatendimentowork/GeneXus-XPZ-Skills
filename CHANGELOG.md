# Changelog

Todas as mudanças relevantes deste repositório serão registradas aqui a partir desta adoção. O histórico anterior permanece distribuído em `historico/`, commits e documentação de frente.

## Português (BR)

O formato segue a ideia de manter uma seção `Unreleased` para mudanças ainda não publicadas em versão formal. Este repositório ainda não adota versionamento semântico público; quando isso mudar, as seções futuras devem registrar a tag correspondente.

### Unreleased

- Padronizados wrappers compartilhados de empacotamento, inventário e sanidade XPZ para JSON por padrão no stdout, sem `-AsJson`, com bloqueios estruturados e aliases operacionais `-InputPath`/`-ObjectList`.
- Adicionado gate para opções caras de build MSBuild: `CompileMains=true` e `DetailedNavigation=true` agora exigem `-AllowCostlyBuildOptions` com confirmação explícita.
- Alinhada a descoberta e a rastreabilidade dos documentos de governança em `README.md`, `09-inventario-e-rastreabilidade-publica.md` e `historico/IdeiasImplementadas_202606.md`.
- Alinhados `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md` e `999-ideias-pendentes.md` após a nova regra de changelog na pré-push.
- Incorporada à rotina pré-push a avaliação semântica obrigatória de `CHANGELOG.md` para mudanças com impacto público.
- Documentado no guia de contribuição que a revisão pré-push deve avaliar atualização do `CHANGELOG.md`.
- Adicionados documentos públicos de governança: `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` e `CHANGELOG.md`.

## Español

Todos los cambios relevantes de este repositorio se registrarán aquí a partir de esta adopción. El historial anterior permanece distribuido en `historico/`, commits y documentación de frentes de trabajo.

El formato mantiene una sección `Unreleased` para cambios aún no publicados en una versión formal. Este repositorio todavía no adopta versionado semántico público; cuando eso cambie, las secciones futuras deberán registrar la etiqueta correspondiente.

### Unreleased

- Estandarizados los wrappers compartidos de empaquetado, inventario y sanidad XPZ para JSON por defecto en stdout, sin `-AsJson`, con bloqueos estructurados y aliases operativos `-InputPath`/`-ObjectList`.
- Agregado gate para opciones costosas de build MSBuild: `CompileMains=true` y `DetailedNavigation=true` ahora exigen `-AllowCostlyBuildOptions` con confirmación explícita.
- Alineada la localización y trazabilidad de los documentos de gobernanza en `README.md`, `09-inventario-e-rastreabilidade-publica.md` e `historico/IdeiasImplementadas_202606.md`.
- Alineados `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md` y `999-ideias-pendentes.md` después de la nueva regla de changelog en la revisión previa al push.
- Incorporada a la rutina previa al push la evaluación semántica obligatoria de `CHANGELOG.md` para cambios con impacto público.
- Documentado en la guía de contribución que la revisión previa al push debe evaluar la actualización de `CHANGELOG.md`.
- Agregados documentos públicos de gobernanza: `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` y `CHANGELOG.md`.

## English

All relevant changes to this repository will be recorded here from this adoption onward. Earlier history remains distributed across `historico/`, commits, and work-front documentation.

The format keeps an `Unreleased` section for changes not yet published in a formal version. This repository does not yet use public semantic versioning; when that changes, future sections should record the corresponding tag.

### Unreleased

- Standardized shared XPZ packaging, inventory, and sanity wrappers to emit JSON by default on stdout, without `-AsJson`, with structured blocks and operational `-InputPath`/`-ObjectList` aliases.
- Added a gate for costly MSBuild options: `CompileMains=true` and `DetailedNavigation=true` now require `-AllowCostlyBuildOptions` with explicit confirmation.
- Aligned discovery and traceability of governance documents in `README.md`, `09-inventario-e-rastreabilidade-publica.md`, and `historico/IdeiasImplementadas_202606.md`.
- Aligned `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, and `999-ideias-pendentes.md` after the new changelog rule in pre-push review.
- Added mandatory semantic evaluation of `CHANGELOG.md` to the pre-push routine for changes with public impact.
- Documented in the contribution guide that pre-push review should evaluate updates to `CHANGELOG.md`.
- Added public governance documents: `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and `CHANGELOG.md`.
