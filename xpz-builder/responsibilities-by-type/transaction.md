# Transaction — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `Transaction` object type. **Load this file end-to-end before generating, editing, or packaging a `Transaction`**, in addition to the main `SKILL.md`.

This file consolidates type-specific RESPONSIBILITIES and QUALITY CHECKLIST entries. Type-agnostic rules (envelope serialization, package collision gate, manifest, etc.) remain in the main `SKILL.md`. Gate scripts (9-BC, 9-IDO, 9-TXW Writability, Transaction Coherence) are referenced here but live in `scripts/` and are invoked from the WORKFLOW in the main `SKILL.md`.

## Responsibilities

### Block classification and edit scope

- Classify the current delta by functional block before editing: `Transaction structure`, `Attributes and attribute properties`, `Rules`, `Events`, `Execution context`, or `Identity and container`.
- When changing a `Transaction`, declare the primary edit block before touching the XML, use only the adjacent blocks required by explicit functional dependency, name each justified block transition, and state whether the intended effect is via web editing, via BC, or both.

### Writability gate (attribute assignments)

- When the delta generates or reviews logic that assigns values to attributes accessed from a Transaction's base table, run the writability classification gate before any assignment is generated. Run `& ..\scripts\Test-GeneXusTransactionWritability.ps1 -TransactionPath <transaction.xml> -CorpusFolder <ObjetosDaKbEmXml> -AsJson`. The script returns a `levelAttributes` list where each item carries `classification` and `writable` (`true`, `false`, or `null` for edge cases). The 8 classifications cover the full algorithm: `key-attribute` (writable) for `key="True"` in the Level; `extended-parent-fk` (non-writable) for `isRedundant="True"` in the Level; `formula` (non-writable) for `Property Formula` in the Attribute XML; `extended-subtype-key` (writable) for SubTypeGroup member whose Supertype is PK in some Transaction; `extended-subtype-descriptive` (non-writable) for SubTypeGroup member whose Supertype is not PK in any Transaction; `extended-fk-key` (writable) when the attribute appears as Member in some Duplicate index of the Transaction's Table XML; `extended-fk-descriptive` (non-writable) when the attribute appears as `key="False"` of some FK entity reachable recursively from the Transaction's Table (max depth 10); `own-physical` (writable) when the attribute is absent from all FK entities in every explored depth. Edge cases return `unclassified-attribute-not-found` (Attribute XML standalone missing from corpus) or `unclassified-table-not-found` (Transaction's Table XML missing from corpus) — these require manual review against `08-guia-para-agente-gpt.md` before generating any assignment. Generating an assignment to an attribute the script reports as `writable=false` is a hard error — **ABORT**. Never conclude a Transaction's physical table has "only keys" before every `key="False"` attribute has been classified.
- When the delta involves `Rules` or `Events` blocks that generate attribute assignments, run the writability classification gate above before writing any assignment; do NOT generate assignments to non-writable attributes.

### Attribute serialization in packages

- For a new `Transaction` package, treat top-level `Attribute` items referenced by the `Level` as mandatory package members under `<Attributes>`, never as `Domain`/object payload under `<Objects>`.

### FK sustained by SubTypeGroup — Table review

- When a phase introduces a new FK sustained by `SubTypeGroup`, the structural review must not stop at the `Transaction` or at a pattern object linked to it.
- Also review the corresponding `Table`, focusing on `Transaction coupling and physical context` and `Secondary indexes and embedded index members`.
- If the new FK depends on later physical materialization or on an embedded index in the `Table`, treat `Transaction`, `SubTypeGroup`, and `Table` as the minimum review set for that phase.

### Evidence labels for Transaction catalogs (XPZ generation)

Canonical policy (Portuguese): [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md), subsection **Politica de evidencia para catalogos `Transaction` (geracao XPZ)** under **Politica para `Transaction`**.

Every row in a consultable catalog here (`on <event>`, `Event` types, symptom→error) must carry **exactly one** label:

| Label | Generation permission |
|-------|-------------------------|
| `confirmado-import` | Rejection/acceptance observed on MSBuild import with traceable message and `exitCode` — do not generate rejected syntax |
| `confirmado-build` | Observed on `BuildAll`/`SpecifyGenerate` (e.g. `spc0150`) — same |
| `confirmado-acervo` | Real use in parallel KB XML (`ObjetosDaKbEmXml/...` after sync) or reproducible sanitized template in `01*` | May generate, subject to writability and coherence gates |
| `padrao-gx-nao-verificado` | GeneXus convention/docs not tested in this base or parallel corpus in session | **Do not use as generation premise** — separate subsection only |
| `nao-listar` | No minimum evidence | **Do not publish** in the catalog |

Operational rules:

- **Generate only** syntax labeled `confirmado-import`, `confirmado-build`, or `confirmado-acervo`.
- Do not promote to `confirmado-*` from another agent’s report or an offline list alone; require reproducible import/build on the target KB, XML read in the parallel corpus, or a versioned sanitized template in this repo.
- Stable Specifier messages (e.g. `src0056`, `spc0150` with full text) may be documented under `confirmado-import` / `confirmado-build` without copying business `Transaction` XML into this repository.
- File-name examples (`Animal.xml`, etc.) with `confirmado-acervo` must state **parallel KB folder** (`ObjetosDaKbEmXml/...`) unless the example is a sanitized template in `01*`.
- Future catalog sections in this file (rules `on <event>`, `Events` restrictions) must follow these labels; do not duplicate the full policy in other skills — cross-reference only.

## Quality Checklist

- [ ] For `Transaction`, every `Level/Attribute@guid` exists in `<Attributes>/Attribute@guid`
- [ ] For `Transaction`, every `Level/Attribute` name exists in `<Attributes>/Attribute@name`
- [ ] For `Transaction`, every `DescriptionAttribute` present exists in the same `Level` and also in `<Attributes>`
- [ ] For `Transaction`, no required `Attribute` was serialized as `Domain` or other object type under `<Objects>`
- [ ] For `Transaction`, the primary edit block was declared before editing, any block transition was justified explicitly, and intended scope via web editing vs BC was stated when relevant
- [ ] When the delta involves `Rules` or `Events` with attribute assignments, `Test-GeneXusTransactionWritability.ps1` was run and any `writable=false` attribute was excluded from assignments (or the assignment caused an explicit ABORT)
- [ ] If the phase introduced a new FK sustained by `SubTypeGroup`, the corresponding `Table` was reviewed and the `Transaction + SubTypeGroup + Table` minimum review set was honored
- [ ] Any new or updated catalog row in this file uses exactly one evidence label (`confirmado-import`, `confirmado-build`, `confirmado-acervo`, `padrao-gx-nao-verificado`); nothing was promoted to `confirmado-*` without import/build, parallel corpus XML, or sanitized template evidence
- [ ] `padrao-gx-nao-verificado` items, if any, live in a clearly titled subsection separate from confirmed rows; no syntax was generated from unverified items alone

## Related gates and WORKFLOW links

Type-agnostic gates and WORKFLOW steps that involve Transactions remain in the main `SKILL.md`. Cross-references:

- **9-BC (BC dependency preflight gate)** — `Test-GeneXusBCDependency.ps1`. Triggered when a Procedure in the batch references `bc:<Transaction>` or `bc:<Transaction>.<Sublevel>`.
- **9-IDO (Import Dependency Ordering)** — `Test-GeneXusBatchDependencyOrdering.ps1`. Triggered when the batch has 2 or more distinct objects.
- **9-TXW (Transaction Writability gate)** — `Test-GeneXusTransactionWritability.ps1`. Triggered when the delta involves `Rules` or `Events` with attribute assignments. See WORKFLOW step `9-TXW`.
- **Transaction Coherence pre-packaging gate** — `Test-GeneXusTransactionCoherence.ps1`. See WORKFLOW step `9-TWS`.
- **Transaction semantic pre-import gate** (Level/Attribute@guid, DescriptionAttribute coherence). See WORKFLOW step in the validation block of the main `SKILL.md`.
- **Package envelope rules and Attribute serialization rules**. See WORKFLOW steps 15 onward in the main `SKILL.md`.
