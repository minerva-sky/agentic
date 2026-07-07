# Round 14 field notes — André Arko resolves the field nobody used

*Built: `examples/capability_resolver.rb` — Bundler-style version
resolution over the `dependencies:` field capabilities have carried
since round 1, with backtracking, highest-compatible selection, and
a conflict error built like the product it is.*

## What I built and why

`CapabilitySpecification` has had a `dependencies:` array and a
`compatible_with?` method since the beginning, and in fourteen
rounds nothing has ever *resolved* them — they were load-bearing
decoration. Resolution is my whole career, so:

```
resolve report 2.0.0:
  report     2.0.0
  summarize  2.0.0
  fetch      2.1.0   <- not 3.0.0 (newest), not 2.0.0 (requested)
```

That fetch line is Bundler's oldest rule in one row:
**highest-still-compatible**. Newest-available breaks majors;
exactly-requested strands you on patch zero forever. The resolver
itself is thirty lines — pick a candidate, recurse into its
dependencies, backtrack on conflict — because resolution really is
just search. (Until the index gets big and the constraints get
weird, at which point it's NP-complete and you write Molinillo. The
thirty lines are honest for this index size and I said so.)

## The error is the product

Ten years of Bundler issues taught me exactly one thing worth
tattooing: **when resolution fails, the error message is the
product.** The algorithm's job is to find an answer; the error's job
is to transfer *understanding of why there isn't one*:

```
CONFLICT: could not find compatible versions for capability 'fetch'
  report (2.0.0) depends on
    fetch (~ 2.x)
  legacy_export (1.1.0) depends on
    fetch (~ 1.x)
fetch cannot be both major-1 and major-2 in one plan.
consider: upgrading legacy_export, or running exports in a separate plan.
```

Both demand chains, named. The impossibility, stated in one
sentence. Two suggested moves, both real. A bare "version conflict"
costs your users an afternoon of spelunking; this costs them a
minute of choosing. The difference between those two error messages
is most of the issue tracker I've ever read.

## Notes

- `compatible_with?` (same major, minor >=) turns out to be a clean
  constraint primitive — the resolver needed zero framework changes,
  which is the recurring shape of this whole experiment: metadata
  declared honestly keeps cashing checks nobody wrote.
- What a production version adds, in order of pain: version ranges
  (not just floors), lockfile output (resolution you don't persist
  is resolution you'll re-litigate), and conflict explanation for
  *transitive* chains three levels deep — the place where showing
  your work stops being optional.

## Verdict

The dependencies field finally does what its name promised, the
happy path picks the version a maintainer would want, and the sad
path explains itself like it respects your afternoon. Resolution is
search; the error message is the deliverable.
