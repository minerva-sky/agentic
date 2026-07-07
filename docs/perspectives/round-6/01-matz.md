# Round 6 field notes — Matz narrates breakfast

*Built: `examples/plan_tour.rb` — any plan, narrated as prose from
`graph[:order]` and `graph[:edges]`, before anything runs.*

## What I built and why

I asked for `graph[:order]` so map-drawers could be correct on purpose;
it arrived, and the first thing I built with it is the oldest debugging
technique there is — **reading your program aloud**:

```
First, boil the kettle.
Meanwhile, slice the bread.
After "boil the kettle": soft-boil the eggs.
After "soft-boil the eggs" (your protein), "toast the bread" (your
  crunch) and "steep the tea" (your comfort): plate everything.
```

Every word is generated: "First" is the order's head, "Meanwhile" is a
root task appearing later in the order, "After X:" is an edge, and
"(your protein)" is a `needs:` label surfacing as *purpose*. If the
prose sounds wrong — if breakfast steeps the tea before boiling the
kettle — the plan is wrong, and your ears caught it while the stove
was still cold. Eyes skim structure; ears parse sequence. Rubber-duck
debugging works because speech serializes thought, and now the
framework serializes the plan for you.

## Confession, in the round's tradition

My first narrator said "Once you boil the kettle is done" — I tried to
inflect English with a regex and produced grammar only a parser could
love. Aaron's law extends past Ruby: *don't parse natural language
with regexes either, not even outbound.* Quoting the task names
verbatim ("After \"boil the kettle\":") is humbler and better — the
narration frames; the plan speaks in its own words. (This is also,
quietly, the correct division of labor for the LLM upgrade: let a
model smooth the prose, but generate the *skeleton* from the graph so
the sequence can never be hallucinated.)

## Small notes

- `order` + `edges` is the whole API surface this needed. Two rounds
  ago this program would have been mostly graph traversal; now it is
  mostly sentences. The framework's share of my programs keeps
  shrinking, which is the trend line I care about most.
- The `needs:` labels reading as "(your protein)" delighted me — the
  consumer named the dependency for code clarity in round 3, and by
  round 6 the same name explains the *cuisine*. Names are the gift
  that keeps arriving.

## Verdict

The plan can draw itself (round 5) and now speak for itself (round 6).
Next it should probably listen — but that's another round.
