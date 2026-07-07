# Round 13 field notes — Tom Stuart enumerates the machine

*Built: `examples/plans_as_automata.rb` — plans treated as transition
systems: the full state space enumerated by breadth-first search,
completion proved by exhaustion, and a cycle's pathology exhibited
as an empty machine.*

## What I built and why

Understanding Computation's whole method is: take a thing people
discuss with adjectives, and replace the adjectives with a small
machine you can run. Strip the agents and LLMs from a plan and
what remains is a transition system — a *state* is the set of
completed tasks; a *step* completes any task whose dependencies are
satisfied. That's the operational semantics, and it fits in one
method:

```ruby
def steps(graph, done)
  tasks.reject { done? } .select { deps.all? { done? } }
end
```

Everything else is just looking:

```
the diamond:  6 reachable states (of 16 conceivable)
              1 terminal state -> complete; 0 stuck
the cycle:    1 reachable state: {} - not one task can ever fire
```

## Exhaustion beats sampling, where it's affordable

The claim "the diamond always completes" is usually an empirical
one — CI ran it, both orders happened at least once, ship it. The
enumeration makes it a *theorem about a finite object*: all six
reachable states, every scheduler choice included, converge on
{a,b,c,d}. Not "observed"; **total**, by exhaustion. Note also
what the state count itself says: 6 reachable of 16 conceivable
subsets — the dependency structure has already eliminated ten
states of nonsense, which is what structure *is*.

The cycle is the same rigor pointed the other way. Its reachable
space is one state — the empty set — and that state is terminal:
no task can ever fire. This gives precise content to two earlier
rounds' intuitions: the scheduler's cycle handling ("appended after
the sorted portion") is a policy about tasks *outside the machine*,
and round 9's depth invariant excusing itself on cycles wasn't
squeamishness — there is no altitude in a building with no floors.

And the honest boundary, stated in the output: at 40 tasks the
state space outgrows the universe. Enumeration is for small
machines; invariant provers (round 9's) are for big ones. The
mistake isn't choosing either tool — it's not knowing which regime
you're in.

## Notes

- `max choice: 2` — the widest state has two ready tasks, which is
  the diamond's true parallelism ceiling, derived rather than
  configured. Samuel's lane arithmetic and this number will always
  agree; one comes from the machine, the other from the meter.
- The state space is a lattice (states ordered by inclusion,
  converging at the top for DAGs). I resisted a digression into
  confluence theory by a margin best described as narrow.

## Verdict

A plan is a small machine wearing a workflow costume. For small
machines, don't argue about behavior — enumerate it, and let
"always completes" mean what it says: every reachable path, checked,
because there are six of them and you have a computer.
