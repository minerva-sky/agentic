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
