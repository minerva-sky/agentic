# Round 14 field notes — Sam Saffron leaves the profiler on

*Built: `examples/always_on_profiler.rb` — a badge line on every
plan, latency budgets that name the offender, and an overhead audit
proving always-on costs ~144 microseconds.*

## What I built and why

rack-mini-profiler's founding heresy was that profiling belongs in
**production**, on **every request**, visible to the **person who
wrote the slow code** — not in a lab you visit twice a year with a
flamegraph and a prayer. The lab model finds regressions you already
shipped; the badge model finds them in the PR preview, because the
person who made it slow *watches the badge go red before merging*.
Plans deserve the same heresy:

```
[prof] completed   67ms  3 tasks  top: rank (30ms)       within budget
[prof] completed  141ms  3 tasks  top: summarize (95ms)  OVER BUDGET (120ms)
                                                         <- fix summarize first
[prof] completed    5ms  1 task   top: check (5ms)       within budget
```

Three rules made mini-profiler work at Discourse scale, and all
three transplant:

1. **Always on.** Sampling is for whales; a plan runs dozens of
   times a day, not millions, so you can afford to measure
   everything. No "enable profiling" flag that nobody flips until
   the incident.
2. **Visible to the author.** A badge in the output the developer
   already reads — not a Grafana dashboard nobody opens until
   paged. Proximity is the whole psychology: the feedback loop has
   to be shorter than the attention span.
3. **Budgets with a named offender.** "Over budget, fix summarize
   first" is an *assignment*; a p95 chart is a vibe. The badge
   doesn't just say slow — it says where, because the hooks already
   carry per-task durations and the max_by is free.

## The overhead audit is the license

Always-on is only defensible when it's near-free, so the example
audits itself: 30 plans with hooks, 30 without — **144 microseconds
per plan**. That number is the entire argument. When someone asks
"won't the profiler slow us down?", the answer isn't a philosophy,
it's a measurement the profiler itself produced. (byroot's rule
from round 12 applies to profilers too: weigh the layer before
having opinions about it.)

## Notes

- The badge prints from the `plan_completed` hook and clears its
  buffer — per-plan state, no accumulation, safe for the always-on
  lifetime. Profilers that leak are how "always on" gets turned off.
- What I'd add at Discourse scale: the badge writes to the journal
  too (one line per plan), so palkan's round-12 group profiler gets
  its raw material for free and the "who regressed last Tuesday"
  question meets amatsuda's tail pager. The observability tools in
  this repo keep composing because they all drink from the hooks.

## Verdict

Every plan now wears its cost on its sleeve, over-budget plans name
their own fix, and the whole apparatus costs 144 microseconds —
cheap enough to never turn off, which is the only kind of profiling
that catches regressions before users do.
