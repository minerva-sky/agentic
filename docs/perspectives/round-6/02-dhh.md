# Round 6 field notes — DHH runs the deploy train

*Built: `examples/deploy_train.rb` — lint → test → build → canary →
ship → announce, run healthy and then with a failing canary. The
second run is the product.*

## What I built and why

Every deploy pipeline demo shows the green path, which is like
reviewing a seatbelt by admiring the buckle. The train's whole reason
to exist is Friday:

```
canary    RED - error rate 4.2% exceeds 1% threshold
ship      CANCELED (never left the yard)
announce  CANCELED (never left the yard)
train status: partial_failure
```

One `after_task_failure` hook calling `cancel_plan` is the entire
brake. The cars behind the red gate report **CANCELED** — a word, in
the results, queryable — not the silent absence that makes 2am
debugging a archaeology dig ("did announce run? grep the logs...").
Jeremy's round-4 status fix is what makes this honest: before it, a
stopped train could report `:completed` and you'd announce a release
you never shipped. I have seen that exact incident in the wild.
Twice.

## What I learned writing the copy

My first closing line claimed the train status was `:canceled` — it's
actually `:partial_failure`, because failure outranks cancellation in
the status precedence. And sitting with it, that's *right*: the
headline should be WHY the train stopped (a gate went red); the
manifest shows what never shipped (the canceled cars). Two different
questions, answered at two different levels. I fixed my prose, not the
framework — a rarity worth recording, and the sign the status enum has
finally earned trust: when the tool and I disagreed, the tool was
right.

## Omakase notes

- `max_retries: 0` on the train. Deploy gates should not be retried
  into submission; a flaky canary is a red canary. Retry budgets are
  for *ingestion*, not *judgment*.
- `concurrency_limit: 1` because a deploy train is a train. There are
  workloads where the queue IS the feature; the framework respecting
  that without ceremony (one integer) is the omakase experience.
- This is `bin/deploy` for anyone whose deploy is Ruby-orchestrable.
  Swap the sleeps for `system` calls and the canary check for a real
  metrics query; the shape ships as-is.

## Verdict

The unhappy path is the product, and it now reads like a train
manifest instead of a shrug. Six stations, one hook, zero incident
reports that end with "we didn't realize it kept going."
