# Round 4 field notes — Aaron Patterson finds the knee

*Built: `examples/knee_finder.rb` — the same plan at seven concurrency
limits, measured with the `task_slot_acquired` hook, with a
recommendation for where adding lanes stops paying.*

## What I built and why

"What should `concurrency_limit` be?" is answered by superstition in
every codebase I've ever audited — someone typed 10 in 2019 and it
became scripture. The knee finder replaces the scripture with a
measurement: run the workload at 1, 2, 3, 4, 6, 8, 12; record wall time
and — new this round — **total queue-wait**, straight from the
`task_slot_acquired` hook I asked for; recommend the smallest limit
within 15% of the best wall time.

```
limit   wall     total queue-wait
    1   1205ms     6790ms
    4    350ms     1001ms
    6    300ms      470ms   <- knee
    8    300ms      230ms
   12    300ms        0ms
recommendation: concurrency_limit 6
```

Wall time flatlines at 300ms from limit 6 onward — because one call in
the workload takes 300ms, and **you cannot fan out a long pole**. Limits
8 and 12 buy zero wall time; they only buy down queue-wait, which is
invisible to your user and costs you open connections. That flatline is
the single most useful line in the chart, and it's exactly what the old
hooks couldn't show: without slot-acquisition timestamps, queue-wait and
run-time were smeared into one number and the knee was unfindable.

## Confession, as tradition requires

My first draft's workload had uniform latencies and the "knee" came out
at the maximum — a straight diagonal, recommendation useless. Real
workloads have a dominant slow call (there is *always* a slow call), and
the moment I added one, the curve grew its knee. Benchmarks that don't
model the long pole recommend infinity. This is the benchmark version of
regexes-vs-parsers: model the thing that actually dominates or your
tool confidently answers the wrong question.

## Framework notes

- The hook composes: `queue_wait += waited` is the entire integration.
  One float closure, no instrumentation framework. Hooks that run
  inline (now documented!) make accumulation this cheap safe.
- Gantt + knee finder are now a pair: the Gantt shows you *where* one
  run's time went ('.' vs '#'); the knee finder shows you *how the
  budget moves* across limits. Ship both in a `agentic-doctor` gem and
  ops people will send you fruit baskets.

## Verdict

Asked for a hook in round 3, used it to kill a superstition in round 4.
That's the feedback loop working at the speed it should.
