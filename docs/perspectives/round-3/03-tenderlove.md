# Round 3 field notes — Aaron Patterson draws the Plan Gantt

*Built: `examples/plan_gantt.rb` — lifecycle hooks timestamp every task;
the run renders as an ASCII timeline. Found and fixed a scheduler
deadlock before the chart drew its first bar.*

## What I built and why

You can't reason about a scheduler you can't see. So: a six-task diamond
(three fetches → two joins → one report) with simulated IO, hooks
recording start/finish, and a Gantt renderer:

```
fetch:users      |############                              |   0-121ms
fetch:orders     |####################                      |   0-200ms
fetch:events     |####################                      |   0-201ms
join:revenue     |                    ###############       | 200-351ms
join:activity    |                    ##########            | 201-301ms
report:weekly    |                                   ###### | 351-411ms
serial floor 710ms -> actual 412ms (1.7x from the scheduler)
```

## The part where the chart never rendered

First run: nothing. Not slow — **hung**. The diamond at
`concurrency_limit: 2` deadlocked the orchestrator, every time.

The autopsy: `schedule_dependent_tasks` ran *inside the completing
task's semaphore slot*, and scheduling a dependent called
`semaphore.async` — which blocks when the semaphore is full. So when
both slot-holders finished around the same moment and each tried to
spawn its dependents, each blocked waiting for a slot that could only be
freed by... the other blocked holder. A textbook hold-and-wait, shipped
since the orchestrator was written, invisible because nothing before
this chart combined fan-in dependencies with a tight limit. My renga
(chain, limit 10) sailed past it; Samuel's latency lab (no deps) sailed
past it; the diamond at limit 2 hit it in one millisecond.

The fix is the structured-concurrency idiom: spawn through the
**barrier** (non-blocking), acquire the semaphore **inside** the spawned
fiber. Slot-holders never block on spawning; waiters queue in their own
fibers. Ninety lines of `schedule_task` also got a long-overdue
extraction into `execute_task_in_slot` — Sandi's dojo had already put
that method on the suspects board, so consider this a twofer. Regression
spec included: diamond, tight limit, five-second timeout, must complete.

## A subtlety the chart makes visible

`fetch:events` shows 0–201ms but only *ran* for 80ms — the bar includes
121ms queued waiting for a slot, because `before_task_execution` fires
at schedule time, not slot-acquisition time. I left it: queue time IS
where your latency went, and a chart that hides saturation is a chart
that lies. But the hooks should probably grow a `task_slot_acquired`
event so tools can split wait from work.

## Verdict

Wrote a visualization, got a deadlock fix, a method extraction, and a
regression test. Observability tools pay for themselves before they're
finished — that's why you build them first, not after the incident.
