# Round 8 field notes — Aaron Patterson interrogates the variance

*Built: `examples/variance_detective.rb` — twenty journaled runs, then
a p90/p50 hunt for the task whose tail betrays it.*

## What I built and why

`duration_percentile` shipped this round (my ask from the perf-history
notes), so the detective works the case averages can't crack:

```
fetch:profile             22ms  24ms   1.1x
fetch:recommendations     22ms  91ms   4.2x  <- SUSPECT
```

Same median as its innocent neighbor — **identical p50s** — and a p90
four times higher. An average would report ~40ms and imply a task
that's uniformly a bit slow; the percentile spread reports the truth:
fine most of the time, terrible 30% of the time, which is the
signature of cold caches, lock contention, or a silently retried
upstream. Flakiness is a *distribution shape*, not a magnitude, and
you cannot see shape in a scalar.

## Craft notes

- The p90/p50 *ratio* is the right detector because it's
  scale-invariant: a 2ms task with an 8ms tail and a 2s task with an
  8s tail are the same pathology at different magnitudes. Absolute
  thresholds would miss one or false-positive the other.
- Twenty runs, not ten. My first draft used ten and the seed
  cooperated with the suspect — the 30% slow path fired often enough
  to drag p50 itself onto the slow side, and the ratio went quiet.
  Percentiles need *samples*; a p90 over ten points is an anecdote
  wearing math. This is the flakiness-detection version of the noise
  floor lesson: statistical tools have minimum feeding requirements,
  and starving them produces confident nonsense.
- The journal made the boring part free: twenty runs accumulated
  samples by description with zero harness code, because
  `duration_samples` just collects what the fsync was already
  writing. The perf suite (Gantt, knee, path, diff, history) now ends
  where it should: variance.

## Where this goes in CI

Nightly: run the plan N times, journal them, fail if any task's ratio
crosses 3x. Flakiness caught *before* it becomes the intermittent
timeout that eats an on-call week — every infra team has that one
task, and none of them found it from a dashboard of averages.

## Verdict

Six performance tools, one journal, and the last one answers the
question that starts the most arguments: "is it slow, or is it
*sometimes* slow?" Those are different bugs with different fixes, and
now they have different numbers.
