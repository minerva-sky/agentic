# Round 11 field notes — Nate Berkopec does the capacity math

*Built: `examples/capacity_planner.rb` — Little's Law over the
journal's duration percentiles, then the plan checked against every
configured limit. The binding constraint wasn't the one the meeting
was about.*

## What I built and why

"How many workers do we need?" is the most expensive question teams
answer by feeling. The feeling-based answers cluster at two poles:
over-provision 4x (pay the cloud bill forever) or size to the demo
(page the on-call forever). Meanwhile the actual answer has been
math since 1961: **L = λW**. Concurrency needed equals arrival rate
times service time. The journal already stores W — per-task duration
samples across thirty runs — so the planner only needs λ, your peak
target:

```
task           p50      p95      lanes (p50/p95)
fetch:ticket    83ms     158ms    1 / 1
classify       364ms     751ms    1 / 2
draft:reply    993ms    2387ms    2 / 5
total at p95: 8 lanes for 120 tickets/min
```

**Plan for p95, not p50.** Capacity sized to the median queues every
time latency has a bad day, and in this journal latency has a bad
day one run in eight — which is what real latency looks like
(log-normal-ish, long right tail), not what the demo looked like.
The gap between the p50 plan (4 lanes) and the p95 plan (8) is
exactly the gap between "works" and "works during the incident."

## The constraint that wasn't in the meeting

Then the part that actually saves the quarter: check the computed
plan against *every* limit in the system, not just the one under
debate. The meeting was about `concurrency_limit: 8` — which, the
math says, *holds*. The provider quota of 90/min against 120/min
arrivals is the real story, and it's not a "slowdown": λ/μ > 1 has
**no steady state**. The queue grows without bound until something
breaks, and the something is usually memory, at 3am, wearing the
disguise of an unrelated alert. Utilization greater than one isn't
a performance problem; it's an arithmetic problem, and no amount of
worker tuning fixes arithmetic.

This is the recurring shape of capacity incidents: everyone tunes
the limit they own, and the binding constraint belongs to a vendor
contract nobody re-read. The planner's job is to put all the limits
in one table with one verdict column.

## Notes

- The journal made this a twenty-line tool. Percentile baselines
  across runs (`duration_percentile`, round 8) were built for
  regression-hunting; capacity planning is the same data asked a
  business question. Good telemetry keeps being reusable like this.
- The planner deliberately reports lanes *per task*: draft:reply
  needs 5 of the 8, so if you shard workers by task type, that's
  your split — and if draft:reply gets slower next release, Aaron's
  perf tools and this planner will disagree with the cloud bill in
  the same direction, which is how you know to act.

## Verdict

A journal plus Little's Law is a capacity plan; a dashboard plus a
feeling is a postmortem. The math took thirty lines, found the
binding constraint outside the meeting's agenda, and turned "how
many workers?" into a question with a receipt.
