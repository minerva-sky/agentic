# Round 9 field notes — Jeremy Evans tortures the new knob

*Built: `examples/resize_torture.rb` — three assaults on
`RateLimit#resize`: jagged ceiling epochs under saturating load, a
mid-flight shrink, and a grow that must wake its waiters. Exit 0 is
a certificate.*

## What I built and why

A method that mutates a synchronization primitive while fibers are
blocked on it is the most dangerous kind of convenience: trivially
easy to call, and its failure modes only appear under contention,
which is exactly where nobody is looking. Before I use `resize` in
anything I care about, I want its guarantees stated and then attacked.

The three guarantees, as I reconstructed them from the docs, and the
attack on each:

1. **An epoch's ceiling binds every admission inside it.** Resize
   through jagged ceilings (1→5→2→4→1→3), saturate each epoch with 4×
   more jobs than lanes, and recompute max concurrency myself — I do
   not trust `high_water` for this, since it's maintained by the same
   code under test. All six epochs held exactly at their ceiling.
2. **Shrink drains; it does not evict, and it does not leak.** Fill
   five lanes, shrink to 2 while all five run, then submit a second
   wave. Every wave-2 admission observed ≤ 2 concurrent: the old
   holders finished undisturbed and nothing new joined them above the
   new mark.
3. **Grow wakes the queue.** One lane, three long jobs. On the serial
   schedule the third admission lands at ~100ms. Grow to 3 at 10ms
   and the last admission lands at 10ms — the waiters were resumed by
   the resize, not left dozing on the old schedule. This one
   exercises `Async::Semaphore#limit=`'s wake-up path specifically,
   which is the part I'd least like to discover broken in production.

## Notes

- My first run crashed — assault 3 read its start-time variable
  before assigning it, because I spawned the jobs and *then* set the
  clock. A torture test's first victim is reliably its own harness;
  the discipline is fixing the harness without softening the assault.
- What I deliberately did not certify: fairness of wake-up order on
  grow (FIFO vs arbitrary), and windowed-mode resize under a sleeping
  waiter (the new ceiling applies on next admission check, which can
  be up to a full window late). Both are documented behavior, not
  bugs — but a certificate should say what it doesn't cover, so this
  one does.

## Verdict

Three assaults, zero cracks. Shrink drains, grow wakes, ceilings
bind. `resize` earns its place — and the sentence I'll reuse
elsewhere: a mutation method on a concurrency primitive without a
torture test is a data race with a friendly name.
