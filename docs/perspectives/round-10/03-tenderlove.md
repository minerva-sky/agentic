# Round 10 field notes — Aaron Patterson reads the meter

*Built: `examples/contract_overhead.rb` — the validator benchmarked
across contract sizes and rule counts, priced as a fraction of the
LLM call it protects.*

## What I built and why

Sooner or later someone says "we skip validation on the hot path,
for performance." That sentence contains a number, and nobody in the
room knows what it is. So: measure. 2,000 validations per row, warm
cache (the first call pays dry-schema compilation — measuring that
would be benchmarking the wrong thing), and the one framing that
matters, which is that **overhead is a fraction**. Everyone quotes
the numerator; the denominator here is an 800ms model round-trip.

```
3 keys, no rules          0.0198ms    0.0025% of the call
10 keys, no rules         0.0411ms    0.0051%
10 keys, 5 relations      0.0600ms    0.0075%
30 keys, 15 relations     0.1426ms    0.0178%
rejection, 5 rules broken 0.7316ms    (the slow path)
```

The whole table rounds to zero. The largest contract I could
pretend was realistic costs a seventh of a millisecond — 0.018% of
the call it guards. Five relation rules add twenty microseconds
over bare keys; relations scale linearly and gently. Skipping
validation "for performance" saves a rounding error and risks
shipping a malformed prompt to a call that *bills you for the
mistake*. That's not an optimization, it's a lottery ticket where
you pay to lose.

## The slow path is the interesting row

Rejection costs 0.73ms — 12x the happy path. That's the exception
plus five rule-violation reports being built, and it's the row I'd
watch in a hostile environment: if an attacker can make you *reject*
cheaply-sent garbage at 0.73ms a pop, the validator is your first
line of DoS absorption, not your bottleneck — but it's worth knowing
that failure costs more than success, because capacity planning on
the happy path is how systems fall over on the sad one.

One measurement note, since benchmarks lie by default: the warm-up
call matters. Cold, the first validation compiles a dry-schema and
costs ~50x the steady state; a naive loop would smear that spike
across the average and report validation as 'slow'. Separate your
one-time costs from your per-call costs or you'll optimize the
wrong one.

## Notes

- Relations were the round-10 worry — "predicates as data" sounds
  like interpretation overhead. The meter says: 4 microseconds per
  relation. Building the lambda from the declaration happens once
  per validation, and it's three hash lookups and a closure. Data
  won.
- The 800ms denominator is conservative. Against a reasoning-model
  call measured in seconds, the fraction gains another zero.

## Verdict

"Can we afford to validate?" was never the question — the question
is whether you can afford not to, and now both numbers are on the
table: 0.14ms against an 800ms call that charges for malformed
input. Validate both doors. The meter says you can afford it.
