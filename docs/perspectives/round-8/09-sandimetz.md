# Round 8 field notes — Sandi Metz lets the graph write the test plan

*Built: `examples/graph_to_specs.rb` — an RSpec skeleton generated from
`orchestrator.graph`, where each task's structural role dictates which
examples it owes.*

## What I built and why

The hardest question in testing isn't "how do I test this?" — it's
"what deserves a test at all?" People answer it by staring at a blank
spec file and free-associating, which produces suites that test the
easy things thoroughly and the important things by accident.

But a plan's graph already knows the answer, because *structural role
implies test obligation*:

- **Roots** own the boundary with the world. They owe a fixture-input
  example and a named-error-when-unreachable example, because the
  world is the only thing that can surprise them.
- **Joins** (two or more dependencies) owe one context per tributary:
  "when sales is missing", "when credits is missing". A join that
  fails vaguely — "something was nil" — is a join nobody can debug at
  3am. The labeled edges give each absence case its *name*.
- **Single-dependency tasks** owe exactly one example: the transform.
  Their input is another task's output; assert on the shape of
  `previous_output` and you're done.
- **Leaves** are promises to the outside. They owe an artifact
  assertion, because a leaf nobody reads is a plan nobody needed.

The generator walks `graph[:order]`, checks each task against
`stats[:roots]`, `stats[:leaves]`, and its dependency count, and
prints the describe blocks. Four tasks became eleven examples, and
not one of them came from free association.

## The part I care about

The join rule is the payoff. `needs: {sales: orders, credits: refunds}`
was declared for *wiring* — but the labels turn out to be exactly the
vocabulary the failure cases need. "When credits is missing" is a
sentence a human wrote without knowing they were writing it. That's
what good declarations do: they answer questions you hadn't asked yet.
(Piotr found the same thing this round from the semver seat; the
contract metadata keeps buying tools nobody planned.)

The generator refuses to write assertions, deliberately. It knows
*what deserves a test*, not *what passes one* — the graph knows
structure, not meaning. A generator that guessed at expectations would
produce green suites that verify nothing, which is worse than no
suite: it's confidence without evidence.

## Notes

- `stats[:roots]` and `stats[:leaves]` landed this round (our round-7
  ask) and this is precisely the tool they were asked for. Before, a
  consumer had to recompute "empty deps" and "never depended on" —
  logic every graph tool would duplicate slightly differently.
- One task can wear two hats — a root that is also a leaf owes both
  sets of examples. The generator handles this by accumulation, not
  classification: roles are checked independently, never `elsif`'d.
  Exclusive categories are how edge cases get orphaned.

## Verdict

"What should we test?" is a structural question, and structure is
data now. The graph decided what deserves a test; the human decides
what passes one. That's the right division of labor — the machine
does the enumeration, the person does the judgment.
