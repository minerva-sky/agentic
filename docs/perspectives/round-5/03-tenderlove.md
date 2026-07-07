# Round 5 field notes — Aaron Patterson walks the critical path

*Built: `examples/critical_path.rb` — graph topology plus measured
durations yields the chain that determined the wall clock, then proves
it by experiment.*

## What I built and why

The knee finder answered "how many lanes"; this answers the question
that comes right after: "which task is the wall clock's fault?" The
answer is never "all of them" — it's the **critical path**, the longest
duration-weighted chain through the dependency graph:

```
wall clock:      341ms
critical path:   340ms  =  pull:orders -> invoice:month -> report:board
(path explains 100% of the wall clock)
```

And because engineers rightly distrust analyzers, the program runs the
experiment instead of asking for faith: make an *off-path* task
instant — wall time unchanged, 341 → 341. Halve the slowest *on-path*
task — 341 → 251. There's your sprint planning: `pull:orders` is the
only work item, and anyone polishing `pull:catalog` is doing charity
for a metric no one measures.

## What the round-4 accessor made possible

The path computation is fifteen lines of memoized DFS over
`orchestrator.graph` joined with durations from one hook. In round 3 my
Gantt *rebuilt* the topology by eavesdropping on hooks, which meant it
could only see what executed; the graph accessor knows what was
*declared*, which is what lets the analyzer say "this chain, and no
other chain, bounds you." Sandi's crowbar complaint became my
load-bearing API within one round — that's the compounding this
experiment series keeps demonstrating.

Matz already filed the follow-up I want: `graph[:order]` (topological).
My DFS re-derives it implicitly; a critical-path tool, a map drawer,
and a scheduler visualizer shouldn't each write their own toposort.

## Perf-nerd footnotes

- "Path explains 100% of the wall clock" is itself a diagnostic: if
  that number drops much below ~95%, your bottleneck isn't the work,
  it's the *scheduler* (queue waits from a too-tight limit). Pair this
  with the knee finder: knee for capacity, path for latency.
- The experiment reruns the whole plan with modified sleeps —
  affordable here, but the analysis itself is O(V+E) memoized and
  needs no rerun. Ship the analysis in CI; save the experiment for
  demos and skeptics.

## Verdict

Three tools now form a performance suite this framework didn't have
five rounds ago: Gantt (where time went), knee (how many lanes), path
(which task matters). All three built from two hooks and one accessor.
APIs that compound are the ones worth shipping.
