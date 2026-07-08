# Round 17 field notes — Sandi Metz refactors without shame

*Built: `examples/shameless_green.rb` — the 99 Bottles arc applied
to a plan: a green god task pinned as a golden master, then one
responsibility extracted per step, each step certified by
byte-identical output. One extraction is deliberately botched; the
referee rejects it; the rope holds.*

## What I built and why

Tenth appearance, and the lottery finally asked me for the workshop
itself: not a critic, not a style guide — the *practice*. 99 Bottles
has one thesis people keep mishearing as two: **first make it work,
then make it right, and the first step funds the second.** Shameless
green isn't a phase you apologize for; it's the deposit that buys
every refactoring after it. Here the deposit is a plan:

```
step 0  shameless green       1 task   4 ops/task  output pinned as GOLDEN
step 1  extract the I/O edge  2 tasks  3 max       identical - certified
step 2  extract calculation   3 tasks  2 max       REJECTED: output changed
step 2' extract calculation   3 tasks  2 max       identical - certified
step 3  one job per task      4 tasks  1 max       identical - certified
```

Step 0 is a god task and it is *green*, and green pinned as a golden
master is worth more than elegant and unverified. Then the loop:
extract exactly one responsibility, re-run the entire plan, compare
byte-for-byte. Watch the two design metrics move in opposite
directions — max responsibilities per task falls 4, 3, 2, 1 while
depth grows — and note that both are **computed from the shape**
(the stage data, the graph's own stats), not asserted by the author.
Numbers you compute can embarrass you; numbers you assert never do,
which is why they're worthless.

## Step 2 is the whole sermon

The botched extraction is not a contrivance — it is the most common
refactoring injury I know: the "cleanup" that quietly changes an
answer. The extracted counter dropped a bug from the count while
looking *more* organized than what it replaced. Organization is not
correctness. The golden master caught it in the same breath, the
step was rejected, the previous shape survived, and the fixed
extraction re-certified. Refactoring is changing the arrangement of
code while *proving* the behavior stands still; without the proof
it's just editing with confidence.

## Notes

- The plan made the discipline cheap: each candidate shape is data
  (stages and their ops), so "try the extraction" is a rebuild and a
  re-run, and rollback is keeping the old array. When shapes are
  this cheap to audition, there is no excuse for auditioning them in
  production.
- Depth growing as ops-per-task falls is the honest trade — smaller
  pieces, longer chain. The metrics report it instead of hiding it;
  whether depth 5 is acceptable is a judgment, but now it's an
  *informed* one.
- After ten of these: the framework's habit of making structure into
  data (stages, graphs, contracts) is why every discipline I've
  brought here — critics, style cops, receipts, and now golden-master
  refactoring — came in under a hundred lines. Cheap change is a
  property of *representation*, and this repo chose the right one.

## Verdict

Five steps, one rejection, output provably still. Shameless green,
golden master, one responsibility per move — the kata works on plans
because plans made their shape visible enough to count. Make it
work, make it right, and never let "right" ship without the receipt
that says "still works."
