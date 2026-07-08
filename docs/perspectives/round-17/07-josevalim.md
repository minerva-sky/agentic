# Round 17 field notes — José Valim plants a supervision tree

*Built: `examples/supervision_tree.rb` — OTP's restart strategies
over plans: one_for_one, rest_for_one, one_for_all, plus bounded
restart intensity with escalation. The same crash is supervised
three ways; the run-count table is the semantics.*

## What I built and why

Round 11 I put a telemetry bus on the lifecycle hooks — observation.
This round the brief asked for a *solution*, and the solution Erlang
taught me is the one I keep re-importing everywhere I go: **workers
do the happy path; supervisors own recovery policy.** The agents in
this file contain zero rescue clauses, and that's the headline, not
a footnote. Every rescue you write inside a worker is a policy
decision smuggled into the wrong layer, made once, invisible to
operators, and different from the rescue your colleague smuggled
into the next worker over.

```
strategy       restarts  runs (c/f/h/s)  who re-ran, and why
one_for_one    1         1/2/1/1         only fetch - its crash is its own
rest_for_one   1         1/2/2/1         fetch AND heartbeat - state suspect
one_for_all    1         2/2/2/1         everyone - the world is rebuilt

the hopeless child: reached maximum restart intensity (3); escalating
```

The three strategies differ in exactly one thing — **blast radius** —
and the table shows it as run counts. `heartbeat` had already
finished when `fetch` crashed: one_for_one protects its result;
rest_for_one rebuilds it because heartbeat started after fetch and
its state may derive from fetch's world; one_for_all rebuilds the
connection too. None of these is "best." They are three different
claims about how state flows between siblings, and choosing one
forces you to *know* which claim is true of your tree. That forcing
is most of the value.

## Intensity is the difference between recovery and denial

A supervisor that restarts forever is a crash loop with better
manners. The hopeless child ran four times — one start, three
restarts — and then the failure went *up the tree*, with a reason
naming the child and its budget. Escalation is not giving up; it's
the correct routing of a problem that turned out not to be
transient. (The framework's own retry machinery handles the
transient tier; the supervisor is deliberately the layer above it —
`max_retries: 0` inside, policy outside.)

## Notes

- Completed work is state the supervisor protects. Each round only
  re-plans the invalidated children and *injects* survivors' outputs
  into their dependents — restart does not mean recompute the world
  unless the strategy says exactly that.
- Start order in a DAG is declaration order; "children started after
  the crashed one" translates cleanly, and the plan graph already
  encodes the rest.
- Missing and wanted: a `restart: :transient | :permanent |
  :temporary` marking per child (this demo treats everyone as
  permanent), and supervisors as children of supervisors — the demo
  escalates to the caller; a real tree escalates to another
  supervisor.

## Verdict

Three strategies, one table, zero rescues in worker code, and a
crash that knew when to stop being retried and start being
escalated. The orchestrator's retry policy handles errors; a
supervision tree handles *failure* — the difference is who gets to
decide, and OTP's answer (one level up, as data) ports to plans
without losing anything in translation.
