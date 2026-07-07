# Round 13 field notes — Steve Klabnik puts the docs on trial

*Built: `examples/doctest_runner.rb` — every `@example` block in lib/
and every ```ruby fence in the README harvested and executed in
sandboxed subprocesses. 11 of 30 are alive.*

## What I built and why

The single biggest thing Rust's documentation culture got right
wasn't tone or completeness — it was that **examples in docs
execute**. `cargo test` runs every code block in every doc comment,
which means a Rust example cannot silently rot: the API changes, the
doctest goes red, someone fixes the letter before a reader ever
opens it. I've spent years telling other ecosystems this is
portable. So: harvest, sandbox, run, report.

```
30 documented examples put on trial
11 RUN
19 dead: undefined local variable, uninitialized constant,
         missing config, drifted method names...
```

Eleven alive out of thirty. Every dead one is *a reader's first
attempt at this library, failing* — because docs written as
illustration were never promoted to execution. And note what kind
of failure each is: `undefined local variable` means the example
references setup it never shows (the reader can't run it either —
the doc is a fragment posing as a program); `undefined method
'comp...'` means the API *drifted* and the README kept teaching the
old world. The second kind is the killer. Nobody chose to lie; the
lie accreted.

## The trial's fairness matters

Each snippet runs in its own process with its own tmpdir and the
gem on the load path — dead examples must be dead on their *own*
merits, not because a neighbor polluted the interpreter. And the
verdict column preserves the first error line, because "dead" without
a cause is a complaint, while "dead: undefined local variable
`plan`" is a diff someone can write.

Fairness also demands this caveat, stated plainly: some of the 19
need credentials or network by nature (a real LLM config), and
"needs setup the fence doesn't show" is a different disease from
"teaches an API that no longer exists" — but both present
identically to a newcomer, which is rather the point. Rust's answer
was annotations (`no_run`, `ignore`) that keep even the non-runnable
examples *compiled*. That's the shape of the fix here too.

Filed as the round-14 ask: promote the README's fences and lib's
@example blocks to runnable-or-annotated — every fence either
executes in CI via this runner, or carries an explicit
"illustrative" marker chosen by a human, on purpose.

## Notes

- The two learning-system examples dying with a LoadError is itself
  a census finding — dead docs cluster around dead-ish corners of
  code. Doc health is a proxy for code health more often than
  either community admits.
- Documentation is a love letter to your future self — and love
  letters are better when the address still exists.

## Verdict

Thirty letters, eleven deliverable. The runner turns docs rot from
a newcomer-facing ambush into a red build, which is the only place
rot ever gets fixed. Arrest the examples you have before writing
more.
