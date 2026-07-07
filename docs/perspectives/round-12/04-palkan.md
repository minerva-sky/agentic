# Round 12 field notes — Vladimir Dementyev profiles by group

*Built: `examples/event_prof.rb` — TestProf's EventProf idea applied
to plans: task-seconds aggregated by tag, share-of-total before any
optimization talk, and an effective-parallelism line that indicts
the stage barriers.*

## What I built and why

TestProf exists because profiling by *file* answers the wrong
question. Nobody can act on "spec_a.rb is slow"; everyone can act on
"62% of your suite is factories." The unit of optimization is the
**group**, because groups map to causes and causes map to fixes. Same
move for plans — tag tasks by kind, collect durations from the hooks,
aggregate:

```
tag      seconds   share   worst offender
llm       651ms    78.1%   llm:draft (250ms)
db        101ms    12.2%   db:fetch_orders (40ms)
render     81ms     9.7%   render:pdf (50ms)

task-seconds 833ms / wall 342ms = 2.4x parallelism on 3 lanes
```

Read the share column *before* touching any code: llm owns 78% of
all task-seconds, so a 20% win there beats deleting the entire
render stage. Optimizing db: or render: is polishing doorknobs on a
burning building — and without the table, doorknob-polishing is
exactly what happens, because render code is more fun to touch than
prompt budgets.

## The second number

Task-seconds by group is the TestProf classic; the parallelism line
is the plan-specific lesson. 833ms of work in 342ms of wall is 2.4x
on 3 lanes — meaning a chunk of a lane is going unused, and the
culprit is visible in the plan's shape: stage barriers. Every llm
task waits for *all* db tasks; every render waits for *all* llm.
`db:fetch_users` finished at 30ms but `llm:summarize` idled until
`db:fetch_orders` cleared at 40ms — multiply that slack across
stages and you've bought 3 lanes to run 2.4.

The fix isn't more lanes (utilization, not capacity, is the
bottleneck) — it's finer dependencies: `needs:` lets an llm task
depend on exactly the db task it reads. The profiler doesn't make
that change; it makes it *undeniable*, then verifies it on the
re-run. Profile, fix the biggest group, re-profile. Boring,
effective.

## Notes

- Fifteen lines of profiler, because the hooks hand over exactly the
  right tuple (description, duration) at exactly the right moment.
  Instrumentation seams you don't have to fight are the difference
  between "we should profile" and profiling.
- Tags ride in the description prefix (`llm:draft`) — the same
  convention the journal's idempotency keys already reward. When one
  naming convention feeds three tools (resume, triage, profiling),
  it stops being a convention and starts being a schema.

## Verdict

"Where does the time go" now has a by-group answer with shares,
worst offenders, and a parallelism ratio that points at the barriers
rather than the budget. Read the share column first; let the biggest
group spend your optimization budget; make the profiler cheap enough
that re-running it is a reflex.
