# Round 6 field notes — Samuel Williams keeps the quota

*Built: `examples/quota_keeper.rb` — the same twenty requests through a
concurrency ceiling and through the new windowed quota; the admission
charts show they are different physics.*

## What I built and why

Round 5 I said concurrency ceilings model connection limits and
windowed quotas model billing, and that both belong. The windowed mode
shipped (`RateLimit.new(5, per: 0.2)`), so this round the two laws
face the same twenty requests:

```
concurrency 3:    0-200ms  #################### 20   (done by 61ms)
window 5/200ms:   0-200ms  #####  5
                200-400ms  #####  5
                400-600ms  #####  5
                600-800ms  #####  5                   (done by 601ms)
```

Same workload, **61ms versus 601ms** — a 10x difference dictated
entirely by which law you chose. Under a concurrency ceiling,
finishing early frees a slot, so fast calls drain the queue at IO
speed. Under a window, finishing early buys *nothing*: five per
period is five per period. Anyone who has ever "optimized" their API
calls and watched throughput not move has met a window while modeling
a ceiling — the chart pair is that lesson in one screen.

## Implementation review (I read the shipped code first, as always)

- The windowed algorithm is the honest simple one: prune stamps older
  than the window, admit if under ceiling, else `sleep` until the
  oldest stamp exits — and that sleep suspends only the *acquiring
  fiber*, so unrelated reactor work proceeds. Fiber-friendly waiting
  is the whole reason this can live in-process instead of in Redis.
- Stamps record at *admission*, making this a sliding-window-of-starts
  — the same law OpenAI and Anthropic quota by. A leaky-bucket variant
  smooths differently; the admission-stamp choice is the right default
  because it matches what providers measure.
- One thing to document: windowed mode intentionally does not bound
  *concurrency* (all five of a window's calls may be in flight
  together). Production wants both laws at once — a window for quota
  and a ceiling for sockets - which today means nesting two limiters.
  `RateLimit.new(3, and_per_window: [30, 60])`... no. Two objects,
  composed. The primitive is right; the composition is the user's
  sentence to write.

## Verdict

Two laws, one class, an honest chart apiece. The rate-limiting story
that started as a crowbar in round 4 is now a taxonomy with
measurements — which is what infrastructure maturity looks like.
