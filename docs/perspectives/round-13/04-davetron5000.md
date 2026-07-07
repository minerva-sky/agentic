# Round 13 field notes — David Bryant Copeland signs the CLI contract

*Built: `examples/cli_contract.rb` — a plan wrapped in a CLI that
honors all four channels (stdout, stderr, exit code, --format json),
proven by invoking itself the way its real consumers would.*

## What I built and why

I wrote a whole book about command-line applications because the
industry keeps treating CLIs as the *casual* interface — and then
wiring them into cron, CI, and shell pipelines, which are the least
casual consumers in computing. A CLI is an API whose clients are
scripts and a tired human at 2am, and each client reads a different
channel:

```
$ digest                       -> stories on stdout, progress on stderr, exit 0
$ digest --format=json --quiet -> pure JSON, silence, exit 0
$ digest --quiet --fail        -> diagnosis + HINT on stderr, exit 1
$ digest --formt=json          -> usage on stderr, exit 64
```

Four invocations, four consumers, and every channel doing exactly
one job. The human sees progress without polluting `digest >
out.txt`. The pipe gets JSON that jq will never choke on, because
chatter went to stderr and `--quiet` killed even that. Cron stays
silent until something matters — the discipline that keeps ops from
mail-filtering your tool into oblivion — and when it fails, the
error comes *with a hint*, because a diagnostic without a next
action is half a diagnostic.

## Exit 64 is the tell

The detail that separates tools people script against from tools
they script around: the typo'd flag exits **64** (`EX_USAGE`, from
sysexits.h), not 1. "You called me wrong" and "the work failed" are
different facts. A deploy script wants to retry a transient exit 1;
retrying an exit 64 means retrying your own typo forever. The
framework helped here more than it knows: `PlanExecutionResult`
distinguishes success from partial failure, and the failure object
carries a typed, messaged cause — so mapping outcomes onto the exit
code taxonomy was a case statement, not archaeology.

Testing note: the whole CLI runs through `run(argv, stdout:,
stderr:)` with injected streams — which is why the example can
invoke itself four ways and assert on the channels. A CLI whose
entry point writes to global `$stdout` is a CLI you can only test
with subprocess gymnastics; inject the streams and your CLI becomes
a function. (This is the one trick from the book I will teach anyone
who stands still long enough.)

## Notes

- `--format=json` should be the *contract* format: shell text output
  is for eyes and may change; JSON output is for machines and gets
  semver discipline. Say so in --help.
- Not built, noted: `--verbose` tiers and a real option parser. The
  hand-rolled loop is fine at two flags and a liability at five —
  the moment options interact, reach for OptionParser and keep the
  stream injection.

## Verdict

Data to stdout, diagnostics to stderr, verdicts in exit codes,
machine format on request — none of it glamorous, all of it the
difference between a tool that joins pipelines and one that breaks
them. The plan supplied the outcomes; the CLI's job was just to
route four facts to four channels without crossing the wires.
