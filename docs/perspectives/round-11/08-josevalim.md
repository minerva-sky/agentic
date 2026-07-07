# Round 11 field notes — José Valim wires the telemetry bus

*Built: `examples/telemetry_bus.rb` — named events on a bus with
attach/detach at runtime and crash isolation, bridged from the
orchestrator's lifecycle hooks in ten lines.*

## What I built and why

In Elixir we learned this lesson expensively: when every library
invents its own instrumentation callbacks, every metrics vendor
writes N adapters, every application couples to all of them, and
nobody can add a tracer without a deploy. The ecosystem converged on
`:telemetry` — tiny, boring, universal: events are **namespaced
tuples**, payloads split **measurements** (numbers) from **metadata**
(context), handlers attach and detach at runtime, and a crashing
handler is detached rather than allowed to take the caller down.

This example is that design, standing on Agentic's hooks:

```
run 1: [trace] SLOW: enrich took 80ms
       [bus] handler exporter crashed (IOError) - detached, plan unharmed
       [metrics] {tasks: 3}
run 2 (tracer detached by ops): [metrics] {tasks: 6}
```

The orchestrator emitted identical events both runs. It cannot tell
that the tracer left or that the Friday exporter died, and that
ignorance is the entire feature: producers that know their consumers
grow opinions about them, and opinions become coupling, and coupling
becomes "we can't upgrade the metrics library until Q3."

## Hooks are the floor, not the house

I want to be precise about what I'm *not* criticizing. Lifecycle
hooks are the right primitive for a framework to export — one
configuration-time seam, no policy. But hooks couple one producer to
one consumer at configuration time; observability needs N consumers
changing at runtime. The bridge between them is ten lines because
the hooks carry exactly the right data (durations, failure types,
statuses — measurements and metadata, already separated in spirit).
A framework's job is to make the bus *possible* in ten lines, not to
ship the bus; ship the bus and you've chosen every user's metrics
vendor.

Crash isolation deserves its sentence: the exporter raised, was
detached, was *reported*, and the plan never noticed. Instrumentation
must never be load-bearing — the day a tracing outage becomes an
application outage, someone deletes all the instrumentation, and
then you're blind *and* fragile.

## Notes

- Handler ids make detach targeted (`BUS.detach(:tracer)`) — the ops
  story ("we got tired of that log line") is real and it should be a
  one-liner, not a deploy.
- The ExecutionJournal is, in this framing, just another handler —
  one that happens to fsync. Round 12 could re-express it as a bus
  subscriber and the hooks stay clean forever. A thought, not an ask.

## Verdict

Callbacks are for configuration; events are for observation. The
framework's hooks turned out to be a good floor — ten lines of
bridge bought runtime attach/detach, crash isolation, and a producer
blissfully ignorant of its audience. Steal `:telemetry`'s design;
it was right the first time.
