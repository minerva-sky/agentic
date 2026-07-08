# Round 17 field notes — Mike Dalessio builds the document refinery

*Built: `examples/document_refinery.rb` — an HTML-to-digest ETL
pipeline as a plan: decode → sanitize → extract → resolve per
document, documents in parallel, one digest fan-in, and a referee
that greps the refined product for everything the fixtures smuggled
in. Exit 1 if any hostility survives refinement.*

## What I built and why

Round 12 I tortured the journal with hostile inputs. This time the
brief asked for a *product*, so I built the workflow I've spent
fifteen years supplying parts for: taking markup you didn't write —
script injections, `onload=` handlers, `javascript:` hrefs, tracking
pixels, encoding damage — and refining it into something you'd let
near a user. The framework's contribution is the shape: each stage
is a task, each document is an independent chain, the chains run in
parallel under one ceiling, and the digest is an honest fan-in that
reads its dependencies by name.

```
refined 3 feeds in parallel:
  - Changelog Weekly — Issue 12 (1 links) - ...
  - Ruby News (1 links) - ...                    [pwn(), steal(), tracker gone]
  - Café Ruby, la gazette (1 links) - ...        [latin-1 bytes, repaired]
referee: no script bodies, no javascript: hrefs, no event handlers,
         all output valid UTF-8, relative links resolved, 3/3 present
```

## The pipeline corrected its author, structurally

My first draft ran encoding repair *last* — "normalize" as a
finishing touch, the way it reads in a design doc. The plan refused:
the sanitize stage crashed on the gazette, because **you cannot run
a regex over invalid UTF-8** — every downstream stage assumes valid
encoding as a precondition. The fix is the ordering Nokogiri has
always embodied (encoding detection happens at *parse*, before
anything touches the tree): **decode is the price of admission, not
a garnish.** The pipeline-as-plan made the wrong order fail loudly
at the right stage name, which is more than my design doc did.

Second fixture lesson, smaller but real: my "latin-1" gazette
originally contained a UTF-8 em dash *and* latin-1 bytes — mixed
encoding in one string — and the repair correctly turned the em dash
into `â€"` porridge. Single strings with two encodings are beyond
transcoding; that one you fix at the source, which is exactly what
real feed triage looks like.

## Notes

- Stdlib-only parsing keeps the example offline; the comment says
  plainly to put Nokogiri at stage 2 in production. Regexes over
  HTML are a demo dialect, not a recommendation — I wrote the
  library that exists so you don't do this.
- Sanitize-before-extract is the other load-bearing order: extract
  from unsanitized markup and your extractor can be steered by what
  the attacker left for it to find.
- The referee greps *outputs* for the fixtures' specific payloads
  (`track(`, `pwn(`, `steal(`, `javascript:`) — the assertion aims
  at what was smuggled in, not at generic cleanliness.

## Verdict

Three hostile feeds in, one clean digest out, and the plan's own
stage boundaries taught the author his ordering was wrong before
any user could learn it the harder way. Parse hostile things with
real parsers, repair encodings at the door, and let the pipeline
shape *be* the security model.
