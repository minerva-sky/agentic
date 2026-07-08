# Round 17 field notes — Richard Schneeman opens the assembly clinic

*Built: `examples/assembly_doctor.rb` — syntax_suggest for plans.
A broken deploy plan gets a diagnosis instead of a stack trace: the
typo'd edge shown with a caret and a did-you-mean, the cycle shown
as the loop itself. Then the repaired plan runs, because doctors
get audited too.*

## What I built and why

Round 12 I priced `require`. This round's brief said build an
*experience*, and the experience I care most about is the worst one
software offers: failing. syntax_suggest exists because "syntax
error, unexpected end-of-input" is technically true and humanly
useless — it names the symptom and hides the street address. Plans
fail the same way one abstraction up. Reference a task that doesn't
exist and you get a KeyError at execution; wire a cycle and you get
a hang. Both messages are true. Neither helps at 5pm:

```
Unmatched dependency, in step 5:
     4  "fetch metadata"
  >  5  "upload assets"  after: "fetch metdata"
                                ^^^^^^^^^^^^^^^ no step has this
                                name (did you mean fetch metadata?)

Dependency cycle - the plan can never start:
  >  run migrations -> verify health -> restart app -> run migrations
     every member of the loop waits for another member. one of these
     edges is aspirational, not structural - probably the newest one.
```

syntax_suggest's rules translate directly: report the **smallest
region that explains the failure** (the one bad edge; the whole
loop — never just one member), show the *code* with an arrow rather
than a trace, and when the system is holding the list of valid
names — it always is — spend one Levenshtein pass turning the
diagnosis into a one-keystroke fix. The framework met me halfway:
`Agentic::Suggestions` (round 15's infrastructure) supplied the
did-you-mean, so the doctor's cleverest line was one call.

## Notes

- The cycle message editorializes on purpose: "probably the newest
  one." Diagnosis without a suggested next action is a lab report,
  not a doctor. syntax_suggest points at the block it thinks you
  should read first; same energy.
- The example ends by fixing both wounds and *running* the repaired
  plan — a doctor whose "all clear" precedes a crash is worse than
  no doctor, so the all-clear is itself asserted.
- The right home for this is inside the framework's own assembly
  errors: `execute_plan` on an unknown dependency could render
  exactly this snippet. The pieces (graph, Suggestions) are all
  public; the doctor is 60 lines of glue.

## Verdict

Two classic wounds, two humane diagnoses, one repaired plan running
green. People don't quit because programming is hard; they quit
because failure is rude. The framework already knows everything the
doctor prints — the product is deciding the user deserves to hear
it.
