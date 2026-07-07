# Round 7 field notes — Xavier Noria diffs the topology

*Built: `examples/plan_structural_diff.rb` — two versions of a plan's
wire format, diffed as structure: tasks added, edges rewired, labels
renamed.*

## What I built and why

Round 6 made plans serializable; serialized artifacts get committed;
committed artifacts get *diffed* — and a line diff of plan JSON
answers the wrong question. Forty changed lines might mean one task
was inserted. The structural diff answers the right one:

```
+ task  dedupe entries
+ edge  parse entries -> dedupe entries
+ edge  dedupe entries -> rank entries
- edge  parse entries -> rank entries
```

Four facts: dedupe appeared, and ranking was rewired to consume it.
The review conversation this produces — "should ranking consume
deduped candidates instead of raw entries?" — is an *architecture*
question, which is the only kind a plan review should be about. Line
diffs make reviewers audit serialization; structural diffs make them
audit design.

## Precision notes

- Edges are keyed by `(from, to)` with the label as the *value*, which
  cleanly separates three kinds of change: an edge appearing, an edge
  vanishing, and an edge merely *renamed* (`~ label` — the dependency
  stayed, its declared purpose changed). A renamed label is a design
  decision worth its own diff line; keying edges by
  `(from, to, label)` would have misreported it as remove + add.
- The diff operates on the wire format, not on live orchestrators —
  deliberately. You diff what you commit; diffing in the artifact's
  own vocabulary means the tool works on any two plan.json files from
  git history without constructing a single Task.
- What it doesn't detect: task *renames* (fetch feed → fetch feeds
  reads as remove + add). Rename detection needs content similarity —
  the same reason git's own rename detection is heuristic. Honest
  tools state their blind spots; this one's is names.

## The pattern, now visible across three rounds

Round 5: generate the artifact (Mermaid). Round 6: prove the
round-trip. Round 7: diff two versions. This is the full lifecycle of
a *format* — render, invert, compare — and it's the same maturation
path every serious format walks (source code, schemas, infrastructure
plans). Plans-as-data is no longer a slogan in this gem; it has the
tooling trilogy.

## Verdict

Plan changes are now reviewable at the altitude where design lives.
Next stop, someone wires this into CI to comment the structural diff
on PRs that touch plan.json — the same afternoon-sized step every
round seems to end with.
