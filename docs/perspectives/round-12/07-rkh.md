# Round 12 field notes — Konstantin Haase sweetens the surface

*Built: `examples/plan_dsl.rb` — a thirty-line Sinatra-flavored DSL:
`step :name, after:, needs:` with the block as the agent, all sugar
over the public API, never inside it.*

## What I built and why

Sinatra's entire argument fit in four lines of README: an API is a
user interface, and interfaces should read like what they mean.
`get "/hi" do` didn't add a single capability Rack lacked — it
*removed the administration* between intention and expression. The
orchestrator's API is honest but administrative: construct tasks,
mind the ids, pass arrays. Meanwhile what a person *means* is:

```ruby
plan = Plan.define do
  step :fetch_orders  do ... end
  step :fetch_refunds do ... end
  step :ledger, needs: {orders: :fetch_orders, refunds: :fetch_refunds} do |t|
    t.needs[:orders].sum { ... } - t.needs[:refunds].sum { ... }
  end
  step :report, after: :ledger do |t|
    "net revenue: $#{t.previous_output}"
  end
end
```

Thirty lines of Builder later, that runs — on a completely real
orchestrator, with labeled edges the round-5-through-11 tools all
consume unchanged.

## What the sugar buys, and what it refuses

Three purchases: **names instead of ids** — symbols resolve to tasks
at definition time, so a typo'd `:fetch_order` raises at *define*,
the cheapest moment a wiring bug can exist. **The block is the
agent** — work lives inside the step that owns it, instead of a
lambda table three screens away. **`after:`/`needs:` read as
English** — the sentence shape carries the semantics (unlabeled
sequence vs named join) that round 8's spec generator later turns
into test obligations.

One refusal, and it's the important one: the DSL **never reaches
into the engine**. Every line delegates to public API — `add_task`,
`execute_plan`, `graph`. That's not politeness; it's the survival
strategy DSLs forget. A DSL that touches internals is pinned to
them, drifts with them, and eventually *is* them, at which point
you've built a second engine with worse error messages. Sugar over
the API can never drift ahead of the engine, and anything it can't
express — retry policies, hooks, rewiring — you drop down one layer
*without rewriting*, because the Builder hands you the orchestrator
it built. The frontend should be a pleasure and the escape hatch
should be a door, not a wall.

## Notes

- `instance_eval` for the block, accepting its tradeoffs (no easy
  access to the caller's self) for the reading experience. Sinatra
  made the same trade for the same reason; if your users need the
  other semantics, take the block arg form instead — one line.
- Deliberately absent: any DSL syntax for concurrency limits or
  hooks. A DSL earns each word by being the *common case*; rare
  cases belong on the layer below, where their full vocabulary
  lives.

## Verdict

Thirty lines bought a surface that reads like the plan it describes,
fails wiring typos at define time, and can't drift from the engine
because it never left the public API. APIs are user interfaces —
sweeten the surface, keep the door open, change nothing underneath.
