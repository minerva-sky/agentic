# Round 2 field notes — Aaron Patterson builds the Performance Detective

*Built: `examples/performance_detective.rb` — one orchestrator task per
Ruby file in `lib/`, each dissecting the file with Prism. The gem
investigates itself. The report names names.*

## What I built and why

63 files, one task each, fanned through the `PlanOrchestrator`; a
`dissect_file` capability parses each file with **Prism** (Ruby's own
parser, stdlib since 3.3) and measures every `def`. The output is a case
file: the seven longest methods in the gem and the densest files.

The usual suspects, for the record: `generate_optimized_sequence` at 110
lines, `schedule_task` at 90, `adjust_plan_via_llm` at 87. Sandi, your
victims are pre-selected; you're welcome.

## The confession

My first draft hand-rolled the method finder with regexes and an
`end`-counting stack. It reported a 353-line `store` method — because a
line reading `end,` (block as hash value) isn't `end`, so my stack never
popped and everything after got charged to `store`. Also three files blew
up with `invalid byte sequence in US-ASCII` because someone put a 🤖 in
`execution_observer.rb` and my `File.foreach` trusted `LANG`. Both bugs
vanished the moment I used the actual grammar: `Prism.parse_file` gives
you `DefNode#location.start_line/end_line` and handles encoding like a
parser should. The lesson never changes: **stop parsing Ruby with
regexes. We shipped you a parser. It's right there.**

## The measurement that matters

Concurrency 16: 96ms. Concurrency 1: 118ms. Nearly nothing — and that's
the honest, load-bearing observation for this framework: the orchestrator
runs tasks as **fibers under async**, which is cooperative concurrency
for *IO*. Parsing is CPU-bound, fibers don't parallelize CPU, so sixteen
lanes of traffic still share one engine. When your tasks are LLM calls
(network IO), this same fan-out is a massive win; when they're compute,
it's a progress bar. Frameworks should say this out loud in their docs —
users will assume `concurrency_limit: 16` means 16× everything.

## Friction while building

Same two walls Matz and David hit, so I'll just +1 them: I keyed the file
path through `task.description` because tasks carry no payload, and I
built a `Casefile` provider + singleton-method worker because the
orchestrator won't take a callable. The adapter tax is real: ~20 of my
~110 lines are plumbing that says nothing about detection or files.

## Verdict

Prism-powered self-audit through the gem's own scheduler, in about a
hundred lines. The fan-out API is genuinely pleasant once the adapter is
paid for — and the case file gave the whole team a refactoring hit list.
