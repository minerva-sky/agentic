# Round 5 field notes — Jeremy Evans opens the freight desk

*Built: `examples/freight_rules.rb` — a quoting capability whose
tariff policy is written as cross-field contract rules; broken rules
are reported all at once, nonsense never reaches them.*

## What I built and why

The cross-field rules Piotr and I asked for shipped this round, so I
built the workload that motivated the ask: a tariff book. Freight
policy is inherently cross-field — "hazardous cargo may not fly" is a
relationship between `mode` and `hazardous`; no per-key check can say
it. Four rules on the contract, five manifests through the desk:

```
#3 REFUSED - 3 rule(s) broken:
     - air freight is limited to 500kg
     - hazardous cargo may not fly
     - insured value over 100k requires sea mode
#5 MALFORMED - mode, weight_kg, destination invalid
   (never reached the tariff book)
```

Two properties I care about, both verified:

1. **All broken rules at once.** Manifest #3 violates three policies
   and hears about all three. First-failure reporting turns a manifest
   correction into a submit-fail-submit-fail scavenger hunt — three
   round trips where one suffices. The implementation runs every rule
   and collects; that's the only correct behavior.
2. **Layering.** Manifest #5 (`mode: "teleport"`, negative weight,
   empty destination) is rejected by per-key validation and the rules
   never run. This is a *soundness* requirement disguised as
   politeness: rule predicates dereference fields
   (`i[:weight_kg] <= 500`), and running them against garbage yields
   NoMethodErrors or — worse — accidental passes. Types first, then
   relationships. The validator sequences it correctly.

## What I'd note for round 6

- Rules are keyed by their description string, which doubles as the
  error message. Good for humans; for machine consumers (Piotr's form
  renderer next door) a structured `{rule: :air_weight_limit,
  message: "..."}` pair would version better. Strings are UI; symbols
  are API.
- My round-3 fuzzer can't fuzz rules — a lambda is opaque to input
  generation. That's an acceptable trade (expressiveness beat
  analyzability here, correctly), but it means rule-bearing contracts
  need hand-written property tests. The freight desk's five manifests
  are that, in miniature.

## Verdict

Policy as data on the contract, checked in the right order, reported
in full. The tariff book and the validation are now the same artifact
— which means the policy can't drift from its enforcement. That's the
property every compliance system claims and almost none have.
