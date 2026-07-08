# Round 17 field notes — Xavier Noria autoloads the capabilities

*Built: `examples/capability_autoloader.rb` — Zeitwerk's contract
ported to capability packs: file path ↔ constant name ↔ capability
name, one bijection, three views. Lazy loading on first use, eager
loading that verifies the bijection at boot, and hot reload with no
process restart.*

## What I built and why

Nine rounds of building *analyzers* on this framework — cartographers,
diffs, invariants. The brief finally asked for an *experience*, and
the experience I know how to manufacture is the one Zeitwerk gave
Rails: **you stop writing requires, and nothing is worse for it.**
The gem's capability registry is good, but every consumer program in
this catalog registers capabilities by hand — a ceremony that lists
everything twice, once on disk and once in an init block. Conventions
delete the second list:

```
pack on disk: 3 files; capabilities loaded: 0 (laziness is a feature)
first use of text.summarize -> loaded 1/3 files
eager_load!: 2 loaded, 1 contract violation:
  BOOT ERROR: expected math/percentile.rb to define Math::Percentile
reload! then re-use -> "EDIT THE FILE!" (the edit, live, no restart)
```

Drop `text/summarize.rb` defining `Text::Summarize` with a `.call`,
and the capability `"text.summarize"` exists. The loader is ~50
lines because the contract does all the work: `camelize` is the
whole bijection, `ensure!` is lazy mode, `eager_load!` is production
mode — load *everything* and verify each file defines the constant
its path promises. The misnamed file (`Math2` in `math/percentile.rb`)
is caught **at boot, by name**, which is the entire point of eager
loading: a file that lies about its constant is a bug you want on
deploy day, not at 3am when someone first touches percentiles.

## Two enemies, both old friends

**Stale registrations.** First reload attempt: the constant was
fresh but the registry still answered with the old provider — same
name, same version. The fix uses the registry's own semantics
instead of fighting them: each reload generation registers as
`1.0.N`, and unversioned lookups resolve to the latest. Old
providers *age out* rather than being mutated in place — which is
also how I'd want a production reloader to behave.

**Cached references.** Second reload attempt: the *agent* had
snapshotted its provider at `add_capability` time. This is the same
war Zeitwerk fights against `MyClass = SomeConstant` — no reloader
can help you if you keep a pointer to the old world. The demo
refreshes the add; a framework fix would be agents resolving
providers per-execute (an unversioned lookup is already cheap).

## Notes

- The one ask: a registry miss-hook — `const_missing` for
  capabilities — would make the loader invisible, and invisible is
  what a loader should be.
- Structured returns (hashes) turned out to be a *convention the
  framework enforces* — the validator rejects bare strings. Good:
  conventions you can't violate silently are the only kind that hold.

## Verdict

Zero requires, one bijection, three gears — lazy, eager, reload.
The registry's version tracking gave reload semantics for free, and
the eager-load contract check turns naming sloppiness into a boot
error with a filename in it. Conventions aren't a style preference;
they're executable documentation with a stack trace.
