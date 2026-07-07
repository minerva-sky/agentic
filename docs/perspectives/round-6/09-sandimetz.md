# Round 6 field notes — Sandi Metz collects the receipts

*Built: `examples/refactor_receipts.rb` — the god-join plan improved in
two small steps, with a critic verdict and a measured receipt after
each one.*

## What I built and why

My round-4 critic could point at the god join and prescribe staged
joins; this round performs the surgery *with receipts*. Three states,
each critiqued and each executed:

```
before:  wall 121ms | fan-in 5 | critic: god task (5 deps)
step 1:  wall 151ms | fan-in 3 | critic: no complaints
step 2:  wall 121ms | fan-in 3 | critic: no complaints
```

The receipt I'm proudest of is the one that embarrassed my first
draft's closing line. I wrote "same speed at every step" — the
measurement said otherwise: **step 1 removed the smell and cost
30ms**, because staging the joins added a level to the critical path.
Step 2 paid it back by letting the report read the stages directly.
I've taught for years that refactoring steps should be *safe*; the
receipts add the adult correction — safe is not free, and pretending
otherwise is how refactoring gets a reputation for making things
slower. Intermediate steps may cost. Receipts *price* them, so the
team can decide to pause at step 1 (shippable, smell-free, 30ms
slower) with open eyes instead of discovering the regression in
production.

## The method, distilled

1. Run the critic — it names the smell and one next step.
2. Take the step. Small. The kind you could revert in one commit.
3. Collect the receipt: structure numbers AND behavior numbers.
4. Decide — continue, stop, or revert — from evidence.

That loop is exactly the refactoring kata I run with classes and
tests, transplanted onto graphs and wall clocks. The framework's
contribution is that steps 1 and 3 are each a dozen lines over
`graph` and `execute_plan` — cheap enough that nobody skips them,
which is the only cheapness that changes behavior.

## A note on the shapes themselves

Step 2's final shape has *no* intermediate `join` at all — the report
reads the staged pairs directly via fan-in. The refactoring didn't
just split the god task; it eventually *deleted* the middleman. That's
the pattern from object design: extract, then notice the extraction
made someone redundant. Graphs shed roles the same way classes do,
one safe step at a time.

## Verdict

The critic found it, the steps fixed it, the receipts priced it, and
my own summary got corrected by the data — a complete refactoring
story, including the humility. Ship the loop, not just the tools.
