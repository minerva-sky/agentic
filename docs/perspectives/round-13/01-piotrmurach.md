# Round 13 field notes — Piotr Murach composes the status board

*Built: `examples/tty_status.rb` — a plan's live state rendered as
composed terminal components (badge, gauge, tree, frame), driven
entirely by lifecycle hooks. Three frames, zero dependencies.*

## What I built and why

I've published a few dozen tty-* gems, and the reason there are
dozens instead of one is the entire philosophy: **terminal output is
a user interface, and interfaces are built from components.** A
spinner is not a progress bar is not a table is not a box — each is
one small thing with one job, and applications *compose* them. The
alternative — `puts` sprinkled wherever the mood struck — is how
CLIs end up with output nobody can read, redirect, or test.

```
+--------------------------------+
| after parse entries            |
+--------------------------------+
| [x] fetch feeds                |
| |-- [x] parse entries          |
|     |-- [ ] rank stories       |
|         `-- [ ] publish digest |
|                                |
| |============            | 2/4 |
+--------------------------------+
```

Four components, each testable alone: `badge` (state → glyph),
`gauge` (counts → bar), `tree` (depth → indent, using the graph's
own `stats[:depth]`), `frame` (lines → box). The StatusBoard only
composes. When the gauge needs to become a spinner, you swap one
component and no rendering code learns about it — that's the whole
toolbox discipline in one sentence.

## The seams were ready

What made this a pleasure to build on: the two data sources are
exactly UI-shaped. The **hooks** hand over state transitions with
names and timing — precisely what a live view consumes, no polling,
no diffing. The **graph** hands over structure — depth for
indentation, order for row sequence — precomputed by round 8's
stats. A UI layer should never have to *derive* the model; it should
only have to *dress* it, and here the model arrives dressed-ready.

One design note on frames versus streaming: the board captures
snapshots at milestones rather than repainting live, which makes the
example testable and redirectable (frames are just arrays of
strings). A real TUI would repaint — but the component layer is
*identical* in both worlds; only the presenter loop changes. Design
the components first and the paint cadence becomes a deployment
detail.

## Notes

- No escape codes, no curses, no gems — deliberately. The discipline
  is the demonstration; color and cursor movement are twenty minutes
  of decoration once the structure is right (and pastel would like a
  word about the colors).
- The `tree` glyphs follow the `|--`/`` `-- `` convention because
  eyes trained on `tree(1)` parse it for free. Terminal UI has
  conventions the way the web does; break them only on purpose.

## Verdict

The plan already knew its structure and announced its transitions;
four tiny components turned that into an interface that was
designed, not accreted. Build the components, compose the board,
and let the terminal be what it's always been: a UI toolkit wearing
a typewriter costume.
