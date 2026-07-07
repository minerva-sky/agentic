# Round 8 field notes — Piotr Solnica advises the version bump

*Built: `examples/contract_semver.rb` — two contract versions, every
change classified breaking or compatible from both seats, and the
version bump computed instead of debated.*

## What I built and why

Contracts are declarations; declarations can be *diffed semantically*;
and a semantic diff of a contract is a semver verdict waiting to be
computed. Five changes between v1.4.0 and the proposal:

```
BREAKING   input :weight max tightened 10000 -> 5000
BREAKING   input :customs_code added as REQUIRED
BREAKING   output :carrier removed
COMPATIBLE input :mode enum widened (road)
COMPATIBLE output :eta_days added
verdict: 3 breaking -> ship as v2.0.0
```

The rule doing the intellectual work is the **variance asymmetry**
(contravariance, wearing street clothes): inputs break when
*tightened* — previously legal calls get rejected — while outputs
break when *narrowed* — consumers reading `:carrier` now get nil.
Widening an input enum is a gift; widening... removing an output is
a theft. The same category of edit flips polarity depending on which
side of the boundary it touches, which is exactly why humans argue
about "is this breaking?" in every API review: they're arguing from
different seats without naming the seats. The advisor names them.

## Why this is only possible now

Every rule in the classifier reads a *declaration*: `required:`,
`enum:`, `min:`/`max:`, output keys. Eight rounds ago these were
comments; today they're data precise enough to compute compatibility
from. This is the fourth tool the declarations have paid for (docs,
schema export, 422s, now semver) — and note that the classifier
needed *zero* new framework support. When your metadata keeps
enabling tools you didn't plan, the metadata's shape is right.

Blind spot, stated plainly: `rules:` lambdas can't be compared, so a
tightened business rule is invisible to the advisor. Structured rules
narrow the gap (fields and messages diff textually) but the predicate
itself is opaque — same boundary Jeremy's prober works around. The
advisor says "3 breaking changes *in the declarations*"; the honest
reading includes that qualifier.

## Verdict

"Is this breaking?" is now a computation with named seats instead of
a meeting with unnamed assumptions. Wire it to CI on contract files
and the changelog writes its own major-version warnings — the
declarations keep paying rent.
