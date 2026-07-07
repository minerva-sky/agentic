# Round 7 field notes — Sandi Metz writes the style guide

*Built: `examples/graph_style.rb` — RuboCop for plans: four cops with
thresholds and reasons, run against a tidy graph and a messy one.*

## What I built and why

My critic (round 4) reviewed one plan; my receipts (round 6) tracked
one refactoring. A team needs neither — it needs a *style guide*,
because style guides argue once, in a config, instead of in every
review. Four cops, each with a threshold and — this part is not
optional — a **why**:

```
Graph/MaxDepth:     present sits 6 deep (limit 4)
Graph/NamedFanIns:  funnel joins 4 but 4 edges are unnamed - use needs:
                    (a join you can't name is a join you don't understand)
```

`NamedFanIns` is the cop I built this example for. It lints
*vocabulary*: any join of two or more dependencies must name them via
`needs:`. The rationale is the same one I give for keyword arguments
over positional — at arity two, order starts lying to you — but
here the names do double duty, because Xavier showed us (round 5)
that `needs:` labels become documentation and diagram edges. A
style rule that improves comprehension AND tooling output is the
kind you can actually get a team to adopt. Note the messy plan's
funnel commits two offenses at once: too wide AND unnamed. Wide
anonymous joins are how plans become haunted houses.

## On thresholds, honestly

MaxDepth 4 and MaxFanIn 3 are *this example's* taste, not laws — the
closing line says so out loud. The failure mode of every style guide
is thresholds mistaken for physics; the value is never the number,
it's that the number is **written down**, so disagreement becomes a
one-line diff and a conversation instead of a review-thread war. (My
own rules — five lines, four arguments — were always conversation
starters wearing the costume of commandments. It said so in the book;
nobody reads that page.)

## Framework note

Every cop reads precomputed facts: `stats[:max_depth]`,
`stats[:depth]`, edge labels. Since `graph[:stats]` shipped (my
third-strike ask, round 7 release), a cop is now a *predicate plus
prose* — ten lines each. When adding a lint rule costs ten lines,
teams write their own; when it costs a graph traversal, they don't.
API convenience isn't a luxury; it's the difference between a tool
and an ecosystem.

## Verdict

Critic, receipts, style guide — see the smell, fix the smell, prevent
the smell. The trilogy is complete, each layer cheaper than the one
before it, which is the correct direction: prevention should always
be the cheapest.
