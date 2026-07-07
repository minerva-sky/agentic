# Round 14 field notes — Janko Marohnić promotes carefully

*Built: `examples/attachment_pipeline.rb` — Shrine's cache/promote
two-phase pattern as a journaled plan: a crash mid-derivatives
resumes at the exact thumbnail it died on, and a double-submit
re-derives nothing.*

## What I built and why

Shrine exists because file uploads look like a form field and are
actually a distributed transaction. Users double-submit. Workers
get OOM-killed mid-thumbnail. Retries arrive from two systems at
once. Every "corrupted avatar" bug report traces back to someone
treating upload as one synchronous step. The pattern that survives
production has two phases with opposite virtues:

```
phase 1 (request):  cached team-photo.jpg - 0ms of processing
phase 2, attempt 1: crashed at derive:web:1200
                    journal holds 2 paid derivatives
                    record NOT promoted; cache still serves the user
phase 2, attempt 2: only 1 derivative scheduled - paid ones skipped
phase 2, attempt 3: 0 scheduled - idempotent all the way down
```

**Cache** is instant and disposable — the user's file is safe the
moment the request returns, no processing in the request cycle,
ever. **Promotion** is slow, background, and must be idempotent —
and this is where the framework earned its invitation: a journaled
plan whose derivative names (`derive:thumb:200`) are idempotency
keys is *exactly* the machine promotion needs. The crash resumed at
the exact derivative it died on; the retry re-paid for nothing; the
third, double-submitted attempt scheduled zero work.

## The record is the second phase

The subtle ordering that separates this from most home-grown
uploaders: `promote:record` — the step that flips the database
record to the permanent store and clears the cache — depends on
*all* derivatives. The record commits only after every thumbnail
exists. Get this backwards (promote first, derive later) and there's
a window where the record points at derivatives that don't exist
yet, which users experience as broken images and engineers
experience as "it's fine on my machine, the derivatives caught up."
Two-phase commit isn't jargon here; it's the difference between an
upload system and an upload demo.

Note also what failure looked like to the *user* at every step:
after the crash, the cache still served the original — a photo, not
an error. Failure isolation in upload pipelines is a UX feature
wearing an architecture costume.

## Notes

- Derivative-name-as-idempotency-key inherits everything the journal
  learned in fourteen rounds: fsync'd receipts (round 1), tolerant
  replay (round 13), per-upload journal files (Eileen's per-shard
  isolation, at upload granularity).
- What real Shrine adds on top: metadata extraction as its own
  cached-phase step, storage abstraction (S3 vs disk behind one
  interface), and background *deletion* — which needs the same
  idempotency discipline everyone forgets until the double-delete.

## Verdict

Uploads are a two-phase commit wearing a file input. Cache
instantly, promote through a journaled plan, let derivative names
be receipts — and crashes become resumes, retries become no-ops,
and the anxious double-click becomes exactly nothing at all.
