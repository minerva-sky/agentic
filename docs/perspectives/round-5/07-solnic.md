# Round 5 field notes — Piotr Solnica generates the 422

*Built: `examples/form_errors.rb` — ValidationError in, API error
document out; the renderer has zero knowledge of any contract because
`#expectations` (this round's release) carries the contract inside the
exception.*

## What I built and why

My round-4 state machine had to reach back into its own transition
table to tell users which states were legal — the exception knew
something was wrong but not what right looked like. `#expectations`
closed that gap, and this is the payoff pattern: **one renderer, every
capability**. The `error_document` function receives an exception and
produces the 422 your frontend wants:

```json
{"field": "plan",
 "messages": ["must be one of: starter, team, enterprise"],
 "allowed": ["starter", "team", "enterprise"]}
```

`allowed`, `minimum`, `maximum` — all read off the exception. The
renderer contains no reference to the checkout contract, which means
it also serves the freight desk next door, and every capability anyone
registers next year. Error rendering just became infrastructure
instead of per-endpoint labor. This is the dry-rb thesis in one
example: when errors are *data with schema*, presentation becomes a
pure function, and pure functions are the only code that never needs
a second copy.

## The seam I'd polish next

The document splits field errors from `policy_violations` (the `:base`
rules) — and submission #3 shows the asymmetry Jeremy also flagged:
field errors carry structured expectations, policy violations carry
prose. A rule that failed *knows* which fields it read
(`plan`, `seats`), but the exception can't say so, so the frontend
can't highlight the offending inputs. Rules declaring their fields —
`rules: {rule_name => {fields: [:plan, :seats], check: ->}}` — would
let the 422 point at widgets for policy failures too. That's the
round-6 ask.

Also noted with approval: dry-schema's own messages ("must be one of:
starter, team, enterprise") already render the enum — the expectations
payload lets you go *beyond* prose into machine-usable structure
(populate the dropdown, set the slider bounds). Messages for humans,
expectations for widgets. Both, not either.

## Verdict

Round 4: exceptions learned what happened. Round 5: they learned what
should have happened. A form library, an API layer, and a CLI can now
share one error pathway — which is what "types at the boundary" was
always for.
