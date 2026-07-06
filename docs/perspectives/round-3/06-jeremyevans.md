# Round 3 field notes — Jeremy Evans fuzzes the boundary

*Built: `examples/contract_fuzzer.rb` — for every registered
capability, generate inputs that should pass and mutations that should
fail, and verify the validator agrees. Deterministic by seed.*

## What I built and why

A validator is a claim: "conforming data passes, violating data does
not." Claims get tested. The fuzzer walks every registered capability's
declared contract and runs three trial families against it:

1. **Conforming inputs must pass** — generated per declared type.
2. **Each required key, dropped, must fail.**
3. **Each typed key, corrupted, must fail** — a number where a string
   was promised, a string where an array was.

Seven standard capabilities, 34 trials, and the verdict I wanted to be
able to print: *the boundary holds*. Both directions matter equally —
a validator that rejects good data breaks working programs, one that
accepts bad data breaks the programs downstream, and only a
bidirectional fuzz distinguishes "strict" from "correct."

## Determinism is the feature

`Random.new(seed)` and every random choice drawn from it, with the seed
printed in the header and settable from ARGV. A fuzzer that can't
reproduce its own failure is a rumor generator. Run it twice, same
verdicts; file a bug with the seed, get the same failure on my machine.
This costs one line and I will die on this hill: **all** randomized
testing should work this way. (I also deliberately fuzz the *validator*,
not `provider.execute` — one of the standard capabilities talks to the
network when executed, and a fuzzer with side effects is a chaos
monkey, which is a different tool with a different consent form.)

## What the exercise says about the framework

- solnic's `CapabilityValidator` passed a test it wasn't written
  against. That's what "the types are load-bearing" means in practice —
  the declarations in `CapabilitySpecification` were precise enough for
  a third party to mechanically derive both the passing and the failing
  cases. Vague contracts can't be fuzzed; these could.
- The fuzzer found no defects *today*. Its value is the exit code: wire
  it into CI and the next person who adds a capability with a mistyped
  contract gets a named trial failure, not a production surprise. Cheap
  insurance is the best kind.
- Gap worth recording: contracts can't yet express constraints beyond
  type and presence — no ranges, no enums, no "non-empty array". The
  fuzzer therefore can't test what can't be said. When contracts grow
  expressiveness, this file is where their honesty gets checked.

## Verdict

Thirty-four trials, zero defects, one exit code CI can trust, and a
reproducibility guarantee. Boring, deterministic, adversarial — the
three virtues of infrastructure testing, in one file.
