# Field notes — Mike Perham (mperham)

*Build: `ExecutionJournal` — the plan state that survives `kill -9`.*

## What I did

Added `Agentic::ExecutionJournal`: an append-only JSONL journal that plugs
into `PlanOrchestrator`'s lifecycle hooks. One JSON line per event —
`task_started`, `task_succeeded` (with output), `task_failed` (with error),
`plan_completed` — each write taken under a mutex *and* an exclusive file
lock, flushed, and fsynced before the hook returns. `ExecutionJournal.replay`
reads the file back into a `ReplayedState`: which tasks completed, what
each one produced, what failed and why. Retry-then-succeed collapses to
completed, the way an operator would expect.

```ruby
journal = Agentic::ExecutionJournal.new(path: "orders.journal.jsonl")
orchestrator = Agentic::PlanOrchestrator.new(lifecycle_hooks: journal.lifecycle_hooks)
# deploy hits, process dies, rerun:
state = Agentic::ExecutionJournal.replay(path: "orders.journal.jsonl")
state.completed?("task-3")  # => true; do NOT pay OpenAI for it again
```

The hooks chain: `journal.lifecycle_hooks(observer.lifecycle_hooks)` journals
first, then delegates, so the CLI's pretty progress display and the boring
durable record coexist. Durability shouldn't cost you your spinners.

## Why this design and not something fancier

- **Append-only JSONL** because the failure mode of "append a line" is a
  truncated last line, which replay can skip; the failure mode of
  "rewrite a JSON document" (what the agent-store index does today) is a
  destroyed file.
- **fsync per event** because a plan event is worth dollars. When each line
  represents an LLM call you'd otherwise re-run at $0.01–$1 a pop, one
  `fdatasync` is the cheapest insurance you will ever buy. If someone runs
  thousand-task plans, batching is a constructor option away — start correct.
- **No new dependency.** Redis is where this ends up at scale (ask me how I
  know), but a gem should offer durability before it demands infrastructure.

## What I found while doing it

- The lifecycle hooks are *exactly* right as an integration seam — I built
  full durability without touching a line of the orchestrator. Whoever
  designed those hooks earned their keep.
- The orchestrator's in-memory `@results` and the observer's save-at-the-end
  `result-TIMESTAMP.json` both evaporate on crash — the file only gets
  written from the `plan_completed` hook, i.e. only when nothing went wrong
  enough to matter. Durability that engages only on success is a mood ring,
  not a seatbelt.
- Aaron left me a note about `PersistentAgentStore#save_index` — unlocked
  read-modify-write of `index.json` shared by any concurrent process. He's
  right. Same medicine applies: lock, or go append-only. Left as a marked
  TODO for a follow-up; it's a data-format change.

## What I'd do next

Idempotency keys: `task_id` is stable within a plan, so `replay` +
"skip completed tasks" gives you resume. The missing piece is the
orchestrator accepting a `skip_completed:` set so resume is one line
instead of a filter the caller writes. Small PR, big invoice savings.
