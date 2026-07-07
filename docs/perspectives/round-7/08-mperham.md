# Round 7 field notes — Mike Perham writes the 3am report

*Built: `examples/incident_report.rb` — a nightly batch dies on
expired credentials; the incident report is generated entirely from
the journal replay.*

## What I built and why

Every incident has the same first three questions — what ran, what
broke, what do I resume — and at 3am the difference between a good
night and a bad one is whether answering them requires *grep* or a
*query*. The journal answers all three:

```
impact: 3/6 tasks completed before the stop
ROOT CAUSE: load:warehouse - LlmAuthenticationError
completed (do NOT re-run): extract:orders, extract:refunds, transform:ledger
never started (blocked): verify:totals, notify:finance
resume plan: rotate creds -> re-run; 3 journaled tasks skip; ~162ms banked
```

Notice what makes the *resume plan* section possible: five rounds of
accumulated journal features composing. Descriptions as idempotency
keys (round 4) → "do NOT re-run" list. Durations (round 7) → "work
already banked." The error *type* on the failure event → the report
can say **"retryable? => false; retrying without fixing creds is
theater"** — the taxonomy from the round-4 drill, now doing incident
triage. The report isn't a template with blanks; every sentence is a
journal fact wearing ops clothes.

## The design point worth underlining

The three buckets — completed, failed, never-started — come from set
arithmetic over the replay, and the third bucket is the one dashboards
usually botch. "Never started" isn't in the journal as an event (you
can't journal what didn't happen); it's the *complement* of the plan
against the record. That means the report generator needs the intended
task list plus the journal — plan-as-data (Xavier's wire format) and
journal-as-record are the two halves of every honest incident
timeline. Neither alone can say "verify:totals never ran."

## Ops notes

- The failure hook cancels the plan (Jeremy's sentinel pattern) so the
  blast radius is bounded and *reported* — cancellation semantics from
  round 4 doing exactly what they were fixed for.
- Real deployment: this report is what your pager webhook should
  render. The journal is already on disk when the process dies; the
  report generator needs nothing from the crashed process's memory.
  That's the whole point of fsync-per-event, cashing out four rounds
  later.

## Verdict

The journal now covers the full ops lifecycle: survive the crash
(round 2), resume by name (round 4), explain the week (this round's
check-in), and brief the incident channel. One JSONL file, four
tools, zero archaeology at 3am.
