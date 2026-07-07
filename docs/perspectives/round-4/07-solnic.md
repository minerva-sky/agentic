# Round 4 field notes — Piotr Solnica types the state machine

*Built: `examples/state_machine.rb` — an order lifecycle where every
transition's guard is an enum predicate on its contract, not an
if-statement.*

## What I built and why

Round 3 closed with Jeremy and me asking for value predicates — enums,
bounds, non-empty. They shipped, so I built the structure that
predicates make possible: a state machine with **no runtime transition
table**. Each event is a capability; its contract declares
`state: {enum: %w[placed]}` as the legal source states; its output
contract declares the destination. The topology of the machine lives
entirely in the type layer:

```
deliver  XX cannot deliver from 'cart' (legal from: shipped)
place    -> now 'placed'
cancel   XX cannot cancel from 'shipped' (legal from: cart, placed)
journey: cart -> placed -> shipped -> delivered
```

An illegal move isn't a branch that returns false — it's input that
*never type-checks*, and the violation arrives with the legal
alternatives attached. Guards-as-contracts means the machine's `fire`
method contains zero domain logic: look up, execute, rescue. Every
state machine library you've used is a DSL for generating exactly the
checks these contracts now express declaratively.

## The detail I'm most pleased by

The **output** enum: each transition declares
`outputs: {state: {enum: [rule[:to]]}}` — a single-element enum, i.e.
"this transition produces exactly this state." While iterating I fat-
fingered a rule to return the event name instead of the target state,
and the *output* contract caught my own machine misbehaving before any
test did. Transitions that can't lie about where they land are the
difference between a state machine and a state suggestion.

## What this exposes about the seam

- Enum violations report `state violated` with dry-schema's default
  message. Serviceable, but the *legal values* live in my rescue block,
  reconstructed from the transition table. The violation payload should
  carry the predicate's expectation (`included_in?: [...]`) so callers
  don't need side-channel knowledge to render a good error. Small
  addition to `ValidationError`, big ergonomic win.
- Missing predicate, noted for round 5: cross-field constraints
  ("`express` shipping requires `quantity <= 10`"). Single-key
  predicates cover 80%; the remaining 20% is where dry-validation's
  rules (not just dry-schema) would enter.

## Verdict

Asked for predicates in round 3; in round 4 they replaced an entire
category of control flow. That's the test of a type-layer feature —
not "can it reject bad data" but "what code does it delete." Here it
deleted the case statement every state machine is built on.
