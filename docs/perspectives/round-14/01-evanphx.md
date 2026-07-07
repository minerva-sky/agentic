# Round 14 field notes — Evan Phoenix serves the plans

*Built: `examples/plan_server.rb` — plan execution over a real
loopback socket: a thread pool, one shared mutexed quota, and the
part everyone skips — a graceful drain proven with a request in
flight.*

## What I built and why

Puma taught me that a server is three disciplines wearing one
process: accept concurrently, share safely, and — the one that
separates production servers from demo servers — **shut down well**.
Everyone benchmarks accept loops; nobody demos the drain. So the
drain is the demo:

```
burst of 8 concurrent requests, 3 workers: 8 of 8 answered
graceful drain with one request in flight:
  in-flight request completed: "processed 7 words"
  drain took 11ms; served 9; new connections: refused
```

The order of operations *is* the grace, and it's worth spelling out
because every wrong shutdown gets it backwards: **close the listener
first** — the OS starts refusing new connections for you, no accept
race, no half-open socket limbo — then let workers finish what they
hold, then join, then exit. `kill -9` has none of those steps, which
is why deploys under it drop the request that was 42 seconds into a
43-second plan, and why the 43-second plan's owner files the ticket.

## A server calls every promise at once

The quieter demonstration: the quota is **one `RateLimit` shared
across all request threads** — real threads, preemptive, the kind
that made Puma's early years educational. It holds because round 12
gave the windowed bookkeeping a real Mutex. This is what I'd tell
that round's skeptics: a server is where every thread-safety promise
in your dependency tree gets called at once, on the same tick, by
someone else's traffic. Frameworks don't get to choose whether
they'll be used from threads; they only choose whether it'll go
well.

Implementation notes with server-operator fingerprints:

- Ephemeral port (`TCPServer.new("127.0.0.1", 0)`) so the example
  never collides with anything — test servers that hardcode ports
  are flaky tests on a delay timer.
- Quota exhaustion answers `{error:, retry_after:}` instead of
  hanging — a server that queues unboundedly when over quota has
  just moved the outage into its own socket backlog.
- `@in_flight` is tracked but the drain relies on `Thread#join`, not
  on polling the counter — join is the primitive that can't miss.

## Verdict

Three workers, one shared limiter, eight bursty clients, and a
shutdown that finished the last request before it stopped being a
server. The plan framework slotted into the request path without
ceremony — and the drain took 11ms, which is 11ms more grace than
`kill -9` will ever have.
