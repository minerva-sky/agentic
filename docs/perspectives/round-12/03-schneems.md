# Round 12 field notes — Richard Schneeman reads the bill

*Built: `examples/require_cost.rb` — derailed-style require costs
(RSS, objects, wall time) measured in pristine child processes, for
the gem and each major dependency — with a plot twist about when the
bill actually lands.*

## What I built and why

Years of Heroku support tickets taught me that memory problems are
almost never mysterious — they're just *itemized late*. Somebody adds
a gem in a two-line PR, the dyno graph climbs 30MB a month later, and
the two events are never introduced to each other. So: measure
requires like purchases, each in a clean subprocess so nobody's
transitive dependencies get billed to a neighbor's account.

```
json (stdlib)                 0.4MB    4,805 objects     9ms
zeitwerk                      0.5MB    7,610            10ms
async                         2.8MB   35,476            51ms
dry-schema                    2.3MB   46,822            67ms
agentic (require only)        0.6MB   11,976            17ms
agentic + first real touch    5.6MB   84,254           118ms
```

## The plot twist

My first draft measured `require "agentic"`, saw 0.6MB, and nearly
wrote the wrong report. The gem's require is **nearly free** — the
round-1 Zeitwerk cleanup means nothing loads until a constant is
touched. The last row is the honest one: touch an orchestrator and a
validator, and async and dry-schema arrive through the autoloader —
5.6MB and 118ms, *at first use*.

**Deferred is not free — it's a bill that arrives during your first
request instead of your boot.** Which one you want depends entirely
on who you are: a CLI or a small script pays only for what it
touches (beautiful — most invocations never load dry-schema at all);
a web worker eats 118ms of autoloading inside somebody's request
(page the on-call and tell them it's "lazy loading"). Same mechanism,
opposite verdicts, and a report that only measures one moment will
confidently tell you the wrong story.

The moves this funds: `eager_load` + `preload_app` in servers — pay
the 5.6MB once in the parent and share it copy-on-write across all
eight workers; stay lazy in CLIs; and run the script in CI so a new
dependency's bill arrives *in the PR that adds it*.

## Notes

- Child-process isolation is non-negotiable for this measurement. In
  a warm parent, half the dependencies are already loaded and every
  row under-reports; my numbers looked suspiciously cheap until each
  probe got its own pristine VM.
- Objects-at-require matters separately from RSS: dry-schema's 46k
  objects are mostly long-lived constants — old-gen residents that
  make every future major GC walk a bigger heap. RSS is rent;
  old-gen objects are a homeowners association fee.

## Verdict

The gem itself is a courteous tenant (12k objects, deferred
everything); its dependencies are the furniture, arriving on first
touch. Both numbers are now on a receipt, and the receipt belongs in
CI — because the cheapest time to argue with a dependency is in the
PR that introduces it.
