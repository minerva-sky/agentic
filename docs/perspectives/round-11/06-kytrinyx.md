# Round 11 field notes — Katrina Owen runs the kata

*Built: `examples/plan_kata.rb` — red, green, refactor for a plan:
five structural assertions written before any task exists, the
smallest additions that move red lines green, two deliberate sins
caught by name, and a rebuild that ends all-green.*

## What I built and why

When I teach TDD, the resistance is never to the tests — it's to
writing them *first*, before you're attached to a design. So the
kata starts where katas should: an empty plan and five assertions
about a plan that doesn't exist yet. One entry point. One
deliverable. Joins that name their inputs. Nothing deeper than four
stages. No orphans.

```
empty plan                     -> 2 red   (the honest starting point)
add the entry point            -> 0 red
add parse                      -> 0 red
bolt on a price feed (2 sins)  -> 2 red   (caught, and NAMED)
rebuild: one entry, labeled    -> 0 red
```

The step that earns the kata its keep is the fourth. "Bolt on a
price feed" is exactly how real plans degrade — a second source
lands as a second root, its join lands unlabeled, and in a
review-free world both would compost quietly into architecture. The
assertions objected *by name*: "has exactly one entry point: RED,"
"every join names its inputs: RED." Tests written before anyone was
defensive about the design critique it without a meeting.

Notice also what the assertions are written against: `stats[:roots]`,
`stats[:leaves]`, labeled edges, `max_depth`. The reflection API is
what makes plan-TDD *possible* — you cannot assert on what you
cannot observe cheaply.

## What the refactor step taught

The green-to-green refactor — dissolve the accidental second root by
routing both feeds through one door — required **rebuilding the
orchestrator from scratch**, because plans are add-only: there is no
`remove_task`, no rewire. The kata absorbs this gracefully (plans
here are cheap to rebuild, and cheap-to-rebuild is itself a virtue
worth practicing), but it's a real gap: refactoring under a green
suite is the entire payoff of having the suite, and today the only
refactoring move is demolition. Filed as the round-12 ask:
`remove_task` or a rewire seam, so a plan can change shape without
losing its identity.

## Notes

- Each step adds the *smallest* thing that moves a line. The
  discipline looks pedantic on a six-task plan and becomes the only
  thing that works on a sixty-task one — step size is a skill you
  practice when it's easy so you have it when it isn't.
- Two of the five assertions are borrowed lessons: "no orphans" is
  zenspider's 5.0-point smell as a boolean, and "joins name inputs"
  is the round-8 spec generator's premise inverted into a gate.
  Katas should steal from the room.

## Verdict

Plans can be test-driven: assert on structure first, grow in
smallest steps, let the reds name your sins while you're still
cheap to persuade. The one missing move — refactor without
demolition — is now on the asks list, with a kata as its acceptance
test.
