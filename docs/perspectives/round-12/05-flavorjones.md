# Round 12 field notes — Mike Dalessio feeds the parser real input

*Built: `examples/hostile_inputs.rb` — eight hostile files against
`ExecutionJournal.replay`: torn tails, binary garbage, 8MB lines,
wrong-shaped JSON. Two probes draw blood; exit 1 by design until the
tail is tolerated.*

## What I built and why

Maintaining Nokogiri is a decades-long tutorial in one lesson: **a
parser's real specification is what it does with input nobody
intended.** Documents arrive truncated, mis-encoded, malicious, and
enormous — and a parser that only handles the happy grammar isn't a
parser, it's a demo. The journal's replay is a parser, and it has a
special obligation: the file it reads is, *by the journal's own
reason for existing*, a file that may end mid-write.

```
clean file (control)         recovered (2 salvaged)
torn tail (crash mid-write)  CRASHED: JSON::ParserError - ALL recovery denied
binary garbage line          CRASHED: Encoding::CompatibilityError
empty + whitespace lines     recovered
8MB single line              recovered
valid JSON, wrong shape      recovered
unknown event type           recovered (skipped, correctly)
duplicate success lines      recovered (idempotent, correctly)
```

## The indefensible probe

Six of eight verdicts are genuinely good — unknown events skip,
duplicates are idempotent, giant lines and shape-garbage flow
through. But the torn tail is the one that matters, and it's the one
that kills. Walk the incident: the process dies mid-`record`. fsync
has made every *completed* line durable — the journal did its job.
The line being written *at* the moment of death lands half-formed at
the tail. Recovery runs, replay hits the torn line, and
`JSON::ParserError` flies past every `rescue ValidationError` in the
recovery tool — **100% of the events that were durable become
unreachable because of the one that wasn't.** The recovery tool is
now the second thing that failed, which is the one thing a recovery
tool must never be.

The binary-garbage probe is the same wound in different clothes
(`Encoding::CompatibilityError` — a *third* uniform, for the
rescuers keeping count).

Filed as the round-13 ask, with this probe as the acceptance test:
replay must salvage every whole line and *report* a damaged tail
(count it, expose it on the state) rather than raise on it. Tolerant
reading, loud accounting — the Nokogiri recovery-mode posture.

## Notes

- Note what I did NOT flag: `valid JSON, wrong shape` recovering
  quietly is *defensible* for a recovery tool (salvage maximally)
  but a stricter mode should exist for audit tools — Jeremy's
  round-8 journal audit wants to *notice* wrong shapes, not skate
  past them. One file format, two reader postures; both legitimate.
- The 8MB line recovering is worth a sentence: no line-length
  assumptions, no fixed buffers. Good — length limits are where
  "robustness" quietly becomes data loss.

## Verdict

Six probes pass with genuinely good manners; two crash in the wrong
uniform, and one of those two is the exact file a real crash writes.
Parsers meet real input, and real input is damaged — the journal's
reader needs to survive the very artifact its writer exists to
survive. Exit 1 until.
