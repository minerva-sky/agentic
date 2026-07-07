# Round 11 field notes — Luca Guidi keeps the center clean

*Built: `examples/ports_and_adapters.rb` — a pure use-case speaking
only to ports, Agentic as one of two interchangeable delivery
mechanisms, and a mechanical purity scan proving the dependency
arrow points one way.*

## What I built and why

Every framework, including the ones I've built, whispers the same
temptation: *put your business logic inside me, where it's cozy.*
And every rescue project I've seen started with someone accepting.
The test of architecture isn't the happy years — it's the migration,
and the part of your app that survives a migration is exactly the
part that never learned the framework's name.

So: `QuoteShipment`, a use-case in pure Ruby. Its entire knowledge
of the outside world is two **ports** — `#rate_for(mode)` and
`#save(result)` — named after what the *domain* needs, not after
what any vendor provides. The adapters (six lines each) live at the
edge. And then two acts:

```
act one - delivered by Agentic:        {price_cents: 1080, ...}
act two - delivered by a bare call:    {price_cents: 600, ...}
purity scan: 0 framework constants in the domain
```

Act two is the migration, rehearsed. The orchestrator leaves; the
use-case doesn't notice, because there was nothing to notice — the
dependency arrow points one way. The edge knows the center; the
center has never heard of the edge.

## The scan is the architecture test

Talking about clean architecture is worthless; *checking* it is
cheap. The domain's source lives in a string precisely so the
example can grep it for framework constants and **exit 1 on a leak**.
That's the whole discipline in one mechanical gate — the kind of
check that belongs in CI, because architectural erosion never
arrives as a decision; it arrives as one convenient `Agentic::` in
a domain file during a hotfix.

What deserves praise: Agentic made act one *easy without demanding
tenancy*. The `agent:` seam takes any callable, so the use-case
walked in as `->(t) { use_case.call(**t.payload) }` — the framework
added retry policy, journaling, concurrency, and the graph *around*
the domain, without the domain signing anything. Frameworks
orchestrate; domains decide. A framework whose integration point is
"be callable" is a framework that respects the boundary — this is
Sandi's duck seam (round 9) viewed from the architecture side.

## Notes

- The ports are minimal on purpose: two methods, no base classes, no
  registry. Ports are a vocabulary, not a bureaucracy — the moment a
  port needs an abstract superclass, it has become an adapter with
  ambitions.
- Act two also quietly demonstrates testability: the "bare call" IS
  what a unit test of the domain looks like. No orchestrator in the
  test suite, no framework boot time in the feedback loop.

## Verdict

The domain would survive the migration, and there's an exit code
that says so. Clean architecture isn't ceremony — it's the freedom
to change your mind about everything except the truth, and this gem,
to its credit, asks for nothing more than a `#call`.
