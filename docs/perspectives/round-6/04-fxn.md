# Round 6 field notes — Xavier Noria closes the round trip

*Built: `examples/plan_roundtrip.rb` — graph → JSON → fresh
orchestrator → graph, with an isomorphism check proving nothing was
lost in either direction.*

## What I built and why

A projection you can only read is a report; a projection you can
*invert* is a format. Round 5's diagrammer read the graph outward
(graph → Mermaid); this round closes the loop: serialize the topology
to JSON, rebuild a brand-new orchestrator from that JSON, and compare
shapes. The verdict line is the deliverable:

```
round trip is faithful: 3 edges, labels intact,
topological order preserved (gather -> check -> weave -> ship)
```

With this, plans become *artifacts*: you can commit them, diff them in
review, hand them between processes, build them in a UI and execute
them in a worker. The CLI's existing `--save plan.json` stores the
planner's *task list*; this wire format stores the *topology* — which
is the part that round 3's piping and round 4's `needs:` made worth
preserving.

## The two decisions that make the format sound

1. **Ids do not travel.** Task ids are per-process UUIDs; a wire
   format that ships them is shipping garbage that will collide or
   mislead. Identity travels as description, structure as edges — the
   same discipline as Perham's journal keys. The isomorphism check
   accordingly compares *shapes* (names and labeled edges), never ids.
2. **`graph[:edges]` is the serialization surface.** Because round 6's
   release pre-merges positional and named dependencies into labeled
   edge records, serialize + deserialize are ~15 lines each with no
   special cases. My round-5 diagrammer had to dedupe needs against
   dependencies by hand; that logic simply no longer exists anywhere
   in this file. When a release deletes code from *examples that
   haven't been written yet*, the API changed at the right layer.

## The caveat, stated plainly

The wire format carries topology, not behavior: agents and payloads
are lambdas and live objects, which do not serialize (and must not —
`Marshal`ing closures is how gems end up in CVE databases). A rebuilt
plan needs its agents re-attached by name, exactly as the CLI
re-resolves agents from specs. Structure travels; capability is
re-granted at the destination. That is a *feature* with security
posture, not a gap.

## Verdict

The graph now survives translation in both directions with a proof
attached. Plans-as-data was always the promise of the plan-and-execute
architecture; as of this round the data part is honest.
