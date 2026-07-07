# Round 6 field notes — Jeremy Evans probes the rules

*Built: `examples/rule_prober.rb` — now that rules declare their
fields, that declaration is a testable claim. One seeded rule lies
about what it reads; the prober catches it in 71 of 300 trials.*

## What I built and why

In round 5 I wrote that rule lambdas were opaque to fuzzing — "an
acceptable trade." The structured-rules release quietly changed the
trade: `fields:` is a *claim about the lambda's data dependencies*,
and claims can be audited. The probe is metamorphic testing at its
simplest: generate a conforming application, record the rule's
verdict, perturb a field the rule does NOT declare, and check the
verdict didn't move. Three hundred trials per rule, seeded:

```
affordability:            honest
subprime_needs_cosigner:  honest
jumbo_screening:          LYING - declares [:amount] but its verdict
                          flipped when :score changed (71/300 trials)
```

`jumbo_screening` reads `:score` off the books. And the harm is
concrete, not aesthetic: Piotr's 422 renderer highlights *declared*
fields, so this rule sends a user to fix `:amount` while the actual
problem — their credit score — sits unhighlighted on the form. A lying
declaration turns a helpful error into a misdirection. That's a
correctness bug in the UX, planted two layers away from any UI code.

## Methodology notes

- Perturbations draw from the same conforming generator as the
  originals, so a flip can never be blamed on invalid data — the probe
  isolates exactly one variable. Fuzzing 101, still worth stating.
- 71/300 flips, not 300/300: the lie only surfaces when
  `amount > 400k` AND the score perturbation crosses 700. Partial
  sensitivity is exactly why eyeballing rules doesn't find this —
  probabilistic bugs need volume, volume needs automation, automation
  needs a seed.
- The exit code makes it CI: `rule_prober` alongside the contract
  fuzzer (round 3) and the README verifier (round 4). The honesty
  suite now covers types, promises, and — new — *declarations*.

## The observation about API design

Nobody designed `fields:` as a testability feature. It shipped (round
6 release) as UI plumbing — "let the 422 highlight widgets." But any
declaration, once machine-readable, becomes a specification you can
check the implementation against. This is the recurring miracle of
typed metadata: **write down what you believe and the tests write
themselves.** It's why I keep asking every round for more things to
be data.

## Verdict

Three rules audited, one liar caught, one seed to reproduce it. The
declarations are honest now — and more importantly, they're *kept*
honest by a forty-line program any CI can run.
