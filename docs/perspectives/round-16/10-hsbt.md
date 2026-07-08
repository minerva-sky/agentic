# Round 16 field notes — Hiroshi Shibata rehearses release day

*Built: `examples/release_rehearsal.rb` — the full ceremony: build
the gem, audit the manifest and version, install into a clean
GEM_HOME, and boot the installed package with the repo pointedly off
the load path. Exit 1 if the artifact can't do its job.*

## What I built and why

Maintaining RubyGems is mostly one lesson at scale: **every gem
that breaks on install worked perfectly in its own repo.** The repo
is not the gem. The gem is whatever the gemspec packages, installed
somewhere your working directory can't help it, booted by a Ruby
that owes you nothing — and the day to discover a file missing from
that package is today, on this machine, not release day in a
stranger's CI:

```
act 1 - gem build: ok (594KB)
act 2 - manifest audit: 437 files packaged; lib coverage complete
        version: gemspec 0.2.0 == Agentic::VERSION 0.2.0 - agree
act 3 - clean install: ok (GEM_HOME=gem_home)
act 4 - boot from the package: "the package works"
```

Each act rehearses a classic release-day wound: files added without
`git add` (invisible to `git ls-files`-based manifests — act 2
diffs `lib/**/*.rb` against the packaged list); version.rb bumped
while something still pins the old number (act 2 compares both
sources of truth); and the implicit load-order dependency that only
your spec_helper ever satisfied (act 4 boots the *installed* gem
and runs a real plan through it — which is exactly how this repo's
round-11 `require "time"` bug would have been caught before any
user met it).

## The rehearsal's first run caught the rehearsal

Act 4 failed on its first execution — and the failure is the best
paragraph in these notes. Under `bundle exec`, `RUBYOPT` smuggles
`bundler/setup` into every child process, and Bundler put **this
repo's lib/ right back on the load path** — the probe was praising
a package it had never loaded. The tripwire I'd written on a hunch
(assert the loaded path is under the temp GEM_HOME) is what caught
it, and the fix is env hygiene: scrub `RUBYOPT`, `RUBYLIB`, and the
`BUNDLE_*` variables before spawning. This is not a niche gotcha —
it's the *default* contamination of every "clean room" test run
from a Bundler project, and half the "works in CI, breaks for
users" mysteries I've triaged reduce to it. Rehearsals must audit
their own stage first.

## Notes

- `--ignore-dependencies` on install keeps the rehearsal offline
  (deps resolve from the host gem path in act 4). A networked
  variant that installs dependencies too is the fuller ceremony —
  run that one nightly, this one on every push.
- The gem is 594KB and 437 files, most of which are examples and
  field notes. A leaner `spec.files` would ship faster installs;
  noted as a maintainer's choice, not a defect — but the number is
  now printed where someone can choose.

## Verdict

Four acts, one genuine catch (the rehearsal's own contaminated
stage), and a certificate that the *package* — not the repo — can
boot and run a plan. Rehearse the ceremony in CI and release day
becomes a tag, not an event.
