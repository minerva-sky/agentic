# Round 12 field notes — Sarah Mei gives the house tour

*Built: `examples/onboarding_trail.rb` — a nine-room reading tour of
the gem, ordered by the code's own who-mentions-whom so no stop
assumes a concept you haven't met, with one human sentence per room.*

## What I built and why

We talk about codebases like they're texts, but people don't *read*
codebases — they **live** in them. And when someone new moves in,
what they need isn't a blueprint (the file tree already is one); it's
a tour: which room to enter first, and why each room makes sense
given the ones you've seen. Nobody's first question is "where is the
scheduler?" It's "what should I read *first* so the rest makes
sense?"

So the trail computes that ordering from the code itself — scan each
core file for mentions of the others, then repeatedly visit the room
with the fewest unmet concepts:

```
1. task_failure        how this house talks about things going wrong
2. task_result         the envelope every outcome arrives in
3. relation_rules      predicates as data
...
8. plan_orchestrator   the living room where everything meets
9. execution_journal   the house's memory
```

## The house's values, visible on day one

The trail starts with `task_failure`, and I want to sit with that,
because it isn't a quirk of the sort — it's the house telling you
who it is. This codebase defines *how it talks about things going
wrong* before it defines work, scheduling, or success. A new
teammate who reads room 1 has learned the house's **values** —
failure is data here, not an exception in both senses — and values
are the thing onboarding docs always mean to convey and never do.

The other design choice I'll defend: the one-line room notes are
**human-written**, and everything else is derived. That's the
correct split. Structure is derivable (and should be, so the tour
never rots); *purpose* isn't — "the house's memory" is a sentence
only someone who lives here can say. Fully-generated docs are
accurate and useless; fully-handwritten docs are useful and stale.
The livable version is a derived skeleton wearing human sentences.

## Notes

- The trail prints a WARNING if the ordering ever visits a room
  before its concepts — an honesty check on its own heuristic. Today
  it's silent; the day someone adds a circular mention, the tour
  itself will complain, which is how documentation should break:
  loudly, at generation time.
- Line counts ride along on purpose (`plan_orchestrator: 731`).
  Telling a newcomer room 8 is 7x the size of room 2 sets pacing
  expectations — tours that hide the mansion's one enormous room
  produce lost guests.
- What I'd add with more rounds: the *social* layer. Which rooms
  change most often (git churn) is where the household actually
  lives; a tour that ends "and this room is under renovation, ask
  before moving furniture" is a tour of a real home.

## Verdict

A map answers "where"; a trail answers "in what order will this make
sense" — and the second question is the one every new teammate is
actually asking. Codebases are places people live. Give the new
roommate a tour, point out where the house keeps its values, and
mention which rooms are big before they open the door.
