# Round 6 field notes — Andrew Kane prices the plan

*Built: `examples/cost_estimator.rb` — price the graph before running
it, gate on budget, reconcile estimate against actuals after.*

## What I built and why

Every LLM team I talk to discovers their spend from the invoice. The
estimator moves that discovery to *before the first token*: each task
carries `{model:, est_tokens:}` in its payload, the pre-flight walks
`graph[:tasks]` against a pricing table, and a budget gate refuses the
plan while refusing is still free:

```
TOTAL  ~57.4c   GATE: under budget, proceeding.
```

Run it with a 30c budget instead and the gate exits 1 *with the fix
suggested* ("downgrade 'draft responses' to the small model") — a
refusal that teaches beats a refusal that scolds. Then the
reconciliation, because estimates are hypotheses:

```
draft responses   est 36.0c   actual 49.8c  (+38%)
TOTAL             est 57.4c   actual 71.7c
```

The demo's seeded drift made the point better than I planned: the run
passed the gate at 57c and *actually cost* 71c. That's not a bug in
the gate — that's the argument for the feedback loop printed in the
last line. Estimates without reconciliation decay into folklore;
actuals fed back into `est_tokens` make next month's gate honest.

## Design notes

- The pre-flight reads `graph[:tasks]` — pricing happens on the
  *declared* plan, no execution machinery involved. Pairs naturally
  with Xavier's wire format: price a plan.json in CI before a human
  approves the deploy that runs it.
- Payload as the cost-metadata carrier is the pattern working as
  designed: the framework never learns what `est_tokens` means, and
  doesn't need to. Opaque payloads age well.
- Real-world wiring is small: `est_tokens` from a tokenizer count on
  your prompts, actuals from the LLM response's usage block (the
  `GenerationStats` class is already sitting in this gem waiting for
  exactly this), pricing table from your provider's page. The shape
  here is the product; the lambdas are placeholders.

## What I'd ship next

`agentic-budget`: the gate as a lifecycle hook (refuse at plan start,
running total during, alert at 80%), reconciliation into Perham's
journal so history accumulates, and a `--price plan.json` CLI mode.
Weekend-sized, invoice-shaped.

## Verdict

The plan can be priced before it runs and audited after — spend
became a gate and a feedback loop instead of a surprise. Six rounds
in, the gem's examples now cover the full lifecycle of an agent plan:
design, review, price, run, observe, resume, and bill.
