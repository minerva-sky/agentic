# Round 12 field notes — Rafael França renames without breaking anyone

*Built: `examples/gentle_deprecations.rb` — a contract field rename
shipped through the three-release choreography: translate-and-warn
(once per call site, caller named), a migration tally, and a strict
mode that turns laggards' CI red on the maintainer's schedule.*

## What I built and why

Most of maintaining Rails isn't writing the better API — it's the
two years of not breaking anyone who used the worse one. A rename is
five minutes of code and three releases of choreography, and
frameworks that skip the choreography don't have users with old
code; they have ex-users. So: `weight:` becomes `weight_kg:`, and
the shim does the whole dance:

```
DEPRECATION: :weight is now :weight_kg (called from
  legacy_billing_job (gentle_deprecations.rb:75); shows once per site)

migration report:
  weight at legacy_billing_job (...:75)   3 calls
  weight at legacy_admin_panel (...:77)   2 calls
  migrated call sites warn nothing and appear nowhere.

strict mode: DEPRECATED input :weight - refused
```

## The three details that make it gentle

**Once per call site.** Warn on every call and a busy legacy job
turns your logs into the outage; warn once globally and the admin
panel's usage hides behind the billing job's. Per-site is the only
granularity that's both quiet and complete — my first frame
arithmetic blamed the shim's own `each` loop until the site detector
learned to skip frames that belong to the shim and the API boundary.
Blame frames are the whole product here; get them wrong and the
deprecation report sends someone to fix the wrong file.

**The tally is the roadmap.** Deprecation warnings people can ignore
are prayers; a *count by call site* is a migration plan with names
on it. Release N ships the shim, N+1 is spent chasing the tally to
zero (five calls, two sites, two small PRs — you can see the whole
job), and the report's most important line is the quiet one:
migrated sites appear nowhere.

**Strict mode is the deadline.** The same shim, `strict: true`,
turns the old name into an ArgumentError — in the laggards' CI
today if they opt in (the deprecation-toolkit pattern), for everyone
at N+2. The deadline is enforced by red builds, never by broken
production, which is the entire difference between a framework users
trust with upgrades and one they fork and freeze.

## Notes

- The shim lives *outside* the contract — the v2 contract only knows
  the new world, so every derived tool (schema, fixtures, diff,
  round 10's whole toolbox) speaks the future tense while the shim
  alone carries the past. Compatibility layers should be deletable
  in one commit.
- `hits` as a Hash is deliberately boring; in production it's a
  counter with the same shape. Deprecation is data about your users
  — collect it like you mean it.

## Verdict

Renames are cheap; broken trust compounds. Translate at the door,
warn once per site with the caller's name, let the tally write the
migration plan, and let CI — not production — enforce the deadline.
That's how a framework gets to have both a past and a future.
