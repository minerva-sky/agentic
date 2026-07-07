# Round 9 field notes — Xavier Noria proves the promises

*Built: `examples/graph_invariants.rb` — seven invariants of the
`graph` reflection API, proved across four plan shapes including a
deliberate cycle. Exit 0 is a certificate.*

## What I built and why

Eight rounds of tools now lean on `orchestrator.graph`: the forest
drawing, the spec generator, the structural diff, the three-way
merge. Every one of them assumes things the documentation *asserts* —
order respects edges, roots have empty dependencies, depth is the
longest path from a root, labels ride their edges. Assertions in
YARD comments are wishes. I wanted proofs:

```
chain / diamond / forest / cycle:
  order is a permutation of the task set        proved
  order respects every edge (acyclic only)      proved
  roots are exactly the tasks with no deps      proved
  leaves are exactly the tasks nothing feeds    proved
  depth is 1 + max dependency depth (acyclic)   proved
  max_depth / max_fan_in agree with sources     proved
  every needs: label appears on its edge        proved
26 proofs, 0 violations
```

Each invariant is a lambda from graph to violations; each plan shape
is chosen to stress a different clause — the diamond for labeled
joins, the forest for multiple roots and an orphan, the cycle for
the degenerate case every reflection API secretly dreads.

## The prover's first catch was its author

My initial depth invariant ran on all four shapes, and the cycle
violated it: `depth[x] = 1, expected 3`. I stared at the "bug" for a
minute before seeing it was in *my invariant*, not the framework:
depth means "longest path from a root," and a cyclic graph has no
such number — the definition chases its own tail (x's depth needs
y's, y's needs x's). The framework's Kahn's-order computation gives
cycle members *some* finite value; any value satisfies no meaningful
contract.

The correct fix was not code but *scope*: the invariant's name now
carries "(acyclic only)", the same qualifier the edge-ordering
invariant already had. This is a lesson I keep re-learning from
Zeitwerk: the hardest part of a contract is not enforcing it but
stating its domain precisely. An unscoped promise is a bug that
hasn't picked its reporter yet.

## Notes

- The needs-label invariant cross-checks two representations of the
  same fact (`needs:` hash vs edge labels). Redundant representations
  are where reflection APIs rot first, because nothing forces them to
  agree — except now something does.
- Everything here belongs in the spec suite eventually. An example
  makes the argument legible; a spec makes it permanent. Filed as a
  thought, not an ask — the round-9 spec file already covers the new
  surface, and porting these seven lambdas is mechanical.

## Verdict

The reflection API's promises are now theorems with a runnable proof,
and the proof's first victim was my own imprecision about cycles —
which is exactly what provers are for. Exit 0, certificate issued.
