# API — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `API` object type. **Load this file end-to-end before generating, editing, or packaging an `API`**, in addition to the main `SKILL.md`.

## Responsibilities

### Block classification and edit scope

- Classify the current delta by functional block before editing: `Service contract`, `Events and orchestration`, `Calls and dependencies`, `Data contract`, or `Identity and container`.

## Quality Checklist

- [ ] For `API`, the primary edit block was declared before editing and any block transition was justified explicitly
- [ ] For `API`, contract deltas were reviewed explicitly against the published operation and the effective orchestration before packaging

## Related rules in main SKILL.md WORKFLOW

The following API-specific rules live inside WORKFLOW step 11 (Locate template, Apply conservative cloning). They remain in the main `SKILL.md`:

- Declare the primary edit block before touching the XML and use only the adjacent blocks required by explicit functional dependency.
- Treat `Service contract` and `Data contract` as their own functional layers; do NOT collapse endpoint contract, response shape, and internal orchestration into a generic code reading.
- If the delta touches exposed method, endpoint, signature, published operation, input/output shape, or response structure, classify `Service contract` or `Data contract` as the primary edit block unless explicit evidence points elsewhere.
- If the delta depends on `.Before/.After`, internal validation, transformation, or orchestration flow, open `Events and orchestration` only as an explicitly justified adjacent block.
- Do NOT treat `Procedure`, `SDT`, `Domain`, `Transaction`, `EXO`, or `DataProvider` dependency inventory by itself as proof of the published contract.
- Name each justified block transition during review (`Service contract -> Data contract` or `Events and orchestration -> Calls and dependencies`).
- If the current reasoning no longer needs a new block, stop expanding; do NOT reopen the whole object by reflex.
