# Round 6 field notes — Mike Perham judges the jitter shootout

*Built: `examples/jitter_shootout.rb` — none vs equal (the default) vs
full (this round's release), same forty synchronized workers, three
histograms, one scoreboard.*

## What I built and why

Round 5's stampede sim argued for the jitter *default*; this round the
`:full` tier shipped, so the shootout puts all three modes on one
seeded scoreboard:

```
none:          peak 40 of 40   spread   2ms
equal +/-25%:  peak 19 of 40   spread  75ms
full [0,d]:    peak 13 of 40   spread 152ms
```

No jitter is a synchronized herd — all forty in one 25ms bucket,
which is a DDoS you scheduled against yourself. Equal jitter (the
default) halves the peak. Full jitter — retries drawn uniformly from
`[0, delay]` — cuts it to a third and doubles the spread, at the cost
of *punctuality*: some workers retry almost immediately, one waits
nearly the full backoff. That trade is exactly right for the
recovering-upstream case: **when the service is already hurting,
"together" is the only wrong arrival time.** This matches the AWS
Architecture Blog's classic analysis, and now the gem's histogram
matches the literature's math, reproducibly, with a seed.

## Operational guidance, straight from the table

- Default (equal) is correct for most fleets: bounded delay variance
  keeps p99 retry latency predictable, peak halves for free.
- Switch to `:full` when the retry *target* is the bottleneck — rate
  limits, brownouts, thundering-herd-prone startup paths. You're
  trading your own latency tail for the upstream's survival, which is
  the right trade because a dead upstream has infinite latency.
- `none` is for tests asserting exact delays, and nothing else. It's
  opt-in now, which is where footguns belong: in the drawer, labeled.

## Notes

- The three-mode comparison needed zero framework hooks — arrivals
  recorded in the agent, seeded via `srand` since the policy uses
  `Kernel#rand`. Policy knobs that honor global seeding are testable
  policy knobs; whoever wires custom RNG injection later should keep
  that property.
- Peak-per-bucket is the metric because upstreams die of *instantaneous*
  concurrency, not totals. Forty retries over 150ms is fine; forty in
  2ms is an incident. Measure what kills you.

## Verdict

Three modes, one seed, one scoreboard: 40 → 19 → 13. The default
protects everyone, the `:full` tier protects the wounded, and the
histogram means nobody has to take my word for any of it anymore.
