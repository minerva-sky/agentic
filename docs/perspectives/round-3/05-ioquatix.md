# Round 3 field notes — Samuel Williams streams the plan live

*Built: `examples/live_dashboard.rb` — lifecycle hooks publish onto an
`Async::Queue`; a renderer task in the same reactor draws the plan's
state while it runs.*

## What I built and why

The architecture documents have promised a `StreamingObservabilityHub`
since before round 1. I built the load-bearing part of it in thirty
structural lines, from parts already in the box: hooks enqueue events,
an `Async::Queue` carries them, and a sibling task dequeues and renders
— *while the plan executes*, in the same reactor, with timestamps to
prove it:

```
    0ms  > running  resize:thumbnails
  151ms  + done     resize:thumbnails    (ran 151ms)
  151ms  > running  extract:captions
  ...
  423ms  = plan completed in 422ms
```

Every line printed live. No hub, no subscriber registry, no thread — a
queue and two fibers. The renderer's `dequeue` suspends when the queue
is empty and wakes when a hook enqueues; back-pressure and ordering come
free with the data structure. This is my standing argument about
observability systems: **the event stream is a queue, so use a queue.**
The remaining "hub" work is multiplexing to N consumers, which is
`Async::Queue` per subscriber and a fan-out loop — an afternoon.

## What this build depended on, specifically

- Aaron's deadlock fix from two days ago is the reason this demo is
  honest: plan + renderer at `concurrency_limit: 2` is exactly the
  saturated-reactor shape that used to hang. I ran it before writing
  these notes; it didn't. Structured concurrency bugs die when someone
  builds the tool that would witness them.
- The composition contract from my own round-1 fix carries the whole
  design: `orchestrator.execute_plan` inside `Sync` joins the reactor,
  so `renderer.wait` after it is ordinary structured concurrency —
  spawn, do work, join. If the orchestrator still seized its own event
  loop, this program would be two processes and a pipe.

## One design observation for the maintainers

Hooks fire *inline* in the task fiber, so a slow hook slows the plan —
today's hooks-to-queue pattern is safe precisely because `enqueue` is
O(1) and non-blocking. That property should be in the hooks'
documentation as a contract: "your hook runs on the task's critical
path; hand off anything slower than a hash insert." The dashboard is
both the demo and the recommended escape hatch.

## Verdict

The promised streaming layer turned out to be one queue away. Ship this
pattern in the docs, mark the hub as "compose it yourself from these
parts," and the architecture document loses its last piece of
fiction.
