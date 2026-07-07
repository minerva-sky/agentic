# Round 9 field notes — Andrew Kane runs the shootout

*Built: `examples/impl_shootout.rb` — two candidate implementations
of one capability, one eval set, and a two-axis verdict: accuracy
AND latency, on the same table.*

## What I built and why

Every capability eventually has a challenger: the regex that shipped
in an afternoon versus the subtler thing someone wrote on a weekend.
The upgrade decision then happens in a meeting, powered by whoever
has the freshest anecdote. I wanted the decision to be a table:

```
v1 regex     accuracy  63%   p50  2.1ms
v2 weights   accuracy 100%   p50 10.1ms
verdict: v2 wins 8/8 to 5/8 - and costs 5x the latency
```

The eval set is the referee, and the deciding cases share one shape:
"password reset email shows an error page" has one bug word and five
points of account evidence. v1 answers by *first match* — clause
order, an accident of code layout — and files it under bug. v2
answers by *total evidence* and files it under account. That
difference is invisible in a demo and everywhere in production,
because production tickets are all like this: multi-topic, casually
worded, keyword-colliding.

## Both axes or it's marketing

The scoreboard refuses to report accuracy without latency. "v2 is
better" is not a finding; "v2 buys 3 more correct routes per 8
tickets at 8ms each" is, because it's *deniable* — a team routing a
million tickets a day at tight budgets can look at the same table
and correctly choose v1. Benchmarks in my gems' READMEs follow the
same rule: publish the numbers that let someone reasonably choose
the competitor, or you've published an ad.

Two implementation notes that carried weight:

- v2's first draft matched exact words and *lost* the crash case —
  "crashes" isn't "crash." Prefix-stem matching fixed it, which is
  the eval set doing its actual job: catching the bug in the
  challenger before the meeting where you propose it.
- A perfect 8/8 doesn't mean v2 is done; it means the eval set
  **stopped discriminating**. The scoreboard says so in its own
  output. Grow the set until your best candidate fails — a suite
  your champion aces is a suite that's stopped asking questions.

## Notes

- The shootout composes with round 8's scorer seam: swap `correct:`
  for a graded scorer and this same harness A/Bs LLM-backed
  candidates, where "accuracy" becomes mean score and latency
  becomes dollars. Nothing about the table changes shape.

## Verdict

Upgrade debates become table reads: two candidates, one eval set,
both axes visible. v2 wins this one on evidence-versus-clause-order,
and the latency price is printed next to the win so the choice stays
a choice.
