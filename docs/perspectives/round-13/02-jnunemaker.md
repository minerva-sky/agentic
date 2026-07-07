# Round 13 field notes — John Nunemaker flips the plan

*Built: `examples/feature_flags.rb` — a Flipper-shaped gate (boolean,
actor, percentage) deciding per run whether the experimental
fact-check step joins the plan, spliced in with `rewire_task`.*

## What I built and why

Flipper exists because "should this code run?" and "is this code
deployed?" are different questions, and teams that conflate them do
their product experiments with `git revert`. Plans have the same
conflation one level up: shipping a new pipeline *step* shouldn't be
a deploy decision. So — gates:

```
phase 1, flag off:      fetch -> summarize -> publish   (everyone)
phase 2, actor acme:    fetch -> summarize -> fact_check -> publish
phase 3, 50% rollout:   acme, globex checked; umbrella not yet
```

The Flipper essentials survive miniaturization intact: **boolean**
for kill-switch, **actor** for design partners (acme ran fact-checked
for a whole phase before anyone else — that's how you learn whether
the step is good *before* arguing about the rollout), **percentage**
with deterministic bucketing. That last adjective is load-bearing:
the bucket is a pure function of the actor, so the same tenant gets
the same verdict every run. Flapping flags — enabled this request,
disabled the next — are worse than no flags, because they turn every
bug report into a coin-flip archaeology dig.

## The step is a plan shape, not an if

The design decision I care most about: the experimental step is
**not** an `if FLAGS.enabled?` *inside* a task. It's a different
*plan*, built per run — the flag consults once at build time, the
step is added, and `rewire_task` (round 12's refactoring seam,
turning out to be a *runtime composition* seam) splices `publish`
onto the new step. Two payoffs: the graph is honest (`graph[:order]`
shows exactly which shape ran — every observability tool from
rounds 5-12 sees the flag's effect for free), and the off state has
*zero residue* — no branch, no dead code path, no "flag check" in
the hot loop. The plan either has the step or it doesn't.

And rollback is `disable`, not deploy. When fact-check misbehaves at
50%, you turn the dial to zero and the next run is the old plan —
while the code stays shipped, warm, and ready for the fix.

## Notes

- My first 50% phase put all three tenants in the bucket — small
  demo, small sample, embarrassing chart. Deterministic bucketing
  means you can *pick* demo tenants on both sides of the line, which
  is itself the operational point: with Flipper you always know
  which side an actor is on.
- Real Flipper adds groups and per-flag adapters; the 30-line
  version keeps gate-check-order (boolean, then actor, then
  percentage) because that ordering IS the semantics people rely on.

## Verdict

Flags decouple shipping code from running it; plans-as-data extend
that to shipping *steps* without running them. One flag, three
gates, three phases, and the rollout of a pipeline stage became a
dial instead of a deploy calendar.
