# Round 14 field notes — Rosa Gutiérrez keys the concurrency

*Built: `examples/concurrency_key.rb` — SolidQueue's
concurrency-key idea over the framework's limiters: at most one
sync per tenant, tenants in parallel, and both overflow postures
(block vs skip) named at the call site.*

## What I built and why

Building SolidQueue taught me that the concurrency control teams
actually need is almost never "at most N jobs total" — it's **"at
most one per THIS thing."** One sync per tenant. One import per
account. Global limits are too blunt (one tenant's backlog throttles
everyone) and no limits are too sharp (two syncs for the same tenant
race each other's writes and the incident report blames "load").
The middle is a key:

```
six concurrent requests (3 per tenant):
  acme runs overlapping each other:    0  (must be 0)
  globex runs overlapping each other:  0  (must be 0)
  cross-tenant overlaps:               5  (parallelism preserved)
```

The judged interleaving is the point of the demo — not that it
"works" but that both halves of the promise are *measured*:
serialization within a key, preserved parallelism across keys. A
keyed limiter that accidentally serializes everything passes the
first check and fails the second, and nobody notices until
throughput dies.

## Two postures, named at the call site

Overflow policy is where keyed concurrency implementations differ,
and SolidQueue's lesson is that the policy must be **explicit**:

- `serialized(key)` — every request eventually runs, in order,
  alone. For backfills, where each request carries distinct work.
- `skip_if_running(key)` — running-now is proof enough. For crons:
  a second sync would do the same work twice, so the cron firing
  during a sync gets `:skipped`, not queued. (Round 11's
  `try_acquire` is exactly this posture's primitive — a budget wants
  to say no, and so does a cron guard.)

The registry detail that earns its comment: `limit(key)` mints the
per-key limiter **once, under a lock** — two fibers discovering
tenant "initech" simultaneously must agree on THE mutex, not each
mint a rival. A concurrency-key registry with a race in its own
lookup is a very quiet way to have no concurrency keys at all.

## Notes

- Global limits ration *capacity*; keyed limits enforce
  *correctness*. Compose them (round 9's `#and`) and you get both:
  `keys.limit("sync/#{tenant}").and(global_pool)`.
- What production adds: key expiry (tenants churn; the registry
  grows forever as written) and cross-process keys (this registry is
  per-process — the SolidQueue version lives in the database
  precisely because your workers don't share a heap).

## Verdict

At most one per tenant, all tenants at once, overflow policy chosen
by name instead of by accident — and the interleaving judged, not
assumed. Most incidents blamed on load are two workers holding the
same tenant; the key is the fix, and now it's forty lines anyone
can read.
