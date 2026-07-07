# Round 9 field notes — Sandi Metz counts the ducks

*Built: `examples/duck_agents.rb` — one plan, five differently-shaped
agents through the single `agent:` seam: lambda, instance, Method
object, curried proc, and a decorator that wraps any of them.*

## What I built and why

Eight rounds of examples have passed lambdas to `agent:` so uniformly
that a reader could be forgiven for thinking the seam *requires*
lambdas. It doesn't, and the difference between "we always pass
lambdas" and "you must pass lambdas" is the difference between a
convention and a cage. I built the parade to prove the cage isn't
there:

```
fetch    lambda                     -> {records: 12, ...}
dedupe   instance with #call        -> {unique: 9, pass: 1}
stats    Method object              -> {mean: 4.2, max: 9}
render   curried proc               -> {rendered: true, format: "html"}
audit    decorator around a lambda  -> {audited: true, timed_ms: 0.0}
```

The seam asks one question — *can you be called with a task?* — and
never asks anyone's class. So every shape that answers walks in, and
each shape earns its place for a different reason:

- The **lambda** for logic too small to deserve a name.
- The **instance** when logic deserves a home — my `Deduper` carries
  state (`pass: 1`) that a lambda would have to smuggle in a closure.
- The **Method object** when the logic already lives somewhere —
  `Stats.method(:summarize)` joins the plan without a wrapper, which
  means no wrapper to test.
- The **curried proc** for configuration applied ahead of time:
  `render.curry["html"]` is dependency injection wearing a very small
  hat.
- The **decorator** is the payoff of all of it: `Timed` consumes the
  same one-message contract it provides, so it stacks around *any* of
  the other four without knowing or caring which it got.

## The design lesson

Depend on messages, not classes, and your plugin API is every object
ever written — including the ones not written yet. The framework got
this right in a way worth naming precisely: `resolve_agent` checks
`respond_to?(:execute)` and otherwise wraps the callable. Two ducks
accepted, both by *capability*, neither by ancestry. There is no
`AgentBase` to inherit, and so there is no inheritance debt to
pre-borrow — the round-1 sin (`FactoryMethods` breaking under
subclassing) has stayed fixed at the seam that matters most.

The decorator deserves one more sentence. That `Timed` works on all
five shapes isn't a feature anyone built; it's a *consequence* of the
narrow contract. Wide interfaces make decorators expensive (forward
everything!); one-message interfaces make them nine lines. If you
want composition, keep your contracts poor.

## Notes

- I resisted adding a sixth duck that type-checks its input, as a
  cautionary contrast. The parade argues better without the clown.

## Verdict

The seam is honest: it asks for what it needs — one message — and
not for who you are. Five shapes, zero adapters, one nine-line
decorator that fits them all. That's what "design for change" looks
like when it's cheap.
