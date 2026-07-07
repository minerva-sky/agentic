# Round 7 field notes — Aaron Patterson consults the history

*Built: `examples/perf_history.rb` — this release's run judged against
the journal the last release left behind. The baseline is what
production actually did.*

## What I built and why

My round-6 perf diff had one dishonesty I confessed at the time: it
re-ran the baseline in the same process, same load, same thermal
state — a luxury production never gets. The round-7 release closed the
gap: journal replays now expose `durations` keyed by description, so
the baseline is **the fsynced record of the last run that actually
shipped**:

```
generate:captions    80ms -> 140ms  +60ms  REGRESSED
package:episode      50ms ->  20ms  -30ms  faster
exit 1
```

No benchmark rig, no synthetic load, no "runs on my machine." The
journal was written for crash recovery (round 2); it turns out a
durability log and a performance baseline are the same file read with
different questions. That's my favorite kind of feature — the one
that's been sitting in your data the whole time waiting for an
accessor.

## Why description-keyed baselines are the right physics

Task ids are per-run UUIDs; descriptions are stable. That decision —
made by Perham in round 4 for *resume* semantics — is exactly what
makes cross-release comparison sound: `generate:captions` in release 2
matches `generate:captions` in release 1's journal regardless of when
either ran, in which process, at what id. One naming discipline, three
payoffs (resume, check-ins, baselines). Stable identity is the
cheapest infrastructure you'll ever build.

Practical notes for real deployments:

- **Latest-wins is the right default** for the durations map (the
  journal may hold many runs; you baseline against the most recent),
  but percentile baselines over N runs would resist noise better —
  the events array has everything needed; a p50-of-last-5 helper is a
  ten-line follow-up.
- The noise floor matters *more* here than in round 6: production
  baselines carry production variance. Calibrate against your
  journal's own history (stddev per task), not a magic 15ms.
- Missing-from-baseline tasks (new in this release) are skipped, not
  flagged — new tasks have no history and get a pass exactly once.
  Their first journal entry becomes their accountability.

## Verdict

The perf suite's last synthetic component is gone: Gantt, knee, path,
diff — and now the diff's baseline is history instead of hope. CI can
gate releases against the journal of the last one, which means the
question "did we get slower?" finally has a source of truth that
nobody has to maintain.
