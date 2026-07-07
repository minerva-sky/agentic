# Round 14 field notes — Marc-André Lafortune audits the freeze

*Built: `examples/ractor_shareability.rb` — every interesting
framework value judged by `Ractor.shareable?`, the strictest freeze
referee Ruby ships, with a proof-of-travel through a real Ractor.*

## What I built and why

I've spent years on frozen things — frozen string literals, freezing
core classes, the RuboCop cops that nag about both — and the lesson
that unifies them: `freeze` is a promise about *one object*, while
immutability people actually want is a promise about *everything it
reaches*. Ruby has exactly one honest arbiter of the second promise,
and it's not a style guide — it's `Ractor.shareable?`:

```
value                  frozen?  shareable?  after make_shareable
graph snapshot         true     false       a deep-frozen copy crosses
graph[:order]          true     true        (already crosses)
graph[:stats]          true     true        (already crosses)
to_json_schema output  false    false       a deep-frozen copy crosses
a Task object          false    false       a deep-frozen copy crosses
a RateLimit            false    false       REFUSED: holds live machinery
```

The graph snapshot is the teaching row: it says `frozen? == true`
and the referee says *not shareable* — a top-floor promise on a
building with unlocked doors below, because the frozen hash reaches
unfrozen Task objects. That's not a bug in the graph (its contract
is "don't mutate the snapshot," which shallow-freeze delivers); it's
the *vocabulary distinction* this audit exists to make. Meanwhile
`order` and `stats` are data all the way down and cross a Ractor
boundary as-is — the round-8 stats work quietly produced
Ractor-ready values before Ractors were anyone's requirement.

## The refusal is the best row

The `RateLimit` cannot be made shareable at any price: it holds a
real Mutex, and no amount of freezing turns a lock into a value.
That refusal is *correct* and clarifying — the limiter is a machine,
not a fact, and the Ractor design pattern is one line: **send facts,
keep machines.** What crosses is testimony (ids, stats, schemas);
what stays is machinery (limiters, orchestrators, semaphores). A
framework whose facts and machines separate this cleanly under the
strictest referee available is a framework whose layering was honest
all along.

Confession, preserved in the example's comments: my first draft
deep-froze the system under audit — `make_shareable` on the
snapshot froze the *real* tasks through the shared references, and
every subsequent row reported contaminated verdicts. The fix (judge
Marshal copies; mutate nothing you're measuring) is the fix for all
instrumentation, everywhere: **referees must not tamper with the
evidence.** Seventh consecutive round of a tool correcting its
author; the streak is the methodology now.

## Verdict

Frozen and shareable are different promises, and now each framework
value knows which one it makes. Facts cross, machines stay, the one
refusal is load-bearing, and the auditor learned on camera not to
freeze the evidence. `Ractor.shareable?` — use it as the linter it
secretly is.
