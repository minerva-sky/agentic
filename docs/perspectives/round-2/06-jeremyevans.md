# Round 2 field notes — Jeremy Evans builds the Schema Advisor

*Built: `examples/schema_advisor.rb` — four deterministic DBA rules as
capabilities, one review task per table, advisories sorted by severity.*

## What I built and why

A schema review: feed it table definitions and a query log, get back the
advisories a careful DBA writes on every consulting gig — queries
filtering on unindexed columns (with the exact `add_index` to run), money
stored in floats, NULL-permissive columns, text primary keys. Three
tables and four logged queries produced thirteen advisories, every one of
them the kind of thing that pages you at 3 a.m. two years from now.

The deliberate design decision: **the rules are deterministic lambdas,
not LLM prompts.** "You filter on `orders.user_id` and have no index on
it" is a *fact*, computable from the schema and the log, and a fact
should never be outsourced to a probabilistic system that might phrase it
differently on Tuesdays. The place an LLM would earn its keep in this
program is the one seat I left open: prose-summarizing the advisory list
for a human audience. Facts from rules, prose from models — that division
of labor is the correct architecture for every "AI code review" product I
have seen, and most of them get it backwards.

## Building-with-it observations

- Capabilities were the right container for rules: each declares its
  inputs (`table`, `definition`, `queries`) and its output shape, so
  adding rule five is registering one lambda. The registry gives you a
  rule engine without writing a rule engine.
- solnic's validator earned its keep again: my first `check_money_types`
  returned `advice:` strings under the wrong key and got an immediate
  `ValidationError` naming the violation, instead of an empty report and
  twenty minutes of puzzlement. Strict boundaries between stages are
  cheap insurance exactly when you're writing many small stages.
- Per-table fan-out through the orchestrator is honest scaling: with 400
  tables instead of 3, `concurrency_limit: 4` becomes meaningful and the
  program doesn't change. Correct programs should scale by changing
  constants, not shape.
- The now-canonical gripes, confirmed independently once more: I keyed
  the table through `task.description`, and wrote a `Consultation`
  provider adapter. Five personas, five identical adapters. The evidence
  phase is over; the API should accept the verdict.

## Verdict

A rule engine with typed seams and free parallelism, in one file, no new
dependencies. Wire it to a real `Sequel::Database#schema` and a
`pg_stat_statements` dump and this stops being an example — which is the
test an example should pass.
