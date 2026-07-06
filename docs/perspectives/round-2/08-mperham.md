# Round 2 field notes — Mike Perham builds the Durable Batch

*Built: `examples/durable_batch.rb` — six billable calls, a real
`exit!` mid-batch, and a resume that pays only for what the journal
can't prove was finished.*

## What I built and why

The demo every durability claim owes its users: don't *simulate* a
crash, **have one**. The batch runs in a forked child that dies with
`Process.exit!(97)` in the middle of invoice-4 — no `ensure`, no
`at_exit`, the honest `kill -9`. Then the parent process replays the
journal and finishes the batch:

```
!! power cut during invoice-4 - process dying with exit!(97)
journal replay: 3 invoice(s) already paid: invoice-1, invoice-2, invoice-3
run 2: processing 3 invoice(s): invoice-4, invoice-5, invoice-6
total spend: $1.75 for 6 invoices (naive rerun-everything: $2.50)
```

Seven calls paid for six invoices — the one unavoidable double-pay is
the call that was mid-flight when the power died (that's what
idempotency keys at the API layer are for). The naive rerun costs ten.
At example prices that's $0.75; at real batch sizes it's the difference
between "rerun it" being a shrug and being a budget meeting.

## What the crash taught, beyond the point of it

- The fsync-per-event decision from round 1 got its vindication:
  `exit!` discards everything buffered — including, amusingly, the
  child's *narration* (`$stdout.sync = true` restored the story, and if
  journal lines had been buffered the way stdout was, the receipt would
  be fiction). Durability you haven't crash-tested is a rumor.
- Found a real gap in my own round-1 design: `task_succeeded` events
  carry the task *id* but not its *description*, and run 2's task ids
  are new UUIDs — so mapping "what's done" back to "which invoice" meant
  joining `task_started` events by hand. The journal should carry a
  caller-supplied idempotency key on every event. My gap, my next PR.
- Resume is still caller-assembled: replay, diff, rebuild the
  orchestrator with the remainder. It's eight honest lines, but
  `PlanOrchestrator.resume(journal:, tasks:)` is the one-liner this
  example proves the API is ready for.

## Verdict

Boring works: append, fsync, replay, skip. The framework's hooks let
durability be an accessory instead of a rewrite, and the crash test
passed on the first honest kill. Ship the idempotency key and the
`resume` helper, and this example becomes the README section titled
"when the deploy hits mid-plan."
