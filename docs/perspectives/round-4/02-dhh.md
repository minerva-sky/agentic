# Round 4 field notes — DHH replaces the onboarding wiki

*Built: `examples/setup_doctor.rb` — four environment checks in
parallel, one diagnosis reading them by name, one exit code.*

## What I built and why

Every onboarding wiki page is a bug report against your tooling. The
doctor runs what the wiki would ask a new hire to do by hand — ruby
version against the gemspec, `bundle check`, git state, test suite
presence — and prescribes. Green means "write code, not wiki pages."
Red means the FIX lines are your first day's checklist, and it exits 1
so CI can enforce it.

The shape I care about is the diagnosis:

```ruby
orchestrator.add_task(diagnosis,
  needs: {ruby: ruby, bundle: bundle, git: git, suite: suite},
  agent: ->(t) { ... t.needs.ruby ... })
```

Last round I asked for exactly this — dependencies declared and
consumed under one name — and it shipped. `t.needs.bundle` is
self-documenting in a way `t.dependency_outputs.values[1]` never was.
The asymmetry I complained about is gone: the declaration IS the
consumption vocabulary. This is the API a Rails person expects, which
I mean as the highest compliment I give.

## Omakase notes

- The checks are real, not simulated — this doctor diagnosed the very
  repo it lives in and told me I had one uncommitted change (it was
  itself; the doctor detected its own birth, which is very Basecamp).
- Each check returns `{ok:, detail:}` — a convention, not a contract.
  I *chose* not to give the checks capability contracts because for a
  five-check doctor that's ceremony. The framework let me choose. The
  gradient the README now documents (capabilities first, orchestrator
  for queues) works in the other direction too: sometimes a bare
  lambda is the whole right answer.
- `bin/setup` should end by exec'ing this. Setup that verifies itself
  is setup people trust; setup people trust never grows a wiki page.

## Verdict

Four rounds in, the pattern for me is one line long: the framework now
lets a small idea stay small. The doctor is 80 lines and half of them
are the actual checks — the framework's share of the file has become a
rounding error, which is where every framework should aspire to live.
