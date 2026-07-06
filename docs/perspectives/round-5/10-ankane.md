# Round 5 field notes — Andrew Kane catalogs the gallery

*Built: `examples/examples_index.rb` — reads every example's own
header, writes `examples/README.md`, and fails loudly on any example
that doesn't document how to run itself.*

## What I built and why

Five rounds produced forty examples — a gallery with no signage. The
signage problem has the same solution as the README-rot problem I
attacked in round 4: **generate the catalog from the artifacts**, so
it can't disagree with them. The librarian tasks fan out (one per
file), each reads its example's leading comment block, and the editor
fans in and writes the table. `examples/README.md` now exists, says
"edit the examples, not this file," and regenerates in one command.

The enforcement matters as much as the catalog: an example whose
header lacks a `bundle exec ruby` line fails the build (exit 1),
because **an example you can't run is a rumor**. Forty of forty pass
today — every persona, it turns out, wrote honest headers. Culture
audits itself when tools check it.

## Confession, as gallery tradition requires

First run cataloged all forty summaries as
"frozen_string_literal: true" — my header extractor grabbed the first
comment it saw, and the first comment in every file is the magic
comment. Parsing "the comment block" means knowing which comments are
prose and which are pragmas; even a forty-line tool meets the
regexes-vs-grammar lesson eventually. (Aaron is legally entitled to
one laugh.)

## Patterns worth naming, five rounds in

- This is the survey/atlas shape's **seventh** appearance, and its
  most meta: the framework cataloging the demonstrations of itself.
- The generated file is committed, not gitignored — same call as
  Xavier's Mermaid: a catalog you can read on GitHub beats a catalog
  you must generate to see, and CI regenerating + diffing keeps it
  honest (`examples_index.rb && git diff --exit-code examples/README.md`
  is the whole check).
- Self-excluding (`files - [me]`) keeps the librarian out of her own
  catalog. Tools that inventory a directory they live in always need
  this line, and always forget it once.

## Verdict

The gallery has signage that maintains itself and a doorman that
rejects undocumented exhibits. Between the README verifier, the
contract fuzzer, and this index, the project's honesty checks now
cover code promises, contract promises, and catalog promises — all
generated, all CI-able, all built on one gem's primitives.
