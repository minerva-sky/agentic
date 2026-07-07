# Round 16 field notes — Benoit Daloze proves the schedule away

*Built: `examples/schedule_equivalence.rb` — the same plan run at
concurrency 1, 2, and 8, with outputs required identical; plus a
smuggler plan that fails the proof by talking through a shared
array, and the boring fix.*

## What I built and why

Last time the lottery seated me I pinned semantics across
*implementations*. Same theorem this time, with schedules standing
in for VMs: a plan's declared meaning is its dependency graph, which
implies a promise almost nobody tests — **outputs must not depend on
the schedule**. If running at concurrency 8 gives a different answer
than concurrency 1, the graph is not the whole truth; some meaning
is being smuggled outside the declared edges.

```
honest plan across 1/2/8:  identical outputs - EQUIVALENT
smuggler plan:
  concurrency 1  sum => "7 (a won the race)"
  concurrency 2  sum => "7 (b won the race)"
  DIVERGED
```

The smuggler has the *same graph* as the honest plan — same tasks,
same `needs:` — plus one shared array on the side. Its sum task
reads `ledger.first`: who arrived first. At concurrency 1 the
schedule is just insertion order, so `:a` always wins; under
parallelism the race decides. The output literally encodes the
winner of a race, which is meaning traveling through no edge any
tool can see — the forest drawing, the spec generator, the merge
tool would all certify this plan while it lies to them.

## The prover's own bug was the lesson in miniature

My first smuggler never diverged: I created the ledger *outside* the
per-run builder, so all three runs shared one array and
`ledger.first` was forever the very first run's `:a`. The
contraband channel had contraband of its own — state leaking across
what should have been independent experiments. The fix (fresh ledger
per run) is the same fix the example preaches: scope your state to
the unit that owns it. A prover that can't manage its own sharing
has no business auditing anyone else's; ninth round running that the
tool corrects the author first.

The fix for real smugglers is always the same and always boring:
**whatever the shared state was whispering, say it with an edge.**
`needs:` hands the sum exactly the values it may know, and the graph
becomes the whole truth again — at which point every schedule is as
good as every other, which is precisely what lets the orchestrator
choose freely.

## Notes

- Races are shy under observation: the prover retries the smuggler
  several times, because a race that happens to land identically
  proves nothing. Absence of divergence is evidence, not proof —
  which is why the *honest* plan gates the exit code and the
  smuggler is a demonstration.
- What I'd want next (soft ask): a deterministic-schedule mode in
  the orchestrator — seeded task interleaving — so this prover could
  *enumerate* schedules instead of sampling them. Property testing
  needs reproducible counterexamples.

## Verdict

A plan isn't correct until its outputs are a function of its graph,
and now there's a prover that asks. The honest plan is equivalent
under every schedule; the smuggler was caught encoding a race; and
the fix fit in one `needs:`. Schedules are just VMs wearing clocks.
