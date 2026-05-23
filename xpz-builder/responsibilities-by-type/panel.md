# Panel - Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `Panel` object type, especially Panel SD. **Load this file end-to-end before generating, editing, or packaging a `Panel`**, in addition to the main `SKILL.md`.

## Responsibilities

- Classify the current delta by functional block before editing: `Panel structure and layout`, `Serialized behavior and configuration`, `Pattern and parent coupling`, `External dependencies`, or `Identity and container`.
- Treat `level id` and `layout id` as one coupled pair. Preserve a pair from a comparable IDE-exported Panel of the same KB when the derivation rule is not proven.
- Inspect `detail/@events` as the serialized behavior source for Panel SD; do not conclude that event coverage is empty from layout actions alone.
- For `<action onClickEvent="'Nome'">`, prefer matching named behavior `Event 'Nome'` from a comparable real Panel. Do not invent `Event Controle.Tap` without direct corpus evidence for that same form.
- Use `scripts/Get-GeneXusObjectSummary.ps1` to extract serialized event and action coverage signals, and `scripts/Compare-GeneXusPanelShape.ps1` to compare those signals against a comparable real Panel before concluding equivalence. Review at least `actionEventCoverage`, `namedEventNames`, `standardEventNames`, `variableEventNames`, and `tapEventNames`.
- When packaging with a comparable template, pass it through the structured envelope flow so the `level/layout` confirmation can be reported. Without a comparable reference, retain the explicit unverified-pair warning.

## Quality Checklist

- [ ] The primary Panel block was declared and any transition to an adjacent block was justified.
- [ ] Every `level id`/`layout id` pair was preserved from or checked against a comparable real Panel, or the absence of proof was explicitly reported as a warning.
- [ ] `detail/@events` was inspected for Panel SD with actions or serialized behavior.
- [ ] Every quoted `onClickEvent` intended to invoke a named action has a matching named event, or the mismatch is explicitly classified.
- [ ] When Panel shape equivalence mattered, `Get-GeneXusObjectSummary.ps1` and/or `Compare-GeneXusPanelShape.ps1` was used to inspect `actionEventCoverage`, `namedEventNames`, `standardEventNames`, `variableEventNames`, and `tapEventNames` without dumping full XML.
- [ ] No `Event Controle.Tap` was synthesized without equivalent evidence from a comparable real Panel in the target KB.

## Related References

- [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md) - operational rules for Panel block review and serialized behavior.
- [08-guia-para-agente-gpt.md](../../08-guia-para-agente-gpt.md) - compact agent guidance for Panel review.
- [01e-moldes-sanitizados-core.md](../../01e-moldes-sanitizados-core.md) - sanitized Panel examples with `detail/@events` and `onClickEvent`.
