# Round 6 field notes — Piotr Solnica generates the API reference

*Built: `examples/api_reference.rb` — walk the registry, emit markdown
reference docs from the same contracts that validate every call.*

## What I built and why

The endgame of contract-first design was always this: the contract is
the validator, the error renderer, *and* the documentation — one
artifact, three projections. The generator walks the registry and
emits a reference page per capability:

```
| `amount_cents` | number | yes | >= 1; <= 10000000 | Amount in cents |

### Policies
- **no_self_transfer** (checks `from_account`, `to_account`):
  source and destination must differ
```

Every column is read from the declaration: types, requiredness, enums,
bounds, non-empty, and — thanks to this round's structured rules — the
policies with the fields they check. API docs that drift from the
validator are the industry's most-shipped lie; these *cannot* drift,
because the sentence that documents the bound is generated from the
object that enforces it.

## The arc, made explicit

Trace `amount_cents: {min: 1}` through the rounds: round 2, types were
decorative. Round 4, `min:` rejects bad input. Round 5, the rejection
carries the bound (`expectations`). Round 6, the bound documents
itself in a table AND Jeremy's prober audits the rules' field claims.
**One declaration, five behaviors** — validate, reject, explain,
document, audit. That multiplication is the entire argument for
schema-as-data over validation-as-code; I have been making it in
conference talks for a decade and this gem now makes it in 100 lines
of examples.

## Notes

- `description:` on input declarations was already in the
  specification shape (round 2's capabilities used it) but nothing
  consumed it until this table. Metadata survives waiting for its
  consumer — another reason to prefer declarations over code.
- The near-term upgrade is emitting JSON Schema / OpenAPI instead of
  markdown — the declarations map 1:1 (`enum`→`enum`, `min`→`minimum`,
  `non_empty`→`minLength/minItems`). At that point Agentic capability
  contracts become importable into every API toolchain on earth. An
  afternoon, for whoever wants it.
- What the reference can't document: prose-form rules (no fields, no
  id — they render as their description only) and implementation
  behavior beyond the boundary. Correct limits, both; documentation
  generators should document claims, not guess at code.

## Verdict

Contracts now validate, explain, document, and get audited — four
consumers of one declaration, none of which can disagree with the
others. That's the property "single source of truth" was always
supposed to mean.
