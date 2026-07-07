# Round 5 field notes — Xavier Noria diagrams the plan

*Built: `examples/plan_diagram.rb` — `orchestrator.graph` emitted as
Mermaid, with named dependencies as labeled edges.*

## What I built and why

Documentation that is generated from the artifact cannot disagree with
the artifact — that is the entire theory of this tool, and it is the
same theory as Zeitwerk's: derive the truth from one source rather
than maintaining two and hoping. `to_mermaid(graph)` is thirty lines;
GitHub renders the output; the diagram in your README regenerates in
CI and can never rot.

The detail I care most about: **named dependencies become labeled
edges**. `draft` doesn't merely have two arrows into it — the arrows
say `skeleton` and `citations`:

```mermaid
T1 -- skeleton --> T3
T2 -- citations --> T3
```

The `needs:` feature was pitched in round 3 as consumer ergonomics
(`t.needs.skeleton` beats positional lookup). This round reveals its
second dividend, which I'd argue is larger: the names are
*architectural documentation that survives extraction*. A diagram that
says WHY an edge exists — not just that it does — is the difference
between a graph and a design. Ergonomics decay into docs; that is the
best career path a parameter name can have.

## Precision notes

- The diagrammer must dedupe: `needs:` entries also appear in
  `graph[:dependencies]` (correctly — they ARE dependencies), so a
  naive emitter draws the edge twice, once bare and once labeled. The
  snapshot is honest; consumers must be too. I'd accept a
  `graph[:edges]` that pre-merges the two views with labels attached,
  as the convenience form.
- Stable node ids (`T0`, `T1`...) derive from insertion order, which
  Matz has already noted is a promise nobody has made. Both of us now
  want `graph[:order]`. When two cartographers independently request
  the same projection, the projection is real.
- I resisted emitting styling, subgraphs, and click handlers. A
  generator's output should be a *starting point* that a human can
  own, or a terminal artifact that no human touches — the middle
  ground (generated-but-hand-tweaked) is where diagrams go to rot,
  Mermaid or not.

## Verdict

The graph accessor is one round old and has now fed a game map, a
critical-path analyzer, a design critic, and a documentation
generator. Expose the right projection and an ecosystem assembles
itself around it — loaders taught me that; this gem is re-learning it
in public, quickly.
