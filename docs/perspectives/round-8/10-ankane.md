# Round 8 field notes — Andrew Kane swaps the scorer, not the harness

*Built: `examples/eval_scorers.rb` — one eval set scored four ways
(exact, keyword containment, numeric tolerance, judge rubric), with a
scoreboard showing which scorer makes failure mean something.*

## What I built and why

Last round I wrote golden-case evals with exact equality and noted
that for LLM-backed capabilities the equality check becomes a scorer —
exact, contains, judge-model — but the harness shape doesn't change.
This round I cashed that claim. The seam is one line:

```ruby
SCORERS = {
  exact:     ->(expected, actual) { expected == actual ? 1.0 : 0.0 },
  contains:  ->(keywords, actual) { keywords.count { ... }.fdiv(keywords.size) },
  tolerance: ->(spec, actual) { (spec[:value] - actual).abs <= spec[:within] ? 1.0 : 0.0 },
  judge:     ->(rubric, actual) { rubric.call(actual) }
}
```

Every scorer is `(expected, actual) -> 0.0..1.0`. That's the whole
contract. The judge here is an offline rubric lambda; in production
it's a model call — and *nothing else in the file changes*, which was
the point being tested.

## The signal-to-noise result

```
exact      1/3 pass    <- flagged 2 cases; 1 is wording noise
contains   2/3 pass    <- flagged only the crash ticket
tolerance  2/3 pass    <- same
judge      1/2 pass    <- same
```

Exact scoring failed the refund ticket because the capability said
"customer reports damaged item, refund requested" instead of my golden
"Damaged item; refund requested". Same meaning, different words —
that's not a regression, that's a scorer measuring the wrong thing.
Meanwhile all three appropriate scorers converged on case 3: crash
tickets score priority 0.3 because the capability has no rule for
crashes. One real failure, unanimously flagged, zero noise.

This is the practical argument for the scorer seam: it's not about
being *lenient* with fuzzy outputs, it's about making every FAIL in
the report be worth reading. An eval suite people ignore because "the
exact-match ones always fail" is a suite that will miss the crash
ticket too.

## Notes

- Scorers return graded scores but the gate is binary (`PASS_AT`).
  Keeping those separate matters: the judge can say 0.6 and the
  threshold decides. When you later want "quality moved from 0.82 to
  0.74 across the suite," the graded numbers are already there.
- Exit 1 when a real failure exists, same as last round's harness.
  Evals that can't fail the build are dashboards, not tests.
- The searchable pattern here is pgvector-era déjà vu: the interface
  (`(expected, actual) -> score`) is boring on purpose, so the
  ecosystem can supply the interesting parts.

## Verdict

The harness shape held: swapping equality for containment, tolerance,
and a rubric touched only the scorer table. Next time quality is in
question, the diff is a scorer entry, not a rewrite — and the round-7
prediction is now a demonstrated fact instead of a field note.
