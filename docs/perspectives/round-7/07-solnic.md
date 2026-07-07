# Round 7 field notes — Piotr Solnica proves the projection

*Built: `examples/json_schema_export.rb` — a contract exported as
draft-07 JSON Schema, then proven faithful: 200 seeded payloads judged
by the live validator and by an independent interpreter reading only
the exported document. Zero disagreements, 44 accepts, 156 rejects.*

## What I built and why

`to_json_schema` shipped this round (my round-6 ask), and an exporter
without a fidelity proof is a rumor generator — the whole value of
exporting your contract to OpenAPI-land is that the *frontend's*
validator and the *backend's* validator enforce the same law. So the
example is two things: the export, and the **agreement proof**. An
independent interpreter (deliberately written against only the JSON
document — it has never seen `CapabilitySpecification`) and Agentic's
own validator judge the same 200 payloads:

```
THE AGREEMENT PROOF (200 seeded payloads, 44 valid)
  the exported schema and the live validator agreed on every payload.
```

Differential testing is the correct verification for any projection:
don't inspect the output, *race it against the source* on shared
inputs. Jeremy's round-6 prober did it for rule declarations; this
does it for the schema export. Between them, a pattern for this
codebase is now established: **every projection ships with its
disagreement detector.**

## The generator lesson (a confession by proxy)

The first payload generator produced only 2 valid payloads in 200 —
statistically the proof barely tested the *accept* path, where the
subtle disagreements live (a too-lenient export rejects nothing it
shouldn't; a too-strict one fails only on accepts). The fix: half the
payloads start valid and suffer exactly one corruption. Coverage of
both verdicts is to differential testing what Jeremy's coverage check
was to bounds testing — the half everyone forgets.

## Notes on the export itself

- `non_empty` maps to `minLength` for strings and `minItems` for
  arrays — the export knows JSON Schema's vocabulary rather than
  inventing `x-agentic-non-empty` extensions. Speak the target
  language natively or don't export.
- What doesn't project: cross-field `rules:`. JSON Schema's
  `dependencies`/`if-then-else` could express *some* of them, but a
  lambda is not data, so the export honestly omits them. The API
  reference (round 6) documents rules as prose instead — different
  projections for different expressiveness, each honest about its
  limits.
- `additionalProperties: true` mirrors the validator's
  unknown-keys-permitted stance. An exporter that silently tightened
  this would fail the agreement proof within ten payloads — which is
  precisely why the proof exists.

## Verdict

The contract now has five faithful projections — validator, error
payload, reference doc, JSON Schema, and (via Jeremy) an audit — and
the new one arrived with a proof of faithfulness in the same commit.
That should be the house rule: no projection without its referee.
