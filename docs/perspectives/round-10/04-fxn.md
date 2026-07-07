# Round 10 field notes — Xavier Noria walks to the frontier

*Built: `examples/projection_agreement.rb` — every presence
combination evaluated against both renderings of the relation rules
(Ruby validator, draft-07 projection), agreement proved point by
point, and the exact frontier where the renderings part ways,
mapped.*

## What I built and why

This round the relation rules began rendering twice: the validator
enforces them, and `to_json_schema` projects `requires` into
`dependencies` and `mutually_exclusive` into not-required clauses.
Two renderings of one law is exactly the situation where drift is
born — nothing forces a projection to stay faithful except a proof
that re-runs. So: four fields, sixteen presence combinations, both
evaluators, demand agreement on every point.

```
16 combinations, 0 disagreements
```

The draft-07 side is evaluated by a four-line interpreter for
exactly the projected keywords — deliberately not a schema library,
because the proof should depend on the spec text, not on another
implementation's opinions of it.

## The frontier, surveyed precisely

Sixteen agreements would have been a boring (if load-bearing)
result, so I walked to where I knew the metaphysics differ: Ruby's
relation presence is *given and non-nil*; JSON Schema's
`dependencies` trigger on the property *existing*, null or not.
`{express: nil}` should split them.

It didn't — and the reason is the finding. For a **typed** field,
nil never reaches the relation check: per-key typing rejects it
first ("must be boolean"), and the schema rejects it too
(dependencies fire). Agreement, but *for different reasons* — the
most dangerous kind of agreement, because it dissolves the moment
someone relaxes a type. I proved that by declaring `express` without
a type: nil sails past per-key checks, the validator's relation
treats it as absent and allows, the schema's dependencies treat null
as present and reject. There it is: the true divergence, exhibited
on the one plane where it exists.

So the certificate reads, in full: *the projection is faithful on
the nil-free plane; typed fields guard the frontier; untyped fields
plus explicit null is the crack.* Senders should omit keys, never
null them. Filed as the round-11 ask: align presence semantics
across the boundary or document them as officially distinct.

## Notes

- This is the survey-map pattern from my round-9 prover again: the
  value isn't "it agrees," it's *knowing the exact shape of where it
  doesn't*. An unscoped promise is a bug that hasn't picked its
  reporter yet; this promise is now scoped to the character.
- Agreement-for-different-reasons deserves its own name in testing
  folklore. Both doors said no, one for typing, one for presence —
  a test asserting only the verdict would have called that a pass
  and learned nothing.

## Verdict

Both renderings of the law agree everywhere the law is meant to
apply, and the one crack is mapped, named, and filed. Exit 0 — a
certificate with its own margins drawn in.
