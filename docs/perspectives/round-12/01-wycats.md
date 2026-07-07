# Round 12 field notes — Yehuda Katz takes the census

*Built: `examples/api_surface.rb` — the full public method surface of
eleven core classes, owner-checked, cross-referenced against 102
example programs to split real API from accidental API.*

## What I built and why

Semver isn't a promise about your documentation — it's a promise
about **everything a user can call**. I learned this running Bundler
and Rails releases: the method you never documented is the method
whose removal breaks three build pipelines and a bank. So before any
1.0 conversation, you take the census:

```
total public surface: 112 methods
exercised by the corpus: 58 (52%)
accidental: 54 - including PlanOrchestrator#find_eligible_tasks,
            #overall_status, #retry?, Task#perform...
```

The corpus is this repo's own 100+ example programs — the richest
usage dataset a pre-1.0 gem could dream of. Every method they call
carries a de facto semver promise *now*, docs or no docs; every
public method they don't is surface the maintainer is paying
interest on without collecting rent.

## The stewardship read

The accidental list is where release engineering lives, and the
right move is **declaration, not deletion**:

- `PlanOrchestrator#find_eligible_tasks` and `#retry?` are scheduler
  internals wearing public visibility. The day a user's code calls
  `retry?` to make decisions, the retry engine can never be
  restructured without a major bump. Privatize while it's free.
- `Task#perform` is the interesting hard case: it's *architecturally*
  public (the orchestrator calls it) but *user-facing* private. That
  distinction — audience-scoped API — is what `@api private` was
  invented for, and Rails' whole `:nodoc:` culture exists because
  Ruby's two visibility levels can't express three audiences.
- `TaskFailure#hopeless?` being unexercised is a *timing* artifact —
  shipped two rounds ago, adopted by policy code, not yet by
  examples. The census can't tell "accidental" from "young"; a
  steward reads the column with a calendar in hand.

First-draft note: the census originally reported 244 methods because
it counted inherited Psych/Object noise (`yaml_tag`, `allocate`) as
surface. Owner-checking the enumeration halved the ledger — get the
attribution wrong and the census indicts the wrong debt, which is
worse than no census.

## Notes

- The 52% exercised rate is *healthy* for this corpus — examples
  skew toward the interesting seams. The number to watch is the
  trend: surface growing faster than exercise means the gem is
  speculating about what users want instead of finding out.
- The corpus method has a blind spot: internal callers (the
  validator uses `RelationRules.check`; specs use everything).
  A production census would union several corpora and weight them.

## Verdict

112 methods, 58 earning rent, 54 on loan. Public-by-default is a
loan against every future refactor, and this census is the bill —
cheap to pay today with a `private` keyword, expensive forever the
day after someone couples. Take the census before 1.0, not after.
