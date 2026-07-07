# Round 9 field notes — Samuel Williams shares the door fairly

*Built: `examples/fair_share.rb` — two tenants behind one global
ceiling: request-fairness vs tenant-fairness, and live share
rebalancing via `resize`.*

## What I built and why

The most common multi-tenancy bug isn't a race — it's a definition.
A FIFO semaphore is perfectly fair *to requests*. But tenant A hires
six workers and tenant B hires two, so "fair to requests" resolves,
silently, to "A gets triple." Nothing errors. Nothing pages. B just
runs at half its entitlement forever:

```
no shares, one door for all     A: 76   B: 24    <- B wants 48
2/2 shares, same greedy A       A: 52   B: 48    <- B whole again
B idle, static 2/2 shares       A: 52   B: 0     <- 2 lanes stranded
B idle, shares rebalanced 4/1   A: 98   B: 0     <- lent, live
B returns, back to 2/2          A: 52   B: 48    <- returned, live
```

The fix is the composition we built in round 7: each tenant acquires
its *own share first*, then the shared door — `share_a.and(global)`.
Phase 2 shows what that buys: B reaches its full 48 no matter how
many workers A hires, and A soaks up whatever remains. Fairness
between tenants, work-conservation within the door.

## What resize adds

Static shares have a tax, and phase 3 states it plainly: B goes idle
and B's two lanes serve *nobody* — the global door runs half empty
while A queues. Before this round, the options were ugly: rebuild
the limiter objects (and re-hand them to every client holding one)
or over-provision the global and pray.

`resize` makes shares a *dial on a live object*. Phase 4 lends B's
spare lane to A mid-flight — A jumps to 98 — and phase 5 takes it
back the moment B returns. The composition never changes shape; no
fiber holding a limiter notices anything except capacity arriving or
draining away. That's the property I care most about: the *topology*
of the limiter graph is fixed at boot, and only the *numbers* move
at runtime. Topology changes race; number changes don't.

## Notes

- My first draft gave B a single worker, and the numbers refused to
  cooperate: B served 24 in phase 1 *and* phase 2 — no starvation,
  because one serial worker can only ever want one lane. The chart
  was right and my story was wrong: starvation requires unmet demand,
  so B needed two workers wanting two lanes. This is now the fourth
  round in which a tool corrected its author before the user saw it.
- Order matters in the composition: own share first, then the door.
  Acquire them the other way and an over-subscribed tenant holds
  global capacity while waiting on its own share — the deadlock-shaped
  version of the same idea.

## Verdict

Request-fairness and tenant-fairness look identical until the tenants
are unequal, which is always. Composition makes the distinction
enforceable, and resize makes it affordable — the idle tenant's lanes
no longer cost the busy one anything. Fairness as an adjustable
object, not a config value baked at boot.
