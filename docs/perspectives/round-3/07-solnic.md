# Round 3 field notes — Piotr Solnica builds a typed command bus

*Built: `examples/command_bus.rb` — commands are composed capabilities
with their own declared contracts; the bus is validation plus routing
and nothing else.*

## What I built and why

In round 2 I flagged one gap: `registry.compose` fused capabilities
into pipelines but the *composition itself* had no contract — types
everywhere except the seam users actually touch. That gap was closed in
the roadmap release (`compose(..., inputs:, outputs:)`), so I built the
pattern that gap was blocking: a **command bus** where every command is
a composition with a contract of its own.

`PlaceOrder` composes `reserve_stock` + `record_entry` and declares
`{sku: string, quantity: number}` in, `{accepted: bool, events: array}`
out. Dispatching is four lines: look up the provider, execute, rescue
`ValidationError` into a rejection event. The run shows the shape I
care about most:

```
REJECTED PlaceOrder(sku: "widget", quantity: "many")
         -> CommandRejected: quantity must be Numeric
REJECTED PlaceOrder(sku: "widget", quantity: 13)
         -> OrderRejected: insufficient stock for widget
```

Two rejections, two *different layers*, both named. The contract
stopped `"many"` before any handler ran — the stock count never even
got read. The domain stopped 13 after consulting the shelf. **Types
stop nonsense; domains stop mistakes.** When those two rejections flow
through one undifferentiated `rescue => e`, every command handler
reimplements the difference badly; when the boundary is a typed
artifact, the bus does it once.

## Notes from building on the improved seam

- The composed contract validates *both directions*: while iterating I
  briefly returned `events: "OrderPlaced"` (a string, not an array) and
  the composition's own output contract caught my handler in the act.
  Compositions that police themselves are what I asked for; it is
  pleasant to be the first customer.
- The bus needed no bus class. Registry lookup *is* routing; contract
  validation *is* input handling; the whole dispatch mechanism is a
  method. When infrastructure disappears into the type layer, that's
  usually the sign the type layer is placed correctly.
- Remaining wish, carried over from Jeremy's fuzzer notes: contract
  expressiveness. `quantity: number` accepts `-3`, and no declared type
  can currently say "positive integer" or "one of :standard, :express".
  Predicates on declared keys (dry-logic is *right there*) would let
  the boundary absorb another band of what is currently handler code.

## Verdict

Round 2 the pipeline had typed stages and an untyped whole; round 3
the whole has a contract and a four-line bus makes it a system.
Boundaries first, then the pattern falls out — every time.
