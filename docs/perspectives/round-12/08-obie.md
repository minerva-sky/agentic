# Round 12 field notes — Obie Fernandez ships the editor with the writer

*Built: `examples/self_correcting_output.rb` — the self-correcting
output pattern: contract violations become the correction prompt for
a bounded retry loop. Attempt 1 is what models actually do to
schemas; attempt 2 ships.*

## What I built and why

I've spent the last stretch of my career cataloging the patterns
that separate AI demos from AI *applications*, and this is the one I
reach for first. Every model output that touches a database, an
invoice, or another system WILL eventually arrive with a string
where a number goes, a currency nobody ISO-coded, and a field simply
forgotten. The demo ignores this. The application needs a pattern:

```
attempt 1: {"vendor":"Initech...","total_cents":"4200","currency":"usd"}
-> rejected; violations become the next prompt:
     - total_cents: must be Numeric
     - currency: must be one of: USD, EUR, GBP
     - due_date: is missing
attempt 2: {..., "total_cents":4200, "currency":"USD", "due_date":"2026-08-01"}
-> contract satisfied. shipped after 2 attempts.
```

**The contract is the editor; the model is the writer.** And the
discovery that makes this framework unusually good at the pattern:
the correction prompt writes itself. The same capability contract
that six other tools already consume produces violations that are
*pre-written actionable feedback* — "currency: must be one of: USD,
EUR, GBP" is precisely the sentence you'd hand a junior writer, and
it beats "please try again" by exactly the margin your production
error rate will show. I've watched teams hand-craft correction
prompt templates per field; declared constraints generate better
ones for free.

## The discipline clauses

Three parts of the loop are load-bearing, and teams skip them in
order of expensiveness:

1. **Bounded attempts.** Unbounded self-correction is a billing
   strategy. Three is the number; a model that can't satisfy a
   schema in three coached tries has a prompt problem or a schema
   problem, and more retries buy neither.
2. **Honest terminal failure.** When the loop exhausts, it raises
   with the full ValidationError — every draft on record. A
   correction loop that swallows its final failure is the timid
   pipeline from Avdi's stall wearing a lab coat.
3. **Validate at the output door, not in the prompt.** Prompting
   "respond with valid JSON matching..." is a request; the validator
   is a *checkpoint*. You need both, and only one of them is a
   guarantee.

## Notes

- Wire this at the CapabilityProvider seam and every LLM-backed
  capability inherits the loop without knowing it exists — the
  pattern wants to be middleware. That's the natural round-13 shape
  if the room wants it.
- The scripted model's first draft (string number, lowercase
  currency, missing field) isn't pessimism — it's a census of the
  three most common schema sins in real extraction logs.

## Verdict

Self-correction is what makes "the model sometimes returns garbage"
an engineering statement instead of a product risk. The contract
supplies the red pen, the loop supplies the patience, the bound
supplies the budget — ship the editor with the writer; never ship
the writer alone.
