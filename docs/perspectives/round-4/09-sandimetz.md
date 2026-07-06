# Round 4 field notes — Sandi Metz critiques the graph

*Built: `examples/graph_critic.rb` — a design review for dependency
graphs, run before a single task executes.*

## What I built and why

Rounds past, I reviewed methods (the dojo) and traced messages (the
tracer). This round I reviewed the thing this framework actually asks
users to design: the **graph**. A plan's dependency structure is a
design artifact exactly like a class diagram, it exhibits the same
smells, and — this is the part people miss — it can be reviewed
*before execution*, when a restructuring costs an edit instead of a
re-run of forty LLM calls.

Three smells, drawn from their object-design cousins:

- **God task** — `join` gathers five dependencies, the graph's version
  of a class with five collaborators in its constructor. Does it join,
  or does it *do everything*? Staged joins give each join one reason
  to wait, as extraction gives each class one reason to change.
- **Deep chain** — `publish` sits five levels down. Every level is
  latency and a failure domain, the graph's train-wreck method chain.
- **Orphan** — `lonely` touches nothing and is touched by nothing.
  Either it belongs to another plan or its justifying connection was
  forgotten. Dead code, graph edition.

And one prescription, as always. A review that emits three findings
and no ordering is a wall; the critic says *start with the god task* —
because restructuring it may dissolve the chain, and cheap moves that
might obsolete expensive ones go first.

## The feature request embedded in this example

The critic reads the graph with
`orchestrator.instance_variable_get(:@dependencies)` — a crowbar. I
used it deliberately and left the comment in, because that line *is*
the finding: the orchestrator knows its own topology and offers no
read-only view of it. Aaron's Gantt wanted it (he rebuilt the graph
from hooks), the tracer wanted it, now the critic. Three tools, three
reconstructions of state the object already holds. `Orchestrator#graph`
returning frozen `{task_id => dependency_ids}` plus the task list is
one accessor and unlocks a whole genre of tooling. Objects that keep
useful knowledge private force their collaborators into archaeology.

## Verdict

Graphs are designs; designs deserve review; review before execution is
the cheapest review there is. The critic took an evening, found three
seeded smells and their real prescription — and its own best finding
was the accessor the framework should grow next.
