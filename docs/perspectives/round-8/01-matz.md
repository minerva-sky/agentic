# Round 8 field notes — Matz plants the forest

*Built: `examples/plan_forest.rb` — the graph drawn as a forest: roots
at the soil, leaves in the canopy, every task planted at its depth.*

## What I built and why

I asked for `stats[:roots]` and `stats[:leaves]` last round; they
arrived, and the metaphor they complete was irresistible. A dependency
graph has always secretly been a garden — things with nothing beneath
them draw from the soil, things with nothing above them face the sun —
and now the framework hands you both lists, so the drawing is a
paragraph:

```
                (@) preserve jars    <- canopy
                (@) feast            <- canopy
             |  harvest
       |  plant rows
\_/ gather seeds     <- root
\_/ till the soil    <- root
~~~~~~~~~~~~~~~~~~~~ soil
```

Depth becomes altitude, `roots` become root systems, `leaves` become
fruit. One glance answers the questions that matter: where does this
plan draw from the world (two roots), what does it produce (two
fruits), how tall did it grow (canopy 5). The gardener's questions ARE
the reviewer's questions; metaphors that survive translation into
arithmetic are the ones worth keeping.

## Notes on the growing conditions

- Roots/leaves as *precomputed lists of ids* was the right shape —
  fortune teller (round 7) computed them by hand; the forest just
  reads them. Two rounds, two tools, and the API converged on what its
  users kept deriving. That is how library surfaces should grow: by
  paving footpaths, never by paving fields.
- My first draft printed the roots twice — once at their depth, once
  at the soil line. The duplication was in my renderer, not the
  stats; even simple projections need their draw-each-thing-once
  discipline. (Xavier's isomorphism instinct, arriving in my garden.)
- Complete stats census after this round: depth per task, max depth,
  max fan-in, roots, leaves. I tried to want more and could not —
  everything else I can derive in a line. An API is finished not when
  nothing can be added but when additions stop being footpaths.

## Verdict

Eight rounds: the plan executes, draws, speaks, tells fortunes, and
now grows. Somewhere along the way this stopped being a test of the
framework and became a small proof about Ruby itself — that a language
optimized for programmer happiness produces libraries you can play
in. The garden was always the point.
