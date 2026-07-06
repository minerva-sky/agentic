# Round 5 field notes — Sandi Metz teaches the three shapes

*Built: `examples/three_shapes.rb` — the same six units of work as a
chain, a star, and staged joins; measured, critiqued, and chosen on
purpose.*

## What I built and why

My graph critic (round 4) could smell a bad shape; this round's tool
teaches the *choosing*. Same workload, three arrangements, and for
each: wall time (measured by running it) plus two structural numbers
read straight off `orchestrator.graph` — depth and max fan-in. One
table, three trades:

```
chain    243ms   depth 6   fan-in 1   trivially debuggable; pays serial price
star     121ms   depth 3   fan-in 4   fastest; one join owns every failure mode
staged   121ms   depth 3   fan-in 3   nearly as fast; each join has one reason to wait
```

The lesson I've taught for years about objects transfers whole: **none
of these is wrong.** The chain is right when the work is truly
sequential. The star is right when the join is trivial. The staged
shape is right when the join has judgment in it, because judgment
deserves small, single-purpose homes. What's *wrong* is not knowing
which one you built — accidental architecture, the graph edition.

Note what the measurement adds that intuition misses: star and staged
tie on wall time (121ms — the scheduler forgives fan-in that fits the
concurrency limit). So the choice between them is **entirely** about
failure modes and change cost, not speed — which is exactly the
conversation teams skip when they only look at latency. The numbers
free you to argue about design.

## On building teaching tools with this framework

- The structural facts are eight lines over the graph accessor; the
  behavioral fact is one `execute_plan`. Structure cheap, behavior
  honest — a teaching tool needs both, because students (rightly)
  distrust tools that only theorize.
- This is my third graph tool in three rounds (critic, tracer,
  shapes), and they compose into a curriculum: *see* the conversation
  (tracer), *smell* the structure (critic), *choose* the shape
  (shapes). A workshop hiding in an examples directory.
- The depth/fan-in computation is now written in three examples
  (critic, critical path, here). When teaching materials repeat a
  computation, the library wants it: `graph[:depth]`, `graph[:fan_in]`
  — or Matz and Xavier's `graph[:order]` plus a tiny stats helper.
  Third strike; extract it.

## Verdict

Design education in forty lines: run the shapes, read the table, have
the argument the numbers permit. When a framework makes trade-offs
this cheap to *demonstrate*, "it depends" stops being a shrug and
becomes a lesson plan.
