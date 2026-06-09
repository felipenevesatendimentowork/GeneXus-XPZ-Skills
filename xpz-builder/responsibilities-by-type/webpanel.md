# WebPanel — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `WebPanel` object type. **Load this file end-to-end before generating, editing, or packaging a `WebPanel`**, in addition to the main `SKILL.md`.

This file consolidates type-specific RESPONSIBILITIES and QUALITY CHECKLIST entries. Type-agnostic rules and detailed cloning rules (which currently live inside WORKFLOW step 11 of the main `SKILL.md`) are not duplicated here — the satellite references them by anchor.

## Responsibilities

### Block classification and edit scope

- Classify the current delta by functional block before editing: `layout`, `events`, `variables`, `serialized functional metadata`, `identity and container`, or `dependencies`.

### Read-only shape inspection (before editing layout or events)

- Before editing a `WebPanel` layout or events, run `scripts/Get-GeneXusObjectSummary.ps1` (the `webpanel` block) to read the shape without dumping `CDATA`: `tables` with `tableType` (Flex vs Responsive) and nesting `depth`, `controls`, `buttons` in both forms (`<action>` and `<ucw>` Button), `eventNames`, and a `coverage` block. Use `tableType` to judge whether inserting a cell is safe (Flex) or touches `responsiveSizes` per breakpoint (Responsive).
- Treat `coverage` as authoritative about scope: controls outside the `GxMultiForm` are not interpreted, and any `gxControlType` absent from `scripts/gx-ucw-gxcontroltype-catalog.json` is reported in `unknownUcwControlTypes`, never silently omitted. Do NOT read a missing control as proof of absence without checking `coverage`.

### Events (GeneXus source)

- When the primary edit block is `events`, consult [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md), section `Mecanismos de descarte de codigo de evento pelo gerador GeneXus`, before changing event source — no-op assignments (`&x = &x`, `&sdt.<m> = &sdt.<m>`, etc.) and `Refresh` alone may be stripped silently (mechanism b) or fail at import (mechanism a). For nested Tab with SDT in data attributes (empty inner tab on first outer activation), also consult [04-webpanel-familias-e-templates.md](../../04-webpanel-familias-e-templates.md) and `02`, subsection `WebPanel, Tab aninhada e re-bind de SDT em data attributes`.

### UCW (User Control Web)

- For `WebPanel` that includes UCW (`<ucw gxControlType="...">`) in the `GxMultiForm` layout: load [04b-ucw-gxcontroltype-reference.md](../../04b-ucw-gxcontroltype-reference.md) before generating or editing the UCW block; never invent `gxControlType` values — use only documented values from that reference.

### Buttons: declaration, the two forms, and the "action" disambiguation

- A button is declared **once** in the layout, in one of two serialized forms — both are the same GeneXus **Button** control (GeneXus Wiki: *"every button must be associated with an event"*), differing only in serialization:
  - `<action controlName="X" onClickEvent="'Y'" caption="Z">` — native action form.
  - `<ucw gxControlType="-2133704903" PATTERN_ELEMENT_CUSTOM_PROPERTIES="…ControlName…Event…CaptionExpression…">` — Button **user control** form (name/event live inside the escaped properties).
  - Observed corpus pattern: the `ucw` Button form appears in **menu/navigation** panels; `<action>` appears in forms, Work With, and prompts. This is an observed pattern, **not** a product rule — the choice is a serialization detail, not a modeling distinction.
- Every button's On Click Event is a **named** user event (`Event 'Name'`) or a **standard** one (`Enter`/`Back`).
- Do **not** confuse the three things that share the word "action" / a button's name in the XML:
  - **Layout button:** `<action controlName= onClickEvent=>` (or `<ucw>` Button) inside `<layout>`.
  - **WorkWithForWeb pattern action:** `<action name="Insert"/>` inside `<actions>` — a Data Pattern structural action, not a free-layout button (see [01j-workwithweb-cdata-padroes.md](../../01j-workwithweb-cdata-padroes.md)).
  - **Property reference in event source:** `Button.Visible`/`.Icon`/`.Enabled` in the events `Source` — manipulates an **already-declared** control; neither a declaration nor an event.
- **Counting anti-pitfall:** N occurrences of a button's name in `Source` is **not** N buttons. One button = one layout declaration + one Event handler; the rest are property references.
- To **add** a button safely, prefer `scripts/Add-GeneXusButton.ps1` (`-BeforeControlName`/`-AfterControlName` (mutually exclusive), `-Form action|ucw`, `-DryRun`): it inserts a new `<cell>` before or after a named leaf control's cell in a **Flex** table, emits the correct serialization (including the escaped `ucw` `PATTERN_ELEMENT_CUSTOM_PROPERTIES`) plus an `Event` stub, bumps `lastUpdate`, and validates well-formedness. It **aborts fail-closed** (`RESPONSIVE_UNSAFE`) on a Responsive table with populated `responsiveSizes` rather than risk the breakpoint array — there, generate the snippet and adjust `responsiveSizes` manually.

## Quality Checklist

- [ ] For `WebPanel`, the primary edit block was declared before editing and any block transition was justified explicitly
- [ ] When the primary edit block was `events`, `02` descarte mechanisms (a)/(b) were considered before editing source; when nested Tab + SDT data attributes apply, `04` observed pattern and `02` Tab/re-bind subsection were consulted
- [ ] When editing or counting `WebPanel` buttons, the two forms (`<action>` vs `<ucw>` Button) were distinguished from `<actions>` pattern actions and from `.Visible`/`.Icon` property references; button count was not inferred from raw name occurrences
- [ ] When adding a button, `scripts/Add-GeneXusButton.ps1` was used (or the equivalent surgical flow); insertion into a populated Responsive table was not forced past the `RESPONSIVE_UNSAFE` gate

## Related rules in main SKILL.md WORKFLOW

The following WebPanel-specific rules live inside WORKFLOW step 11 (Locate template, Apply conservative cloning) and step 17 (Validate). They remain in the main `SKILL.md`:

- Declare the primary edit block before touching the XML and use only the adjacent blocks required by explicit functional dependency.
- Verify where each relevant property is actually persisted before editing: `Conditions` may live in its own `Part`, while `ControlWhere`, `ControlBaseTable`, `ControlOrder`, `ControlUnique`, `PATTERN_ELEMENT_CUSTOM_PROPERTIES`, and `WebUserControlProperties` often live inside serialized layout metadata.
- Treat serialized functional metadata as its own functional layer; do NOT collapse it into visual layout when planning or reviewing the delta.
- Do NOT treat template defaults mentioning `Conditions` as proof that a real filter is materialized.
- NEVER manually reconstruct serialized layout `CDATA` after truncated reading.
- Name each justified block transition during review (`events -> variables` or `layout -> serialized functional metadata`).
- For cloned `WebPanel`, validate matching `fieldSpecifier` count and names; classify any divergence as intentional delta or clone error.

## Related references

- [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md) — generator event discard (a)/(b); Tab/SDT re-bind when editing `events` or diagnosing empty inner tabs.
- [04-webpanel-familias-e-templates.md](../../04-webpanel-familias-e-templates.md) — documented WebPanel families and observed runtime/layout patterns (used in WORKFLOW step 11 for template location).
- [04b-ucw-gxcontroltype-reference.md](../../04b-ucw-gxcontroltype-reference.md) — UCW catalog (mandatory load when WebPanel contains UCW).
- [01j-workwithweb-cdata-padroes.md](../../01j-workwithweb-cdata-padroes.md) — WorkWithForWeb `<actions>` hierarchy (list/detail/grid), to distinguish pattern actions from layout buttons.
- [scripts/Get-GeneXusObjectSummary.ps1](../../scripts/Get-GeneXusObjectSummary.ps1) — read-only WebPanel shape (`tables`/`tableType`, `controls`, `buttons`, `eventNames`, `coverage`) without dumping CDATA.
- [scripts/gx-ucw-gxcontroltype-catalog.json](../../scripts/gx-ucw-gxcontroltype-catalog.json) — `gxControlType` -> control-type map consumed by the shape inspector (documented in `04b`).
- [scripts/Add-GeneXusButton.ps1](../../scripts/Add-GeneXusButton.ps1) — surgical button insertion before or after a named leaf control in a Flex table (`-BeforeControlName`/`-AfterControlName`, mutually exclusive); fail-closed (`RESPONSIVE_UNSAFE`) on populated Responsive.
