# Round 16 field notes — Piotr Solnica lays the rails

*Built: `examples/railway_plan.rb` — a fourteen-line Result monad
over `TaskResult`/`TaskFailure`, composing plan steps with `bind` so
the first failure switches everything downstream onto the bypass
track.*

## What I built and why

Seven of my rounds on this bench were about contracts — the
boundaries. The lottery sent me back, so this time: the *middle*.
How do outcomes compose between the boundaries? Ruby's native
answer is rescue blocks and `return unless`, which is to say:
failure as *interruption*. dry-monads' answer — the one I've spent a
decade advocating — is failure as *composition*:

```ruby
run_task("validate", order) { ... }
  .bind { |o| run_task("price", o) { ... } }
  .bind { |o| run_task("invoice", o) { ... } }
```

Read it top to bottom; that reading IS the control flow. The empty
cart diverts at `validate`, and price/invoice **never run** — not
because anyone checked, but because `Failure#bind` returns itself.
No rescue pyramid, no nil creeping past step two, no defensive
conditionals (Avdi's timid pipeline, solved from the algebra side
instead of the barricade side — same destination, different proof).

## The framework had already done the hard part

The monad is fourteen lines because `TaskResult`/`TaskFailure` are
already Result values in street clothes — round 1's "failure as
data" decision, paying rent again fifteen rounds later. The diverted
train doesn't carry a string or a nil; it carries a first-class
`TaskFailure` with type, message, timestamp, and the retryable
verdict, which means the *end of the line* can still make policy
decisions (retry the whole railway? park it?) with full testimony.
A monad over rich failure values is worth ten monads over `:error`.

What I deliberately left out: do-notation, `fmap`, `or_else`, the
whole algebra. The discipline that survives translation into any
codebase is the small part — **failures compose, they don't
interrupt** — and a pattern demo that requires a gem's worth of
combinators teaches the gem, not the pattern.

## Notes

- `Railway.from(result, task)` is the single lift point between the
  orchestrator's world and the railway's — one seam, easy to test,
  easy to delete if the team decides monads aren't their dialect.
  Patterns should be cheap to adopt AND cheap to abandon.
- Each step here is its own one-task plan for demo clarity; in real
  use you'd lift a multi-task plan's terminal result the same way,
  or bind across plans — the composition is indifferent to what's
  inside each step, which is the point of it.

## Verdict

The checkout reads as three binds, the empty cart was diverted with
its full testimony intact, and the monad cost fourteen lines because
the framework modeled failure as data from round one. Railways are
what result objects grow up into when you let them.
