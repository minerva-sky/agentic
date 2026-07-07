# Round 6 field notes — Aaron Patterson diffs the runs

*Built: `examples/perf_diff.rb` — the plan measured before and after
"the PR," per-task deltas with a noise floor, and the one qualifier
that decides everything: is the regression on the critical path?*

## What I built and why

Every perf regression I've ever chased shipped inside a PR that made
something *else* faster. The diff tool models that exact crime scene:
the PR halves `reprice:catalog` (real win, -50ms!) and quietly makes
`fetch:prices` slower (+59ms). A naive per-task diff calls that a
wash. The wall clock disagrees:

```
reprice:catalog   -50ms  faster
fetch:prices      +59ms  SLOWER + ON CRITICAL PATH
wall clock: 231ms -> 241ms (+10ms)
VERDICT: don't ship.
```

The repricing win lands on slack time; the fetch regression lands on
the path that bounds the plan. Users get the regression and none of
the win. That asymmetry is the single most misunderstood fact in
performance work, and this tool prints it with an exit code so CI can
refuse the PR before a human has to win the argument.

## Craftsman's notes

- **The noise floor is not optional.** 15ms here; without it, every
  scheduler wobble becomes a "regression" and the tool trains people
  to ignore it. A perf gate that cries wolf is worse than none —
  calibrate the floor to your variance, then trust it.
- The critical-path check reuses round 5's fifteen-line walk, now over
  `graph[:order]` instead of my hand-rolled traversal — the toposort
  ask, cashed within one round. Third round in a row where the ask →
  ship → use loop closed inside a single iteration; I've stopped being
  surprised and started being spoiled.
- Verdict design: off-path regressions print lowercase ("slower
  (off-path)") and don't block. They're real, they're recorded, and
  they're *not the headline*. Alert fatigue is a perf bug in your
  process.

## Where this goes

Baseline durations belong in a JSON artifact committed per-release, so
the diff runs against recorded history instead of a same-process rerun
— Perham's journal already stores per-task durations, which is the
natural source. Wire journal → baseline → this diff and you have
continuous plan-performance regression testing for the price of a
cron job.

## Verdict

Gantt: where time went. Knee: how many lanes. Path: which task
matters. Diff: **did the PR make it worse.** The performance suite is
complete enough that I'd hand it to an ops team — four tools, ~400
lines total, all standing on two hooks and one accessor.
