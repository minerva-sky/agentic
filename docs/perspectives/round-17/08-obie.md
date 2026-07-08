# Round 17 field notes — Obie Fernandez builds the escalation ladder

*Built: `examples/support_escalation.rb` — the pattern under every
AI product that survives contact with customers: tier 0 auto-resolves
from playbooks, tier 1 drafts for known-but-nuanced intents, the
human queue takes the rest, and every handoff carries a dossier.
Exit 1 if any ticket lands on the wrong rung.*

## What I built and why

Round 12 I made outputs self-correct against their contracts — a
pattern at the scale of one response. The brief this round asked for
a *solution*, so I shipped the pattern I put at the center of the
book: **multitude of workers, ladder of trust.** Not "the AI handles
support" — that sentence has bankrupted more startups than fraud —
but the machine doing the whole job it can *prove* it can do, and
handing the remainder up with everything it learned.

```
tier 0 - auto-resolved:  T-1 password reset (0.9)   T-4 feature request (0.95)
tier 1 - specialist:     T-2 refund draft (0.9)     T-5 export repro (0.95)
the human queue:         T-3 sensitive (0.9 confident, and it does not matter)
                         T-6 low confidence (0.0)
```

Two rules make this a product rather than a demo, and both are in
the routing code where you can point at them:

1. **Thresholds are business policy as data.** `auto_resolve_at:
   0.8, draft_at: 0.5` live in a POLICY hash a product manager can
   read, diff in a pull request, and A/B by tenant. The day legal
   asks "who decided the bot answers billing questions?", the answer
   is a line with a git blame, not a vibe inside a prompt.
2. **Sensitivity trumps confidence — structurally.** The sensitive
   branch is *first* in the conditional, before confidence is even
   consulted. T-3 is the ticket that proves it: the classifier was
   0.9 confident it's a refund (it is!), and it still went to a
   human, because the text mentions lawyers, and being sure is not
   the same as being allowed.

The third rule is quieter: escalation hands over a **dossier**, not
a shrug. The human queue items arrive with the full ticket, the
triage verdict, and the attempt history — the human starts from
everything the machine learned. Support agents don't hate AI; they
hate AI that makes them re-do the interview.

## Notes

- The framework earned its keep in the shape: triage → resolve as a
  two-task chain per ticket, tickets in parallel under one ceiling,
  the dossier riding `previous_output`, everything journaled. The
  ladder logic itself is 15 lines.
- Escalation is not failure. Two of six tickets reaching humans *is
  the product working* — the metric to watch is dossier quality on
  handoff, not deflection rate. Deflection-rate worship is how you
  get bots that gaslight customers about lawyers.
- Production wants: per-tenant POLICY rows, a feedback loop from
  human resolutions back into playbooks (the round-8 dead-letter
  office pattern, pointed at success instead of failure), and QA
  sampling of tier-0 output.

## Verdict

Six tickets, three rungs, zero machine fingerprints on the legal
threat. Confidence thresholds as data, sensitivity above confidence,
dossiers on every handoff — the escalation ladder is what
"human-in-the-loop" means when it's a design and not a disclaimer.
