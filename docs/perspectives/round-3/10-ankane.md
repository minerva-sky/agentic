# Round 3 field notes — Andrew Kane ships the Changelog Scout

*Built: `examples/changelog_scout.rb` — classifies real git history
through a contract-checked capability and drafts release notes:
features, fixes, internals, and a one-line summary of the quiet work.*

## What I built and why

The release-notes chore, automated the way I'd actually automate it:
one `classify_commit` capability (subject in; kind, cleaned note,
breaking-flag out), one task per commit fanned out at concurrency 8,
one writer task that fans all forty classifications in and drafts the
markdown. Real repo, real history, 50ms.

And the demo gods smiled: pointed at this branch, the scout's output
*is the summary of this whole experiment* — ten features, four fixes
(the suite truncation, the reactor nesting, the logger level, the
scheduler deadlock), one internal, twenty-five docs commits. A tool
that documents the project that built it on its first run is a tool
I'd package tonight.

## The design choice worth copying

The classifier is a deterministic lambda *behind a declared contract*.
Conventional-commit parsing covers 95% of real subjects for free — and
when you want an LLM to handle the messy 5% ("various fixes", "wip",
the Friday-afternoon specials), you swap the lambda for a client call
and **nothing else changes**, because the contract
(`kind/note/breaking`) is the interface the writer consumes. Start
deterministic, upgrade selectively, keep the seam typed. That's the
whole playbook for sprinkling LLMs into working software without
letting them eat the architecture.

## Scorekeeping across three rounds

I keep count of when the orchestrator earns its keep versus plain
capability calls. This one earns it twice: real fan-out (40 commits)
*and* fan-in (the writer needs all classifications). In round 2 I built
Gem Scout without the orchestrator because two sequential calls didn't
need a scheduler — and I stand by the rule the README now prints:
capabilities first, orchestrator when there's a queue, planner when
the task list itself should come from a model. The framework finally
documents its own gradient. Frameworks that tell you when *not* to use
their big hammer are the ones that survive.

## What I'd ship next

`--since v0.2.0` (tag-to-HEAD range), a `CHANGELOG.md` writer mode, and
a `--llm` flag that routes only unparseable subjects to a model. At
that point: `gem install changelog_scout`. Examples should keep
graduating into gems — that's the ecosystem working as intended.
