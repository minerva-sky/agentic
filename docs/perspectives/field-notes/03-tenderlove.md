# Field notes — Aaron Patterson (tenderlove)

*Build: `benchmark/boot.rb` + a mutex for the global that needed one.*

## What I did

Two things, because you can't fix what you can't measure and you shouldn't
measure what you won't fix:

1. **`benchmark/boot.rb`** — each scenario in a fresh subprocess, reporting
   wall time, object allocations, and `$LOADED_FEATURES` count.
2. **Made `Agentic.initialize_agent_assembly` thread-safe.** It memoized four
   pieces of global state with a bare `unless @ivar` check. Two threads walk
   in, both see nil, both build a `PersistentAgentStore`, and now you have
   two objects that both think they own `~/.agentic/agents/index.json`.
   Classic check-then-act. Mutex, double-checked re-entry, and — the subtle
   part — the flag ivar is now assigned *last*, so a thread that skips the
   lock can never observe a half-built system. I have fixed this exact bug in
   Rails so many times I could type it with my chin.

## The numbers (Ruby 3.3.6, this machine)

| scenario | wall | allocations | loaded files |
|---|---|---|---|
| baseline (empty ruby) | ~0 ms | 4 | 156 |
| `require "agentic"` | 14.5 ms | 11,791 | 186 |
| + `Agentic::CLI` (thor, tty-*) | 41.2 ms | 39,948 | 251 |
| + agent assembly init | 30.4 ms | 29,375 | 205 |

Before Xavier's loader cleanup, that first row was **272 ms and 612 files** —
every library consumer paid the full CLI row on every boot. Now the tty-*
tax is only charged to people actually running the CLI, which is the whole
point of autoloading.

## Things I noticed while in there

- The assembly init allocates ~29k objects, most of it JSON-parsing the
  agent index and registering seven standard capabilities. It's lazy now, so
  nobody pays it until they touch capabilities. Good. Keep it lazy.
- `Agentic.logger` defaults to `$stdout` at **debug** level. My benchmark had
  to set `level = :error` just to keep its own output readable. A library
  printing INFO into its host's stdout is how you end up in *my* terminal,
  and I will find you. (Jeremy is on it.)
- Nothing here is CPU-bound enough for YJIT to matter; your latency budget
  is 99.9% OpenAI. But boot time and allocations are paid by every process,
  network or not — which is why they're the right thing to benchmark.

## Verdict

The gem boots fast now, the global init is safe, and there's a benchmark to
keep both honest. Also I found a filesystem race in the agent store's
read-modify-write of `index.json`, but Perham gets paid to worry about
durability, so I left him a note. It's his turn.
