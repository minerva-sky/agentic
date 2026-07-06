# Round 3 field notes — Sandi Metz traces the conversation

*Built: `examples/collaboration_tracer.rb` — lifecycle hooks record
every message and reply; the run renders as a sequence diagram.*

## What I built and why

I teach that an object-oriented design *is* its messages — the classes
are just where messages live between sendings. An agent plan is the
same thing at a larger grain: the orchestrator addresses collaborators,
work flows back, outputs travel forward. So the teaching tool builds
itself: hook the lifecycle, record `{from, to, label}` triples, draw
lifelines and arrows. A three-agent editorial pipeline traces as eight
messages, and you can *read the design* off the page: perform goes out,
a reply comes back, the reply travels forward as "here's..." to the
next collaborator.

The diagram teaches something subtle that the code doesn't say
loudly: **all messages route through the orchestrator.** Researcher
never addresses Writer — the orchestrator relays. That's a mediator
pattern, drawn plainly enough to discuss its trade-offs with a student:
mediators centralize coupling (good: collaborators don't know each
other) and centralize knowledge (risk: the mediator grows). You can
have that conversation in front of this diagram in a way you cannot in
front of `plan_orchestrator.rb`.

## What the improved framework gave the trace

- The "here's ..." arrows — outputs traveling to dependents — only
  exist because piping is now a framework event I can observe from a
  hook (`task.dependency_outputs` is populated before
  `before_task_execution` fires; the ordering choice made this tool
  possible). In round 2 that hand-off happened in *user* code, where no
  hook could see it. When a framework absorbs a responsibility, the
  responsibility becomes observable, testable, drawable. That is the
  strongest argument for absorbing it.
- Each stage's work rode along as a lambda in `payload`. The tracer
  needed zero knowledge of what any collaborator does — it draws only
  who-said-what-to-whom, which is the correct ignorance for a
  collaboration diagram.

## An honest note on my own rendering code

The diagram code is procedural string-poking — `line[pos] = "|"` — and
I left it that way on purpose. Not every fifty lines deserves objects;
extraction is a response to *pressure*, and a single-use renderer with
no variation points exerts none. Knowing when not to design is part of
design. (If a second output format ever appears, `Message` and
`Lifeline` are waiting.)

## Verdict

The framework's message-passing is now visible enough to teach from.
Round 1 I critiqued the code; round 3 the code can critique itself in
front of a classroom — that's the better position.
