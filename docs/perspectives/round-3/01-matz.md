# Round 3 field notes — Matz plays the telephone game

*Built: `examples/telephone_game.rb` — a rumor passes through five
villagers, each hearing the previous version through the dependency
pipe and repeating it imperfectly.*

## What I built and why

In round 2 I asked for one thing: let dependent tasks *see* what their
dependencies produced. It exists now, so I built the program that is
nothing but that feature: the telephone game. Each villager's task
depends on the previous villager's, and the garbled rumor arrives via
`t.dependency_outputs` — no scroll smuggled through shared state, no
provider structs. The framework itself carries the whisper.

"Old Tom saw a cat chase two mice" arrives at the town crier as
"HEAR YE: OLD TOM WRESTLED AN ENORMOUS CAT CHASE TWELVE WOLVES, DOWN BY
THE RIVER!!" — five hops, one millisecond, zero mutable globals.

## Comparing my two rounds honestly

My renga needed 110 lines and three pieces of scaffolding I resented:
the shared scroll, the `PoetAtTheTable` adapter, the `RengaProvider`.
The telephone game does *more* piping in ~50 lines and contains no
scaffolding at all — `add_task(task, [previous], agent: ->(t) { ... })`
is the entire wiring. This is what I mean when I say APIs should
disappear: the remaining code is all game, no framework.

One line I especially enjoyed writing:
`heard = t.dependency_outputs.values.first || t.payload` — the first
villager has no dependency, so he reads the original rumor from his
payload. The nil case fell out naturally instead of needing a branch
somewhere else. When the empty case and the full case share a shape,
the design is right.

## A small wish for round 4

`t.dependency_outputs.values.first` works but reads like plumbing. For
the extremely common one-dependency case, a `t.previous_output` (or
letting `output_of` default to the sole dependency) would make the line
sing. Grammar for the common case, hash access for the general one.

## Verdict

Round 2 I wrote a poem despite the framework; round 3 I wrote a joke
with it. Progress in a library is measured exactly there — in what you
stop noticing.
