# Round 13 field notes — Kasper Timm Hansen riffs the knob

*Built: `examples/api_riffs.rb` — three runnable API shapes for the
journal's group-commit knob (constructor kwarg, policy object,
per-call override), judged where users actually live: the call
site.*

## What I built and why

The way I design APIs on stream is embarrassingly simple: write the
call site three ways, read each out loud, and listen for the one
that sounds like what it does. The design work happens in the
*comparing*, not the committing — and the subject here is live,
because `fsync_every:` shipped this very round. So: the riffs that
could have been.

```ruby
# riff 1 (shipped)
ExecutionJournal.new(path:, fsync_every: 20)
# riff 2
ExecutionJournal.new(path:, durability: Durability.grouped(20))
# riff 3
journal.record(event, payload, durable: false)
```

**Riff 1** puts the trade at construction: visible, greppable in the
diff that chose it, and immutable — nobody weakens durability
mid-flight three files away. Cost: it's a magic integer ("20 of
*what*?" is a docs-lookup away). **Riff 2** reads like a sentence —
`Durability.strict` is self-documenting, and future policies
(flush-after-100ms) get names without new kwargs. Cost: a whole
constant wardrobe for what is, today, one integer. **Riff 3** is
maximal flexibility, and that's the indictment: durability becomes a
per-*call-site* opinion, so the invariant "this journal survives
crashes" stops being a property of the object and becomes a property
of every author's judgment, forever. Flexibility is where invariants
go to die.

## The verdict, and the meta-verdict

Shape 1 deserved to ship: a durability contract belongs to the
*object* (riff 3 dissolves it), and one integer hasn't yet earned a
policy wardrobe (riff 2 can arrive later, *wrapping* the kwarg,
the day time-based flushing becomes real — nothing about shipping
the kwarg forecloses the sentence-shaped API).

The meta-verdict matters more than this knob: the exercise cost
forty lines and ten minutes, against the years a shipped API lives
and the majors it costs to change. Every riff here *executes* —
sketches that run tell you things sketches in a gist don't, like
riff 3's keyword colliding with the payload hash the moment a real
caller showed up (Ruby's kwargs had opinions; the call site always
knows more than the class definition).

## Notes

- Riffing needs a subject with real constraints — I riffed against
  the actual journal, inherited its real signature, hit its real
  argument-passing semantics. Riffs against imaginary classes only
  produce imaginary confidence.
- The three shapes here are THE three shapes of most config
  decisions: construction-time value, named policy, per-use
  override. Learn to hear all three before believing the first.

## Verdict

Call sites read differently than class definitions, and the call
site is where your users live. Riff before you commit: three shapes,
ten minutes, read aloud — and the shipped kwarg now has a written
record of why it beat its rivals, which is more than most APIs can
say.
