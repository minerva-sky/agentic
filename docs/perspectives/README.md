# Ten Rubyist Perspectives on Agentic

An exercise in multi-perspective review: we embraced the personas of ten of the
most prolific Rubyists, asked how each would use this gem, what they would
build with it, what would delight or confuse them — and then **built the thing
each persona proposed**, taking field notes in character along the way.

> These are imagined characterizations of public figures, grounded in their
> well-known public work and stated philosophies. They are not the actual
> opinions of the people named.

## Round 1 — reviewing and repairing the framework

| # | Persona | Lens | What they built | Field notes |
|---|---------|------|-----------------|-------------|
| 0 | Prologue | The broken baseline | Repaired the truncated test suite | [00-prologue.md](field-notes/00-prologue.md) |
| 1 | Matz | Language design, developer happiness | `examples/haiku_agent.rb` — the three-line agent | [01-matz.md](field-notes/01-matz.md) |
| 2 | DHH | Conceptual compression | `Agentic.run("goal")` — the one-liner | [02-dhh.md](field-notes/02-dhh.md) |
| 3 | Aaron Patterson | Performance, runtime internals | `benchmark/boot.rb` + thread-safe assembly init | [03-tenderlove.md](field-notes/03-tenderlove.md) |
| 4 | Xavier Noria | Code loading correctness | Zeitwerk as the single loader; 19× faster require | [04-fxn.md](field-notes/04-fxn.md) |
| 5 | Samuel Williams | Structured concurrency | Reactor-composable `PlanOrchestrator` | [05-ioquatix.md](field-notes/05-ioquatix.md) |
| 6 | Jeremy Evans | Fail-fast correctness | Fail-fast credential validation, `ConfigurationError` | [06-jeremyevans.md](field-notes/06-jeremyevans.md) |
| 7 | Piotr Solnica | Types and boundaries | Capability input validation against declared schemas | [07-solnic.md](field-notes/07-solnic.md) |
| 8 | Mike Perham | Durability, boring reliability | `ExecutionJournal` — crash-surviving plan state | [08-mperham.md](field-notes/08-mperham.md) |
| 9 | Sandi Metz | Small objects, honest messages | `execute_with_schema` honesty + subclass-safe factory | [09-sandimetz.md](field-notes/09-sandimetz.md) |
| 10 | Andrew Kane | Practical ML gems | Pluggable `web_search` capability backend | [10-ankane.md](field-notes/10-ankane.md) |

## Round 2 — building *with* the gem

Each persona then built something novel **using** Agentic as a consumer —
every program under `examples/` runs offline, and the field notes record
what building on the framework actually felt like.

| # | Persona | Built with the gem | Run it | Field notes |
|---|---------|--------------------|--------|-------------|
| 1 | Matz | Renga circle — dependency graphs as poetic form | `examples/renga_circle.rb` | [round-2/01-matz.md](round-2/01-matz.md) |
| 2 | DHH | HEY-style ticket screener (parallel capability pipeline) | `examples/ticket_screener.rb` | [round-2/02-dhh.md](round-2/02-dhh.md) |
| 3 | Aaron Patterson | Performance Detective — Prism audits the gem's own methods | `examples/performance_detective.rb` | [round-2/03-tenderlove.md](round-2/03-tenderlove.md) |
| 4 | Xavier Noria | Namespace Cartographer — maps constant trees, audits conformance | `examples/namespace_cartographer.rb` | [round-2/04-fxn.md](round-2/04-fxn.md) |
| 5 | Samuel Williams | Latency Lab — measured fan-out scaling + reactor cohabitation | `examples/latency_lab.rb` | [round-2/05-ioquatix.md](round-2/05-ioquatix.md) |
| 6 | Jeremy Evans | Schema Advisor — deterministic DBA rules as capabilities | `examples/schema_advisor.rb` | [round-2/06-jeremyevans.md](round-2/06-jeremyevans.md) |
| 7 | Piotr Solnica | Typed ETL pipeline — contracts stop bad data at named boundaries | `examples/typed_pipeline.rb` | [round-2/07-solnic.md](round-2/07-solnic.md) |
| 8 | Mike Perham | Durable Batch — real `exit!` mid-run, resume without re-paying | `examples/durable_batch.rb` | [round-2/08-mperham.md](round-2/08-mperham.md) |
| 9 | Sandi Metz | Refactoring Dojo — three critics, one prescribed next step | `examples/refactoring_dojo.rb` | [round-2/09-sandimetz.md](round-2/09-sandimetz.md) |
| 10 | Andrew Kane | Gem Scout — search + score pipeline on the pluggable backend | `examples/gem_scout.rb` | [round-2/10-ankane.md](round-2/10-ankane.md) |

## Round 3 — new experiments on the improved framework

The round-2 consensus was delivered as a release (task payloads, direct
agents/callables, dependency output piping, provider-optional
`execute_plan`, composed-capability contracts, journal idempotency keys,
and the concurrency documentation — plus a scheduler deadlock fix found
by one of these builds). The personas then built ten *new* things:

| # | Persona | Built with the improved gem | Run it | Field notes |
|---|---------|------------------------------|--------|-------------|
| 1 | Matz | Telephone game — piping as the whole program | `examples/telephone_game.rb` | [round-3/01-matz.md](round-3/01-matz.md) |
| 2 | DHH | Standup digest — parallel collectors fan into one writer | `examples/standup_digest.rb` | [round-3/02-dhh.md](round-3/02-dhh.md) |
| 3 | Aaron Patterson | Plan Gantt — ASCII execution timeline (found a scheduler deadlock) | `examples/plan_gantt.rb` | [round-3/03-tenderlove.md](round-3/03-tenderlove.md) |
| 4 | Xavier Noria | Documentation surveyor — 90.2% YARD coverage, fan-in report | `examples/doc_coverage.rb` | [round-3/04-fxn.md](round-3/04-fxn.md) |
| 5 | Samuel Williams | Live dashboard — hooks → `Async::Queue` → live renderer | `examples/live_dashboard.rb` | [round-3/05-ioquatix.md](round-3/05-ioquatix.md) |
| 6 | Jeremy Evans | Contract fuzzer — seed-deterministic boundary attack, 34 trials | `examples/contract_fuzzer.rb` | [round-3/06-jeremyevans.md](round-3/06-jeremyevans.md) |
| 7 | Piotr Solnica | Command bus — commands as contract-bearing compositions | `examples/command_bus.rb` | [round-3/07-solnic.md](round-3/07-solnic.md) |
| 8 | Mike Perham | Flaky API drill — retries that provably wait, journaled | `examples/flaky_api_drill.rb` | [round-3/08-mperham.md](round-3/08-mperham.md) |
| 9 | Sandi Metz | Collaboration tracer — plans as sequence diagrams | `examples/collaboration_tracer.rb` | [round-3/09-sandimetz.md](round-3/09-sandimetz.md) |
| 10 | Andrew Kane | Changelog scout — release notes from real git history | `examples/changelog_scout.rb` | [round-3/10-ankane.md](round-3/10-ankane.md) |

## Round 4 — the asks become grammar

The round-3 asks shipped as a release (named dependencies via `needs:`,
`Task#previous_output`, the `task_slot_acquired` hook, retry policies
consulting `failure.retryable?`, and contract value predicates —
`enum:`, `min:`/`max:`, `non_empty:`), and ten more experiments followed:

| # | Persona | Built on the round-4 release | Run it | Field notes |
|---|---------|------------------------------|--------|-------------|
| 1 | Matz | Exquisite corpse — creature parts assembled by name | `examples/exquisite_corpse.rb` | [round-4/01-matz.md](round-4/01-matz.md) |
| 2 | DHH | Setup doctor — the onboarding wiki, deleted | `examples/setup_doctor.rb` | [round-4/02-dhh.md](round-4/02-dhh.md) |
| 3 | Aaron Patterson | Knee finder — measured concurrency recommendations | `examples/knee_finder.rb` | [round-4/03-tenderlove.md](round-4/03-tenderlove.md) |
| 4 | Xavier Noria | Coupling cartographer — the constant-reference force map | `examples/coupling_cartographer.rb` | [round-4/04-fxn.md](round-4/04-fxn.md) |
| 5 | Samuel Williams | Shared rate limit — one credential ceiling across two plans | `examples/shared_rate_limit.rb` | [round-4/05-ioquatix.md](round-4/05-ioquatix.md) |
| 6 | Jeremy Evans | Invariant sentinel — laws checked after every task (found the `:canceled` status bug) | `examples/invariant_sentinel.rb` | [round-4/06-jeremyevans.md](round-4/06-jeremyevans.md) |
| 7 | Piotr Solnica | Contract state machine — enum guards instead of transition tables | `examples/state_machine.rb` | [round-4/07-solnic.md](round-4/07-solnic.md) |
| 8 | Mike Perham | Error taxonomy drill — errors testify about their own retryability | `examples/error_taxonomy_drill.rb` | [round-4/08-mperham.md](round-4/08-mperham.md) |
| 9 | Sandi Metz | Graph critic — design review for dependency graphs, pre-execution | `examples/graph_critic.rb` | [round-4/09-sandimetz.md](round-4/09-sandimetz.md) |
| 10 | Andrew Kane | README verifier — every snippet parsed, every constant resolved (found a 4-round-old broken snippet) | `examples/readme_verifier.rb` | [round-4/10-ankane.md](round-4/10-ankane.md) |

## Round 5 — the ecosystem turn

The round-4 asks shipped as a release (`PlanOrchestrator#graph`,
`ValidationError#expectations`, cross-field contract `rules:`,
`Agentic::RateLimit` + `LlmClient limiter:`, jitter-on-by-default), the
three examples that requested them were modernized onto them, and ten
more experiments followed:

| # | Persona | Built on the round-5 release | Run it | Field notes |
|---|---------|------------------------------|--------|-------------|
| 1 | Matz | Dungeon crawl — the map drawn from the plan itself | `examples/dungeon_crawl.rb` | [round-5/01-matz.md](round-5/01-matz.md) |
| 2 | DHH | Live kanban — the WIP limit is the concurrency limit | `examples/kanban_board.rb` | [round-5/02-dhh.md](round-5/02-dhh.md) |
| 3 | Aaron Patterson | Critical path — which task the wall clock is actually about | `examples/critical_path.rb` | [round-5/03-tenderlove.md](round-5/03-tenderlove.md) |
| 4 | Xavier Noria | Mermaid diagrammer — docs generated from the graph, labeled by `needs:` | `examples/plan_diagram.rb` | [round-5/04-fxn.md](round-5/04-fxn.md) |
| 5 | Samuel Williams | Burst absorber — `RateLimit` characterized under hostile waves | `examples/burst_absorber.rb` | [round-5/05-ioquatix.md](round-5/05-ioquatix.md) |
| 6 | Jeremy Evans | Freight desk — a tariff book as cross-field rules, all violations at once | `examples/freight_rules.rb` | [round-5/06-jeremyevans.md](round-5/06-jeremyevans.md) |
| 7 | Piotr Solnica | 422 generator — one contract-agnostic error renderer from `expectations` | `examples/form_errors.rb` | [round-5/07-solnic.md](round-5/07-solnic.md) |
| 8 | Mike Perham | Stampede simulator — the jitter default, argued by histogram | `examples/stampede_sim.rb` | [round-5/08-mperham.md](round-5/08-mperham.md) |
| 9 | Sandi Metz | Three shapes — chain vs star vs staged, chosen by evidence | `examples/three_shapes.rb` | [round-5/09-sandimetz.md](round-5/09-sandimetz.md) |
| 10 | Andrew Kane | Examples index — self-maintaining signage for a 40-example gallery | `examples/examples_index.rb` | [round-5/10-ankane.md](round-5/10-ankane.md) |

## Round 6 — plans as artifacts

The round-5 asks shipped as a release (`graph[:order]` via Kahn's
algorithm, labeled `graph[:edges]`, structured rules with
`fields:`/`rule_violations`, `backoff_jitter: :full`, and windowed
rate limits `RateLimit.new(30, per: 60)`), four examples were
modernized onto them, and ten more experiments followed:

| # | Persona | Built on the round-6 release | Run it | Field notes |
|---|---------|------------------------------|--------|-------------|
| 1 | Matz | Plan tour — the plan narrated as prose, before it runs | `examples/plan_tour.rb` | [round-6/01-matz.md](round-6/01-matz.md) |
| 2 | DHH | Deploy train — the unhappy path as the product | `examples/deploy_train.rb` | [round-6/02-dhh.md](round-6/02-dhh.md) |
| 3 | Aaron Patterson | Perf diff — did the PR make it worse, path-qualified | `examples/perf_diff.rb` | [round-6/03-tenderlove.md](round-6/03-tenderlove.md) |
| 4 | Xavier Noria | Plan round-trip — graph → JSON → graph with isomorphism proof | `examples/plan_roundtrip.rb` | [round-6/04-fxn.md](round-6/04-fxn.md) |
| 5 | Samuel Williams | Quota keeper — ceiling physics vs window physics, 61ms vs 601ms | `examples/quota_keeper.rb` | [round-6/05-ioquatix.md](round-6/05-ioquatix.md) |
| 6 | Jeremy Evans | Rule prober — field declarations audited; a lying rule caught | `examples/rule_prober.rb` | [round-6/06-jeremyevans.md](round-6/06-jeremyevans.md) |
| 7 | Piotr Solnica | API reference — docs from the contracts that validate the calls | `examples/api_reference.rb` | [round-6/07-solnic.md](round-6/07-solnic.md) |
| 8 | Mike Perham | Jitter shootout — none/equal/full on one scoreboard: 40/19/13 | `examples/jitter_shootout.rb` | [round-6/08-mperham.md](round-6/08-mperham.md) |
| 9 | Sandi Metz | Refactor receipts — the god join dissolved in priced steps | `examples/refactor_receipts.rb` | [round-6/09-sandimetz.md](round-6/09-sandimetz.md) |
| 10 | Andrew Kane | Cost estimator — the plan priced before it runs, reconciled after | `examples/cost_estimator.rb` | [round-6/10-ankane.md](round-6/10-ankane.md) |

## Round 7 — the referee round

The round-6 asks shipped as a release (`RateLimit#and` composition,
`graph[:stats]`, journal `durations` keyed by description,
`CapabilitySpecification#to_json_schema`, injectable retry `rng:`),
two graph tools were modernized onto `stats`, and ten more experiments
followed:

| # | Persona | Built on the round-7 release | Run it | Field notes |
|---|---------|------------------------------|--------|-------------|
| 1 | Matz | Plan fortune teller — structural diagnoses in a mystic's robe | `examples/plan_fortune.rb` | [round-7/01-matz.md](round-7/01-matz.md) |
| 2 | DHH | Weekly check-in — the journal answers so nobody's Friday has to | `examples/weekly_checkin.rb` | [round-7/02-dhh.md](round-7/02-dhh.md) |
| 3 | Aaron Patterson | Perf history — regressions judged against the last release's journal | `examples/perf_history.rb` | [round-7/03-tenderlove.md](round-7/03-tenderlove.md) |
| 4 | Xavier Noria | Structural diff — plan review at design altitude, not JSON altitude | `examples/plan_structural_diff.rb` | [round-7/04-fxn.md](round-7/04-fxn.md) |
| 5 | Samuel Williams | Composed limits — both laws at once; the chart names the binding one | `examples/composed_limits.rb` | [round-7/05-ioquatix.md](round-7/05-ioquatix.md) |
| 6 | Jeremy Evans | Backoff conformance — nine timing envelopes certified via injected rng | `examples/backoff_conformance.rb` | [round-7/06-jeremyevans.md](round-7/06-jeremyevans.md) |
| 7 | Piotr Solnica | Schema export + agreement proof — every projection ships its referee | `examples/json_schema_export.rb` | [round-7/07-solnic.md](round-7/07-solnic.md) |
| 8 | Mike Perham | Incident report — the 3am questions answered from the journal | `examples/incident_report.rb` | [round-7/08-mperham.md](round-7/08-mperham.md) |
| 9 | Sandi Metz | Graph style guide — RuboCop for plans, ten lines per cop | `examples/graph_style.rb` | [round-7/09-sandimetz.md](round-7/09-sandimetz.md) |
| 10 | Andrew Kane | Capability evals — contracts check types, evals check truth | `examples/capability_evals.rb` | [round-7/10-ankane.md](round-7/10-ankane.md) |

### What round 7 surfaced

1. **The referee pattern generalized**: six exit-code-gated honesty
   tools now exist (fuzzer, prober, verifier, conformance, agreement
   proof, evals) — the framework can no longer lie about its
   contracts, rules, docs, timing, exports, or answers.
2. **The journal became four products**: crash recovery, resume keys,
   perf baselines, and prose (check-ins, incident reports) — one
   fsynced JSONL file, read with different questions.
3. **Tools kept correcting their authors**: Samuel's binding-constraint
   prose and Piotr's generator coverage were both fixed by their own
   measurements — the third straight round of measurement-over-narrative.
4. **Next asks**: `stats[:roots]`/`stats[:leaves]`, percentile
   baselines over journal history (p50-of-last-N), rename detection
   hints in the structural diff, JSON Schema `if/then` emission for
   expressible rules, and an eval-scorer seam for LLM-backed
   capabilities.

## Round 8 — structure becomes vocabulary

The round-7 asks shipped as a release (`stats[:roots]`/`stats[:leaves]`,
journal `duration_samples` with `duration_percentile(desc, pct, last:)`,
and `x-agentic-rules` emission in `to_json_schema`), and ten more
experiments followed:

| # | Persona | Built on the round-8 release | Run it | Field notes |
|---|---------|------------------------------|--------|-------------|
| 1 | Matz | Plan forest — the graph drawn as trees, depth as altitude | `examples/plan_forest.rb` | [round-8/01-matz.md](round-8/01-matz.md) |
| 2 | DHH | Hill chart — where the work *is*, from lifecycle hooks | `examples/hill_chart.rb` | [round-8/02-dhh.md](round-8/02-dhh.md) |
| 3 | Aaron Patterson | Variance detective — flaky vs slow, settled by percentiles | `examples/variance_detective.rb` | [round-8/03-tenderlove.md](round-8/03-tenderlove.md) |
| 4 | Xavier Noria | Plan merge — three-way merge with conflicts at seam altitude | `examples/plan_merge.rb` | [round-8/04-fxn.md](round-8/04-fxn.md) |
| 5 | Samuel Williams | Adaptive throttle — AIMD finds the capacity nobody documented | `examples/adaptive_throttle.rb` | [round-8/05-ioquatix.md](round-8/05-ioquatix.md) |
| 6 | Jeremy Evans | Journal audit — five invariants; a tampered journal named precisely | `examples/journal_audit.rb` | [round-8/06-jeremyevans.md](round-8/06-jeremyevans.md) |
| 7 | Piotr Solnica | Contract semver — breaking-or-compatible computed, bump advised | `examples/contract_semver.rb` | [round-8/07-solnic.md](round-8/07-solnic.md) |
| 8 | Mike Perham | Dead letter office — requeue, parked, recovered, by last word | `examples/dead_letter_office.rb` | [round-8/08-mperham.md](round-8/08-mperham.md) |
| 9 | Sandi Metz | Graph to specs — structural roles dictate the test plan | `examples/graph_to_specs.rb` | [round-8/09-sandimetz.md](round-8/09-sandimetz.md) |
| 10 | Andrew Kane | Eval scorers — four ways to say "good enough", one seam | `examples/eval_scorers.rb` | [round-8/10-ankane.md](round-8/10-ankane.md) |

### What round 8 surfaced

1. **Structure became vocabulary**: `roots`/`leaves`/`depth` landed and
   were immediately spent three ways — a drawing (forest), a test plan
   (graph-to-specs), and merge conflicts named at seam altitude. Metadata
   that keeps buying unplanned tools is metadata shaped right.
2. **Durations became distributions**: `duration_samples` turned point
   readings into percentiles, and two tools acted on them — the variance
   detective separates flaky from slow (p90/p50 ratio), and the adaptive
   throttle steers concurrency by p50 drift instead of vibes.
3. **Signal-to-noise as a design goal**: the dead letter office triages
   by *most recent* attempt (no paging for ghosts), and the eval scorers
   flag exactly one real failure where exact-match flags two. Both argue
   the same point: a report is only as good as what its failures mean.
4. **The declarations' blind spot held**: Piotr's semver advisor and
   Jeremy's audit both stop at callable rules — predicates stay opaque
   to every static tool. Structured rules narrow the gap; they don't
   close it.
5. **Next asks**: `RateLimit#resize(n)` so the adaptive throttle can
   steer the real limiter instead of simulating one, and journaling
   `retryable:` at write time from `failure.retryable?` so triage
   survives taxonomy renames. (`eval_scorers.rb` joins the
   exit-1-by-design set.)

## Round 9 — the operations round

The round-8 asks shipped as a release (`RateLimit#resize(n)` — live
ceiling changes, growing wakes waiters, shrinking drains — and the
journal recording `retryable:` on `task_failed` at write time from the
failure's own verdict), the two examples that asked were modernized
onto them, and ten more experiments followed:

| # | Persona | Built on the round-9 release | Run it | Field notes |
|---|---------|------------------------------|--------|-------------|
| 1 | Matz | Failure weather — retryable is weather, non-retryable is climate | `examples/failure_weather.rb` | [round-9/01-matz.md](round-9/01-matz.md) |
| 2 | DHH | Traffic dial — a canary rollout as one resized limiter | `examples/traffic_dial.rb` | [round-9/02-dhh.md](round-9/02-dhh.md) |
| 3 | Aaron Patterson | Throughput knee — the ceiling sweep with two honest clocks | `examples/throughput_knee.rb` | [round-9/03-tenderlove.md](round-9/03-tenderlove.md) |
| 4 | Xavier Noria | Graph invariants — seven promises of the reflection API, proved | `examples/graph_invariants.rb` | [round-9/04-fxn.md](round-9/04-fxn.md) |
| 5 | Samuel Williams | Fair share — tenant-fairness composed, shares rebalanced live | `examples/fair_share.rb` | [round-9/05-ioquatix.md](round-9/05-ioquatix.md) |
| 6 | Jeremy Evans | Resize torture — shrink drains, grow wakes, ceilings bind | `examples/resize_torture.rb` | [round-9/06-jeremyevans.md](round-9/06-jeremyevans.md) |
| 7 | Piotr Solnica | Contract fixtures — examples derived from declarations, proved | `examples/contract_fixtures.rb` | [round-9/07-solnic.md](round-9/07-solnic.md) |
| 8 | Mike Perham | Circuit breaker — three strikes for 503s, one for a revoked key | `examples/circuit_breaker.rb` | [round-9/08-mperham.md](round-9/08-mperham.md) |
| 9 | Sandi Metz | Duck agents — five shapes through one seam, one tiny decorator | `examples/duck_agents.rb` | [round-9/09-sandimetz.md](round-9/09-sandimetz.md) |
| 10 | Andrew Kane | Impl shootout — accuracy AND latency on one table | `examples/impl_shootout.rb` | [round-9/10-ankane.md](round-9/10-ankane.md) |

### What round 9 surfaced

1. **resize turned limits into policy objects**: five tools steer one
   live limiter — the rollout dial, the ceiling sweep, tenant share
   rebalancing, the torture certificate, and the modernized AIMD
   throttle. The topology of a limiter graph stays fixed; only the
   numbers move at runtime, which is the property that makes it safe.
2. **The write-time verdict became a decision input**: the weather
   report (wait vs dig a well), the circuit breaker (three strikes vs
   instant trip), and the modernized dead letter office all *act* on
   `retryable:` instead of reconstructing it — the error's testimony,
   recorded when fresh, drives policy later.
3. **The tools kept correcting their authors** (fifth consecutive
   round): Samuel's one-worker tenant couldn't starve, Aaron's
   "throughput goes flat" was actually a fall, Xavier's depth
   invariant was ill-posed on cycles, Jeremy's harness read its clock
   before setting it, Mike's breaker read the wrong journal event, and
   Kane's challenger lost a case to a missing stem. Every one was
   caught by the example's own output before a user saw it.
4. **Fairness needs unmet demand to be visible**: a FIFO door is fair
   to requests, not tenants — starvation only appears when a tenant's
   demand exceeds its receipts, which is why quiet outages stay quiet.
5. **Next asks**: relation-typed structured rules (`sum_lte:`,
   `requires:`, `mutually_exclusive:`) so generators can satisfy and
   advisors can diff the declarable majority of cross-field rules
   (Piotr); and a breaker-friendly convention for `retryable: nil` —
   "no opinion" should mean retry-with-suspicion, not hopeless (Mike).

## Round 10 — predicates become data

The round-9 asks shipped as a release (`Agentic::RelationRules` —
`sum_lte`/`requires`/`mutually_exclusive` declared as data, enforced
by the validator with derived messages, projected into real draft-07
keywords, and carried in `x-agentic-rules`; plus the retryable-nil
convention on `TaskFailure`: `hopeless?` / `possibly_transient?`),
the two asking examples were modernized, and ten more experiments
followed:

| # | Persona | Built on the round-10 release | Run it | Field notes |
|---|---------|-------------------------------|--------|-------------|
| 1 | Matz | Polite form — every declaration read aloud as a question | `examples/polite_form.rb` | [round-10/01-matz.md](round-10/01-matz.md) |
| 2 | DHH | One-file API — schema, 422s, and 201s derived from one declaration | `examples/one_file_api.rb` | [round-10/02-dhh.md](round-10/02-dhh.md) |
| 3 | Aaron Patterson | Contract overhead — validation priced against the call it guards | `examples/contract_overhead.rb` | [round-10/03-tenderlove.md](round-10/03-tenderlove.md) |
| 4 | Xavier Noria | Projection agreement — both renderings of the law, proved; the nil frontier mapped | `examples/projection_agreement.rb` | [round-10/04-fxn.md](round-10/04-fxn.md) |
| 5 | Samuel Williams | Cancel drill — task cancel is prompt; plan cancel bills you anyway | `examples/cancel_drill.rb` | [round-10/05-ioquatix.md](round-10/05-ioquatix.md) |
| 6 | Jeremy Evans | Relation prober — 13 probes pass; one step off the road draws blood | `examples/relation_prober.rb` | [round-10/06-jeremyevans.md](round-10/06-jeremyevans.md) |
| 7 | Piotr Solnica | Relation diff — the rules join semver; opacity becomes opt-in | `examples/relation_diff.rb` | [round-10/07-solnic.md](round-10/07-solnic.md) |
| 8 | Mike Perham | Retry budget — one fleet-wide wallet; 45 doomed calls become 17 | `examples/retry_budget.rb` | [round-10/08-mperham.md](round-10/08-mperham.md) |
| 9 | Sandi Metz | Rule shapes — one policy, three representations, four consumers | `examples/rule_shapes.rb` | [round-10/09-sandimetz.md](round-10/09-sandimetz.md) |
| 10 | Andrew Kane | Batch import — a reject file with line, field, and rule, at 162us/row | `examples/batch_import.rb` | [round-10/10-ankane.md](round-10/10-ankane.md) |

### What round 10 surfaced

1. **Predicates as data compounded immediately**: within one round,
   relation rules were asked as questions (polite form), served as
   draft-07 keywords (one-file API), satisfied by the generator,
   diffed for semver, audited for consumer count, and used to explain
   118 CSV rejections. Six consumers for a feature shipped that
   morning — the strongest version yet of "metadata keeps buying
   unplanned tools."
2. **Two real defects found by drills**: `cancel_plan` under a joined
   reactor is bookkeeping-only — every agent runs and bills while the
   status says canceled (Samuel); and a relation rule over an
   undeclared field escapes as raw TypeError instead of
   ValidationError, turning 422 paths into 500 paths (Jeremy, whose
   prober exits 1 by design as the acceptance test).
3. **Agreement-for-different-reasons is a named hazard**: typed
   fields guard the nil frontier so both renderings reject
   `{express: nil}` — for unrelated reasons; relax the type and the
   renderings diverge. Verdict-only tests would call that a pass
   (Xavier).
4. **The meter settled the validation debate**: the largest contract
   costs 0.14ms against the 800ms call it guards, and rejection
   costs 12x the happy path — both numbers now on the table (Aaron,
   Kane concurring at 162us/row with rejects included).
5. **Next asks**: make `cancel_plan` stop the scheduler and in-flight
   fibers (the cancel drill is the acceptance test); relation rules
   must type-check their fields at declaration time or wrap
   evaluation failures in ValidationError (the relation prober is
   the acceptance test); `RateLimit#try_acquire` for non-blocking
   admission so retry budgets can be RateLimits; and align or
   document presence semantics (Ruby nil vs JSON null) across the
   projection boundary. (`relation_prober.rb` joins the
   exit-1-by-design set.)

## Round 11 — a new cast takes the bench

The round-10 asks shipped as a release: `cancel_plan` is now prompt
(bookkeeping first, then fiber stops - never the reactor handle, never
the calling fiber), relation declarations fail fast at validator
construction (undeclared fields and sum_lte-over-strings refuse to
boot), `RateLimit#try_acquire` gives non-blocking admission, and
relations over untyped fields stay out of draft-07 keywords. The two
exit-1-by-design probers flipped to green acceptance tests, the retry
budget's wallet became a real windowed RateLimit — and then **ten new
prolific Rubyists** took over the experiments:

| # | Persona | Built with the gem | Run it | Field notes |
|---|---------|--------------------|--------|-------------|
| 1 | Koichi Sasada (ko1) | Allocation audit — exact object counts per operation, via GC.stat | `examples/allocation_audit.rb` | [round-11/01-ko1.md](round-11/01-ko1.md) |
| 2 | Charles Nutter (headius) | Threads drill — real parallelism vs everything shared; a load-order bug caught | `examples/threads_drill.rb` | [round-11/02-headius.md](round-11/02-headius.md) |
| 3 | Nate Berkopec | Capacity planner — Little's Law over journal percentiles | `examples/capacity_planner.rb` | [round-11/03-nateberkopec.md](round-11/03-nateberkopec.md) |
| 4 | Ryan Davis (zenspider) | Plan flog — a pain score per plan; idiom free, coupling priced | `examples/plan_flog.rb` | [round-11/04-zenspider.md](round-11/04-zenspider.md) |
| 5 | Avdi Grimm | Confident pipeline — ten timid conditionals vs one barricade | `examples/confident_pipeline.rb` | [round-11/05-avdi.md](round-11/05-avdi.md) |
| 6 | Katrina Owen | Plan kata — red/green/refactor with graph assertions written first | `examples/plan_kata.rb` | [round-11/06-kytrinyx.md](round-11/06-kytrinyx.md) |
| 7 | Bozhidar Batsov | Contract cop — seven named cops, mechanical autocorrect only | `examples/contract_cop.rb` | [round-11/07-bbatsov.md](round-11/07-bbatsov.md) |
| 8 | José Valim | Telemetry bus — :telemetry on the hooks; runtime attach/detach, crash isolation | `examples/telemetry_bus.rb` | [round-11/08-josevalim.md](round-11/08-josevalim.md) |
| 9 | Luca Guidi | Ports and adapters — the domain survives the migration, with a purity scan | `examples/ports_and_adapters.rb` | [round-11/09-jodosha.md](round-11/09-jodosha.md) |
| 10 | Eileen Uchitelle | Tenant shards — N journals, N limits, one ignorant control plane | `examples/tenant_shards.rb` | [round-11/10-eileencodes.md](round-11/10-eileencodes.md) |

### What round 11 surfaced

1. **Fresh eyes found a fresh class of bug immediately**: headius's
   bare-journal drill caught `Time#iso8601` used without requiring
   "time" — a load-order bug nine rounds of fiber-world examples never
   tripped, fixed in this round's release. New perspectives audit
   different assumptions.
2. **The runtime got audited from below**: exact allocation counts
   (37 objects per happy validation, 11x on rejection, zero GC runs
   per plan), real-thread verdicts (journal and registry hold on real
   locks; the windowed limiter coasts on the GVL), and Little's Law
   turning the journal into a capacity plan whose binding constraint
   was outside the meeting.
3. **The teaching seat is real**: the kata (assertions before tasks),
   the flog score (calibrated so idiom is free), the confident/timid
   contrast (nil-tolerance launders errors), and the cop (autocorrect
   only what has one right answer) are all *pedagogy tools* built on
   the same reflection surfaces the ops tools use.
4. **The architecture seat approves the seams**: the duck-typed
   `agent:` seam let a pure domain walk in without signing tenancy
   (ports-and-adapters with a purity scan), and ten lines bridged the
   hooks to a :telemetry-style bus with crash isolation - frameworks
   orchestrate, domains decide, handlers come and go.
5. **Next asks**: a Mutex around the windowed limiter's stamp
   bookkeeping so the answer is the same on every Ruby (headius);
   `remove_task`/rewire so refactoring a plan doesn't mean demolition
   (Katrina, with the kata as acceptance test); and a multiprocess
   journal drill to certify the flock claim (headius, follow-up).

## Round 12 — a third cast, and the bill arrives itemized

The round-11 asks shipped as a release: the windowed limiter's stamp
bookkeeping holds a real Mutex (the threads drill now certifies
instead of observes), `remove_task`/`rewire_task` make plan
refactoring surgical (the kata refactors in place), and the process
drill certifies the flock claim across four forked writers. Then a
third cast of ten prolific Rubyists took the bench:

| # | Persona | Built with the gem | Run it | Field notes |
|---|---------|--------------------|--------|-------------|
| 1 | Yehuda Katz (wycats) | API surface census — 112 methods, 58 earning rent, 54 on loan | `examples/api_surface.rb` | [round-12/01-wycats.md](round-12/01-wycats.md) |
| 2 | Sarah Mei | Onboarding trail — a house tour computed from who-mentions-whom | `examples/onboarding_trail.rb` | [round-12/02-sarahmei.md](round-12/02-sarahmei.md) |
| 3 | Richard Schneeman | Require cost report — the bill lands at first touch, not at require | `examples/require_cost.rb` | [round-12/03-schneems.md](round-12/03-schneems.md) |
| 4 | Vladimir Dementyev | EventProf for plans — task-seconds by tag; llm owns 78% | `examples/event_prof.rb` | [round-12/04-palkan.md](round-12/04-palkan.md) |
| 5 | Mike Dalessio | Hostile inputs — a torn tail denies ALL recovery; exit 1 until | `examples/hostile_inputs.rb` | [round-12/05-flavorjones.md](round-12/05-flavorjones.md) |
| 6 | Justin Searls | Honest doubles — fakes show their papers at load time | `examples/honest_doubles.rb` | [round-12/06-searls.md](round-12/06-searls.md) |
| 7 | Konstantin Haase | Plan DSL — thirty lines of Sinatra over the public API | `examples/plan_dsl.rb` | [round-12/07-rkh.md](round-12/07-rkh.md) |
| 8 | Obie Fernandez | Self-correcting output — violations become the correction prompt | `examples/self_correcting_output.rb` | [round-12/08-obie.md](round-12/08-obie.md) |
| 9 | Rafael França | Gentle deprecations — warn once per site, tally, strict on schedule | `examples/gentle_deprecations.rb` | [round-12/09-rafaelfranca.md](round-12/09-rafaelfranca.md) |
| 10 | Jean Boussier (byroot) | Write path profile — JSON acquitted at 0.4%; the fsync IS the product | `examples/write_path_profile.rb` | [round-12/10-byroot.md](round-12/10-byroot.md) |

### What round 12 surfaced

1. **The stewardship seat spoke**: the census split 112 public
   methods into earned API and accidental API; the deprecation shim
   choreographed a rename across three releases; the DSL proved sugar
   can stay entirely outside the engine. Three different answers to
   "how does this gem grow old gracefully."
2. **One real defect, found where parsers meet reality**: a torn
   journal tail — the exact artifact of the crash the journal exists
   for — crashes replay in the wrong error class and denies all
   recovery (`hostile_inputs.rb` exits 1 as the acceptance test).
3. **Costs arrived itemized**: require costs land at first constant
   touch, not at require (Zeitwerk's deferral, priced); the journal
   write is 99.6% fsync and 0.4% JSON, with group commit named as a
   different promise rather than a faster one; plan time profiles by
   tag with the barriers indicted, not the budget.
4. **The AI-application seat matured**: the self-correcting output
   loop showed the contract doubling as a correction-prompt
   generator, and honest doubles put load-time verification at the
   LLM boundary — patterns, not vibes.
5. **Next asks**: tolerant journal replay — salvage whole lines,
   report (don't raise on) a torn or mis-encoded tail
   (`hostile_inputs.rb` is the acceptance test); an optional
   `fsync_every: n` group-commit mode with its durability trade
   named in the constructor (byroot); and consider a strict-shapes
   replay mode for audit tools vs the tolerant recovery default
   (flavorjones).

## Round 13 — a fourth cast, and the docs go on trial

The round-12 asks shipped as a release: journal replay is
tolerant-by-default (whole lines salvaged, damage reported with line
and reason on `state.damage`), a strict mode raises
`JournalDamagedError` for audit tools, and `fsync_every:` makes group
commit an explicit constructor choice with its durability trade
named. The hostile-inputs probe flipped green; the write-path profile
benches the real knob. Then a fourth cast of ten took the bench:

| # | Persona | Built with the gem | Run it | Field notes |
|---|---------|--------------------|--------|-------------|
| 1 | Piotr Murach | TTY status board — badge, gauge, tree, frame, composed | `examples/tty_status.rb` | [round-13/01-piotrmurach.md](round-13/01-piotrmurach.md) |
| 2 | John Nunemaker | Feature flags — the experimental step is a plan shape, not an if | `examples/feature_flags.rb` | [round-13/02-jnunemaker.md](round-13/02-jnunemaker.md) |
| 3 | Akira Matsuda | Journal tail pager — page 1 costs 16KB of a 2.5MB file | `examples/journal_tail.rb` | [round-13/03-amatsuda.md](round-13/03-amatsuda.md) |
| 4 | David Bryant Copeland | CLI contract — four channels, EX_USAGE distinct from failure | `examples/cli_contract.rb` | [round-13/04-davetron5000.md](round-13/04-davetron5000.md) |
| 5 | Hiroshi Shibata | Stdlib census — logger and cgi caught before the 3.5 wave | `examples/stdlib_census.rb` | [round-13/05-hsbt.md](round-13/05-hsbt.md) |
| 6 | Noel Rappin | Money discipline — integer cents as a tripwire type | `examples/money_discipline.rb` | [round-13/06-noelrap.md](round-13/06-noelrap.md) |
| 7 | Tom Stuart | Plans as automata — completion proved total by exhaustion | `examples/plans_as_automata.rb` | [round-13/07-tomstuart.md](round-13/07-tomstuart.md) |
| 8 | Chris Oliver | Job adapter — retry_on/discard_on in forty lines | `examples/job_adapter.rb` | [round-13/08-excid3.md](round-13/08-excid3.md) |
| 9 | Kasper Timm Hansen | API riffs — three shapes for fsync_every, judged at the call site | `examples/api_riffs.rb` | [round-13/09-kaspth.md](round-13/09-kaspth.md) |
| 10 | Steve Klabnik | Doctest runner — 11 of 30 documented examples are alive | `examples/doctest_runner.rb` | [round-13/10-steveklabnik.md](round-13/10-steveklabnik.md) |

### What round 13 surfaced

1. **Two more live hazards fixed in-round**: the stdlib census caught
   `logger` (bundled-gem promotion in Ruby 3.5) and `cgi` (trimmed in
   3.5) required-but-undeclared — both now in the gemspec with
   reasons. Same law as round 11's "time" bug: a transitive require
   is a loan, and rubies refinance.
2. **The docs went on trial and lost**: the doctest runner executed
   all 30 documented examples (YARD @example blocks + README fences)
   in sandboxes — 11 run, 19 are dead from missing setup or API
   drift. Dead docs cluster around dead-ish code corners.
3. **The release's own features were immediately load-bearing**:
   `rewire_task` spliced flag-gated steps (Nunemaker), `fsync_every`
   made the pager's 20k-event fixture affordable and got its API
   shape riffed and vindicated (kaspth), and `hopeless?` backstopped
   `discard_on` in the job adapter.
4. **The theory seat earned its keep**: enumerating the diamond's
   six-state space proves completion totally rather than sampling
   it, and exhibits the cycle as an empty machine — giving precise
   content to two earlier rounds' cycle intuitions. Know which
   regime you're in: enumeration for small machines, invariant
   provers past forty tasks.
5. **Next asks**: runnable-or-annotated docs — every README fence
   and @example either executes in CI via the doctest runner or
   carries a deliberate "illustrative" marker (Klabnik); and revive
   or retire the learning-system corner whose examples all died with
   LoadErrors (the census-adjacent smell).

## Round 14 — the docs go green, and a fifth cast arrives

The round-13 asks shipped as a release: the doctest runner is now a
referee (every doc example runs or carries a deliberate
"illustrative" annotation — 26 run, 4 annotated, 0 dead), the drifted
README fences were fixed against current APIs, and the learning
corner was **revived**, not retired: three more missing stdlib
requires, a double-counting history store (memory cache + files now
deduped by id), and the never-functional `register_with_orchestrator`
replaced by `Learning.lifecycle_hooks` — the same construction-time
seam the journal uses. Then a fifth cast took the bench:

| # | Persona | Built with the gem | Run it | Field notes |
|---|---------|--------------------|--------|-------------|
| 1 | Evan Phoenix | Plan server — thread pool, shared quota, a drain with dignity | `examples/plan_server.rb` | [round-14/01-evanphx.md](round-14/01-evanphx.md) |
| 2 | André Arko | Capability resolver — the dependencies: field, finally resolved | `examples/capability_resolver.rb` | [round-14/02-indirect.md](round-14/02-indirect.md) |
| 3 | Soutaro Matsumoto | RBS export — shape from contracts; the validator keeps the law | `examples/rbs_export.rb` | [round-14/03-soutaro.md](round-14/03-soutaro.md) |
| 4 | Benoit Daloze | Behavior spec — six boundary choices, pinned in a 30-line mspec | `examples/behavior_spec.rb` | [round-14/04-eregon.md](round-14/04-eregon.md) |
| 5 | Yuki Nishijima | Did you mean — three error seams finish your sentence | `examples/did_you_mean.rb` | [round-14/05-yuki24.md](round-14/05-yuki24.md) |
| 6 | Sam Saffron | Always-on profiler — a badge per plan, budgets that assign work | `examples/always_on_profiler.rb` | [round-14/06-samsaffron.md](round-14/06-samsaffron.md) |
| 7 | Ryan Tomayko | Unix workers — fork, pipe, kill, wait; 9/9 served, 3/3/3 | `examples/unix_workers.rb` | [round-14/07-rtomayko.md](round-14/07-rtomayko.md) |
| 8 | Marc-André Lafortune | Ractor audit — send facts, keep machines | `examples/ractor_shareability.rb` | [round-14/08-marcandre.md](round-14/08-marcandre.md) |
| 9 | Rosa Gutiérrez | Concurrency key — one per tenant, tenants in parallel, judged | `examples/concurrency_key.rb` | [round-14/09-rosa.md](round-14/09-rosa.md) |
| 10 | Janko Marohnić | Attachment pipeline — cache instantly, promote via journaled plan | `examples/attachment_pipeline.rb` | [round-14/10-janko.md](round-14/10-janko.md) |

### What round 14 surfaced

1. **The learning corner's autopsy generalized round 11's lesson**:
   three more files used stdlib without requiring it, a store
   double-counted its own records, and a public API called a method
   that never existed — dead docs had been pointing at dead-ish code
   all along, and reviving the docs revived the code.
2. **The dormant metadata kept paying**: the `dependencies:` field
   (unused since round 1) became a Bundler-style resolver;
   contracts became RBS signatures with the shape/law boundary drawn
   on principle; `try_acquire` became cron-guard semantics
   (`skip_if_running`); the journal became an upload promotion log.
3. **Process-grade patterns joined the catalog**: a real socket
   server with a measured graceful drain, preforked workers reaped
   by pid, per-tenant serialization with judged interleavings, and a
   Ractor audit whose one refusal (the mutex-holding limiter) is
   load-bearing: send facts, keep machines.
4. **Seventh consecutive round of tools correcting authors**: the
   burst-fed pipe wasn't fair (9/0/0 until arrivals were paced), the
   Ractor auditor froze its own evidence, and the Unix example
   committed the exact missing-require sin the census preaches
   against. The streak is the methodology.
5. **Next asks**: thread did-you-mean suggestions into
   ValidationError and the rewire/remove errors (the candidate lists
   are already in scope at every raise site — yuki24); and pin
   fiber-vs-thread safety guarantees per public method as behavior
   specs, not just drills (eregon).

## Round 15 — the closing release

The final round delivers the round-14 asks and closes the loop with
no new asks outstanding:

- **Did-you-mean became infrastructure** (`Agentic::Suggestions`): a
  conservative Levenshtein engine threaded into the framework's own
  errors. `ValidationError` now diagnoses renamed keys from
  missing-plus-similar-extra ("You sent :weight_kilo - did you mean
  :weight_kg?", in the message and as structured `hints`), and the
  rewire/remove errors suggest close task names. The engine stays
  silent past a length-scaled threshold - a wrong suggestion is worse
  than none. `did_you_mean.rb` flipped from retrofit to native
  demonstration.
- **The concurrency contract is pinned, not just drilled**:
  `spec/agentic/concurrency_contract_spec.rb` promises per-method
  guarantees (journal writes thread-safe and cross-process safe,
  windowed limiter thread-safe, concurrency-mode limiter
  fiber-scoped, registry thread-safe), and the methods themselves
  carry `@note Concurrency contract:` documentation.

Suite at 610 examples, 0 failures; 131 runnable example programs;
every doc example runs or says why it doesn't.

## The series, closed out

Fifteen rounds. Fifty personas across five casts. Thirteen releases,
each built from the previous round's in-character field notes. What
the experiment demonstrated:

1. **The loop worked.** Personas building *with* the gem generated
   asks; shipping the asks made the next builds possible; the new
   builds found the next seams. Features that emerged this way -
   the graph API, the journal's percentiles and tolerant replay,
   relation rules, resize/try_acquire, remove/rewire, suggestions -
   all arrived pre-validated by a consumer that already existed.
2. **Examples are a defect detector.** The builds surfaced real bugs
   the suite never touched: a truncated test run, a scheduler
   deadlock, canceled plans that billed anyway, relation rules
   crashing in the wrong error class, a torn journal tail denying
   all recovery, six files using stdlib without requiring it, a
   history store double-counting itself, and a public API calling a
   method that never existed. Every one was found by *using* the
   thing, and fixed with the finding example as the acceptance test.
3. **Declarations compound.** The single biggest return came from
   making things data: contract declarations bought validation,
   docs, schemas, fixtures, semver, RBS, 422s, polite forms, and a
   resolver; relation rules bought enforcement, generation,
   projection, and diffing; the graph bought drawing, testing,
   merging, linting, and flogging. Code keeps secrets; data makes
   friends - the series' most-repeated lesson because it kept being
   re-earned.
4. **Tools correct their authors.** Eight consecutive rounds ended
   with an example's own output overruling the prose its author had
   drafted. Measurement-over-narrative wasn't a value we asserted;
   it was a pattern the artifacts enforced.
5. **The referee pattern scales.** Exit-code-gated honesty tools
   (probers, provers, drills, the doctest runner) turned findings
   into acceptance tests: each round's sharpest complaint became the
   next round's green check, and stays in the repo re-running.

The catalog stands at 131 offline example programs, ten field-note
directories, and a framework whose contracts, journals, limiters,
and plans all testify about themselves. The bench is cleared; the
asks list is empty; everything the room asked for was shipped.

## Round 16 — the lottery round

The close-out lasted one message. With no asks outstanding, the
bench was drawn by lottery — ten names sampled at random from all
fifty prior personas — so returning builders faced the framework a
second time with different obsessions:

| # | Persona | Built with the gem | Run it | Field notes |
|---|---------|--------------------|--------|-------------|
| 1 | Yukihiro Matsumoto | Gentle deadline — optional tasks decline with regrets, essentials never starve | `examples/gentle_deadline.rb` | [round-16/01-matz.md](round-16/01-matz.md) |
| 2 | Piotr Solnica | Railway plan — a 14-line Result monad lifts plan outcomes into `.bind` chains | `examples/railway_plan.rb` | [round-16/02-solnic.md](round-16/02-solnic.md) |
| 3 | Benoit Daloze | Schedule equivalence — same plan at concurrency 1/2/8 must agree; a smuggler proves the prover | `examples/schedule_equivalence.rb` | [round-16/03-eregon.md](round-16/03-eregon.md) |
| 4 | Bozhidar Batsov | Configurable cops — a YAML layer over plan lints, with a pending-cop policy | `examples/configurable_cops.rb` | [round-16/04-bbatsov.md](round-16/04-bbatsov.md) |
| 5 | Noel Rappin | Spend ledger — integer cents, `afford!` before work, an invoice with a running balance | `examples/spend_ledger.rb` | [round-16/05-noelrap.md](round-16/05-noelrap.md) |
| 6 | Eileen Uchitelle | Shadow traffic — v2 answers every request, serves none; mismatches journaled | `examples/shadow_traffic.rb` | [round-16/06-eileencodes.md](round-16/06-eileencodes.md) |
| 7 | Justin Searls | Discovery testing — fakes discover interfaces, then reality replaces them shape-checked | `examples/discovery_testing.rb` | [round-16/07-searls.md](round-16/07-searls.md) |
| 8 | Vladimir Dementyev | Progress channel — every subscriber names its backpressure policy; publish never blocks | `examples/progress_channel.rb` | [round-16/08-palkan.md](round-16/08-palkan.md) |
| 9 | John Nunemaker | Kill switch — per-capability, use-time, non-retryable by decree, flips audited | `examples/kill_switch.rb` | [round-16/09-jnunemaker.md](round-16/09-jnunemaker.md) |
| 10 | Hiroshi Shibata | Release rehearsal — build, audit, clean-install, and boot THE PACKAGE, not the repo | `examples/release_rehearsal.rb` | [round-16/10-hsbt.md](round-16/10-hsbt.md) |

### What round 16 surfaced

1. **Second appearances built different organs.** Every returning
   persona attacked a seam their first visit never touched: Matz went
   from three-lines-that-smile to time-budget courtesy, solnic from
   contract boundaries to railway composition, eregon from behavior
   specs to schedule-equivalence proofs, Nunemaker from feature flags
   ("who gets this?") to kill switches ("how fast can it stop?").
   The framework held; the angles were new.
2. **Ninth consecutive round of tools correcting authors.** The
   equivalence prover's smuggler never diverged because the shared
   ledger was created once *outside* the per-run builder — the race
   detector had its own race removed; and the release rehearsal's
   first boot probe praised a package it never loaded, because under
   `bundle exec` RUBYOPT smuggles `bundler/setup` into every child
   and puts the repo back on the load path. Both catches came from
   tripwires the examples had written for themselves. The smoke run
   then added a third: the stacked-PR merge subjects carry em dashes,
   and in a locale-less container two older git-reading examples
   (changelog scout, standup digest) choked on US-ASCII-tagged
   backtick output — fixed with an explicit UTF-8 force.
3. **The operational trilogy completed itself**: budgets that veto
   before work (spend ledger), switches that stop mid-incident
   (kill switch), and channels that shed or disconnect by declared
   policy (progress channel) — all built on the same two seams,
   the duck-typed `agent:` wrapper and the lifecycle hooks. Sixteen
   rounds in, cross-cutting concerns still cost exactly one lambda.
4. **Soft asks, gently held** (no release planned; recorded for
   whoever reopens the shop): an `optional:` task marking the
   scheduler understands, so deadline courtesy is a property instead
   of a convention (Matz); a scheduling-veto hook so budget/spend
   gates run before a task is dispatched rather than inside its agent
   (Noel); and a deterministic seeded-schedule mode so equivalence
   provers can enumerate interleavings instead of sampling them
   (eregon).

## Round 17 — the builders' round

A second lottery (round-16's bench excluded), with a sharpened
brief: don't probe the framework — **build on it**. Each persona
shipped a product-shaped thing: a tool, a workflow, an experience
that solves a problem the framework doesn't solve by itself:

| # | Persona | Built on the gem | Run it | Field notes |
|---|---------|------------------|--------|-------------|
| 1 | Ryan Davis | Plan heckler — mutation testing for workflows; specs graded on whether they can FAIL | `examples/plan_heckler.rb` | [round-17/01-zenspider.md](round-17/01-zenspider.md) |
| 2 | DHH | Omakase scaffold — rails-new for plans; six lines of recipe, a running program back | `examples/omakase_scaffold.rb` | [round-17/02-dhh.md](round-17/02-dhh.md) |
| 3 | Mike Dalessio | Document refinery — hostile-HTML ETL: decode, sanitize, extract, resolve, referee | `examples/document_refinery.rb` | [round-17/03-flavorjones.md](round-17/03-flavorjones.md) |
| 4 | Richard Schneeman | Assembly doctor — syntax_suggest for plans: carets, did-you-mean, the loop shown whole | `examples/assembly_doctor.rb` | [round-17/04-schneems.md](round-17/04-schneems.md) |
| 5 | Nate Berkopec | Queue-time autoscaler — Little's law closes the loop on a live resized pool | `examples/queue_time_autoscaler.rb` | [round-17/05-nateberkopec.md](round-17/05-nateberkopec.md) |
| 6 | Xavier Noria | Capability autoloader — Zeitwerk's contract for capability packs: lazy, eager-verified, reloadable | `examples/capability_autoloader.rb` | [round-17/06-fxn.md](round-17/06-fxn.md) |
| 7 | José Valim | Supervision tree — one_for_one / rest_for_one / one_for_all with bounded restart intensity | `examples/supervision_tree.rb` | [round-17/07-josevalim.md](round-17/07-josevalim.md) |
| 8 | Obie Fernandez | Escalation ladder — confidence tiers as policy data; sensitivity trumps confidence; dossiers on handoff | `examples/support_escalation.rb` | [round-17/08-obie.md](round-17/08-obie.md) |
| 9 | André Arko | Plan lockfile — constraints resolve once; frozen runs verify digests and refuse drift | `examples/plan_lockfile.rb` | [round-17/09-indirect.md](round-17/09-indirect.md) |
| 10 | Sandi Metz | Shameless green — golden-master refactoring of a god task, one responsibility per certified step | `examples/shameless_green.rb` | [round-17/10-sandimetz.md](round-17/10-sandimetz.md) |

### What round 17 surfaced

1. **The framework held up as a platform, not just a subject.** Ten
   products — a mutation tester, a generator, an ETL refinery, a
   diagnostic UI, an autoscaler, a code loader, a supervisor, a
   triage ladder, a lockfile, a refactoring engine — and none needed
   the gem's cooperation beyond its public seams: plans-as-data made
   mutants one-symbol sabotages and refactoring shapes cheap
   auditions; the resizable limiter made the autoscaler a 30-line
   loop; the registry's version tracking gave the autoloader its
   reload semantics; `Suggestions` gave the doctor its did-you-mean.
2. **The tools-correct-authors streak reached ten rounds, in
   volume.** The heckler's fixture never crossed the discount bar
   (a surviving mutant can mean an input hole, not a missing
   assertion); the scaffold's first generated program didn't boot —
   `Dir.tmpdir` without the require, the census sin, now committed
   by a *generator*; the refinery's first draft ran encoding repair
   last and the plan itself refused (you can't regex invalid UTF-8);
   and the autoloader fought both classic reloader wars in one file
   (stale registrations, cached references) and won them with the
   registry's own version resolution.
3. **Recovery/routing policy kept wanting to be data one level up**:
   the supervisor's strategies are blast-radius declarations; the
   ladder's thresholds live in a POLICY hash with sensitivity
   structurally outranking confidence; the lockfile splits "what
   you accept" from "what you run" with a human diff between them.
   Same shape three times — policy as data, above the workers,
   below the humans.
4. **Soft asks, gently held**: a registry miss-hook (const_missing
   for capabilities) so loaders can be invisible, and per-execute
   provider resolution in agents so reloads don't fight add-time
   snapshots (fxn); assembly-time rendering of the doctor's
   snippet-and-caret diagnosis inside the framework's own errors
   (schneems); auto-generated edge mutants from `graph[:edges]`
   (zenspider); and `restart:` markings per child plus nestable
   supervisors (josevalim).

### What round 6 surfaced

1. **Plans became artifacts**: narratable (tour), serializable with an
   isomorphism proof (round-trip), priceable before execution (cost
   gate), and diffable across runs (perf diff). The graph accessor's
   second round turned topology into a first-class document.
2. **Declarations became testable claims**: rule `fields:` shipped as
   UI plumbing and immediately became an auditable specification — the
   prober caught a seeded lying rule that would have misdirected form
   highlighting.
3. **One contract, five behaviors**: validate, reject, explain,
   document, audit — the same declaration now feeds all five.
4. **Honest prose corrections**: two personas (DHH, Sandi) had their
   example copy corrected by their own measurements — the tools are
   now good enough to disagree with their authors.
5. **Next asks**: composing a windowed and a concurrency limiter as
   one object, journal-fed baselines for the perf diff, OpenAPI
   emission from contracts, custom RNG injection for retry policies,
   and a `graph`-level depth/fan-in stats helper (Sandi's third
   strike).

### What round 5 surfaced

1. **The graph accessor compounded immediately**: one round old, it fed
   a game map, a critical-path analyzer, a Mermaid generator, and a
   design curriculum. Expose the right projection and an ecosystem
   assembles itself.
2. **Named dependencies turned out to be documentation**: `needs:`
   labels became labeled diagram edges — ergonomics maturing into
   architecture records.
3. **Every round-4 feature was characterized under load the round it
   shipped** — the burst absorber (RateLimit), the stampede histogram
   (jitter), the freight desk (rules), the 422 generator
   (expectations).
4. **Next asks**: `graph[:order]` (topological sort — requested
   independently by three personas) plus `graph[:edges]` with labels,
   structured rule identifiers (`{rule: :symbol, fields: [...]}`) so
   policy violations can point at widgets, a `backoff_jitter: :full`
   tier, and time-windowed rate limits alongside the concurrency
   ceiling.

### What round 4 surfaced

1. **Two more real defects found by examples**: canceled plans reported
   `:completed` (`overall_status` never consulted the canceled state —
   fixed, regression-tested), and the README's composition snippet had
   been syntactically invalid since round 1's review first side-eyed it
   (fixed; the verifier now guards it).
2. **Every round-3 ask got exercised the round it shipped** — named
   deps (corpse, doctor), slot hook (knee finder), `retryable?`
   (taxonomy drill), predicates (state machine). Tight feedback loops
   keep features honest.
3. **The survey/atlas shape is the framework's signature** — parallel
   facts, one fan-in verdict — now in six examples. It deserves a
   documented name.
4. **Next asks**: a read-only `Orchestrator#graph` accessor (three
   tools have crowbarred `@dependencies`), violation payloads carrying
   the predicate's expectation (legal enum values), a credential-scoped
   `RateLimit` class (`LlmClient` accepting `limiter:`), jitter-on by
   default, and cross-field contract rules.

### What round 3 surfaced

1. **The adapter tax is gone.** Zero provider structs, zero
   string-keyed lookups across all ten builds; several programs are
   shorter than their round-2 counterparts while doing more.
2. **A real scheduler deadlock** — fan-in dependencies at a tight
   concurrency limit deadlocked slot-holders spawning dependents. Found
   by the Gantt chart, fixed (spawn through the barrier, acquire inside
   the fiber), regression-tested.
3. **Piping enabled new shapes**: fan-in aggregation (digest, doc
   coverage, changelog), observable hand-offs (collaboration tracer),
   and retry-transparent downstream reads (flaky drill).
4. **Next asks, in priority order**: named dependencies
   (`needs: {facts: task}`), a `previous_output` convenience for
   single-dependency chains, a `task_slot_acquired` hook to split queue
   time from run time, `failure.retryable?` consulted by retry
   policies, and richer contract predicates (ranges/enums).

### What round 2 taught (the consumer's consensus)

Building *with* the gem surfaced different findings than reviewing it:

1. **Tasks need a payload, and the orchestrator should accept agents or
   callables directly.** Six personas independently wrote the same two
   workarounds: smuggling domain objects through `task.description` and
   wrapping an agent they already had in a `get_agent_for_task` provider
   struct. That's the API's users voting.
2. **Dependent tasks can't see each other's outputs** (Matz hit it first
   and hardest): the orchestrator schedules around dependencies but
   doesn't pipe results into dependents, forcing shared mutable state.
3. **The concurrency story is real and needs one honest paragraph**:
   near-ideal scaling for IO-bound tasks (Samuel measured within 10ms of
   theoretical), nothing for CPU-bound work (Aaron measured that too).
4. **Capabilities-as-lambdas is the gem's best idea.** Every build used
   them; contracts (round 1's validator) caught real mistakes during
   development in three of the ten builds.
5. **Start with capabilities, add the orchestrator when there's a
   queue.** The builds that didn't fan out (typed pipeline, gem scout)
   were better off without it.

---

## 1. Yukihiro "Matz" Matsumoto — optimizing for happiness

**What I'd build:** Nothing big — open `bin/console` and play. Can I make an
agent in three lines that makes me smile?

**What interests me:** The block-based builder (`Agent.build do |a|`) and the
`StructuredOutputs::Schema` DSL are genuinely Rubyish. An AI orchestration gem
that reads like Ruby instead of like a Python port makes me happy.

**What's confusing:** `Task#perform(agent)` vs `Agent#execute(task)` — the
same act expressed from two directions, and `Agent#execute` even calls
`task.perform(self)` back. Which object owns the verb?

**Worked well:** The plain-English goal → plan flow. **Didn't:**
`raise "Capability not found: #{name}"` — bare `RuntimeError` strings when
`Agentic::Error` already exists. Errors deserve names too.

## 2. DHH — conceptual compression, majestic monolith

**What I'd build:** The 80% version: `Agentic.run("Summarize this week's
support tickets")`. One line, batteries included.

**What's confusing:** The gap between documentation and code. The architecture
documents promise a `MetaLearningSystem`, `StreamingObservabilityHub`,
`InterventionPortal` — layers documented before they exist. Four architectural
layers for a gem with one real user path.

**Worked well:** `PlanOrchestrator`'s lifecycle hooks — a real, earned
abstraction. **Didn't:** Everything you must understand before your first
agent runs. Compress it. Delete half the nouns.

## 3. Aaron Patterson (tenderlove) — performance and runtime internals

**What I'd build:** First, a benchmark: `require "agentic"` was eagerly
loading Thor and six tty-* gems into every library consumer. Your web app was
booting a progress-bar library.

**What interests me:** `PlanOrchestrator` on `Async` with a semaphore and
barrier — I want to throw 500 tasks at it and watch allocations.

**Didn't work:** `initialize_agent_assembly` memoized global state with no
mutex — two threads race, both build a `PersistentAgentStore`. I've fixed this
bug in Rails at least nine times. Hi!

## 4. Xavier Noria — Zeitwerk author

**What's confusing:** `lib/agentic.rb` called `loader.setup` and then
immediately issued nine `require_relative` calls for constants Zeitwerk
already manages, plus more scattered inside files. Two loading mechanisms with
different semantics. Either trust the loader or don't use one.

**Worked well:** File/constant naming is perfectly conventional — the loader
maps cleanly (once `ui` joined `cli` in the inflector).

## 5. Samuel Williams (ioquatix) — async maintainer

**What I'd build:** A streaming agent server on Falcon. The gem chose
`async ~> 2.0`, so it's already in my house.

**What interests me:** `execute_plan` uses `Async::Barrier` with a `Semaphore`
parented to it — the documented-correct composition. Someone read the manual.

**What's confusing:** The orchestrator created its own root `Async` block.
Called inside an existing reactor (say, under Falcon), you get a nested event
loop rather than joining the parent.

## 6. Jeremy Evans — minimal dependencies, ruthless correctness

**What's alarming:** `Configuration#initialize` defaulted `access_token` to
the string `"ollama"`. A silent fake credential means misconfiguration fails
at request time with a confusing 401 instead of loudly at boot. Fail fast.

**What's confusing:** Twelve runtime dependencies for a library, six of them
tty-* UI gems, plus `ostruct`. Those belong in a separate `agentic-cli` gem.

## 7. Piotr Solnica — dry-rb, types and boundaries

**What interests me:** The instinct is *so close* to ours:
`AgentSpecification`, `TaskDefinition`, `ExpectedAnswerFormat` are value
objects with `to_h`/`from_hash` — `Dry::Struct` written by hand.

**Didn't work:** Types declared but not enforced. `CapabilitySpecification`
defines `inputs:` with types and `required:` flags, and then nothing ever
validates inputs against them. Ceremony without safety — the worst of both
worlds.

## 8. Mike Perham — Sidekiq, boring reliability

**What's confusing:** Everything lives in process memory. `kill -9` the
process mid-plan and the plan never happened — except OpenAI billed you for
it. Persistence was bolted onto *agents* but not onto *executions*, which is
where the money is.

**Worked well:** `continue_on_failure` semantics and explicit state
transitions — a real state machine, easy to persist. Make it boring. Boring
survives restarts.

## 9. Sandi Metz — POODR, cheap change

**What interests me:** Injection is everywhere; `TaskResult`/`TaskFailure`
model failure as data instead of control flow. These choices make change cheap.

**Didn't work:** `execute_with_schema` checked `has_capability?("text_generation")`
and then *silently ignored the schema you passed it* — a method that doesn't
do what its name promises will hurt someone at 2 a.m. And `FactoryMethods`
set its DSL state only on the including class — subclass `Agent` and the DSL
quietly breaks. Inheritance debt, pre-borrowed.

## 10. Andrew Kane (ankane) — shipper of practical ML gems

**What I'd build:** The missing capabilities as tiny plug-ins. The README
advertises `--capabilities=text_generation,web_search`, but the shipped
`web_search` implementation returned hardcoded fake results.

**What interests me:** `CapabilityProvider` taking a bare lambda is the whole
plugin API, and it's low-ceremony enough that people will actually write
plugins. The `api_base_url` escape hatch means local-first works today.

---

## What the room agrees on

Ten different sensibilities converge on five points, which makes them the
highest-value fixes:

1. **Split the CLI from the library** (Jeremy, Aaron, Piotr) — thor + tty-*
   shouldn't load into library consumers. *Addressed for load-time by the
   Zeitwerk cleanup; a gem split remains future work.*
2. **Resolve the dual loading scheme** (Xavier, Aaron) — Zeitwerk *or*
   `require_relative`, not both. *Done.*
3. **A real error hierarchy and no silent fallbacks** (Matz, Sandi, Jeremy) —
   string `raise`s, the `"ollama"` token default, and `execute_with_schema`
   ignoring its schema are all the same bug: failure hidden until later.
   *Addressed in the Jeremy and Sandi builds.*
4. **Durability and thread-safety for the thing that costs money** (Mike,
   Jeremy, Samuel) — execution state was in-memory only, globals
   unsynchronized. *Addressed by `ExecutionJournal`, the assembly mutex, and
   reactor composability.*
5. **The docs promise more than the code delivers** (DHH, Andrew) — either
   build the missing layers or trim the architecture documents. *Partially
   addressed: the fake `web_search` now has a real, pluggable backend.*

The consensus compliment: the plan-and-execute core with result objects,
lifecycle hooks, and Async-based orchestration is genuinely good Ruby — the
bones deserved the cleanup they got here.
