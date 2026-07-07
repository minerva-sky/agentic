# Round 8 field notes — Mike Perham opens the Dead Letter Office

*Built: `examples/dead_letter_office.rb` — every failure across three
journaled runs, triaged by most-recent-attempt into requeue, parked,
and recovered.*

## What I built and why

Sidekiq's morgue taught me that a dead-letter queue is really three
queues wearing one name, and confusing them is how on-call rotations
die. The office sorts the journal's failures into all three:

```
REQUEUE:   sync:billing (429 x2), sync:tickets (502)
PARKED:    sync:warehouse (401 key revoked - a human must act)
RECOVERED: sync:crm (timed out Monday, fine Tuesday - NOT dead)
```

Two decisions carry the design:

1. **Triage by most recent attempt.** sync:crm failed once and
   recovered — paging on it is paging for a ghost. sync:tickets
   succeeded once and *then* threw a 502 — its old success excuses
   nothing. Both mistakes are common in real DLQs, and both come from
   treating failure as a set membership instead of a timeline. The
   journal is a timeline; the office just reads it in order and keeps
   the last word.
2. **The taxonomy addresses the mail.** Rate limits and 502s go on
   the requeue manifest; the revoked key gets parked with "a human
   must act." Requeuing an auth failure isn't retrying, it's ritual —
   the round-4 lesson (errors testify about their own retryability),
   now applied at the *fleet* level across runs instead of inside one
   policy.

## The attempt-count column

"2 failed attempt(s) on record" on sync:billing is quiet gold: a
letter that's been requeued twice already deserves suspicion the
first-timer doesn't. Real offices should escalate on attempt count —
requeue at 1-2, park-with-review at 3+ — and the journal makes the
count free because every failure was fsynced when it happened.
Escalation policies need memory; the journal *is* memory.

## Notes

- One triage decision I made deliberately: the office rebuilds
  retryability from the error *type name* in the journal, via an
  explicit table. The journal stores `error_type` as a string (it
  must — it's JSON), so the mapping lives at read time. An
  alternative is journaling `retryable:` at write time from
  `failure.retryable?`; that's more honest to the moment of failure
  and survives taxonomy renames. Filed as the round-9 ask.

## Verdict

Requeue, park, recover — three verbs, correctly assigned, from one
replay. The office closes the failure-handling loop the drills
started: errors testify, policies listen, and now the backlog is
sorted by what the testimony actually said.
