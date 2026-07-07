# Round 8 field notes — Samuel Williams lets the throttle learn

*Built: `examples/adaptive_throttle.rb` — an AIMD controller probing
an upstream whose capacity is undisclosed, converging on it from
latency alone.*

## What I built and why

Aaron's knee finder (round 4) measures capacity *offline*; production
needs the online version, because upstream capacity isn't a constant —
it's a weather system (noisy neighbors, deploys, regional failover).
The answer is thirty years old: **AIMD**, TCP's congestion algorithm.
Probe up one lane per healthy batch; halve on congestion:

```
batch 3   target 3   20ms   healthy -> probe up to 4
batch 4   target 4   50ms   congested -> halve to 2
batch 7   target 4   50ms   congested -> halve to 2
...oscillates around 3.0 - the secret capacity is 3
```

The controller never sees `SECRET_CAPACITY`; it derives it from the
only signal a client legitimately has — its own latency — and the
sawtooth (2→3→4→halve) *is* the discovery, permanently re-verifying
itself. When the upstream degrades to capacity 2 next Tuesday, the
throttle notices within two batches. The static `concurrency_limit`
in your config noticed nothing, ever: it's a guess frozen at deploy
time.

## Why AIMD and not something cleverer

Because the sawtooth is a *feature*: the periodic probe upward is how
the controller learns capacity has increased, and the multiplicative
decrease is what makes many independent clients converge to a fair
share without coordinating (the same reason the internet doesn't
collapse). Fancier controllers (gradient, BBR-style) estimate faster
but need better signals; AIMD needs one comparator and one threshold.
Infrastructure defaults should be the dumb thing that provably
converges.

## Notes for the framework

- Built entirely in userland: a fresh `Async::Semaphore` per batch is
  the "adjustable limiter." That works but re-queues waiters at each
  resize; a first-class `limit.resize(n)` on `Agentic::RateLimit`
  would make the controller continuous rather than batched. That's my
  round-9 ask, and the controller here is its specification.
- The congestion threshold (1.6x base) is doing quiet work — too
  tight and healthy jitter reads as congestion (herd of false
  halvings), too loose and you camp in the degraded zone. Real
  deployments should set it from the journal's p50 history (Aaron's
  percentiles), closing the loop between the observability stack and
  the control stack.

## Verdict

The limiter family now has a missing-manual entry: fixed ceilings for
laws you know, windows for quotas you're billed, and — pattern
demonstrated, primitive requested — adaptation for capacities nobody
will tell you. The network figured this out in 1988; agent frameworks
get to skip the intervening collapse.
