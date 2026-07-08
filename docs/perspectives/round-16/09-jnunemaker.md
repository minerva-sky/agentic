# Round 16 field notes — John Nunemaker installs the big red button

*Built: `examples/kill_switch.rb` — per-capability kill switches
checked at use time: instant, no deploy, non-retryable by decree,
with an audit trail of who pressed and why in the same journal as
the work.*

## What I built and why

Flipper taught me that feature flags are really two products
wearing one API. Flags answer "who should get this?" — percentages,
actors, groups, the growth side (I built that here in round 13).
Kill switches answer the grimmer operational question: **"how fast
can a human make this STOP?"** Every capability that touches money,
email, or someone else's API needs the second product, and the
requirements are written in pager ink:

```
tuesday 09:14, email:send KILLED mid-incident:
  email:send is KILLED (by oncall-dana: provider duplicating sends, INC-2291)
  summarize still ran; verdict journaled retryable: false
tuesday 11:40, restored
audit trail: killed by oncall-dana (INC-2291) / restored by oncall-dana
```

Four design decisions, each one an incident I've lived:

1. **Checked at use time.** No deploy, no restart — the next task
   sees the flip. Two minutes of incident is a story; twenty (the
   deploy pipeline's length) is a postmortem.
2. **Per-capability, not global.** The summarizer kept working while
   email went dark. Dark the organ, not the patient — a global
   panic button gets pressed exactly once, and then never again,
   because it hurt too much.
3. **Killed calls fail with a NON-retryable verdict.** A human said
   stop; the retry machinery must not out-vote her. The verdict
   flows into the journal, so round 8's dead letter office *parks*
   these instead of hammering a bleeding provider — the series'
   failure taxonomy and the red button snap together with no
   adapter.
4. **Every flip records who and why.** The switch nobody remembers
   pressing is the outage nobody can end. The audit trail lives in
   the same fsynced journal as the work, so "what was killed during
   this run" is part of the run's own replay.

## Notes

- The guard is a lambda wrapping a lambda — the duck-typed `agent:`
  seam again, doing for operations what it did for architecture in
  rounds 9 and 11. Cross-cutting concerns keep costing one wrapper.
- Production wants the switch state shared across processes (Redis,
  a DB — this registry is per-process, and says so). The *shape* —
  use-time check, hopeless verdict, audited flips — survives any
  storage.
- Restore is as audited as kill. Incidents end, and "who turned it
  back on" is tomorrow's first question.

## Verdict

The digest lost only its risky organ, the retry machinery obeyed
the human, and the whole incident reads back out of one journal —
press, park, restore, all with names attached. Flags decide who
gets a feature; switches decide how fast you can take one away.
Build both; press calmly.
