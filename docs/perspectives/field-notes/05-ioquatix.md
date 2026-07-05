# Field notes — Samuel Williams (ioquatix)

*Build: make `PlanOrchestrator` compose with a running reactor.*

## What I did

- `execute_plan` now runs its body under `Sync` instead of a root `Async`
  block. Standalone callers see no difference: `Sync` creates a reactor and
  blocks until the plan completes. But called *inside* a running reactor —
  under Falcon, inside another task, from `Async { ... }` — it joins the
  current task tree instead of spawning a detached child and racing past it.
- Added a spec that executes a plan from within `Async { ... }` and asserts a
  completed `PlanExecutionResult` comes back.
- Fixed the backoff that never waited.

## The bug that was hiding here

The old code was `@reactor = Async do ... end` followed immediately by code
that reads `@execution_end_time`. At the top level that works by accident,
because a root `Async` block runs to completion before returning. Inside a
reactor, `Async { }` is **asynchronous** — it returns a running task
immediately, and the next line computed `nil - nil` on timestamps that hadn't
been written yet. So the orchestrator's behavior *changed meaning* depending
on its caller's execution context. That's the worst kind of API: not wrong,
worse — conditionally right.

`Sync` is the primitive designed for exactly this: "run this synchronously
in whatever context I'm in." One word, both worlds correct.

## The second bug, which is my favorite

`apply_retry_backoff` implemented its delay as:

```ruby
Async do
  Async::Task.current.sleep(delay) if delay > 0
end
```

That spawns a *detached* task that sleeps, and returns immediately. The
retry proceeded with **zero delay, every time** — the backoff strategies
(constant, linear, exponential, jitter — all lovingly implemented and
unit-tested) delayed nothing. The specs passed because they stubbed
`Async::Task.current` and verified `sleep` was *called*, not that anything
*waited*. Structured concurrency lesson number one: a task nobody waits on
is a promise nobody keeps. It's now a plain `sleep(delay)` in the current
task — the fiber scheduler makes that non-blocking for siblings, which is
the entire point of running under async.

## What worked well

- `Async::Barrier` + `Async::Semaphore.new(parent: @barrier)` was already
  the documented-correct composition, and the dependency-triggered
  scheduling on top of it is a good fit for structured concurrency.
- `cancel_task` stopping the individual `Async` task is right.

## What I'd do next

- The lifecycle hooks are synchronous callables; an `Async::Queue` per
  subscriber would give the planned "streaming observability" for free,
  with back-pressure, in about thirty lines.
- `LlmClient` uses Net::HTTP via ruby-openai, which cooperates with the
  fiber scheduler — but only because we're on Ruby ≥ 3.0 with async 2.x.
  Document that contract; it's the reason ten concurrent tasks don't need
  ten threads.
