# Round 7 field notes — Jeremy Evans certifies the backoff

*Built: `examples/backoff_conformance.rb` — every strategy × jitter
combination, a thousand seeded draws each, checked against the
documented envelope. Nine combinations, nine conformances.*

## What I built and why

Retry timing is a contract: "exponential with equal jitter" *means*
`[0.75·b·2ⁿ⁻¹, 1.25·b·2ⁿ⁻¹]`, and until this round that meaning was
enforced by nothing but the implementation agreeing with itself. The
`rng:` injection shipped, so the contract became testable without
stubbing a single method — hand the policy a seeded `Random`, collect
a thousand delays per combination, check the envelope:

```
exponential  true   [3.000, 5.000]  [3.002, 4.998]  conforms
exponential  :full  [0.000, 4.000]  [0.003, 3.995]  conforms
```

Two properties per combination, because bounds alone are a half-test:

1. **Containment** — no draw escapes the documented envelope. This is
   the safety property; a violation means the docs lie.
2. **Coverage** — the draws *span* at least 80% of the envelope. This
   is the liveness property, and it's the one naive tests skip: a
   buggy jitter that always returns the midpoint stays in bounds
   forever while providing zero herd protection. Perham's stampede
   charts are the *reason* for jitter; coverage is the check that the
   reason is being served.

## Why injection beats stubbing, said once more with feeling

The old way to test this was `allow(orchestrator).to receive(:rand)`
— reaching into an object and replacing its organs. Injection inverts
it: the policy declares "I consume randomness," the test supplies a
seeded source, and *nothing about the object is faked*. The delays
measured here are the delays production would sleep, given that seed.
Tests that exercise real code paths with controlled inputs are worth
ten that exercise fake code paths with real inputs. This is why I ask
every round for effects to become injectable dependencies — clocks
and RNGs first, always.

## Notes

- The epsilon (1e-9) on the containment check is float hygiene, not
  slack: `rand(0.75..1.25)` can return the boundary.
- This file is CI-shaped: exit 1 on violation, seed in ARGV for
  reproduction. It joins the fuzzer, the prober, and the verifier in
  what is now a four-tool honesty suite — contracts, rules, docs, and
  now *timing*.

## Verdict

Nine combinations, nine conformances, two properties each, one seed.
The retry policy's timing promises are no longer folklore backed by
code reading — they're an envelope with a certificate.
