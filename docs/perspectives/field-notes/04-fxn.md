# Field notes — Xavier Noria (fxn)

*Build: make Zeitwerk the single code loader for the gem.*

## What I did

- Deleted all 37 `require_relative` calls that pointed at Zeitwerk-managed
  files: nine in `lib/agentic.rb` and the rest scattered through `lib/`
  (`agent.rb`, `plan_orchestrator.rb`, `task.rb`, the verification
  strategies, …). Constants are now resolved by the loader, as they should be.
- Stopped eager-requiring the CLI from the library entrypoint. The
  `do_not_eager_load` on `lib/agentic/cli` was already correct in spirit —
  but the very next lines required those files by hand, defeating it.
  `exe/agentic` reaches `Agentic::CLI` through a normal autoload.
- Added `require "thor"` to the two CLI files that reopen
  `class CLI < Thor`, so each file in that directory is loadable on its own.
  Requiring *external* dependencies at the top of the file that needs them is
  the correct pattern; requiring *siblings* is not.

## What I found while doing it

- The comment justifying the requires — "Thor requires subcommands to be
  loaded before they're referenced" — was a misdiagnosis. Thor's `subcommand`
  takes a constant; referencing the constant triggers the autoload. The one
  real loading bug was elsewhere: `lib/agentic/ui.rb` defines `Agentic::UI`,
  but the inflector only knew about `cli`. Every reference to `Agentic::UI`
  worked *only because* of the manual require. Remove the crutch and the
  misconfiguration surfaces immediately: `NameError: uninitialized constant
  Agentic::Ui`. This is the recurring lesson: mixed loading doesn't just
  offend taste, it **masks** configuration errors.
- `Zeitwerk::Loader.eager_load_all` now passes, which is the real proof that
  every file/constant pair in the project is coherent. I'd suggest adding
  exactly that as a spec — it's the cheapest CI guard Zeitwerk offers.

## Measured result

| | before | after |
|---|---|---|
| `require "agentic"` | ~272 ms | ~14 ms |
| `$LOADED_FEATURES` after require | 612 | 186 |

A 19× faster require, and library consumers no longer load Thor, six tty-*
gems, and Pastel to use a `TaskPlanner`. Aaron will want these numbers for
his benchmark; he can have them.

## What worked well / what didn't

- **Well:** the file naming was already 100% conventional. Not one file
  needed renaming — only the inflector entry for `UI`. Whoever laid out this
  tree had internalized the conventions even while bypassing the loader.
- **Didn't:** `spec/spec_helper.rb` requires the whole gem for every spec, so
  nobody noticed the library couldn't autoload on its own. Fast requires also
  make `bin/console` start instantly, which is where Matz is headed next.
