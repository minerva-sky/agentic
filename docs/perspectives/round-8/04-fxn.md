# Round 8 field notes — Xavier Noria merges the branches

*Built: `examples/plan_merge.rb` — a three-way merge of plan wire
formats: independent changes combine, the same seam rewired two ways
is a conflict, reported in topology vocabulary.*

## What I built and why

Round 6 made plans serializable, round 7 made them diffable; a format
isn't done until it *merges*, because artifacts that live in version
control get edited on branches. The scenario is the eternal one: ours
adds `dedupe` between parse and rank; theirs adds `moderate` in the
same seam (plus an independent `audit` leaf). The merge:

```
cleanly merged: + publish -> audit, + both new stages
CONFLICTS: seam parse -> rank:
  ours:   parse -> dedupe -> ...
  theirs: parse -> moderate -> ...
```

The independent change merged silently, as it should. The collision is
reported as what it *is* — two teams rewired the same seam — and the
example says the important sentence out loud: **resolution is a design
decision.** Should content be deduped before moderation or after? No
textual merge algorithm can answer that; the tool's whole job is to
ask the question in vocabulary a human can adjudicate. A line-based
merge of these two JSONs would have either produced a mangled edge
list or, worse, auto-merged both edges in and silently created a graph
where rank has two competing inputs nobody ordered.

## The confession, promptly

My first conflict detector found nothing — the replacement-finder
closed over the outer scope's `in_base` (always true at that point)
instead of testing each candidate edge against the base. A shadowing
bug, the classic block-variable kind, and the demo printed "cleanly
merged" over an actual conflict. **A merge tool that under-reports
conflicts is maximally dangerous precisely because its failure mode
looks like success.** The corrected detector was two `base_edges.key?`
calls; the lesson is older: test your tool on the case it exists for
before trusting the case it exists for.

## Format-trilogy notes

- Merge operates on the wire format, like the diff — you merge what
  you commit. The trilogy (render/invert, diff, merge) is now
  complete, and each tool is ~40 lines because the format carries
  labels and identity-by-description.
- Rename detection remains the shared blind spot (a renamed task
  reads as remove+add in both diff and merge). It's the correct
  blind spot to have — heuristic renames in a *merge* tool multiply
  the silent-wrongness risk I just demonstrated personally.

## Verdict

Plans now have the full version-control lifecycle: serialize, prove,
diff, merge — with conflicts surfaced as design questions. And I've
re-learned, in public, why merge tools are held to the highest
honesty standard of any tooling: their lies arrive wearing green
checkmarks.
