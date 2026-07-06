# Round 5 field notes — Samuel Williams absorbs the burst

*Built: `examples/burst_absorber.rb` — three request waves against
`Agentic::RateLimit` (this round's release); the table of wait times
is the capacity plan.*

## What I built and why

Round 4 I built the rate limiter from primitives and said "this is one
class away from a feature." The class shipped (`Agentic::RateLimit`,
plus `LlmClient limiter:`), so this round I characterized it the way
you'd characterize any queueing system — under bursts, because steady
state flatters everyone:

```
wave 1: 6 requests   wait p50  50ms   worst  50ms
wave 2: 2 requests   wait p50   0ms   worst   0ms
wave 3: 9 at once    wait p50  50ms   worst 100ms
high-water mark: 3 of 3 - held
```

Six into three slots: one 50ms queueing round. Two requests: through
untouched. Nine at once: the tail waits two full service times. That
last number is the one to frame — **a ceiling doesn't eliminate burst
cost, it converts it** from a provider-side 429 (opaque, retried,
billed twice) into local queueing (visible, measurable, bounded). The
wait table IS the capacity conversation: if 100ms of p-worst is
unacceptable at wave-3 volume, you need a second credential, and now
you know *before* production tells you.

## Design review of my own feature

- The `ensure` inside `RateLimit#acquire` — decrementing in-flight even
  when the block raises — is the difference between a limiter and a
  slow leak. I checked the shipped implementation first thing; it's
  there. Review your own requests hardest.
- High-water as a first-class reader means every demo doubles as a
  regression test ("3 of 3 - held"). Observability designed into the
  primitive, not bolted on.
- What it doesn't do (correctly, for now): time-windowed limits
  (requests-per-minute vs concurrent). Concurrency ceilings model
  connection limits; token buckets model quota. Both belong eventually,
  but shipping the semaphore-shaped one first was right — it's the one
  that can't be approximated from outside.

## Structured-concurrency footnote

The waves themselves are nested `task.async` fan-outs with `sleep`
staggering — the test harness for the feature is the same three
primitives as the feature. When your testing DSL is just your
concurrency model, the concurrency model is probably right.

## Verdict

Feature requested, shipped, and characterized under hostile load
within two rounds. The wait table converts "we should rate limit" from
compliance theater into an engineering table with numbers in it.
