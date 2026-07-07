# Round 4 field notes — Xavier Noria charts the coupling

*Built: `examples/coupling_cartographer.rb` — a constant-reference
graph between files: who defines what, who references it, which walls
bear load, which files lean hardest, and whether any pair leans on
each other.*

## What I built and why

Rounds 2 and 3 mapped names and prose; round 4 maps *forces*. Each file
is surveyed (Prism, in parallel) for constants defined and constants
referenced; the atlas task joins the two sides into a directed graph.
Ownership is resolved by trailing segment, because inside `module
Agentic` a reference reads `LlmClient`, not `Agentic::LlmClient` —
the survey must resolve constants the way Ruby does, relative to the
namespace you stand in, or the map measures a language that doesn't
exist.

Findings for this gem:

- **Load-bearing walls**: `llm_config.rb` (8 dependents) and
  `errors.rb` (6). Both are leaf-like value/constant definitions —
  exactly what you want at the bottom of a dependency graph. A change
  to either is a change to a public commitment; their test coverage
  should match their in-degree.
- **Heaviest leaners**: `cli.rb` at 15 — unsurprising and fine (a CLI
  is a terminus; nothing leans back on it), and `agentic.rb` at 12,
  which is the entry point doing entry-point things.
- **One mutual dependency**: `agentic.rb <-> llm_client.rb`. True and
  known — the module owns configuration, the client reads it, the
  module exposes `Agentic.client`. Mutual edges at the entry point are
  tolerable; mutual edges between two mid-level files would be a
  design smell. The atlas found exactly one, at the tolerable spot,
  and none elsewhere: a genuinely clean graph.

## The bug I wrote, in the spirit of full disclosure

`Hash.new { |h, k| h[k] = [] }` leaked out of the builder into the
reader, and the mutual-dependency probe — merely *asking* whether a
file had edges — **invented** empty edge lists mid-iteration:
"can't add a new key into hash during iteration." A default proc is a
constructor's convenience and a reader's trap; copy it away at the
boundary. Loaders taught me this same lesson years ago: mutation
behind an innocent-looking read is where the strangest bugs live
(`const_missing`, anyone?).

## Framework note

The 65-way fan-in atlas is by now routine — third round in a row this
shape appears (digest, doc coverage, now this). It's the framework's
signature move: parallel facts, one joining task. The pattern deserves
a name in the docs. I propose *survey/atlas*.

## Verdict

The map shows a gem whose load flows downward onto small, stable
files, with one honest cycle at the front door. Cartography's highest
compliment: nothing surprising, now with evidence.
