# Round 10 field notes — Mike Perham gives retries a wallet

*Built: `examples/retry_budget.rb` — one fleet-wide retry allowance:
transient failures spend from it, hopeless ones can't touch it, and
an empty wallet means failing fast instead of joining the storm.*

## What I built and why

A retry storm is the outage you throw yourself, on top of the one
you already have. Every job's retry policy is individually
reasonable — three attempts, backoff, jitter, all the round-5
hygiene — and collectively insane, because during a real outage
*every* retry is doomed and every one of them costs a timeout,
a connection, and a line item:

```
strategy A - every job for itself:  45 calls at a dead host
strategy B - one wallet, 5 retries: 17 calls, 10 jobs failed fast
```

Twenty-eight requests deleted, zero value lost — the upstream was
down for all of them. The difference is one idea: **retries are a
shared resource**. Per-job policies answer "should I try again?";
during an incident the only question that matters is "should
ANYONE?" — and a question about *anyone* needs state that belongs
to *everyone*, which is what the budget is. Round 9's breaker asked
the same question per-upstream; the budget asks it per-window. Both
are fleet-memory where per-job policies have only self-memory.

## The nil convention, spending department

The wallet composes with this round's other release: the auth job's
journaled verdict (`retryable: false`) means it never spends from
the budget — not because we're stingy, but because a hopeless
failure retried is a lie told twice, and worse, it *drains the
wallet the transient failures might still need*. Meanwhile a nil
verdict spends normally: suspicion, not a death sentence, exactly
per `TaskFailure#possibly_transient?`. Policy code finally splits
the three-valued verdict at the right joint without every author
re-deriving the joint.

## Notes

- The budget class is fifteen lines in the example because it wants
  **non-blocking admission**: a `RateLimit` makes you *wait* for
  capacity; a budget must tell you *no* right now. Waiting for retry
  capacity during an outage would be a queue of doomed requests —
  the storm with extra steps. Filed as the round-11 ask:
  `RateLimit#try_acquire`, so windowed budgets can be RateLimits and
  this class can retire.
- Failing fast when the wallet is empty is not giving up — it's
  *believing the fleet's own evidence*. Five doomed retries in one
  window is a diagnosis; the eleventh job doesn't need to reconfirm
  it at the price of another timeout.

## Verdict

45 calls down to 17 with nothing lost, and the deleted 28 were the
ones that would have kept the upstream on its knees. Retry policies
are habits; budgets are decisions. Give the fleet a wallet.
