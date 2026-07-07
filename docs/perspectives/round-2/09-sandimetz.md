# Round 2 field notes — Sandi Metz builds the Refactoring Dojo

*Built: `examples/refactoring_dojo.rb` — three critic agents review a
method from three distinct perspectives in parallel; the sensei
prescribes exactly one next step.*

## What I built and why

A dojo, because review is a practice, not a gate. Three critics, three
*genuinely different* ways of seeing: the **rule keeper** counts (lines,
parameters — my rules are shorthand for "would you have to scroll to
lie about this method?"), the **squint tester** looks at shape (changes
in indentation are changes in concept), and the **name watcher** reads
the words (a `result` that appears nine times is a name refusing to
tell you what it holds). Each critic is an agent with one capability;
the orchestrator convenes the circle in parallel.

Today's student, fittingly, is the gem itself — `schedule_task`, the
90-line second-place finisher on Aaron's suspects list:

```
rule keeper:   90 lines; the rule is five.
squint tester: 5 levels of shape change - each ridge is a concept
               asking for its own method.
name watcher:  'result' appears 9x - a name that could mean anything
               means nothing.
```

And the part I care most about — the sensei returns **one** step, not
three. A review that hands you every finding at once is a wall; a
practice hands you the smallest safe move and says "come back."
Refactoring is many small safe steps, not one brave rewrite.

## What building with it taught me

- Multiple-perspective review is what this framework's *architecture
  documents* promise (the CriticFramework, multi-perspective
  evaluation), and here's the encouraging news: the primitives that
  exist — agents, capabilities, parallel tasks — were enough to build it
  in a page. The vision isn't vaporware; it's an afternoon of
  composition away. The documents should point at working code like
  this instead of at unbuilt hubs.
- The critics measure; they do not opine. Deterministic critics agree
  with themselves tomorrow, which is what makes them teachable — a
  student can predict the critic, and predicting the critic IS the
  lesson internalized. (An LLM critic belongs in the circle too, but as
  a fourth voice, not the referee.)
- I'll say the quiet part about the adapter one more time, gently: my
  `Dojo` provider found each critic by matching `task.description`
  against an agent's name — string-keyed identity for objects I was
  holding in my hand. Six of us have now written this same workaround.
  The framework is being told something by its users; the polite thing
  is to answer.

## Verdict

The gem let me express a event-of-practice — circle convenes, sees
differently, prescribes smally — in code a workshop attendee could read
over coffee. That's the test of a framework's vocabulary: can you teach
with it. You can.
