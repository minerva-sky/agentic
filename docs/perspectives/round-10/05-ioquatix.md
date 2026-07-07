# Round 10 field notes — Samuel Williams runs the cancel drill

*Built: `examples/cancel_drill.rb` — three measured drills against
the two cancellation paths: surgical task cancel (in-flight and
pending) and plan-wide cancel. One of them fails the drill.*

## What I built and why

Structured concurrency makes exactly one non-negotiable promise:
**stop means stop, promptly**. Everything else — nurseries, barriers,
scoped lifetimes — exists to make that promise keepable. So before I
trust a cancel API in anything that bills by the token, I drill it,
and the drill is always the same: don't read the status, read the
*clock* and the *invoice*.

```
drill 1 - cancel one in-flight task at 30ms:
  job2 began at 32ms on the canceled fiber's lane - not at 100ms
drill 2 - cancel one pending task:
  agents actually ran: 5/6 - the canceled job never started, never billed
drill 3 - cancel_plan at 30ms:
  status flipped to :canceled by 30ms... then the plan ran 301ms
  anyway, 6/6 agents executed, results discarded
```

Drills 1 and 2 pass beautifully. `cancel_task` on an in-flight task
stops the fiber mid-sleep — and the proof is the *next job's start
time*: job2 began at 32ms on the freed lane, not at 100ms when the
canceled job would have finished. Canceling a pending task is even
better: it simply never runs. Queued work canceled is money returned.

## Drill 3 is the finding

`cancel_plan` flipped every status to `:canceled` within
milliseconds — and then the plan ran its full 300ms with **all six
agents executing**, their results thrown away on arrival. That's the
worst trade available: full cost, zero product. A dashboard would
show a plan canceled at 30ms; the invoice would show six completed
LLM calls; and both would be telling the truth about different
things, which is the most expensive kind of true.

The mechanism: `cancel_plan` stops `@reactor` — but when
`execute_plan` joins an existing reactor (the composability we built
in round 1!), that handle isn't the private event loop it was
written to be, and stopping it doesn't reach the scheduler or the
in-flight fibers. Meanwhile the pending→canceled bookkeeping doesn't
stop `schedule_dependent_tasks` from starting those very tasks. The
promise breaks precisely at the intersection of two features that
each work alone. That's not a rare shape of bug; it's the *usual*
shape, and it's why you drill.

Filed as the round-11 ask, with the drill as the acceptance test:
`cancel_plan` must stop the scheduler and the in-flight fibers —
`@barrier.stop` and per-task stops, not a reactor-handle stop — so
that drill 3 reads like drills 1 and 2.

## Notes

- Every claim in the output is a measurement: start timestamps prove
  lane-freeing, agent-run counters prove billing, wall clocks prove
  promptness. Status fields are testimony; clocks are evidence.
- Note drill 1's subtlety: total wall time was 300ms with or without
  the freed lane — my first draft "proved" freeing from the total and
  the arithmetic didn't hold. Only the third job's start time
  discriminates. Sixth consecutive round of the tools correcting
  their authors.

## Verdict

Task-level cancellation keeps the structured-concurrency promise;
plan-level cancellation currently sells its status cheaper than its
work. The drill is written, the ask is filed, and next round drill 3
should cost 30 milliseconds instead of 300.
