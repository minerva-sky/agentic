# Round 16 field notes — Eileen Uchitelle rehearses in production

*Built: `examples/shadow_traffic.rb` — v1 serves every request while
v2 runs in the shadow on the same inputs: results compared,
mismatches journaled, users untouched. The cutover decision becomes
a table.*

## What I built and why

Upgrading load-bearing infrastructure at GitHub scale taught me the
rule I trust most: **the safest replacement is the one that never
answers until it's proven.** Blind cutovers bet the pager; staging
bets that staging resembles production (it doesn't; production's
inputs are weirder than anyone's fixtures). The move that works is
the scientist pattern — serve from the incumbent, run the candidate
beside it on real traffic, compare, throw the candidate's answer
away:

```
6 requests served by v1; 6 shadowed by v2
agreement: 5/6 (83%)   latency: v1 p50 0.01ms, v2 p50 1.17ms
mismatch: "Please resend my invoice" - served: general | candidate: billing
```

And there it is — the mismatch is *exactly the case that would have
paged* after a blind cutover. v2 casts a broader net ("invoice"),
which is either the bug finally fixed or a regression introduced.
The shadow can't tell you which; what it guarantees is that a
**human decides with the example in hand**, before a single user
was reclassified. That's the entire trade: rehearsal buys you the
argument with evidence instead of the incident with apologies.

## The discipline clauses

Three rules make shadowing safe rather than merely interesting, and
the example enforces each:

1. **The shadow's output feeds nothing.** Asserted on every request
   — the plan raises if v2's answer ever reaches serving. A shadow
   that leaks is a cutover you didn't schedule.
2. **Shadow failures can't fail the plan.** The candidate crashing
   is *data* (it goes in the report), never an outage.
3. **Comparisons land in the journal** — the same fsynced file the
   recovery and audit tooling already read. The cutover meeting
   replays a file; nobody's memory is load-bearing.

The plan shape made this almost free: `shadow` depends on `serve`
via `previous_output`, so the comparison has both answers without
any side channel — the declared edge IS the comparison wire (eregon
would note the shadow is schedule-independent for exactly this
reason).

## Notes

- Latency rides along in the same report (v2 is 100x slower here) —
  agreement without latency is half a cutover decision, as the
  capacity-planning seat keeps reminding this series.
- At real scale you'd sample (shadow 1% of traffic), cap shadow
  concurrency with its own limiter so the rehearsal can't starve
  the show, and diff structured outputs field-by-field. All three
  are additive; none change the shape.

## Verdict

v2 rehearsed on live traffic, disagreed once, and the disagreement
is now a line in a table with the request attached — reviewed by a
person, felt by no one. Rehearse in production, serve from the
incumbent, cut over on evidence. Scale isn't bravery; it's
choreography.
