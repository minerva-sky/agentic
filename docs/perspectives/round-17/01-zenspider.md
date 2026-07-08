# Round 17 field notes — Ryan Davis heckles the plan

*Built: `examples/plan_heckler.rb` — mutation testing for workflows.
Five sabotages applied one at a time to a pricing pipeline; the
plan's spec is graded not on whether it passes but on whether it can
FAIL. Exit 1 while any mutant survives.*

## What I built and why

Round 11 I flogged plans — a pain score for structure. The lottery
sent me back and the brief said build a *tool*, so I built the other
half of heckle's old job: your plan has tests, cute, but **do the
tests fail when the plan is wrong?** The heckler answers empirically.
Break the plan on purpose — no-op the pricer, kill the discount
branch, divide the tax rate by ten, bypass the tax stage entirely,
truncate the receipt — and run the spec against each mutant:

```
SPEC v1 - the tests the team wrote (3 assertions):  1/5 killed
SPEC v2 - plus a golden total and a roll-call:      4/5 killed
SPEC v3 - plus a golden that CROSSES the bar:       5/5 killed
```

v1 is every spec I've ever been mad at: "completes, says TOTAL,
number is positive." It waved four of five saboteurs through,
including a **bypassed tax stage**. The fix isn't clever — pin one
golden end-to-end number you priced by hand, and roll-call the
stages (`ran == %w[price discount tax receipt]`).

## The heckler heckled its author

v2 still let `discount_never_fires` walk, and the reason is the
round's best finding: my fixture order was under the discount bar,
so the discount branch never executed, so no assertion on Earth
could see it die. **A mutant that survives isn't always a missing
assertion — sometimes it's a fixture that never visits the branch.**
The heckler audits your inputs as much as your expectations; every
branch your fixtures never reach is a mutant sanctuary. One bulk
order later: 5/5. (Yes: the mutation tool's author got caught by the
mutation tool, on its first run. Ninth… tenth? I've lost count.
The streak continues.)

## Notes

- The framework made mutation cheap: plans assemble from data, so a
  mutant is a one-symbol argument to the builder — drop an edge,
  swap a lambda. No AST surgery, no reloading. Heckle needed to
  rewrite methods at runtime; here the graph IS the program.
- The baseline gate matters: heckling a red plan proves nothing, so
  the heckler aborts unless the unmutated pipeline passes everything
  first. Same rule as heckle had. Same rule as always.
- Extensions that stay honest: auto-generate edge mutants from
  `graph[:edges]` (drop each in turn), and score fixtures by branch
  visitation before wasting runs.

## Verdict

Three specs, five mutants, one embarrassed author. Mutation testing
doesn't ask whether your tests pass; it asks whether they can fail —
the only thing a test is for. The plan graph being data makes plans
*more* heckleable than Ruby ever was, and I say that with love.
