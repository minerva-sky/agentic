# Round 10 field notes — Piotr Solnica diffs the laws

*Built: `examples/relation_diff.rb` — semver classification for the
rules themselves: tightened limits, widened demands, changed laws,
added and removed rules, and the one honest shrug that remains.*

## What I built and why

My round-8 semver advisor ended every report with a qualifier I
hated: "3 breaking changes *in the declarations*." Rules were
lambdas; a diff cannot see inside a lambda; so the most dangerous
class of contract change — policy — was invisible to the one tool
whose job is noticing change. I filed the ask in round 9, the
relations shipped this morning, and this example is the payoff:

```
BREAKING   rule :fits limit tightened 6000 -> 4000
BREAKING   rule :customs now also demands incoterm
BREAKING   rule :one_auth changed LAW: mutually_exclusive -> requires
BREAKING   rule :speedy added - a new law callers never agreed to
OPAQUE     rule :audited is a lambda in both versions
COMPATIBLE rule :legacy removed
verdict: 4 breaking rule changes -> major version bump
```

The classification logic is the same variance reasoning as round 8,
now applied one level up. Rules constrain *inputs*, so they break
when they *tighten*: a lower `sum_lte` limit rejects previously
legal calls; a `requires` that demands one more field fails callers
who satisfied v1; a new rule is a law existing callers never agreed
to. Removal is the loosening direction — every v1-legal call stays
legal — so it's compatible, however alarming a deleted rule looks in
review.

## The law-change row

The subtlest classification is `:one_auth`: same rule id, same
fields, but the relation flipped from `mutually_exclusive` to
`requires`. That's not a tightening or a loosening — the two laws
aren't even comparable on one axis ("give at most one" versus "if
one, then both"). The diff refuses to arithmetic it and says what it
is: **a new contract wearing an old name**, breaking by definition.
Tools that force every change onto a tighter/looser spectrum
misclassify exactly these, and these are the ones that page you.

And the lambda rule still gets the shrug — `OPAQUE, presumed
breaking` — but the meaning of that shrug has inverted. In round 8
it was a ceiling on the tool; now it's a *choice made per rule*. If
`:audited` mattered to your consumers, you'd declare it as a
relation and it would join the diff. Opacity is now opt-in, which is
the correct default for escape hatches.

## Notes

- Presumed-breaking for opaque rules is the only safe default: a
  diff that can't see a change must not certify its absence. The
  advisor's job is to be conservative exactly where it is blind.
- Fourth derivation tool from the rules metadata in two rounds
  (validation, generation, projection, now diffing) — the same
  compounding the field declarations showed in rounds 5-8. Predicates
  as data pays the same rent schedule.

## Verdict

The last opaque corner of the contract now diffs. "Is this breaking?"
covers the declarations *and* the laws over them, with one
honestly-labeled shrug remaining — and even the shrug is a choice
now, not a limitation.
