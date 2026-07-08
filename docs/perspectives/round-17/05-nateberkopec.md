# Round 17 field notes — Nate Berkopec closes the scaling loop

*Built: `examples/queue_time_autoscaler.rb` — the consulting
playbook as a control loop: measure p95 queue time around the
acquire, scale by Little's law, resize the live worker pool with
`RateLimit#resize`, and let the identical spike re-run to prove the
math. Exit 1 unless scaling collapses the queue.*

## What I built and why

Round 11 I built the capacity *planner* — the spreadsheet. The brief
this round said build the *product*, and the product version of that
spreadsheet is a loop that doesn't need me on the retainer: measure,
decide, resize, verify. What I refuse to automate is the wrong
trigger, so the scaler's entire personality is one sentence I've
said in every engagement since 2015: **scale on queue time, never
utilization.**

```
wave                       workers  p95 queue  utilization  verdict
calm (10 req @ 33/s)         1        0.0ms       69%       healthy
spike (40 req @ 250/s)       1      613.8ms       99%       31x service -> resize 1 -> 6
spike_again (40 @ 250/s)     6        0.0ms       75%       healthy
```

The table is the argument. The calm wave ran one worker at 69%
utilization and no request waited — a utilization-triggered scaler
would have bought hardware for a machine that was merely earning
its keep. The spike posted 99% — but 99% doesn't tell you whether
you're fine or drowning; the 614ms p95 queue time against a 20ms
service time does, because queue time is the only metric with a
user attached. And the resize isn't a panic response: Little's law
(workers = arrival rate × service time, plus one for luck) computes
6, `pool.resize(6)` applies it to the *live* pool with no restart,
and the same 250/s spike re-runs at 0.0ms p95.

## Notes

- Queue time is measured at the only honest place: around the
  `acquire` itself, per request. Sampling it from outside the pool
  (or worse, averaging it) hides exactly the tail you're paying for.
- The framework gave me the two halves of the loop for free: the
  plan runs requests as fibers under one ceiling, and `RateLimit`
  is resizable mid-flight (round 9's ask, still compounding). The
  scaler is ~30 lines of decision between them.
- Headroom is "+1", not "+50%". If you need more slack than one
  worker, your service time is lying to you — measure it again.
- Production wants a sampling window and hysteresis (don't downscale
  on one quiet second). The trigger metric is the part that must not
  change.

## Verdict

Three waves, one resize, queue collapsed 614ms → 0. Utilization is
a lie with a dashboard; queue time has a user attached; Little's
law is not advice, it's arithmetic. The pool being resizable at
runtime is what turns a capacity report into a capacity *product*.
