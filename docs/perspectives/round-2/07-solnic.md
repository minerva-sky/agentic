# Round 2 field notes — Piotr Solnica builds a typed ETL pipeline

*Built: `examples/typed_pipeline.rb` — extract → transform → load as
contract-bearing capabilities composed via `registry.compose`; malformed
data is stopped at the first boundary that can name what's wrong.*

## What I built and why

Four raw payment events, one of them garbage (`user=` empty,
`amount_cents=not-a-number`). Three capabilities with deliberately
different strictness: **extract** is forgiving (parsing is not
judgment), **transform** is where loose fields must become facts (its
*output* contract requires a present user and numeric amount), **load**
trusts its input contract completely. `registry.compose` fuses them into
one `etl_pipeline` capability.

The run prints the thesis better than I can:

```
POSTED   ev-1
REJECTED ev-3 at the 'transform' outputs boundary:
           user: is missing
           amount_cents: must be Numeric
LEDGER (only facts made it this far):
  USD    1041.00
```

Both violations, named, at the boundary that first noticed — and the
ledger arithmetic never saw the poison. That is the entire dry-rb
philosophy in fourteen lines of output.

## The design move worth stealing

The transform lambda doesn't validate. It *parses optimistically* and
lets its own **output contract** catch what didn't parse — `Integer()`
falls back to the raw string, empty user becomes an omitted key, and
the declared schema (built in round 1 on the gem's own dry-schema
dependency) does the rejecting with structured violations. Stages stay
dumb; boundaries stay strict. When validation logic lives in the
contract instead of the stage, adding stage four costs nothing and the
error messages stay uniform across the pipeline.

## Building-with-it observations

- `registry.compose` is a genuinely nice primitive — providers arrive as
  an ordered array and the composition lambda is just function
  composition. But the composed capability's own `inputs`/`outputs` are
  **not declarable** (the `compose` signature accepts no contracts for
  the whole), so the pipeline-as-a-unit has no contract even though
  every stage does. The seam between compositions is exactly where
  you want types most.
- One `ValidationError` carrying `capability`, `kind`, and all
  violations made the rescue-and-report loop four lines. Errors designed
  as data compose into UIs; errors designed as prose compose into grep.
- No orchestrator here, deliberately: per-record sequential flow with a
  contract at each seam didn't need one. Right-sized tools — the
  registry alone is a respectable pipeline runtime.

## Verdict

The gem let me express "data becomes facts at a named boundary" without
importing anything beyond what it already shipped. Give composed
capabilities their own contracts and this pattern would be
production-honest end to end.
