# Round 5 field notes — DHH ships the kanban board

*Built: `examples/kanban_board.rb` — a running plan rendered as To Do /
Doing / Done, every frame captured live from lifecycle hooks.*

## What I built and why

We spent two decades wiring project-management tools to *approximate*
the state of work, staffed with people whose job is updating the
approximation. But when the work is a plan, the orchestrator already
IS the board — the columns are just `pending`, `in_progress`, and
`completed` wearing better clothes. Two hooks move the cards:

- `task_slot_acquired` → card moves To Do → Doing (note: *slot*
  acquired, not scheduled — a card in Doing means someone is actually
  working it, which is the entire honesty proposition of a kanban
  board; before round 4's hook this column would have lied)
- `after_task_success` → Doing → Done

Twelve frames, 302ms, and mid-flight the board shows exactly what a
two-person team looks like: `layout page` in Doing, `review` and
`publish` waiting on it, three cards shipped. Nobody typed a status.

## The insight worth the price of admission

The **WIP limit is the concurrency limit.** Kanban's whole discipline —
"limit work in progress" — is `concurrency_limit: 2`, enforced by the
scheduler instead of by a coach reminding people in a meeting. When
your process tool and your execution engine are the same object, the
process can't drift from reality, because it *is* reality. That's the
argument I've been making about software writ small: the best process
is the one your system enforces structurally, invisibly, for free.

## Notes

- The board never shows a "Blocked" column because dependency-waiting
  cards just stay in To Do. For this demo that's fine; a real board
  wants `blocked` derived from graph[:dependencies] minus done. One
  `orchestrator.graph` call — everything's there. Fizzy could be forty
  lines on this framework, and I'm only half joking.
- Frame capture is an array push in a hook — Samuel's
  "hooks-run-inline" contract means I thought about cost for exactly
  one second, which is what a documented contract buys.

## Verdict

Five rounds ago this framework couldn't tell you what it was doing;
now it renders its own kanban in real time from two hooks. Delete the
status meeting. The plan will speak for itself.
