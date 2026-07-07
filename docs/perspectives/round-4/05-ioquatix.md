# Round 4 field notes — Samuel Williams shares the rate limit

*Built: `examples/shared_rate_limit.rb` — two plans in one reactor,
one credential-scoped semaphore, ceiling held at 3 in-flight across
both.*

## What I built and why

My round-3 note said the thing you actually want to bound is usually
per-*credential*, not per-orchestrator: one OpenAI key means one rate
limit shared by every plan in the process. This round I built it in
userland to prove the primitives suffice: a `RateLimitedApi` owning an
`Async::Semaphore(3)`, handed to two orchestrators that each *think*
they're allowed 10 concurrent tasks. The run is the argument:

```
plan 1: completed, 8 tasks
plan 2: completed, 8 tasks
in-flight high-water mark: 3 (ceiling 3) - held
calls interleaved across plans: yes
```

Sixteen calls, both plans finishing, calls interleaving freely across
plan boundaries — and never more than three in flight. **Rate limits
belong to the resource, so the semaphore lives with the resource.**
The orchestrator's `concurrency_limit` is a scheduling policy; the
credential's ceiling is a law of physics. Two different numbers, two
different owners, and the design falls out correctly the moment you
ask who owns each.

## Structured-concurrency notes

- Both plans run as sibling `Async` tasks under one `Sync` — three
  rounds of composability work (`Sync` in execute_plan, the barrier
  spawn fix) are what make "two orchestrators in one reactor" a
  two-line expression instead of a threading design document.
- The semaphore + fiber scheduler interaction is doing quiet heavy
  lifting: a task blocked on the credential's semaphore yields its
  *orchestrator* slot's fiber but not the reactor — sibling tasks from
  the other plan run through the gap. That's why the interleaving
  check passes; a thread-per-task design would show convoy effects
  here.
- The high-water mark is the honest metric. Don't assert "the
  semaphore works" — count concurrent entries and report the max. Any
  future refactor that breaks the ceiling turns "held" into
  "BREACHED" in the output, which makes this example its own
  regression test.

## For the maintainers

This pattern is one small class away from being a feature:
`Agentic::RateLimit.new(ceiling)` that an `LlmClient` (or any agent)
wraps its calls in, shareable across plans. The example is the design
document; the class is an afternoon. I'd also accept
"`LlmClient` accepts a `limiter:`" as the minimal version.

## Verdict

Per-credential rate limiting: asked for in round 3, demonstrated from
primitives in round 4, one high-water mark from being a feature. The
reactor did exactly what structured concurrency promises — nothing
surprising happened, measurably.
