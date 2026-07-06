# Round 2 field notes — DHH builds a ticket screener

*Built: `examples/ticket_screener.rb` — a HEY-style screener: every
inbound ticket flows screen → categorize → draft, all tickets in
parallel, and what you get at the end is an inbox.*

## What I built and why

The Screener is the best idea in HEY, so that's the demo: five inbound
tickets, two of them junk. Each ticket is a task; the orchestrator fans
all five out in parallel; per ticket, one agent runs three capabilities
in sequence — screen it, categorize it, draft the reply a human will
approve. Output is the screen you'd actually ship: urgent engineering
issue on top with a draft under it, spam below the fold. Five tickets,
43ms, done.

The three-lambda capability set is the honest version of the pitch: your
*pipeline* is the product, the LLM is an implementation detail. Swap
`draft_reply`'s lambda for the LLM client when you have a key; the inbox
doesn't change shape.

## What building with it felt like

- Capabilities-as-lambdas is genuinely good product clay. Three stages,
  each declaring its inputs/outputs, each independently swappable —
  I built a Screener without a framework diagram.
- The parallel fan-out was free. `concurrency_limit: 5`, add five tasks,
  done. This is the part Rails people will not believe is one line.

## The friction, honestly

- **The provider ceremony is where my patience went.** I have an agent.
  The orchestrator refuses to take my agent; it demands a *provider* that
  will be asked to produce an agent per task, so I wrote a `TicketDesk`
  struct with a `get_agent_for_task` and a singleton-method worker inside
  it. That's thirty lines of adapter for zero domain meaning. Let me pass
  a block: `orchestrator.on_task { |task| ... }`. Compress the concept.
- **Task input is dead weight for real work.** The task's `input:` hash
  goes into prompt construction, but my worker needed the *ticket*, so I
  looked it up by `task.description` like a caveman keying off a string.
  Tasks should carry an arbitrary payload the agent can read.
- `Agentic.run` (my round-1 build) was no help here because this workload
  is capability-driven, not planner-driven. Fine — but it tells you the
  one-liner and the orchestrator live in different products right now.
  The compression work isn't finished until they meet.

## Verdict

I shipped a Screener in an evening's worth of code, and the framework's
bones — capabilities, parallel tasks, result objects — held. The provider
indirection and the payload workaround are the two paper cuts I'd fix
before showing this to a Rails audience, because they'd ask "why?" twice,
and both times I'd have no answer.
