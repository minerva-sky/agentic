# Round 9 field notes — Piotr Solnica derives the examples

*Built: `examples/contract_fixtures.rb` — fixtures generated from
contract declarations (minimal and maximal per capability), proved
against their own validator, with a mutant to prove the validator
still has teeth.*

## What I built and why

Every README has an example payload, and every example payload is
lying by the second release. Not maliciously — entropically. The
contract moved and the prose didn't, because nothing *runs* the
prose.

The fix follows from a principle this framework has been converging
on for six rounds: **anything declared can be derived from.** A
declaration rich enough to *reject* a payload is rich enough to
*construct* one:

- `enum:` → its first member (`"air"`)
- `min:`/`max:` → the midpoint (`2500` — legal by construction, and
  visibly *inside* the range rather than tremblingly on its edge)
- `required:` → membership in the minimal fixture
- everything else → a string that names its own key

Two fixtures per capability: **minimal** (required keys only — the
smallest legal call, which is what a new integrator actually wants
to see) and **maximal** (every declared key — what a code generator
wants). Then the part that makes it an engineering artifact instead
of a convenience: the referee validates every generated fixture
against the same contract it came from, and then drops a required
key to prove the validator still rejects things. A generator proved
only against an accept-everything validator has proved nothing —
the mutant is what makes the green checkmarks mean something.

Handwritten examples are promises; derived ones are consequences.

## The blind spot, on the record

`rules:` are predicates, and a generator cannot see inside a lambda.
A fixture that is legal per-field can still violate a cross-field
rule — my midpoint weight and first-enum mode could, in some
contract, be exactly the forbidden combination. The example prints
this caveat in its own output because a derivation tool that
overstates its coverage is worse than none.

This is now the third tool to hit the same wall (Jeremy's prober
works around it dynamically, my semver advisor stated it, now the
generator inherits it), and the shape of the fix is visible:
structured rules already carry `fields:` and `message:`; if the
common cases also carried a machine-readable *relation* (`sum_lte:`,
`requires:`, `mutually_exclusive:`), the generator could satisfy
them and the advisor could diff them. Filing that as the round-10
ask: **relation-typed structured rules** — keep the lambda escape
hatch, but let the declarable majority be declared.

## Verdict

The contract now produces its own documentation examples, and proves
them on every run. Third derivation tool this quarter from the same
metadata (docs, schemas, semver, now fixtures) — when declarations
keep compounding like this, the metadata design has paid for itself
several times over.
