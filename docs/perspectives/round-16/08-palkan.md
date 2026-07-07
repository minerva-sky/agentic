# Round 16 field notes — Vladimir Dementyev names the backpressure

*Built: `examples/progress_channel.rb` — plan progress broadcast to
N subscribers where every subscriber declares its backpressure
policy: `:latest_wins` for dashboards, `:every_event` (bounded, loud
disconnect) for auditors. A deliberately awful slow consumer proves
both.*

## What I built and why

Round 12 I profiled where plan time goes; the lottery brought me
back for the AnyCable half of my life: what happens when you
broadcast that progress to *subscribers*, and one of them is slow.
Because one always is — a laggy browser tab, a stalled websocket, a
consumer doing synchronous writes — and the moment it happens, your
"real-time layer" quietly becomes either a memory leak or a brake
on the thing it's observing. Years of cable operations distill to
one rule: **every channel names its backpressure policy.**

```
plan: 10 tasks in 557ms (publish never blocked it)
dashboard  latest_wins  holding 1 frame; 19 stale frames dropped
auditor    every_event  DISCONNECTED at buffer 8 - gaps unacceptable
firehose   every_event  alive and current (it kept draining)
```

The two policies are two *promises*, and the demo shows why mixing
them up hurts people. A dashboard doesn't need history — it needs
the truth *now* — so `:latest_wins` drops stale frames without
ceremony; 19 frames died and the dashboard is perfectly informed.
An auditor is the opposite: a record with silent holes is worse
than no record (the holes will be exactly where the incident was),
so `:every_event` buffers to a bound and then **disconnects
loudly** — an absent auditor gets reconnected by an alarm; a
quietly lossy one gets discovered by a subpoena.

## The publisher's vow

The third promise belongs to the publisher: `publish` never blocks
and never raises into the plan. The lifecycle hooks run on the
task's own fiber (the framework's docs say so plainly), so anything
slower than a hash insert there is instrumentation taxing the work
it measures — the channel absorbs or sheds *by policy*, in a mutex
window sized to an array operation. The plan finished in 557ms with
a subscriber in ruins behind it, which is the whole point:
observers may suffer; the observed may not.

## Notes

- The buffer limit is 8 on purpose — laughably small, so the demo
  *shows* the disconnect. Production numbers are bigger; the shape
  of the promise is identical.
- Natural extensions, all additive: per-subscriber threads doing
  real IO, a `:sample` policy (every Nth event) for metrics, and
  resumable auditors that reconnect with a journal replay to fill
  their gap — the journal already has everything they missed, which
  is a lovely property this repo gets for free.

## Verdict

Ten tasks, three subscribers, one deliberate disaster: the
dashboard stayed current by forgetting, the auditor failed loudly
rather than lie, the firehose earned its keep by draining, and the
plan never felt any of it. Name your backpressure policy, or
production will name it for you — and its name will be "incident."
