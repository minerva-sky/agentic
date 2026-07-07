# Round 16 field notes — Matz declines the garnish

*Built: `examples/gentle_deadline.rb` — a time-budgeted plan whose
optional tasks bow out by name when the clock runs low, so the meal
is always served and nobody sees an error page.*

## What I built and why

Most deadline code is violent. A timeout fires and everything dies —
the user receives an error at 30.0 seconds that could have been a
perfectly good answer at 29. The violence comes from a modeling
failure, not a timing one: we tell the computer *when* we must be
done but never *what matters most*, so when time runs out it
executes everything equally, which is to say it executes the render
step for the crime of coming after the pull quotes.

The kitchen knows better. A cook running late does not cancel
dinner; a cook declines the garnish:

```
a leisurely evening (500ms): served 6 courses - garnish and all
a hurried lunch (160ms):     served 3 courses in 122ms, completed
  declined with regrets: related links; pull quotes; summary haiku
  (the meal was still served - nobody saw an error page)
```

The mechanism is one question, asked politely before each *optional*
task: is there comfortably time for me AND the essentials still
owed? The `essentials_owed` sum is the important half — an optional
task must never spend the time a required task downstream will need.
If the answer is no, it declines *by name* and returns
`:declined_with_regrets`, and the plan flows on to what matters.

## Why gentleness is a data-model feature

I have spent this whole series saying kindness is anticipating the
need before the failure, and here the anticipation is a single
boolean: `essential:`. Mark the garnish as garnish, and lateness
becomes a *menu decision* instead of an outage. Refuse to mark it,
and every deadline is a coin flip about which task gets murdered
mid-simmer. The framework needed nothing new for this — payload
booleans and a monotonic clock — which pleases me most of all: the
graciousness lives in how the plan is *written*, not in machinery.

Note also what the declined tasks are: still *successes*, carrying a
value that says what happened. A decline is not a failure — the
failure ledger stays clean for things that actually broke, and the
regrets list is its own honest report.

## Notes

- The 0.01s of slack in the comfort check is hospitality arithmetic:
  promising to be exactly on time is how one becomes late.
- A follow-up thought for the room (a soft ask, not a demand): an
  `optional:` marking at `add_task` that the scheduler itself
  understands could make this pattern first-class - declined tasks
  reported in their own state rather than smuggled through outputs.

## Verdict

Deadlines are not the enemy of graciousness; treating every task as
equally essential is. Two lines of menu-thinking turned a timeout
from a guillotine into a maître d' — and the hurried lunch was
served, on time, with regrets instead of a stack trace.
