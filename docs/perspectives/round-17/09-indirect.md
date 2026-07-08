# Round 17 field notes — André Arko locks the plan

*Built: `examples/plan_lockfile.rb` — Gemfile.lock for workflows.
`lock` resolves capability constraints once into exact versions plus
content digests; `run --frozen` verifies and refuses instead of
resolving. New versions enter through a relock and a reviewable
diff, never silently.*

## What I built and why

Round 14 I built the resolver — the algorithm. The brief this round
asked for the *workflow*, and the workflow is the part of Bundler
people actually depend on: not resolution, but the **contract
between the constraint file and the deploy.** A plan that says
`text.summarize ~> 1.0` has expressed a wish. Production doesn't run
wishes:

```
day 1   lock + frozen run: text.summarize 1.1.0, markdown.render 2.3.1
day 30  1.2.0 published; frozen run: still 1.1.0 (ignored it)
day 31  2.3.1 edited IN PLACE:
        FROZEN RUN REFUSED: content digest mismatch (locked b867..., found cc89...)
relock  1.2.0 adopted NOW, in a diff someone reviews - not silently on day 30
```

Day 30 is the boring half everyone understands: frozen means frozen;
a new upstream version changes nothing until a human relocks. Day 31
is the half ecosystems learn bleeding: **version numbers are claims.**
Same number, different code — a yanked-and-republished capability, a
prompt edited in place, a "hotfix" to a shared tool — is the exact
lie `Gemfile.lock` can't see but a content digest catches in one
line. For plans this matters *more* than for gems: a capability
here is a prompt plus a lambda, and prompts get "just one tweak"
edits at a rate `lib/` never dreamed of.

## Notes

- The resolver reuses `Gem::Requirement`/`Gem::Version` — stdlib
  ships pessimistic-constraint semantics, and reimplementing them
  badly is a rite of passage nobody needs.
- Every refusal message carries the four things a 2am operator
  needs: which capability, expected what, found what, and the one
  command out (`plan lock --update`). Bundler's hardest-earned
  lesson wasn't the resolver; it was that error text is part of the
  lockfile's API.
- The capability registry already tracks multiple versions per name
  (the autoloader next door leans on it too). The lockfile is the
  missing *policy* layer over that mechanism: registry = what
  exists; lock = what this plan agreed to run.
- Production wants the digest to cover the plan graph too — same
  reasoning, one level up: "same plan name, different wiring" is
  also a lie.

## Verdict

Three moments, one discipline: constraints say what you can accept,
the lock says what you are running, and nothing moves between them
without a diff a human reviews. Bundler spent a decade earning those
rules gem by gem; a workflow framework gets to inherit them for the
cost of one JSON file and the humility to check digests.
