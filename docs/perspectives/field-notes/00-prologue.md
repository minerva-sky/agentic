# Prologue — before anyone could build anything

*Field notes from the session itself, before putting on any persona.*

Every persona's build depends on a trustworthy test suite, so the first stop
was `rake spec`. What we found shaped everything after it:

- `rspec` reported **65 examples** in 0.06 seconds. A `--dry-run` reported
  **474 examples**. The suite wasn't fast; it was being killed.
- The culprit: `spec/agentic/cli_spec.rb` invoked
  `agent create --role=... --instructions=...`, but the command requires
  `--purpose`. Thor's `exit_on_failure?` is `true`, so Thor called `exit(1)`
  — inside the rspec process — and the run silently truncated at whatever
  example happened to be number 65.
- Repairing that revealed **12 latent failures** that had presumably been
  red for a long time, invisible because the process died before reaching
  them.

The latent failures were real bugs, not stale assertions:

1. `Agentic::Agent.new do |a| ... end` in the CLI and in specs — but
   `Agent#initialize` never yields, so the configuration block was silently
   discarded. Agents were being created with nil roles and purposes.
   (`Agent.build` is the yielding constructor.)
2. `PersistentAgentStore#store` generated an ID for id-less agents but never
   assigned it back, so storing the same agent twice created two unrelated
   agents instead of two versions of one.
3. `PersistentAgentStore#list_all` didn't accept the `all(filter: {...})`
   calling convention its own ADR-015 documents.
4. `Agentic.register_capability` / `.assemble_agent` used module ivars
   directly, so the public readers existed but were bypassed — and specs that
   stubbed the readers were stubbing nothing.
5. Capability inference required the literal string `data_analysis` to appear
   in a task description; "Analyze the data" matched nothing.

**Lesson for the room:** a test suite that exits early is worse than a failing
one — it converts red to green by truncation. If your CI passed on this
codebase, your CI was measuring how far rspec got before Thor shot it.
