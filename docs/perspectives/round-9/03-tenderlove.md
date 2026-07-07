# Round 9 field notes — Aaron Patterson finds the knee

*Built: `examples/throughput_knee.rb` — one limiter swept from ceiling
1 to 8 via `resize`, two clocks per job, and the exact ceiling where
more concurrency stops buying throughput.*

## What I built and why

Every team eventually has the "just raise the concurrency" meeting.
Someone raises it, latency gets worse, someone else lowers it too far,
and the final number is whoever argued loudest. I wanted the number to
come from a sweep instead: resize one limiter through every ceiling,
push the same 24 jobs through each, measure, done.

```
ceiling   jobs/sec   service p50   total p50
4           198.5       20.1ms       80.3ms   <- the knee
5           132.8       40.1ms      100.2ms
8            79.8      100.1ms      140.2ms
```

The upstream secretly runs 4 in parallel. The sweep found it without
being told — and `resize` is what made the sweep honest: one limiter
object, eight ceilings, no rebuild-and-reshare between rows.

## Two clocks or you're lying to yourself

The design decision that matters: every job gets timed twice.
*Service time* starts when the limiter admits you; *total time*
starts when you submit. The difference is your queue — the wait you
can see. Below the knee, service time is flat at 20ms and total time
shrinks as lanes open: your queue is draining faster. Above the knee,
**service time itself rises** — the queue didn't disappear, it moved
to the server's side of the wire, where your metrics can't see it
and your timeouts will misattribute it.

That's the diagnostic worth memorizing: *when raising your ceiling
raises the server's latency, you found their ceiling, not yours.*

And one measurement corrected my own script's prose: I wrote
"throughput goes flat past the knee" and the table said it *falls* —
199 → 133 → 80 jobs/sec. Of course it falls: this upstream degrades
everyone under overload, not just the excess. Flat is the best case;
falling is the common one. The chart knew better than I did, which
is the whole reason to make the chart.

## Notes

- The knee detector is one line: the first ceiling whose successor
  gains less than 8%. Crude, but it only has to beat "whoever argued
  loudest," and it does.
- Samuel's adaptive throttle (round 8) and this sweep are the same
  physics, opposite instruments: his AIMD *tracks* the knee
  continuously in production; mine *maps* it once on a bench. You
  want the map to set the initial ceiling and the tracker to follow
  the knee when it moves.

## Verdict

Ceiling arguments are now a bench run: sweep, watch both clocks,
read the knee off the table. The polite move past someone else's
ceiling is to stop pushing — and now you know exactly where their
ceiling is.
