# Round 17 field notes — DHH scaffolds the omakase plan

*Built: `examples/omakase_scaffold.rb` — `rails new` for plans. A
six-line recipe in, a complete runnable program out: journal wired,
retries configured, concurrency chosen, TODOs where your work goes.
The generated files are actually executed — the proof of a generator
is its output booting.*

## What I built and why

Seven rounds of building products on this framework and the brief
finally asked the Rails question directly: where's the *on-ramp*?
The gem's primitives are good — I've said so, grudgingly, since
round 2 — but every program in this catalog starts with the same
fifteen lines of ceremony that someone had to already know: the
journal, the retry policy with jitter, the concurrency ceiling.
Conventions that live only in examples are folklore. **Generators
are how conventions travel.**

```
recipe "newsletter_digest" (4 steps declared)
  generated: newsletter_digest.rb (46 lines you didn't write)
  ran it:    "newsletter_digest: completed, 4/4 steps, journal at ..."
```

The recipe is the entire interface: a name, steps, `after:` for
order. The scaffold pours the omakase around it — every run
journaled and replayable, transient errors retried three times with
full jitter, a sane parallelism ceiling. Disagree with the chef?
**The file is yours.** Plain Ruby, your name on it, no framework
umbilical, TODOs marking exactly where your real work replaces the
stubs. That's the part people miss about omakase: it's not that you
can't choose, it's that you don't have to choose *first*.

## The scaffold's first output didn't boot

And here is why the example *runs* its generated programs instead of
admiring them: the first template used `Dir.tmpdir` without
`require "tmpdir"` — the exact missing-require sin this repo's
census (round 11) and learning-corner autopsy (round 14) have
documented six times in handwritten code. Now a *generator* committed
it, which is worse, because a generator ships a bug at scale. The
smoke assertion caught it on first run. A generator that doesn't
execute its own output in CI is a template with delusions.

## Notes

- Generation is string assembly, ~40 lines, no ERB, no engine. The
  plan graph being data means the template barely has logic: steps
  become tasks, `after:` becomes the dependency array. Compression
  where it counts.
- The right home for this is `agentic new <recipe>` in the CLI, with
  the recipe format exactly as minimal as this one. If the recipe
  ever needs a manual, the scaffold has failed.

## Verdict

Six lines of intent became a 46-line running program with the 2am
concerns already handled. The framework's ceremony was never the
problem — unshipped conventions were. A generator is a gem's opinion
made portable; this gem has opinions worth shipping.
