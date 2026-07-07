# Round 7 field notes — Andrew Kane runs the evals

*Built: `examples/capability_evals.rb` — golden test cases against
registered capabilities, scored and gated. One capability has a bug
the contracts can't see; the evals catch it.*

## What I built and why

Seven rounds of contract machinery check that outputs have the right
*shape*. Evals check the right *substance* — and the seeded bug shows
why both layers exist:

```
extract_amount   1/3 (33%) BELOW THRESHOLD
  FAIL "you owe $12.50 by friday"
       expected {:cents=>1250}, got {:cents=>1200}
```

`{cents: 1200}` is a perfectly contract-valid answer — number, present,
positive. It's also *wrong by fifty cents*, because the parser drops
the decimal. No type system catches a plausible lie; only a golden
case does. That's the whole ML-in-production lesson compressed:
**contracts check types, evals check truth, and the failures that hurt
are always in the gap between them.**

This matters double for this gem specifically: every capability here
is designed to be swapped from lambda to LLM (it's been the pitch
since my round-2 notes). The eval suite is what makes that swap
*safe* — change the implementation, rerun the goldens, read the score.
Same cases, new brain, numeric verdict. Nobody should ship a model
swap on vibes.

## Design choices worth stealing

- **Evals live next to the capability name, not the implementation** —
  the suite is a property of the *interface*, so it survives every
  implementation change. That's also why the expected values are
  subsets (`expect.all? { actual[key] == expected }`): implementations
  may return extra keys; goldens pin only what's promised.
- Per-capability pass rates plus a suite score with a threshold and
  exit code — the shape CI wants. classify_sentiment at 100% doesn't
  excuse extract_amount at 33%; averages hide, per-capability tables
  testify.
- For LLM-backed capabilities the equality check becomes a scorer
  (exact / contains / judge-model), but the harness shape doesn't
  change. Start exact, loosen deliberately.

## The honesty-suite census, seven rounds in

Fuzzer (types), prober (rule declarations), verifier (docs),
conformance (timing), agreement proof (schema export), and now evals
(substance). Six referee tools, all exit-code-gated, all built on the
gem's own primitives. The framework can no longer lie to you about
its contracts, its docs, its timing, or — as of today — its answers.

## Verdict

The gap between "valid" and "correct" now has a test suite. That's
the last gap that matters, and it's the one every team skips until
the fifty-cent bugs compound into a refund queue.
