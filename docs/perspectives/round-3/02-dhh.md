# Round 3 field notes — DHH cancels the standup

*Built: `examples/standup_digest.rb` — three collectors read the repo in
parallel, one writer fans their outputs in and publishes the digest.*

## What I built and why

The asynchronous standup is the calm-company move: nobody talks, the
repo speaks. Three collectors run in parallel — recent commits grouped
by theme, TODO/FIXME debt in `lib/`, the size of the safety net — and a
writer task that depends on all three composes the digest:

```
shipped: 12 recent commits (11 docs, 1 feat)
owed: 0 TODO/FIXME/HACK markers in lib/  (clean!)
guarded by: 530 examples across 57 spec files
```

Real data, real repo, 26ms. And the shape is the point: **fan-in**. The
writer declares `[commits, debt, tests]` as dependencies and reads
`t.output_of(commits)` for each. In round 2 this exact shape would have
required a shared hash and a provider struct; now it's the framework's
native grammar. This is what I meant by compression — the concept count
in my program dropped to the concept count of my *idea*.

## What building it felt like this time

- `add_task(task, [commits, debt, tests], agent: ->(t) { ... })` —
  passing actual Task objects as dependencies instead of `.id` strings
  is a small mercy that removes a whole category of typo.
- `payload` killed the "look it up by description" caveman move from my
  ticket screener. Nothing in this program is keyed by string except
  things that are actually strings.
- The collectors shelling to `git log` felt right, not hacky: the
  framework doesn't care whether an agent is an LLM, a lambda, or a
  subprocess. That agnosticism is worth protecting.

## Remaining gripe, downgraded from complaint to suggestion

The writer reads three outputs with three `t.output_of(...)` calls.
Fine. But notice the asymmetry: dependencies are declared in one place
and consumed in another, connected by nothing but my discipline. The
Rails move would be naming them:
`add_task(digest, needs: {shipped: commits, owed: debt}, ...)` then
`t.needs.shipped` in the agent. Declared and consumed under one name.
File under round 4.

## Verdict

Round 2 I shipped a screener despite thirty lines of adapter; round 3 I
shipped a standup-killer in zero. The roadmap wasn't advisory — it was
the product backlog, and it shipped.
