# Round 14 field notes — Benoit Daloze writes down what it means

*Built: `examples/behavior_spec.rb` — a compliance file in a 30-line
self-contained mspec: six boundary behaviors of the limiter, the
relations, and the journal, pinned as executable semantics.*

## What I built and why

I maintain ruby/spec, which exists because of one uncomfortable
discovery: "MRI does X" is not a specification — it's an
implementation detail wearing one. When TruffleRuby needed to know
what Ruby *means*, the answer couldn't be "read the C"; it had to be
executable, implementation-neutral, and phrased as behavior. Any
library that expects to be ported — to another VM, into a Ractor, to
another language — eventually needs the same document. So:

```
ok  RateLimit: admits exactly ceiling acquisitions, then refuses
ok  RateLimit: try_acquire without a block still consumes a slot
ok  RateLimit: resize applies to the NEXT admission decision
ok  RelationRules: presence means key-given-and-non-nil
ok  RelationRules: sum_lte treats missing as zero, boundary closed
ok  Journal: a later success erases an earlier failure
6 behaviors pinned, 0 drifted
```

Every pinned behavior is a *choice that could have gone the other
way* — the ceiling-th+1 call could queue instead of refuse; resize
could reset the window instead of counting old stamps against the
new ceiling; a nil trigger could engage `requires`. The
implementation chose; the spec is the choices, written down, so
"what the code happens to do" and "what the code means" stop being
the same sentence.

## Why the harness is thirty lines of nothing

The mspec here is deliberately dependency-free — describe/it/expect
in one module. This is ruby/spec's founding constraint transplanted:
**the spec must not depend on what it specifies** (or on tooling
that does). A compliance file that needs RSpec needs everything
RSpec needs, and now the port has to bootstrap a test framework
before it can check its first boundary. Thirty lines of harness is
the price of a spec that runs anywhere the subject might be
reimplemented, and it's the cheapest thirty lines in the file.

The relationship to the existing suites, precisely: the RSpec suite
tests *this implementation* (internals, mocks, seams); Jeremy's
round-10 prober *attacks* this implementation (hostile inputs,
oracle checks). This file *specifies the contract* any
implementation must satisfy. Three documents, three audiences, and
the third one didn't exist until a porter needed it.

## Notes

- The journal behavior ("later success erases earlier failure") is
  the one I most expected to be accidental rather than chosen — but
  the dead-letter office and breaker were *built* on it in rounds
  8-9, so it's load-bearing semantics. Now it's load-bearing AND
  written down, which are different states.
- What I'd pin next: fiber-vs-thread guarantees per method — which
  operations are reactor-safe, which are thread-safe, which are
  both. The threads drill measures it; a spec would *promise* it.

## Verdict

Six boundary choices promoted from behavior to specification, in a
harness that depends on nothing it specifies. When someone ports
this limiter to a place its authors never imagined — and someone
always does — this file is the difference between a port and a
guess.
