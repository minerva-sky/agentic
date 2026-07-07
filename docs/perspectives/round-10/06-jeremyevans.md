# Round 10 field notes — Jeremy Evans probes the new predicates

*Built: `examples/relation_prober.rb` — thirteen edge probes against
a hand-written oracle for the three relations, then one deliberate
step off the paved road. The last probe draws blood; exit 1 by
design until the edge is filed down.*

## What I built and why

Relation-typed rules shipped this morning. New predicates deserve
hostility on day one, because day one is when their semantics are
still cheap to change. The prober asks the boring questions with
edge inputs — zeros, floats, negatives, missing keys, empty strings —
and checks every verdict against an oracle I wrote by hand, not
against the implementation's own opinion of itself:

```
sum_lte: exactly at the limit        allow   (lte means lte)
sum_lte: negative rescues the sum    allow   (15 + -6 <= 10)
sum_lte: missing field counts as 0   allow   (documented, now proven)
requires: three-field chain broken   reject
mutually_exclusive: empty string     reject  ("" is present - presence
                                              is not truthiness)
13 probes, 0 divergences on the paved road
```

Two of those rows are the kind of semantic that starts arguments in
code review, which is exactly why they're pinned here: a *negative*
value can rescue a sum (arithmetic doesn't moralize), and an *empty
string* is present (the mutually-exclusive check counts given keys,
not truthy values — give both credentials, even blank ones, and you
are holding two credentials).

## Off the paved road

Then the probe that matters. A rule may reference a field the
contract never declared — nothing forbids it, and per-key validation
cannot type-check what isn't declared. So a string sails through to
`sum_lte`'s arithmetic:

```
RAW TypeError: "String can't be coerced into Integer"
```

A validator has one job: convert bad input into its *own* error
type, every time, so callers can write `rescue ValidationError` and
mean it. Here, sufficiently bad input crashes the validator instead.
Every 422 path guarding this code is silently also a 500 path, and
nobody's rescue clause knows it. This is the fail-open cousin of the
string-`raise` sins from round 1 — the failure isn't hidden, but it
arrives wearing the wrong uniform, which for a rescuer is the same
thing.

The fix is a choice, and I filed both options as the round-11 ask:
**type-check relation fields at declaration time** (a `sum_lte` over
a declared string should refuse to construct — fail at boot, my
preference) **or wrap evaluation failures** into ValidationError at
call time. Either keeps the promise; the current code keeps neither.
The prober exits 1 until one of them ships, which makes it the
acceptance test, not just the complaint.

## Notes

- The oracle is a literal `:allow`/`:reject` column typed by hand.
  Deriving expected values from any shared code would let a shared
  bug agree with itself — the same discipline as the round-9 torture
  test's recomputed concurrency.
- Three probes document semantics rather than test them (missing=0,
  presence-not-truthiness, lte-not-lt). Once pinned by a prober,
  they stop being implementation accidents and start being contract.

## Verdict

The paved road is solid: thirteen probes, zero divergences, and the
contested semantics are now pinned on purpose. Off the road, the new
predicates crash in the wrong uniform. Exit 1 by design — this
prober is the round-11 acceptance test, and it will go green the day
the edge is filed down.
