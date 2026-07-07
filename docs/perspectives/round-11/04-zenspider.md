# Round 11 field notes — Ryan Davis flogs the plans

*Built: `examples/plan_flog.rb` — a pain score per task and per plan,
flog-style: joins, depth, anonymous edges, and orphans each cost
points; boring plans score zero.*

## What I built and why

Flog exists because "this method feels complicated" loses every
argument to "this method is fine, I wrote it." Numbers don't feel.
So: same treatment for plans. Every structural sin has a price —

- **extra join inputs**, 1.5 each (a pipe is free; the *second*
  input is where coupling starts)
- **fan-out past 2**, 1.0 (blame-spreading)
- **depth past 3**, 0.8 per level (latency hiding in a trench coat)
- **anonymous inputs at joins**, 1.2 (data flow you can't name is
  data flow you can't debug)
- **orphans**, 5.0 flat (it runs on every execution and feeds
  nothing — a bug or a billing strategy, pick one)

```
tidy pipeline      0.0  fine
labeled diamond    1.5  fine
the monster       24.5  REFACTOR ME  do_everything=14.7  orphan=5.0
```

## Calibration is the actual work

My first scoring charged every dependency 1.5 — and the tidy
three-step pipeline scored 5.4. Garbage. A sequential pipe is the
*most idiomatic plan there is*; a metric that punishes idiom trains
people to ignore it, which is worse than no metric. The fix: pain
starts at the second join input, and anonymity only costs where
there's more than one input to confuse. Now the pipe scores 0.0 and
the diamond 1.5, which matches every practitioner's gut — that's
what calibration *is*: the metric agreeing with good taste on the
easy cases so it can overrule bad taste on the hard ones.

(Flog went through exactly this. Early versions punished things
Rubyists do on purpose; the weights moved until they didn't. The
weights ARE the opinion. Own them.)

## The number ends the meeting

`do_everything` costs 14.7 on its own — five extra inputs of
coupling plus six anonymous edges. Everyone in the room already
*knew* the monster was a monster; what they lacked was a way to end
the "it's fine, it works" filibuster. "It's a 25; the threshold's
12" ends it. Then Sandi's refactor-receipts show *how* to dissolve
the join, Xavier's diff proves you did, and the flog score drops on
the next run — metric, method, proof, all from one graph accessor.

The orphan deserves its flat 5: roots-that-are-also-leaves in a
multi-task plan came straight from `stats[:roots]` ∩
`stats[:leaves]`, and it's the smell nobody looks for because
nothing *fails*. It just... runs. Forever. On your bill.

## Notes

- One number per plan AND per task — aggregate scores without
  itemization are how metrics become astrology. The breakdown is
  printed because a score you can't argue with is a score you can't
  learn from.
- Thresholds (12 = refactor) are round numbers chosen to be argued
  about. Good. Argue about the threshold, not about whether the
  monster is fine.

## Verdict

Plans have flog now: idiom is free, coupling has a price list, and
the monster's 25 outlives everyone's patience for the word "fine."
Numbers don't refactor plans — they just end the meeting where
nobody was going to.
