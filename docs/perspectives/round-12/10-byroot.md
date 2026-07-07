# Round 12 field notes — Jean Boussier weighs the layers

*Built: `examples/write_path_profile.rb` — the journal's write path
benchmarked one layer at a time: serialize, buffered write, flush,
flock+fsync, and the group-commit alternative. The profiler acquits
JSON and indicts nothing — the expensive layer is the promise.*

## What I built and why

I've spent enough years on Ruby's JSON and string internals to know
exactly how these conversations go: a journal is "slow", somebody
proposes switching serializers, three days are spent on a gem swap,
and the p99 doesn't move — because nobody weighed the layers first.
So, weigh them:

```
JSON.generate only                  2.7us
+ buffered write                    3.5us
+ flush to kernel                   4.6us
journal.record (flock+fsync)      712.3us
group commit (fsync per 20)        76.5us
```

Serialization is **0.4%** of the real write. You could make
JSON.generate infinitely fast and the journal would be 99.6% as slow
as before. The other 707 microseconds are the fsync — the syscall
where the kernel promises the bytes survived power loss — and that
cost is not overhead. **It's the product.** The journal's only
promise is that a crash cannot unwrite what `record` returned from;
fsync is that promise's unit price. (I optimize stdlib JSON for a
living and I'm telling you: leave it alone here. It was already
fast, and it was already irrelevant.)

## Group commit is a different promise, not a faster one

The honest knob exists: batch 20 events per fsync and the amortized
write drops to 77us — a 9x improvement that every high-throughput
journal (databases, Kafka, WALs) eventually reaches for. But say
precisely what was traded: a crash can now eat up to 19
*acknowledged* events. That's not an optimization; it's a **different
durability contract**, and only the caller knows which contract
their recovery story needs. An LLM-cost journal probably wants
per-event fsync (each event is money); a metrics journal wants group
commit (losing 19 counters is nothing). The right framework move —
if throughput ever matters here — is `fsync_every: n` as an explicit
constructor argument, so the trade has a name and a diff, not a
folklore.

## Notes

- Bench hygiene: each layer gets its own file and its own loop; the
  "real" row goes through the actual `journal.record` including the
  per-call open and flock, because users pay the whole path, not
  the flattering subset.
- The flush row (4.6us) vs the fsync row (712us) is the pedagogical
  gap: "flushed to the kernel" and "durable" differ by 150x, and
  conflating them is how systems pass every test and lose data
  anyway. The page cache is not a disk; it's an optimist.

## Verdict

The profiler acquitted JSON in one table and priced the actual
choice — per-event durability at 712us or group-commit throughput at
77us with 19 events of exposure. Optimization budgets follow
profiles or they follow fashion; this one now has a profile.
