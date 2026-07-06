# Round 4 field notes — Jeremy Evans posts the invariant sentinel

*Built: `examples/invariant_sentinel.rb` — domain invariants checked
after every task from a lifecycle hook; a seeded off-by-one is caught
at the task that caused it, and the plan stops. Also fixed the plan
status lying about cancellation.*

## What I built and why

Validation checks data at boundaries; invariants check the *world*
between steps. The sentinel is a hook that runs every declared law
after every task: stock never negative, stock always equals initial +
received − picked. One picker in the job list decrements 3 while
recording 2 — the accounting bug every warehouse system eventually
writes — and the run shows the payoff:

```
LAW BROKEN: "stock equals initial + received - picked"
  by: pick 2 widgets (buggy picker)
jobs completed before the stop: 3 of 4
```

The corrupting task is named, the world state at the moment of arrest
is printed, and the fourth job never ran. Corruption caught at the
task that caused it is a bug report; corruption found at month-end
close is an incident with a conference call. The second invariant is
the one that fired, note — the *conservation law*, not the obvious
"never negative" check. Cheap invariants catch crashes; conservation
invariants catch lies.

## The framework bug this flushed out

My first run printed `plan status: completed` — for a plan the
sentinel had just *canceled*. `overall_status` checked failed, pending,
and in-progress states but never consulted `:canceled`, so a canceled
plan with no failures reported itself complete. That is a status API
telling a comforting falsehood, which is worse than no status API.
Fixed in the framework (canceled tasks → `:canceled`), regression
spec added. Sentinels that watch the watchers: this is the third
round in a row where a persona's example found a defect the suite
missed, and the pattern is consistent — **suites test what authors
imagined; examples test what users do.**

## Design notes

- `concurrency_limit: 1` is load-bearing: with parallel jobs, "which
  task broke the law" becomes probabilistic. Determinism first, then
  speed — an auditor that sometimes names the wrong suspect is worse
  than a slow one.
- The state snapshot uses `Marshal` deep-copy at arrest time, because
  an evidence photo that mutates after the arrest is not evidence.
- These invariants are lambdas over global state for demo brevity; in
  production they'd be queries over your actual store. The pattern is
  the hook placement, not the storage.

## Verdict

Two laws, four jobs, one arrest, one framework fix. Invariant checking
from hooks costs a dozen lines and converts a class of month-end
incidents into same-second bug reports. Post the sentinel.
