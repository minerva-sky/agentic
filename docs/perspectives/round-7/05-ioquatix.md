# Round 7 field notes — Samuel Williams composes the laws

*Built: `examples/composed_limits.rb` — `quota.and(pool)` (this
round's release) enforcing a billed window and a connection ceiling
simultaneously, with the run showing which law binds.*

## What I built and why

Round 6 ended with my note that production APIs enforce two laws at
once and composition was "the user's sentence to write." The release
made it the framework's sentence — `quota.and(pool)` — so this round
characterizes the composition under load:

```
window 1:  ###### 6 admitted (quota allows 6)
window 2:  ###### 6 admitted
pool high-water: 2 of 2 - the socket law held
```

Both laws held in their own dimensions, and — the part worth the
example — the run reveals **which one binds**. The pool could clear
~8 calls per window; the quota admits 6; the chart shows exactly 6.
Raise the quota and the wall moves to the pool. Capacity planning is
mostly the art of knowing your binding constraint, and a composed
limiter that *shows* it beats two separate limiters that each swear
they're innocent.

## The confession, and the lesson it carried

My first draft's closing prose declared the pool the binding
constraint. The chart said otherwise — 6 per window, quota-bound,
arithmetic I'd done wrong in my head (8 > 6, the pool had slack). I
fixed the prose, not the chart. Seventh round, and the tools are now
routinely correcting their own authors mid-example; I've stopped
counting this as embarrassment and started counting it as the
methodology working. **Write the measurement first, the narrative
second.**

## Ordering, the subtle contract

`quota.and(pool)` acquires the quota *before* waiting for a socket.
That order is load-bearing: quota refills on a clock whether you're
ready or not, while sockets are scarce and held. The reverse order
would hold a connection hostage while waiting on the meter — a
convoy generator. The Composite acquires in the order you compose,
so the order you write IS the policy; the docs now say so, and the
example demonstrates the correct idiom. (Composition APIs that make
ordering invisible make deadlocks invisible too — flattening the
nesting but preserving the sequence was the right call in the
implementation.)

## Verdict

Two laws, one object, a chart that names the bottleneck, and an
ordering contract stated out loud. The rate-limiting arc that started
with a crowbarred semaphore in round 4 is now a small, honest algebra
— which is all infrastructure ever needed to be.
