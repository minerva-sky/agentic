# Round 10 field notes — Sandi Metz counts the consumers

*Built: `examples/rule_shapes.rb` — one policy written three ways
(lambda, structured check, relation), audited by four consumers.
The table is the argument.*

## What I built and why

"Express shipments need a customs code" is one sentence of policy,
and this framework now offers three ways to write it down. When a
system gives you three representations of the same thing, that's
not redundancy — it's a design decision it has politely declined to
make *for* you. So the question worth an example is: how do you
choose?

Not by taste. By **counting who must understand it**:

```
shape             enforced  explains  generatable  projects
lambda            yes       no        no           no
structured check  yes       yes       no           no
relation          yes       yes       yes          yes
```

All three enforce. If enforcement were the whole job they'd be
interchangeable, and style guides would argue about them forever
precisely because nothing real was at stake. But the consumers
differ, and each row is a different answer to "who else gets to
understand this policy?"

- The **lambda** answers one message — `call` — so it has exactly
  one consumer: the validator, at runtime, with real inputs in hand.
  Everyone else (the message deriver, the generator, the schema
  export, Piotr's diff) gets nothing. Code keeps secrets.
- The **structured check** adds `fields:` and `message:` — metadata
  *about* the predicate. Now violations explain themselves and point
  at their fields. Two more consumers, same opaque core.
- The **relation** makes the predicate itself data, and the
  consumers multiply behind your back: tools that never *run* the
  rule can still *read* it. This week alone: Matz asked it as a
  question, DHH projected it into a schema, Piotr diffed it across
  versions. None of those tools existed when the rule was declared.
  That's the tell of a good representation — it keeps answering
  questions it wasn't designed for.

## The principle underneath

This is the same lesson as my duck-agents parade last round, viewed
from the other side. There, a *narrow message contract* let five
shapes of object walk through one seam. Here, a *rich data contract*
lets one shape of rule serve five kinds of consumer. Both are the
same discipline: decide what must understand what, then choose the
representation that makes those dependencies cheap — messages when
behavior should stay private, data when it must be shared.

And the closing caveat matters: save lambdas for policies that are
*genuinely* secrets — the fraud heuristic, the pricing curve. An
escape hatch used by default stops being an escape hatch and starts
being a ceiling.

## Notes

- The four consumer probes are each five lines and behavioral — the
  table's "yes" means a consumer actually extracted value, not that
  a capability was advertised. Audits should run, not read.

## Verdict

Representation isn't style; it's a decision about who else gets to
understand you. Count the consumers, then choose. Code keeps
secrets, data makes friends — and this framework now lets a policy
pick its social life per rule.
