# Round 4 field notes — Andrew Kane makes the README testify

*Built: `examples/readme_verifier.rb` — every ruby fence in the README
parsed with Prism and every `Agentic::` constant it names checked
against the loaded gem. Exit 1 on broken promises.*

## What I built and why

Back in round 2 I wrote: "my rule: every README snippet is a CI-run
test. The fake web_search survived because nothing ran the promises
the README made." Four rounds later I built the enforcement. The
verifier extracts all 21 ruby fences (376 lines of promised code),
fans them out, syntax-checks each with Prism, and resolves every
`Agentic::`-prefixed constant a snippet mentions against the actual
loaded gem — because a snippet that parses but names
`Agentic::MetaLearningSystem` is still a lie, just a better-dressed
one.

**First run: caught one.** README line 514, the capability-composition
example, contained `{ data: { ... } }` — a literal ellipsis inside a
hash, unparseable since the day it was written. And here's the kicker:
the very first persona review in round 1 (DHH) called out *this exact
snippet* as "the README being ahead of the code." It took us four
rounds and a tool to convert that observation from an opinion into an
exit code. Opinions decay; exit codes don't.

## Design notes

- **Constant resolution beats execution.** I deliberately don't *run*
  snippets — half of them need API keys, several would write files.
  Parse + resolve gets you 90% of the lie-detection with 0% of the
  side effects; it's the right default tier (same reasoning as the
  DuckDuckGo backend: free and honest first, paid and thorough as an
  upgrade). Executing the safe subset in a sandbox is the `--strict`
  flag this grows next.
- The survey/atlas shape again (Xavier's right that it needs a name):
  per-snippet checks in parallel, one verdict fanning in with
  `t.output_of(check)`. Fourth build in two rounds with this skeleton;
  it's the framework's `map/reduce`.
- One `rescue NameError` per constant lookup, and note it must be
  `Object.const_get`, not `eval` — verifiers that eval their input
  become the vulnerability they were hired to prevent.

## Verdict

Wire this into CI next to Jeremy's fuzzer and the docs can never
silently rot again: the fuzzer keeps the contracts honest, this keeps
the promises honest. It found a four-round-old lie on its first run —
tools that pay for themselves before the commit lands are the only
kind worth writing.
