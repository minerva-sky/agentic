# Round 10 field notes — Andrew Kane ships the reject file

*Built: `examples/batch_import.rb` — 500 seeded-dirty rows through
one contract: 382 accepted, 118 rejected with line, field, and rule,
in 81ms.*

## What I built and why

Every data tool I've shipped eventually meets the same file: the
customer upload. Typos in enums (`"trian"`), zero weights, columns
that drifted a header to the left, and combinations that are
individually fine and jointly impossible. The two ways importers
die: they **raise on row 37** (an importer that crashes on the
first bad row is a tool for importing 36 rows), or they **write
"invalid row"** in a log (a reject file without reasons is a support
ticket generator).

The contract turns out to supply both fixes for free:

```
accepted: 382   rejected: 118   (500 rows, 81ms, 162us/row)
reject causes: customs 45, mode 36, weight 26, fits 11
line 12: customs: express requires customs_code
```

Collect-don't-crash is just `rescue ValidationError` per row — the
validator reports *every* violation on a row at once (round-5
behavior), so a row with three problems generates one reject line
with three reasons, not three round-trips through support. And the
reasons are already sentences, because the relations derive their
own messages.

## The rows only relations catch

The interesting rejects are `fits: 11` and most of `customs: 45` —
rows where **every column is individually valid**. Weight 4,000:
fine. Volume 4,500: fine. Together: not fine, and no per-column
check — no spreadsheet data-validation dropdown, no CSV linter —
will ever catch it, because the error lives *between* columns.
Cross-field dirt is the dirt that survives all the usual cleaning,
which is exactly why it's the dirt that reaches production. One
declared `sum_lte` caught all eleven.

Throughput note, because importers are batch jobs: 162 microseconds
a row including the rejection path. Aaron's bench said the same
thing this morning from the other side — at these prices you
validate everything and the bottleneck remains, as always, the
part that talks to the network.

## Notes

- The reject file records `line: index + 2` — one-based plus the
  header row. Off-by-two line numbers in reject files have burned
  more support hours than most bugs; if your reject file says line
  12, pressing ctrl-G 12 in the customer's actual CSV must land on
  the bad row.
- The summary histogram (`customs 45 ####...`) is for the engineer;
  the per-line file is for support. Same data, two audiences, both
  derived — don't make either one read the other's report.

## Verdict

An importer is a contract with a patience policy. This one accepts
382 rows, explains 118 rejections down to the rule, and costs less
per row than a DNS lookup. Ship the reject file; your support queue
will send flowers.
