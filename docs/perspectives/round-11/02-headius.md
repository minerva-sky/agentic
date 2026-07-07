# Round 11 field notes — Charles Nutter brings real threads

*Built: `examples/threads_drill.rb` — the journal, the registry, and
the windowed limiter hammered by actual Ruby threads, judged by the
standard of a VM with no GVL to hide behind.*

## What I built and why

Fibers are polite: they yield when asked and never interrupt a
two-step dance. Threads are not, and on JRuby they run *actually in
parallel* — every "works fine in production" claim earned under
MRI's GVL gets re-examined on my VM, usually at 2am. So I drill
everything this gem calls shared:

```
journal, 8 threads x 150 events:  1200/1200 lines, 0 torn
registry, 8 threads x 50 each:    0 registrations lost
windowed try_acquire, ceiling 50: admitted 50/50 (observed)
```

The journal and the registry hold, and they hold for the right
reason: they *paid* — a Mutex, flock, fsync. Those survive real
parallelism because they're real locks, not scheduling luck.

## The drill drew blood before the threads even started

First run, drill 1 crashed in all eight threads at once:
`undefined method 'iso8601' for an instance of Time`. The journal
calls `Time#iso8601` — a method from the `time` stdlib — without
requiring it. Every previous example worked because something else
(async, loaded when an orchestrator or limiter was touched) had
required it first. My drill used the journal *bare*, and the
load-order debt came due.

This is the classic works-on-my-boot bug, and it's exactly the
species JRuby users hit constantly: different load orders, different
lazy-loading, same gem, sudden NoMethodError on a stdlib method.
The fix is one line (`require "time"` where it's used) and it's in
this round's release — but the lesson is the durable part: **every
file must require what it uses.** Transitive requires are a loan
from a dependency's internals, and dependencies refinance without
telling you.

## Luck wearing a lab coat

Drill 3 is the honest one. The windowed limiter's `try_acquire`
reads `@stamps.size`, then appends — check-then-act, no mutex. Eight
threads, 1600 attempts, ceiling 50: admitted exactly 50. So it's
fine? No — it's *unobserved*. MRI's GVL makes the two steps nearly
atomic by scheduling accident; JRuby runs them genuinely
concurrently, and unsynchronized size-check-then-append is precisely
the shape that over-admits there. The drill prints both possible
outcomes honestly and files the round-12 ask: a Mutex around the
stamp bookkeeping, so the answer is the same on every Ruby. A lock
you only need on some VMs is a lock you need.

## Notes

- The journal's flock+fsync means it would hold across *processes*,
  not just threads — the strongest claim in the gem, and the drill
  only tested the weaker half. A multiprocess drill is the natural
  sequel.
- Note what I did NOT ask for: making the orchestrator thread-safe.
  It's fiber-architected and says so; the drill only holds
  *explicitly shared* structures to the parallel standard.

## Verdict

Two structures paid for real locks and passed a real-parallelism
drill; one is coasting on the GVL and now has that in writing; and
the drill's warm-up caught a load-order bug that fiber-world never
would have. Bring threads to your gem before your users' VM does.
