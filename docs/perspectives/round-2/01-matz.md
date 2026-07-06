# Round 2 field notes — Matz builds a renga circle

*Built: `examples/renga_circle.rb` — three poet agents compose a
linked-verse poem where the dependency graph is the poem's form.*

## What I built and why

Renga is collaborative poetry with a rule: your verse must answer the one
before it. That is a dependency graph wearing a kimono. So: Basho, Buson,
and Issa as agents, each with a `verse` capability in their own voice, and
a `PlanOrchestrator` whose task dependencies enforce the form — Buson
cannot begin until Basho has spoken.

```
first light, autumn wind -     (Basho, no dependencies)
answering first: ...           (Buson, depends on Basho)
yes, geese - and yet ...       (Issa, depends on Buson)
```

Eighty milliseconds, `completed`, and a poem. I am content.

## What building with it felt like

- Registering a capability per poet and calling
  `poet.execute_capability(...)` was pleasant — the lambda-as-craft idea
  survives contact with a real (if small) program.
- The orchestrator's dependency declaration is lovely:
  `add_task(task, [previous_task.id])` reads exactly like the rule it
  encodes.

## The friction, honestly

- **Dependent tasks cannot see each other's output.** The whole point of
  renga is that verse N reads verse N-1, but a `Task`'s `input` is frozen
  at creation and the orchestrator does not pipe a completed task's output
  into its dependents. I smuggled a shared `scroll` array into every
  agent — mutable shared state, the thing the architecture documents say
  they avoid. The framework knows the dependency exists (it scheduled
  around it!) yet withholds the one thing the dependency produces. A
  `task.input_from(other_task, :verse)` would make this program five lines
  shorter and much more honest.
- I also had to invent a `RengaProvider` and a `PoetAtTheTable` adapter
  struct because the orchestrator wants a provider-of-agents while I
  already *had* my agents. `orchestrator.add_task(task, agent: poet)`
  would have let the poets sit at the table directly.

## Verdict

The gem let me write a poem with a scheduler, which is the kind of
program Ruby exists for. The missing output-piping between dependent
tasks is the first thing a real user hits — worth building next.
