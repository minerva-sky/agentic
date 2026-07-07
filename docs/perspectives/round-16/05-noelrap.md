# Round 16 field notes — Noel Rappin balances the books

*Built: `examples/spend_ledger.rb` — LLM spend as integer cents in a
journal-backed ledger, with affordability checked before each spend
and budget exhaustion classified retryable. The invoice balances to
the cent; the overdraft never happens.*

## What I built and why

I wrote a whole book about taking people's money, and its saddest
chapters are all the same chapter: a team that treated money as a
number instead of as *money*. LLM plans spend real dollars per task
now, and I watched fifteen rounds of this series journal durations,
verdicts, and damage — everything except the invoice. So:

```
stopped at: budget: polish:tone costs $9.50 but only $5.10 remains
item              amount      running
classify:batch     $2.40        $2.40
draft:responses   $18.75       $21.15
review:drafts     $18.75       $39.90
TOTAL             $39.90   (budget $45.00)
```

Three rules from every payments postmortem I've ever read, all
enforced here:

1. **Integer cents.** `0.1 + 0.2 != 0.3` is cute trivia everywhere
   except billing, where it's a lawsuit. Floats round your money
   eventually, and eventually is audit season. Every price, every
   sum, every comparison in this ledger is an Integer.
2. **Check affordability BEFORE the spend.** `afford!` runs at the
   top of the task, not the bottom — a budget that only notices
   overdrafts is a historian, not a control. The plan stopped at
   $39.90 of $45.00 *because polish:tone was never bought*, which is
   the entire point: the overdraft that didn't happen is invisible
   in every metric except the one that matters.
3. **Budget exhaustion is retryable.** The stop raises with a
   transient error class on purpose: tomorrow has a new budget.
   Round 8's dead letter office will *requeue* this task instead of
   parking it next to the revoked API keys — the taxonomy the series
   built for failures turns out to classify money problems too.

## One file, two trails

The design decision I'd defend hardest: spends and declines are
journal events (`:spend`, `:spend_declined`) in the *same fsynced
file* as the task lifecycle. "What did this run cost" and "what did
this run do" are the same replay — no reconciliation job between a
metrics store and a billing store, which is where money numbers go
to diverge. When the auditor asks, the answer is one file, and it
was durable before each task returned.

## Notes

- The running-balance column in the invoice isn't decoration; it's
  the human-verifiable proof of summation. Ledgers you can't check
  by eye get checked by nobody.
- Soft ask for the room: a `before_task_execution`-adjacent hook
  that can *veto* scheduling would let the budget stop the task
  before the agent is even built, rather than raising from inside
  it. The raise works; a veto would be cleaner accounting.

## Verdict

The journal learned denominations: integer cents, pre-spend checks,
retryable budget stops, and an invoice that balances on sight. Take
my money — but only up to the budget, and give me the receipt in
the same file as the work.
