# Round 3 field notes — Mike Perham runs the Flaky API Drill

*Built: `examples/flaky_api_drill.rb` — a scripted-flaky task under a
real retry policy with exponential backoff, journaled end to end.*

## What I built and why

Every reliability feature is a rumor until you watch it under failure.
The drill scripts the failure: an API that times out twice and delivers
on the third call, run with `max_retries: 3`, exponential backoff from
100ms, and the journal recording everything. The timeline is the
receipt:

```
  51ms  > attempt 1 ...
  53ms  x attempt failed: TimeoutError
 155ms  > attempt 2 ...          <- ~100ms backoff, as configured
 156ms  x attempt failed: TimeoutError
 359ms  > attempt 3 ...          <- ~200ms backoff, doubled
 360ms  + sync:accounts succeeded
 362ms  + audit:trail succeeded: "audited 42 accounts"
```

Those gaps — 100ms, then 200ms — are the point. Before Samuel's round-1
fix, the backoff code *computed* those delays, spawned a detached fiber
to sleep them, and retried immediately. The unit tests passed the whole
time because they asserted `sleep` was called, not that anything
waited. This drill is the test those tests should have been: wall-clock
timestamps on real retries. Reliability claims get verified in the
timeline or not at all.

## What the improved framework contributed

- **Journal idempotency keys** (my round-2 gap, closed in the roadmap
  release): `state.completed?("sync:accounts")` answers **by name**.
  Task ids are per-run UUIDs; descriptions survive reruns. The
  resume-after-crash pattern from my durable batch no longer needs the
  hand-joined event mapping — one method call.
- The journal keeps the *failures* too: two `task_failed` events with
  error types on disk next to the successes. When ops asks "how flaky
  was the upstream last night," the answer is `grep task_failed`, not
  archaeology.
- The dependent `audit:trail` task shows retries compose with piping:
  it waited through the whole ordeal and then read the final output via
  `t.output_of(sync)`. Downstream tasks don't know retries happened —
  which is exactly the abstraction boundary you want.

## What I'd still harden

- `retryable_errors: ["TimeoutError"]` matches class names as strings —
  fine until someone's error is `Net::ReadTimeout` or a namespaced
  `Errors::LlmTimeoutError` (which has a `retryable?` method the policy
  ignores!). The retry policy should consult `failure.retryable?` when
  the error object offers it, and fall back to the list.
- Backoff still lacks jitter-by-default. Two hundred workers retrying
  an upstream on the same exponential schedule is a synchronized
  stampede; `backoff_jitter: true` exists but defaults off. Reliability
  defaults should assume the crowd.

## Verdict

Retries that wait, a journal that remembers failures, resume keyed by
name. The drill passed on the first run — which, given what the suite
used to hide, is the sentence worth framing.
