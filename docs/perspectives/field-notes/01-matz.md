# Field notes — Yukihiro "Matz" Matsumoto

*Build: `examples/haiku_agent.rb` — the three-line agent.*

## What I did

I did what I always do with a new gem: opened a console and tried to write
the smallest program that makes me smile. It became `examples/haiku_agent.rb`
— an agent in three lines, a capability as a lambda, a poem as the result.
It runs with no API key, because a capability is just a callable and the
framework doesn't insist on a network to be understood. That is a very good
property. Programs you can understand offline are programs you can trust.

## What made me happy

- `Agent.build do |a| ... end` — the builder block reads like Ruby breathing.
- `CapabilityProvider.new(implementation: ->(inputs) { ... })` — the entire
  extension story is "hand me a callable." No base class to inherit, no
  interface to declare. This is the principle of least surprise applied to
  plugins.
- The `StructuredOutputs::Schema` DSL (`s.string :name, enum: [...]`) feels
  like it grew here rather than being transplanted from JSON Schema.

## What made me pause

- My poem arrived wrapped in bureaucracy: eight lines of
  `INFO: Registered capability: ...` before three lines of haiku. A library
  that speaks when not spoken to is like a friend who narrates their own
  helpfulness. (Jeremy says he will fix the default logger. Good.)
- I wrote `poet.execute_capability("haiku", ...)` but I first tried
  `poet.execute(...)` and `task.perform(poet)` — three verbs for one idea.
  The objects should agree on a sentence structure. My suggestion: the agent
  is the subject. `poet.perform(task)`. Subjects act; objects receive.
- `add_capability` raises `"Capability not found: haiku"` as a plain
  `RuntimeError` if you forget to register first. I forgot, so I met it.
  A `Agentic::CapabilityNotFoundError` would have told me *who* was
  complaining. (Sandi has opinions here too.)

## Verdict

Three lines to an agent, one screen to the whole idea. The gem passes the
happiness test at small scale — now it should pass it at every scale.
