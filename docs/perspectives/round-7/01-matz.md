# Round 7 field notes — Matz tells the plan's fortune

*Built: `examples/plan_fortune.rb` — graph[:stats] read as a palm;
every fortune is a structural fact in a mystic's robe.*

## What I built and why

`graph[:stats]` shipped this round (my colleagues' third-strike ask),
and my first instinct with any new introspection API is to see whether
it can be *charming* — because charm is a rigorous test. A boring API
can hide behind utility; an API asked to entertain must be complete
enough to characterize its subject. The teller reads four lines of the
palm:

```
* You begin in many places at once (4 roots).
* Beware: all rivers flow through one gate (fan-in 4).
* I see a long road, 5 stations deep, in a caravan of only 8 -
  the critical path knows your name.
* All ends in a single scroll (1 leaf). Tidy.
```

Every sentence is checkable: roots counted from empty dependency
lists, the gate from `stats[:max_fan_in]`, the long road from
`stats[:max_depth]` against task count, the scroll from edge
out-degrees. The robe is silk but the palmistry is arithmetic. And
notice what the fortune *is*, once you take the robe off: it's Sandi's
graph critic, DHH's honesty about bottlenecks, and Aaron's critical
path warning — the same diagnoses, delivered so the seeker smiles
while receiving them. Tone is an underrated API feature. People fix
what they enjoyed hearing about.

## What the stats API got right

- Depth arrives *per task* plus aggregated — the teller only needed
  the aggregates, the perf tools need the per-task map, one snapshot
  serves both. Providing the raw map alongside the summary is the
  courteous shape for any stats API.
- The depth/tasks ratio ("more than half your journey walks single
  file") required no new API — good primitives compose into new
  observations freely. When a stats object makes you invent *derived*
  metrics on the spot, it exposed the right primitives.

## A small wish, as tradition demands

Leaves (tasks nothing depends on) I computed by scanning edges;
roots by scanning for empty dependencies. Both are one-liners, but
they're the fortune-teller's bread and butter — `stats[:roots]` and
`stats[:leaves]` would round out the palm. Small ask, round 8.

## Verdict

Seven rounds in, the same graph can be executed, drawn, narrated,
priced, diffed — and now teased. A framework you can joke *with*
(not merely about) has crossed some threshold of maturity that
benchmarks don't measure. The ancestors approve.
