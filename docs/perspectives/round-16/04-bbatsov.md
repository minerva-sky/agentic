# Round 16 field notes — Bozhidar Batsov writes the minutes

*Built: `examples/configurable_cops.rb` — the contract cops grown a
config layer: enable/disable per cop, parameters instead of
hardcoded taste, and new cops arriving `pending` so an upgrade can
never redden a build without the team's signature.*

## What I built and why

Round 11 I built the cops; the lottery sent me back to build the
part that actually keeps the peace. RuboCop's deepest lesson was
never any single cop — it's the `.yml`. A style guide nobody can
configure isn't a guide, it's a style *fight* on a delay timer, and
the fight re-runs in every code review until someone writes the
decision down where a build can read it:

```
same contract, two teams:
team A (defaults + opted into pending cop):   4 offenses
team B (Max: 8, EnumOrder off, pending off):  1 offense
```

Team B's config is the artifact I care about. `Max: 8` sits next to
a comment explaining *why* ("seven required inputs and we've MET our
capability"), blame-able to a person and a date. `EnumOrder:
Enabled: false` records that their enums are ordered by freight
class, not alphabet — a real reason, now written where the linter
reads it instead of re-argued wherever reviewers meet. Hardcoded
taste creates rebels; configurable taste creates a paper trail.
**The style guide is the conversation; the config file is its
minutes.**

## Pending is the load-bearing status

The policy that saved RuboCop's users a thousand ruined mornings:
**new cops arrive `pending`** and fire only when a team opts in.
`Lint/UntypedField` ships in this "release," and for team B it fired
zero times — not because it's wrong (it's load-bearing! untyped
fields lose schema projection), but because a linter upgrade must
never turn a green build red by surprise. Team A read the release
notes and signed; team B will get there on their own schedule.
Trust, once spent on a surprise red build, does not refund — the
pending policy is how a linter stays upgradeable for a decade.

Implementation notes: `Enabled` defaults derive from cop status
(stable on, pending off), per-cop params merge over `defaults:`, and
the whole config engine is a dozen lines because the cops from round
11 already took `(spec, params)` — parameterize your checks from day
one and the config layer is a merge, not a rewrite.

## Notes

- Deliberately absent: `inherit_from`. Real teams need config
  inheritance (org defaults + team overrides); it's the natural next
  twenty lines and the example says so by omission rather than by a
  half-implementation.
- The comment IN team B's YAML is part of the design. Config without
  rationale rots into cargo cult; the `.yml` should read like
  minutes, not like output.

## Verdict

One contract, two teams, two verdicts, zero fights — every
divergence a recorded decision with a name on it, and the new cop
politely waiting for signatures. Style guides earn adoption by being
configurable and keep it by never surprising anyone on upgrade day.
