# Round 11 field notes — Avdi Grimm builds the barricade

*Built: `examples/confident_pipeline.rb` — one pipeline, two
postures: ten conditionals of timidity versus a contract at the
door, then both fed the same garbage so the difference is behavior,
not aesthetics.*

## What I built and why

Timid code is easy to recognize once you hear it read aloud: it's
all subordinate clauses. *If the order isn't nil, and if the items
are an array, and if the price responds to arithmetic, then perhaps
we might total it.* Every method re-litigates reality because it
trusts nothing — including the methods it just called. The narrative
voice of the code is a worried mumble.

```
timid:       10 conditionals, 24 lines
confident:    0 conditionals,  9 lines
```

The confident version isn't brave; it's *organized*. All the doubt
is pushed to one barricade — a capability contract validated at the
input door and (this matters) at the output door too, because
honesty is also a promise about what you return. Inside the
barricade, every line is a declarative sentence about data that is
known to be shaped: `order[:items].sum { ... }`. Indicative mood.
No hedging. The `fetch(:qty, 1)` is the one permitted courtesy — a
*declared default*, which is confidence about optionality, not fear
of it.

## The laundering demonstration

The comparison that matters isn't line count — it's what each
posture does with garbage. Fed an order with a nil price and an
empty email:

```
timid:     {total_cents: 0, delivery: "no receipt"}
confident: raises ValidationError - email rejected AT THE DOOR
```

Look closely at the timid answer. It's polite. It's well-formed.
It's *wrong* — zero dollars and no receipt, delivered with full
confidence to whatever ledger consumes it. All those nil checks
didn't handle the bad input; they **laundered** it, converting a
detectable error into a plausible lie. `return nil if` is not error
handling — it's error *forwarding*, with the sender's address torn
off. Some downstream system now owes a customer an explanation, and
the stack trace that would have named this method is gone.

The confident version says no, out loud, at the door, with the
field names attached. Failure at the barricade is cheap, local,
and honest. Failure past the barricade is a mystery novel.

## Notes

- The conditional count is computed from this file's own source at
  runtime — the example won't drift into claiming a difference it
  no longer exhibits.
- The contract can't see inside array items (a nil price sails to
  the output door, where the *output* contract would catch a
  non-numeric total). Item-level schemas would deepen the barricade;
  worth a future ask if list-shaped inputs become common.

## Verdict

Confidence isn't optimism — it's pushing all the doubt to the
boundary, where it can say no out loud. One barricade bought back
ten conditionals, and more importantly it converted a laundered lie
into an honest rejection. Write the happy path like it's happy;
make the door do the worrying.
