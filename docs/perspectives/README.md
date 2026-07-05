# Ten Rubyist Perspectives on Agentic

An exercise in multi-perspective review: we embraced the personas of ten of the
most prolific Rubyists, asked how each would use this gem, what they would
build with it, what would delight or confuse them — and then **built the thing
each persona proposed**, taking field notes in character along the way.

> These are imagined characterizations of public figures, grounded in their
> well-known public work and stated philosophies. They are not the actual
> opinions of the people named.

## The reviews, the builds, the field notes

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
