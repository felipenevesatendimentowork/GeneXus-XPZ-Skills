# WebPanel — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `WebPanel` object type. **Load this file end-to-end before generating, editing, or packaging a `WebPanel`**, in addition to the main `SKILL.md`.

This file consolidates type-specific RESPONSIBILITIES and QUALITY CHECKLIST entries. Type-agnostic rules and detailed cloning rules (which currently live inside WORKFLOW step 11 of the main `SKILL.md`) are not duplicated here — the satellite references them by anchor.

## Responsibilities

### Block classification and edit scope

- Classify the current delta by functional block before editing: `layout`, `events`, `variables`, `serialized functional metadata`, `identity and container`, or `dependencies`.

### Events (GeneXus source)

- When the primary edit block is `events`, consult [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md), section `Mecanismos de descarte de codigo de evento pelo gerador GeneXus`, before changing event source — no-op assignments (`&x = &x`, `&sdt.<m> = &sdt.<m>`, etc.) and `Refresh` alone may be stripped silently (mechanism b) or fail at import (mechanism a). For nested Tab with SDT in data attributes (empty inner tab on first outer activation), also consult [04-webpanel-familias-e-templates.md](../../04-webpanel-familias-e-templates.md) and `02`, subsection `WebPanel, Tab aninhada e re-bind de SDT em data attributes`.

### UCW (User Control Web)

- For `WebPanel` that includes UCW (`<ucw gxControlType="...">`) in the `GxMultiForm` layout: load [04b-ucw-gxcontroltype-reference.md](../../04b-ucw-gxcontroltype-reference.md) before generating or editing the UCW block; never invent `gxControlType` values — use only documented values from that reference.

## Quality Checklist

- [ ] For `WebPanel`, the primary edit block was declared before editing and any block transition was justified explicitly
- [ ] When the primary edit block was `events`, `02` descarte mechanisms (a)/(b) were considered before editing source; when nested Tab + SDT data attributes apply, `04` observed pattern and `02` Tab/re-bind subsection were consulted

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
