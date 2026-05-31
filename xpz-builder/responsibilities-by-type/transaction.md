# Transaction — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `Transaction` object type. **Load this file end-to-end before generating, editing, or packaging a `Transaction`**, in addition to the main `SKILL.md`.

This file consolidates type-specific RESPONSIBILITIES and QUALITY CHECKLIST entries. Type-agnostic rules (envelope serialization, package collision gate, manifest, etc.) remain in the main `SKILL.md`. Gate scripts (9-BC, 9-IDO, 9-TXW Writability, Transaction Coherence) are referenced here but live in `scripts/` and are invoked from the WORKFLOW in the main `SKILL.md`.

## Responsibilities

### Block classification and edit scope

- Classify the current delta by functional block before editing: `Transaction structure`, `Attributes and attribute properties`, `Rules`, `Events`, `Execution context`, or `Identity and container`.
- When changing a `Transaction`, declare the primary edit block before touching the XML, use only the adjacent blocks required by explicit functional dependency, name each justified block transition, and state whether the intended effect is via web editing, via BC, or both.

### Writability gate (attribute assignments)

- When the delta generates or reviews logic that assigns values to attributes accessed from a Transaction's base table, run the writability classification gate before any assignment is generated. Run `& ..\scripts\Test-GeneXusTransactionWritability.ps1 -TransactionPath <transaction.xml> -CorpusFolder <ObjetosDaKbEmXml> -AsJson` (facade over `GeneXusTransactionWritabilityCore.py`). The script returns a `levelAttributes` list where each item carries `classification` and `writable` (`true`, `false`, or `null` for edge cases). The 8 classifications cover the full algorithm: `key-attribute` (writable) for `key="True"` in the Level; `extended-parent-fk` (non-writable) for `isRedundant="True"` in the Level; `formula` (non-writable) for `Property Formula` in the Attribute XML; `extended-subtype-key` (writable) for SubTypeGroup member whose Supertype is PK in some Transaction; `extended-subtype-descriptive` (non-writable) for SubTypeGroup member whose Supertype is not PK in any Transaction; `extended-fk-key` (writable) when the attribute appears as Member in some Duplicate index of the Transaction's Table XML; `extended-fk-descriptive` (non-writable) when the attribute appears as `key="False"` of some FK entity reachable recursively from the Transaction's Table (max depth 10); `own-physical` (writable) when the attribute is absent from all FK entities in every explored depth. Edge cases return `unclassified-attribute-not-found` (Attribute XML standalone missing from corpus) or `unclassified-table-not-found` (Transaction's Table XML missing from corpus) — these require manual review against `08-guia-para-agente-gpt.md` before generating any assignment. Generating an assignment to an attribute the script reports as `writable=false` is a hard error — **ABORT**. Never conclude a Transaction's physical table has "only keys" before every `key="False"` attribute has been classified.
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

| Label | Meaning | Generation permission |
|-------|---------|-----------------------|
| `confirmado-import` | Rejection/acceptance observed on MSBuild import with traceable message and `exitCode` | Rejected syntax: do not generate. Accepted syntax: may generate after remaining gates |
| `confirmado-build` | Observed on `BuildAll`/`SpecifyGenerate` (e.g. `spc0150`) | Same |
| `confirmado-acervo` | Real use in parallel KB XML (`ObjetosDaKbEmXml/...` after sync) or reproducible sanitized template in `01*` | May generate, subject to writability and coherence gates |
| `padrao-gx-nao-verificado` | GeneXus convention/docs not tested in this base or parallel corpus in session | **Do not use as generation premise** — separate subsection only |
| `nao-listar` | No minimum evidence | **Do not publish** in the catalog |

Operational rules:

- **Generate only** syntax labeled `confirmado-import`, `confirmado-build`, or `confirmado-acervo`.
- Do not promote to `confirmado-*` from another agent’s report or an offline list alone; require reproducible import/build on the target KB, XML read in the parallel corpus, or a versioned sanitized template in this repo.
- Stable Specifier messages (e.g. `src0056`, `spc0150` with full text) may be documented under `confirmado-import` / `confirmado-build` without copying business `Transaction` XML into this repository.
- File-name examples (`Animal.xml`, etc.) with `confirmado-acervo` must state **parallel KB folder** (`ObjetosDaKbEmXml/...`) unless the example is a sanitized template in `01*`.
- Other skills must cross-reference this catalog section instead of duplicating it; see [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md) for repository scope (XPZ motor rejections vs GeneXus language documentation such as **nexa**).

## Catalog: `on <event>` clauses in declarative `Rules` and `Events` restrictions

Consult **before** generating or editing `Rules` or `Events` in a `Transaction` XPZ delta. This section records what the **XPZ import/build trail** has accepted or rejected — not correct GeneXus usage in general (**nexa** and product documentation own that).

### Catalog 1 — `on <event>` in declarative `Transaction` `Rules`

| Construct | Status | Specifier / motor evidence | Short example |
|-----------|--------|---------------------------|---------------|
| `on AfterValidate(<Attribute>)` or any `on <event>(<parameter>)` | **Rejected** | `confirmado-import` — `src0056: Missed ';' at the end of the rule. (Transaction '<name>' Rules, Line: <n>)` on MSBuild import (GeneXus 18) | `AttrB = expr if cond on AfterValidate(AttrA);` — **do not generate** |
| `on AfterValidate` (no parameters) | **Accepted** | `confirmado-acervo` — real use in parallel KB XML after sync (e.g. `Animal.xml`, `Carga.xml`, `PedidoCompraProdutoItem.xml` under `ObjetosDaKbEmXml/...`) | Level validation timing on commit path — **not** a per-field leave hook |
| `on BeforeInsert` | **Accepted** | `confirmado-import` on controlled trail; `confirmado-acervo` in parallel corpus | `Attr = expr on BeforeInsert;` |
| `on BeforeUpdate` | **Accepted** | `confirmado-import` on controlled trail (same frente as parameterized rejection) | `Attr = expr on BeforeUpdate;` |

#### GeneXus standard — not verified in this base (`padrao-gx-nao-verificado`)

Do **not** generate from this list without **confirmado-import**, **confirmado-build**, or **confirmado-acervo** on the target KB. Keep separate from the table above.

`on BeforeDelete`, `on AfterDelete`, `on BeforeValidate`, `on BeforeComplete`, `on AfterInsert`, `on AfterUpdate`, `on AfterComplete`, and other lifecycle triggers described in GeneXus product documentation or **nexa** (`common-rules.md` TRIGGERS, including `AfterLevel [level <attribute>]` for level-scoped timing — distinct from `on AfterValidate(<Attribute>)`).

### Catalog 2 — `Events` in `Transaction` (web scope unless noted)

| Construct / action | Status | Specifier / motor evidence | Notes |
|--------------------|--------|---------------------------|--------|
| `Event Start`, `Event After Trn` | **Listed** | `padrao-gx-nao-verificado` until `confirmado-acervo` in parallel corpus for your KB | Confirm in `ObjetosDaKbEmXml/...` before first use in a generated delta |
| `Event <Attribute>.ControlValueChanged` `[web]` | **Accepted pattern** | `confirmado-acervo` — parallel corpus examples adjust **control** surface (e.g. `.Caption`, `.Visible`, `.Enabled`), `SetFocus()`, not transaction attribute assignment | Do not copy as license to assign another attribute’s value |
| Assign to **transaction attribute** inside `Event` (`<Attribute> = <value>`) | **Rejected** | `confirmado-build` — `spc0150: Cannot update database. Changes to database are only allowed in procedures. (Transaction '<name>' Events, Line: <n>)` | Put persisted values in declarative `Rules`; use `Events` for UI, variables, `msg`/`Error`, external proc calls |
| Control UI properties, `&var`, `msg`/`Error`, proc `.execute()`, `SetFocus` / `SetEmpty` on variables | **Allowed class** | `confirmado-acervo` for UI-only `ControlValueChanged` bodies in parallel corpus | Still run **9-TXW** if any assignment touches level attributes in `Rules` |

`Event <Attribute>.IsValid` `[web]` stays `nao-listar` in this repository: there is no `confirmado-*` evidence here for Transaction Events. Verify in the target KB before generating; do not assume from commented XML alone.

Architectural note (XPZ scope only): persisting a new attribute value **via `Event`** is structurally blocked by the Specifier message above; attribute values belong in declarative `Rules` (and writability gates), with `Events` limited to non-persisted UI and side effects allowed by the motor.

### Catalog 3 — Symptom → likely cause → idiom (motor-focused)

| Symptom | Likely cause | Idiom |
|---------|--------------|--------|
| Import fails: `src0056` … `end of the rule` in `Transaction` `Rules` | Parameterized `on <event>(…)` (e.g. `on AfterValidate(<Attribute>)`) not accepted in declarative `Transaction` `Rules` on tested GX18 import | Remove the parameter; use only forms from Catalog 1; for per-field timing see **nexa** / product docs — do not reintroduce via `Event` attribute assignment |
| Build fails: `spc0150` … `only allowed in procedures` in `Transaction` `Events` | Transaction attribute assignment inside `Event` | Move value logic to declarative `Rules`; keep `Event` to UI / variables / proc calls (Catalog 2) |
| Rule present in XML, import OK, field value on screen unchanged when another field changes | Mixing **business timing** with motor-blocked shortcuts | Do **not** “fix” with Catalog 1 rejected forms or Catalog 2 attribute assignment; diagnose evaluation path in target KB — correct GeneXus modeling is **not** duplicated here |

## Quality Checklist

- [ ] For `Transaction`, every `Level/Attribute@guid` exists in `<Attributes>/Attribute@guid`
- [ ] For `Transaction`, every `Level/Attribute` name exists in `<Attributes>/Attribute@name`
- [ ] For `Transaction`, every `DescriptionAttribute` present exists in the same `Level` and also in `<Attributes>`
- [ ] For `Transaction`, no required `Attribute` was serialized as `Domain` or other object type under `<Objects>`
- [ ] For `Transaction`, the primary edit block was declared before editing, any block transition was justified explicitly, and intended scope via web editing vs BC was stated when relevant
- [ ] When the delta involves `Rules` or `Events` with attribute assignments, writability was closed with `Test-GeneXusTransactionWritability.ps1` for each affected Transaction **or** with `Test-GeneXusKbIntelligenceWritabilityParity.ps1` already passed on that parallel KB folder (index `schema_version=2`); `transaction-writable-attributes` may have been used for triage only — it does not replace that closure; any `writable=false` attribute was excluded from assignments (or the assignment caused an explicit ABORT); any `writable=null` (`unclassified-*`) was either resolved or explicitly documented as a classification gap before packaging
- [ ] If the phase introduced a new FK sustained by `SubTypeGroup`, the corresponding `Table` was reviewed and the `Transaction + SubTypeGroup + Table` minimum review set was honored
- [ ] Any new or updated catalog row in this file uses exactly one evidence label (`confirmado-import`, `confirmado-build`, `confirmado-acervo`, `padrao-gx-nao-verificado`); nothing was promoted to `confirmado-*` without import/build, parallel corpus XML, or sanitized template evidence
- [ ] `padrao-gx-nao-verificado` items, if any, live in a clearly titled subsection separate from confirmed rows; no syntax was generated from unverified items alone
- [ ] Before editing `Rules` or `Events`, the agent consulted **Catalog: `on <event>` clauses…** above and did not generate Catalog 1 rejected forms or Catalog 2 attribute assignments in `Events`

## Related gates and WORKFLOW links

Type-agnostic gates and WORKFLOW steps that involve Transactions remain in the main `SKILL.md`. Cross-references:

- **9-BC (BC dependency preflight gate)** — `Test-GeneXusBCDependency.ps1`. Triggered when a Procedure in the batch references `bc:<Transaction>` or `bc:<Transaction>.<Sublevel>`.
- **9-IDO (Import Dependency Ordering)** — `Test-GeneXusBatchDependencyOrdering.ps1`. Triggered when the batch has 2 or more distinct objects.
- **9-TXW (Transaction Writability gate)** — `Test-GeneXusTransactionWritability.ps1`, or `Test-GeneXusKbIntelligenceWritabilityParity.ps1` when index parity is already validated on the parallel KB folder. Triggered when the delta involves `Rules` or `Events` with attribute assignments. See WORKFLOW step `9-TXW`.
- **Transaction Coherence pre-packaging gate** — `Test-GeneXusTransactionCoherence.ps1`. See WORKFLOW step `9-TWS`.
- **Transaction semantic pre-import gate** (Level/Attribute@guid, DescriptionAttribute coherence). See WORKFLOW step in the validation block of the main `SKILL.md`.
- **Package envelope rules and Attribute serialization rules**. See WORKFLOW steps 15 onward in the main `SKILL.md`.
