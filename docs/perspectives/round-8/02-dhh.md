# Round 8 field notes — DHH draws the hill

*Built: `examples/hill_chart.rb` — Basecamp's hill chart rendered live
from lifecycle hooks: uphill while uncertain, downhill once it's just
execution.*

## What I built and why

The hill chart is the only progress visualization I've ever trusted,
because it separates the two things "80% done" conflates: **figuring
out** versus **doing**. Plans have the same split, and the hooks map
onto it without a single judgment call: pending and queued climb the
left slope (waiting on dependencies or a slot — uncertainty you can't
schedule away), `task_slot_acquired` crests the hill, done rolls to
the right base. Three snapshots show the release rolling downhill,
BC→EF→ABCDEF, nobody asked anyone for a percentage.

The kanban board (round 5) shows *columns*; the hill shows *risk*.
A task stuck uphill for three snapshots is a different conversation
than a task grinding downhill — the first needs unblocking, the
second needs patience. Boards can't say that; hills say only that.

## The honest-divider argument

Human hill charts have a known failure mode: people park dots at the
crest because admitting "still uphill" feels like confessing. This
hill can't lie — positions are derived from hook events, and the
crest is *literally* `task_slot_acquired`. When the chart is a
projection of facts rather than a survey of feelings, the pathology
disappears. Same lesson as the check-in (round 7): status extracted
from work beats status reported about work, every time, because it
can't be performed.

## Notes

- The surface-following renderer reads the hill's own ASCII art to
  find where letters sit — the drawing is data about itself. Silly,
  but it meant changing the hill shape is editing a string, not a
  coordinate table.
- Mapping choice worth stating: `queued` (scheduled, awaiting a slot
  or dependencies) is UPhill. That's the round-4 hook distinction
  paying off again — before `task_slot_acquired` existed, queued and
  running were indistinguishable, and this chart would have put
  blocked work on the downhill side, which is exactly the lie hill
  charts exist to prevent.

## Verdict

Kanban for columns, hills for risk, check-ins for prose — all three
generated from the same hooks, none requiring a meeting. The project
management suite nobody has to feed is nearly complete; someone
should stop me before I build the Gantt-chart-hater's Gantt chart.
(Aaron already did. It's fine. It's good, even.)
