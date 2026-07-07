# Round 14 field notes — Soutaro Matsumoto writes the types down

*Built: `examples/rbs_export.rb` — RBS signatures generated from
capability contracts, with optionality projected as `?`-keys and an
agreement spot-check against the validator.*

## What I built and why

The hardest part of bringing types to Ruby was never the type
system — it was that the truth about types lives scattered in
runtime code, and asking people to write it down *twice* (once in
checks, once in sigs) guarantees the two copies diverge. But this
framework's capability contracts already ARE the truth, validated on
every call. RBS is that same knowledge written down for tools that
*read* instead of run:

```rbs
class QuoteShippingCapability
  def call: ({ mode: String, weight_kg: Numeric,
               ?express: bool, ?customs_code: String } inputs)
         -> { price_cents: Integer, carrier: String }
end
```

Generated, not written. Steep and an IDE can now check every caller
of this capability before anything executes — misspelled keys,
wrong types, forgotten requireds all become editor squiggles instead
of 422s.

## Shape versus law

The design decision worth recording is what the RBS does *not*
carry. `mode`'s enum, `weight_kg`'s bounds, the cross-field rules —
none project into the signature, and the generated comment says so:
**RBS carries the SHAPE, the validator carries the LAW.** This is a
principled line, not a limitation shrug: shape is what's decidable
statically (keys, types, optionality — note `required:` projecting
as the presence/absence of `?`, which is exactly RBS record
optionality semantics); law needs *values* to judge. A signature
that tried to encode `max: 5000` would be lying about what checkers
check. The two layers are projections of one declaration, which is
why they cannot drift the way hand-written sig files against
hand-written validations always, always do.

And because two projections of one truth is exactly the situation
where round 10 taught this repo to demand proofs, the export
spot-checks itself: omit a `?`-marked key, the validator accepts;
omit an unmarked key, the validator rejects. Two points don't prove
the projection, but they pin its corners, and the exit code makes
the pin permanent.

## Notes

- `Array[untyped]` for array inputs is honest poverty: the contracts
  don't declare element types yet. If they ever grow
  `items: {type:}` (the round-11 Avdi note about list-shaped
  inputs!), the generator upgrades to `Array[String]` in one line —
  declarations compound again.
- Generated class-per-capability is a naming choice for the demo;
  real integration would emit one .rbs file per registered
  capability into sig/, run steep in CI, and let the type checker
  meet the validator at the same source.

## Verdict

The contracts already knew their types; now they're written down
where tools can read them, with the shape/law boundary drawn on
purpose and spot-checked by exit code. Gradual typing works when
the types come from where the truth already lives — and here, it
already lived in the right place.
