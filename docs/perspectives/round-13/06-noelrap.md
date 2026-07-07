# Round 13 field notes — Noel Rappin counts it in cents

*Built: `examples/money_discipline.rb` — one invoice priced two
ways: floats (the demo arithmetic) versus integer cents with a Money
value object, a named rounding policy, and a books-must-balance
rule. The contract can only be signed by one of them.*

## What I built and why

I wrote a whole book about payment code because every money bug in
production is the same three bugs wearing different tickets: floats
for currency, rounding decided by whoever's line got there first,
and totals that "should" add up instead of being *made* to. The
invoice here isn't contrived — API calls at $0.10, storage at
$29.99 — and the float column confesses immediately:

```
              float version              ledger version
subtotal      230.19999999999999         $230.20
tax           18.99150000000000          $18.99
total         249.19149999999999         $249.19
```

That `...999999` tail is IEEE 754 paying out interest: 0.1 × 3 is
not 0.3 in binary and never was. Today it rounds to the right
penny; at some other quantity or tax rate it won't, and the
discrepancy will surface in a reconciliation report eleven months
from now, assigned to whoever touched the code last. Money bugs
are the *slowest* bugs — that's what makes them expensive.

## The three sentences of discipline

1. **Money is integer cents — and cents are a type.** The contract
   declares `total_cents: {type: "integer"}`, which means the float
   version *cannot sign it*. That's not pedantry; it's a tripwire.
   A validator that accepts "number" would wave 249.19149999 through
   and the lie becomes load-bearing; "integer" makes the type system
   an accountant.
2. **Rounding is a named policy applied at declared points.** The
   Money object rounds banker's-style (`half: :even`) at
   multiplication — one place, one policy, greppable. The float
   version rounds wherever printf happens to be standing, which
   means the invoice PDF, the database row, and the payment gateway
   can each round differently. Three documents, three totals, one
   angry customer.
3. **The books balance by rule, not by hope.** The `adds_up`
   structured rule — total equals subtotal plus tax, to the penny —
   runs on every output. It sounds tautological until the day
   separate rounding paths make it false, which is exactly the day
   you want a ValidationError instead of a reconciliation project.

## Notes

- The Money struct is deliberately tiny — closed arithmetic (`+`
  returns Money, `*` rounds by policy), one formatter. The moment
  money leaks out as bare numerics, every call site re-decides the
  three questions the value object exists to answer once.
- Real systems add currency codes and allocation (splitting $10
  three ways without losing a cent). Both slot into the same value
  object; neither rescues you if the foundation is floats.

## Verdict

The same plan ran both arithmetics; only one could sign the
contract. Integer cents, named rounding, balance-by-rule — three
sentences of discipline, enforced by a schema instead of a code
review memory. Take my money — but count it in cents.
