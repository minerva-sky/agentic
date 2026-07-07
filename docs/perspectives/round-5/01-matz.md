# Round 5 field notes — Matz maps the dungeon

*Built: `examples/dungeon_crawl.rb` — a quest as a plan: rooms are
tasks, doors are dependencies, and the map is drawn from
`orchestrator.graph` before anyone delves.*

## What I built and why

Every dungeon game maintains two truths: the map the player sees and
the graph the engine walks — and every dungeon game eventually ships a
bug where they disagree. This crawl has one truth. The map is printed
from `orchestrator.graph`, the same frozen topology the scheduler will
execute:

```
[Entrance Hall]  <- you are here
[Treasury]  doors from: Spider Nest, Flooded Crypt
```

Then the party delves — nest and crypt in parallel, the treasury
waiting on both keys via `needs: {web:, depths:}` — and the loot fans
in: "a chest of coppers (unlocked with someone's boot and a silver
coin)." There is no second map to fall out of date, because the
document and the program are the same object. That is the deepest kind
of DRY: not avoiding repeated *text*, but avoiding repeated *truth*.

## What pleased me

- `graph` being **frozen** is the right manner. A map you can scribble
  on is a map you can lie with; the accessor hands you a photograph,
  not the territory's steering wheel. (I tried to mutate it, for
  science. `FrozenError`. Good.)
- Five features from three rounds cohabit in sixty lines without
  crowding: payloads, callables, positional deps, named needs, the
  graph view. New vocabulary that doesn't jostle the old vocabulary is
  the sign the design is growing rather than accreting.
- Seeded loot, again. "Reproducible whimsy" is my favorite genre now.

## A small observation for the maintainers

The map loop wants the rooms in *dependency order* (entrance first,
treasury last), and I got it by accident because insertion order
matched. `graph` preserves insertion order — Ruby hashes promise that —
but a plan built in scrambled order would print a scrambled map. A
`graph[:order]` with a topological sort would let map-drawers be
correct on purpose instead of lucky. (Aaron will want it for critical
paths within the hour; ask him.)

## Verdict

The framework can now draw itself before it runs itself. When a
library's introspection is good enough to build a game's UI from, the
architecture documents can retire — the code has learned to give the
tour.
