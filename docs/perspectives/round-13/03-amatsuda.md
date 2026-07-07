# Round 13 field notes — Akira Matsuda paginates the journal

*Built: `examples/journal_tail.rb` — a tail pager that reads pages of
a 20,000-event journal backwards in 16KB chunks, with byte-offset
cursors. Page 1 costs 0.6% of the file and runs ~9,500x faster than
full replay.*

## What I built and why

Kaminari taught me that pagination looks like a UI problem and is
actually a *cost model* problem: `OFFSET 19950` reads and discards
19,950 rows to show you 50, and the page numbers shift under your
feet whenever rows append. Production journals are production
tables wearing a filesystem costume, and the question asked of both
is almost always "what happened *recently*?" Answering that with
`ExecutionJournal.replay` is `SELECT *`:

```
last page (50 events):     0.3ms,    16KB read  (t19950 .. t19999)
full replay (control):  3245.4ms,  2542KB read

page 1: t19950 .. t19999
page 2: t19900 .. t19949
page 3: t19850 .. t19899
```

The pager seeks to EOF and reads *backwards* in fixed chunks until
it has a page of complete lines. Page 1 cost 16KB of a 2.5MB file
and the incident responder is looking at the last fifty events
before the full replay would have finished parsing March.

## Cursors, not page numbers

The `prev_cursor` is a **byte offset**, not a page number, and this
is the kaminari scar tissue speaking: numbered pages shift when rows
append — page 3 of a growing journal is a different fifty events
every time someone's plan completes, which makes "look at page 3
again" a lie between colleagues. Byte offsets are stable under
append (an append-only file never moves old bytes), so a cursor
pasted into an incident channel means the same events tomorrow.
Append-only files are secretly the easiest pagination target there
is — no vacuum, no reorder, no gaps — and it would be a shame to
paginate them badly out of habit.

Boundary care: a chunk read may start mid-line, so the pager drops
the first fragment unless it reached byte zero — the same off-by-one
that plagues every backwards-reader, handled once, in one place,
with a comment.

## Notes

- Division of labor stated plainly: full replay remains correct for
  *resume* (you need every completion, and round 13's tolerant mode
  besides); the pager is for *looking*. Different questions, different
  I/O shapes — don't make the browser pay the restorer's bill.
- The pager tolerates torn lines by skipping them (filter_map with a
  rescue) — inherited politeness from this morning's release; a tail
  reader meets the torn tail more often than anyone.
- Built on `fsync_every: 500` for the 20k-event setup, because
  writing the fixture at per-event durability would have spent three
  minutes proving byroot's point from last round.

## Verdict

The journal now has an index-friendly way to answer its most common
question. Page 1 in a third of a millisecond, cursors that survive
append, and full replay reserved for the job that actually needs it
— pagination is a cost model, and this one finally charges the
reader for what they read.
