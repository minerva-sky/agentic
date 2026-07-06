# Round 2 field notes — Samuel Williams builds the Latency Lab

*Built: `examples/latency_lab.rb` — 20 simulated LLM calls through the
orchestrator at three concurrency limits, plus a heartbeat sharing the
reactor to prove the plan composes instead of monopolizing.*

## What I built and why

Aaron's detective showed fibers buy nothing for CPU-bound work; this lab
shows what they buy for the workload this gem actually exists for. Twenty
tasks, each 200ms of simulated IO (`sleep`, which under the fiber
scheduler yields exactly like a socket read). Measured on this machine:

```
concurrency  1 ->  4.01s wall  (ideal  4.00s)
concurrency  4 ->  1.00s wall  (ideal  1.00s)
concurrency 20 ->  0.20s wall  (ideal  0.20s)
```

Within 10ms of theoretical at every limit. That's the semaphore doing
precisely its job: at limit 20, twenty "API calls" cost one API call of
wall clock. This is the number to show anyone who asks why an agent
framework should care about structured concurrency — a 20-task LLM plan
is 4 seconds of latency serial and 0.2 seconds fanned out, and the code
difference is one integer.

## The composition proof

The second half runs the plan **inside** a host reactor, alongside a
heartbeat task beating every 100ms. The heartbeat kept beating (4 beats
during a 0.4s plan) — the orchestrator joined the reactor as a sibling
rather than seizing the event loop. This is the behavior my round-1 `Sync`
change bought, now demonstrated from the consumer side: you can embed a
plan in a Falcon request handler, next to your websocket pings, and
nobody starves. Before that change, this program would have printed the
starvation line.

## Building-with-it observations

- `sleep` being non-blocking inside tasks is delightful and *undocumented*.
  Users writing custom agents need to know: any Ruby IO — `Net::HTTP`,
  `sleep`, sockets — cooperates automatically under the reactor, and
  anything that grabs the GVL for compute does not. One paragraph in the
  README would set expectations for both.
- `PlanExecutionResult#execution_time` made the lab's measurement code
  trivial — the framework timing its own plans is a small design decision
  that keeps paying off.
- The one rough edge: `concurrency_limit` is per-orchestrator, but the
  thing you actually want to bound is usually per-*provider* (one OpenAI
  key = one rate limit shared across every plan in the process). A shared
  semaphore injected into the client would express that. Noted for
  round 3.

## Verdict

The concurrency story survives contact with measurement: ideal scaling
on IO, honest nothing on CPU, and polite cohabitation inside a host
reactor. That's the whole async contract, kept.
