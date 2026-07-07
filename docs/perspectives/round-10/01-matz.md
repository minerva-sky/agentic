# Round 10 field notes — Matz asks before it's an error

*Built: `examples/polite_form.rb` — a form assistant that turns the
contract's declarations into questions: requireds become requests,
bounds become gentle corrections, relations become follow-ups.*

## What I built and why

An error message is just a question you asked too late. A 422 that
says "express requires customs_code" contains a perfectly good
question — *"since you chose express, may I have your customs
code?"* — wearing armor. I wanted to take the armor off:

```
assistant: may I have your mode? (air, sea, road)
assistant: ah - weight must be less than or equal to 5000. shall we adjust it?
assistant: together weight and volume come to 7000, and 6000 is our
           limit - could we lower the volume?
assistant: since you chose express, I'll also need your customs_code
assistant: you've given me api_key and oauth_token - I only need one;
           which shall we keep?
```

Six questions, zero errors shown, and *nothing was written twice*:
every line of the conversation is a declaration read aloud in a
kinder register. `required:` became a request, `max:` a correction,
and — this is the part only possible since this morning — the three
relation rules each became their natural follow-up. `requires` is
"then I'll also need"; `sum_lte` is "could we lower it"; and
`mutually_exclusive` is "which shall we keep?"

## Why relations made this possible

Last round the generator could *satisfy* relations silently; this
round the assistant can *discuss* them, and the difference is the
same one: the predicate is data now. A lambda rule could only ever
say pass or fail — you cannot ask a lambda which field to lower, or
what the limit is, or which two things conflict. The relation
declaration carries all three, so the assistant reads the `fields:`,
the `limit:`, and the relation's own shape, and phrases the question
a human clerk would ask. Omotenashi is anticipating the need before
the failure; it turns out anticipation is a data-model feature.

## Notes

- The engine is a ten-line loop: validate, catch, convert the first
  violation to a question, repeat. Fixed-point politeness. I enjoyed
  that convergence is guaranteed by the same property that makes the
  validator honest — every question, answered, strictly shrinks the
  violation set.
- The `mutually_exclusive` case is the only one where the assistant
  *removes* something rather than requesting it, and it asks
  permission first. Deleting a user's input without asking is the
  form equivalent of clearing their cart.

## Verdict

The contract now has two voices — the strict one for machines (422s,
schemas) and this one for people — and both read from the same
declarations, so they can never disagree. Kindness that stays
synchronized with correctness: that is my favorite kind of feature.
