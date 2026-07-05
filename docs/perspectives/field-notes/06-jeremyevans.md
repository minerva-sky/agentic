# Field notes — Jeremy Evans

*Build: fail-fast credential validation and library logging etiquette.*

## What I did

- Removed the `"ollama"` default access token. `Configuration#access_token`
  is now the environment variables or nil — no invented credential.
- Added `Configuration#validate!` and `Agentic::Errors::ConfigurationError`.
  `LlmClient.new` validates at construction: no token and no base URL means
  you find out **now**, with a message listing the three ways to fix it —
  not twenty minutes later as a bare 401 from a host you didn't know you
  were talking to.
- Base-URL-only setups (Ollama and friends) remain first-class: they pass
  validation and get an explicit `"local"` placeholder token, because local
  endpoints ignore it. The difference from before is that this is now a
  *decision written in code with a comment*, not a magic string in a
  default.
- Default logger level is now `:warn`. A library that prints
  `INFO: Registered capability: ...` eight times into its host's stdout is
  taking liberties. The CLI can raise verbosity for interactive use; that's
  its prerogative, not the library's default.

## What I found while doing it

The best part: `cli.rb` already had `check_api_token!`, which raises a
helpful boxed error `unless Agentic.configuration.access_token`. Dead code.
The `"ollama"` default meant `access_token` could **never** be nil, so the
guard never fired, so every misconfigured user sailed straight past the
helpful error into the confusing one. A fail-fast check and a
silently-succeeding default cannot coexist; the default always wins. Delete
the default and the check started working for the first time — I just had to
teach it that a base URL is also a valid answer.

Also worth stating plainly: `filter_sensitive_data` in the spec helper was
dutifully scrubbing the string `"ollama"` out of VCR cassettes. Security
theater for a credential that never existed.

Postscript: setting the default level to `:warn` did nothing at first.
`Agentic::Logger#initialize(*args)` was folding the `level: :warn` keyword
into a positional hash — which `::Logger` reads as `shift_age` — so every
level ever passed to this constructor had been silently discarded and the
logger always ran at DEBUG. Ruby 3 keyword separation is not optional
trivia. `initialize(...)` forwards correctly; the INFO chatter is gone.

## What I did not do (yet), and would

- The gemspec still ships thor + six tty-* gems + ostruct to every library
  consumer. The Zeitwerk cleanup means they no longer *load*, which fixes
  the runtime cost, but they still *install*. The real fix is an
  `agentic-cli` gem. That's a release-process decision, not a patch, so I
  left it as a recommendation.
- `ExecutionHistoryStore` does read-modify-write on JSON files with no file
  locking, under an orchestrator whose whole job is concurrency. Perham's
  journal (see his notes) is the model; the history store should follow it.

## Verdict

Errors moved from request time to boot time, the fake credential is gone,
and the library stopped talking over its host. Correctness is mostly the
discipline of refusing to guess.
