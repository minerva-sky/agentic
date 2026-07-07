# Round 16 field notes — Justin Searls discovers the design

*Built: `examples/discovery_testing.rb` — outside-in in three acts:
fakes for collaborators that don't exist yet, wishes hardening into
interfaces, and a discovered seam that turned out to fit an entire
orchestrated plan behind it.*

## What I built and why

Round 12 I policed doubles that had drifted from reality. The
lottery sent me back for the other half of the sermon — the half
people skip: doubles aren't primarily an *isolation* tool, they're a
*discovery* tool. Most folks fake collaborators that already exist.
The better trick is faking collaborators that **don't exist yet**,
and letting test pressure tell you what interfaces you wish you had:

```
act 1: triager orchestrates two DISCOVERED interfaces      ok
act 2: triager unchanged as fakes become real (seam held)  ok
act 3: router realized as a two-task plan, same interface  ok
fakes still match reality: #classify, #route               ok
```

Act 1 is the design session. Writing `TicketTriager` top-down
forced two wishes into existence — `classify(text) → label` and
`route(id, label) → receipt` — not sketched on a whiteboard but
*extruded under test pressure*, sized exactly to what the caller
needs and nothing more. That's why discovered interfaces come out
narrow: nobody wishes for a config hash.

Act 2 is the proof the seam was right: the classifier became real
and the triager **didn't change**. If realizing a collaborator
forces edits upstream, the double didn't discover a design; it
hid the absence of one.

## Act 3 is why this belongs in this repo

The discovered interface is *indifferent to what stands behind it*.
`route(id, label)` was a two-line fake; it became a **two-task
orchestrated plan** — enqueue, then notify, with the framework's
whole apparatus (journaling, retries, the graph) available behind a
seam the triager never renegotiated. This is Sandi's duck seam and
my discovery workflow shaking hands: discovery testing finds the
narrow waist, and the plan framework is exactly the kind of heavy
machinery you want *behind* a narrow waist rather than threaded
through your domain.

And the last checks keep round 12's law: fakes that outlive their
realization must show their papers (method + parameter shapes
against the real class), or they quietly start vouching for a
design that moved. Discovery and verification are one workflow —
wish, realize, verify, forever.

## Notes

- The fakes are anonymous classes, five lines each, because
  discovery fakes should be *cheap to throw away* — a fake with a
  factory and a builder DSL has become an investment someone will
  defend in review.
- Deliberate omission: no mocking framework. `Class.new` and a
  `#parameters` check carry the whole discipline; the tooling is
  optional, the workflow isn't.

## Verdict

Two interfaces discovered under pressure, one realized as a plain
class, one as an entire plan — with the top of the design never
edited after act 1. The doubles were scaffolding; the interfaces
they discovered are the building, and the building held.
