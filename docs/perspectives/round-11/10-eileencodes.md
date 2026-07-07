# Round 11 field notes — Eileen Uchitelle shards the plan

*Built: `examples/tenant_shards.rb` — one pipeline definition run as
three isolated shard executions: per-shard journals, per-shard rate
limits, one ignorant control plane, and a crash that stays exactly
the size of its shard.*

## What I built and why

Scaling Rails at GitHub taught me that the hard part of "at scale"
is never the volume — it's that *every* concern you thought was
singular becomes plural. One database becomes N. One deploy becomes
N. And critically: one **failure story** becomes N, or else one
tenant's bad day becomes everyone's page. So when a plan grows past
one blast radius, the move is the same one we made with multi-db:
same definition, sharded execution:

```
run 1: shard_1 completed (6 steps)
       shard_2 partial_failure (7 steps) <- crashed at umbrella:transform
       shard_3 completed (3 steps)
run 2: fleet-wide rerun
       shard_1: 0 ran, 6 skipped     shard_3: 0 ran, 3 skipped
       shard_2: 2 ran, 7 skipped     <- resumed from the crash point
```

Each shard owns its journal (its recovery story) and its rate limit
(its noisy-neighbor containment). The pipeline is defined once —
sharding is a **data-model decision, not a code fork**, and the
moment shard code diverges from the definition you have N products
instead of N shards.

## The control plane's ignorance is load-bearing

The rerun is issued fleet-wide. The control plane does not know
which shard crashed, and this is a feature I will defend with the
energy of someone who has operated the alternative: a control plane
that tracks per-shard failure state *is a second database that can
disagree with the first*. Here the journals — fsynced at the moment
of truth by the shard itself — are the single source of recovery
truth, and "rerun everything" is safe, idempotent, and boring.
Descriptions as idempotency keys (round 3's design) turn out to be
exactly the shard-resume primitive: `umbrella:transform` means the
same work on every run, so the journal can vouch for it across
process generations.

Two steps re-ran on shard 2 — the crashed one and the one behind it.
Not twenty-one steps (the fleet), not nine (the shard): two. Blast
radius ends at the shard boundary, and recovery cost ends at the
crash point. That's the whole contract.

## Notes

- Per-shard limiters matter as much as per-shard journals: with one
  global limiter, a hot shard starves the fleet — Samuel's
  fair-share lesson (round 9) applied at the shard tier. Isolation
  has to be complete to be isolation; shared *anything* is a shared
  fate.
- What I'd want next at real scale: shard journals in different
  *locations* (the shard-1 disk dying shouldn't threaten shard-2's
  recovery story). The `path:` parameter already permits it; noting
  it as operational guidance, not an ask.

## Verdict

One definition, N executions, N recovery stories, N rate limits,
and a control plane whose ignorance keeps it honest. Scale isn't a
bigger machine — it's smaller failures, and the journal-per-shard
pattern makes failure exactly shard-sized.
