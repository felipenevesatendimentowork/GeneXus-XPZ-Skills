# DataProvider — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `DataProvider` object type. **Load this file end-to-end before generating, editing, or packaging a `DataProvider`**, in addition to the main `SKILL.md`.

## Responsibilities

### Block classification and edit scope

- Classify the current delta by functional block before editing: `Output structure`, `Source`, `Navigation context`, `Calls and dependencies`, or `Identity and container`.

## Quality Checklist

- [ ] For `DataProvider`, the primary edit block was declared before editing and any block transition was justified explicitly
- [ ] For `DataProvider`, output-shape deltas were reviewed explicitly against the promised return structure before packaging

## Related rules in main SKILL.md WORKFLOW

The following DataProvider-specific rules live inside WORKFLOW step 11 (Locate template, Apply conservative cloning). They remain in the main `SKILL.md`:

- Declare the primary edit block before touching the XML and use only the adjacent blocks required by explicit functional dependency.
- Treat `Output structure` as its own functional layer; do NOT collapse return shape into a generic `Source` reading.
- If the delta touches collection vs simple, nested groups, node names, or return cardinality, classify `Output structure` as the primary edit block unless explicit evidence points elsewhere.
- If the delta depends on `For each`, base table, filters, or navigation ambiguity, open `Navigation context` only as an explicitly justified adjacent block.
- Do NOT treat `SDT`, `Procedure`, `BC`, or `Transaction` dependency inventory by itself as proof of the output shape.
- Name each justified block transition during review (`Output structure -> Source` or `Source -> Navigation context`).
- If the current reasoning no longer needs a new block, stop expanding; do NOT reopen the whole object by reflex.
