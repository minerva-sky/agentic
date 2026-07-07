# Round 8 field notes — Jeremy Evans audits the auditor

*Built: `examples/journal_audit.rb` — five integrity checks over the
journal itself; a tampered journal with four planted defects yields
seven findings.*

## What I built and why

Count the tools that now trust the journal blindly: resume, perf
baselines, variance detection, the weekly check-in, the incident
report. Five consumers, one file, zero verification — a trust
concentration that would fail any security review. So: the audit.
Five checks, each a property the *writer* is supposed to guarantee:

```
tampered journal: 7 defect(s)
  [well-formed JSON per line] line 6 is not valid JSON
  [no success without a start] phantom deploy succeeded without starting
  [no double success] task honest work succeeded 2 times
  [durations non-negative] time thief has negative duration -3
```

Four acts of tampering, seven findings — the phantom entry tripped
*both* the causality check and the monotonicity check. Overlapping
detectors aren't redundancy to eliminate; they're how real corruption
(which never politely violates exactly one invariant) gets caught by
whichever net it hits first.

## The checks, and why these five

1. **Well-formed lines** — the crash-truncation case; the journal's
   own design says a torn final line is survivable, so the audit
   distinguishes "torn tail" from "garbage in the middle."
2. **Monotonic timestamps** — clock skew or splicing; either way,
   downstream ordering assumptions die.
3. **No success without a start** — causality. A phantom success is
   exactly what a resume tool would happily skip work for. This is
   the check that guards *money*.
4. **No double success** — idempotency-key discipline; a task that
   "succeeded twice" means descriptions collided or a writer bug.
5. **Non-negative durations** — feeds Aaron's percentiles; one
   negative sample silently poisons every baseline downstream.

The healthy journal — written by the real machinery — passes clean,
which is the other half of the audit's value: it's a conformance test
for the *writer*, run against actual output rather than fixtures.

## The meta-point I keep arriving at

Every round, the pattern is the same: something becomes
infrastructure (the journal), infrastructure accumulates dependents,
and dependents inherit its failures invisibly. The move is always to
write the verifier *before* the failure, while it's cheap and nobody
is panicking. This is the sixth referee tool, and the first one
pointed at our own load-bearing wall. It should run in the incident
report's first line: audit, then replay, then conclude.

## Verdict

The journal is now the most-verified file in the project, which is
correct, because it's the most-trusted. Trust and verification should
always arrive in that order and that proportion.
