# Field notes — DHH

*Build: `Agentic.run("goal")` — conceptual compression in one method.*

## What I did

Added `Agentic.run(goal, model: nil, concurrency: 5)`. Plan the goal, build
the tasks, execute them, return the result. It's fourteen lines and it is the
API 80% of users actually want:

```ruby
result = Agentic.run("Summarize this week's support tickets")
```

That's the whole program. No `TaskPlanner`, no `PlanOrchestrator`, no
`DefaultAgentProvider`, no `LlmConfig` — those all still exist and you can
graduate to them when you need dependency-ordered tasks or lifecycle hooks.
But you shouldn't have to meet five classes to say one sentence.

## What I found while doing it

- The pieces composed *cleanly*. Planner → task definitions → tasks →
  orchestrator → result took no glue-hacking at all, which tells you the
  underlying design is better than its own surface suggests. The framework
  had a great one-liner in it all along; nobody had written it.
- The CLI already contained this exact code — `execute_plan_immediately` in
  `cli.rb` does plan → tasks → orchestrator — but it was buried in a Thor
  class where no library user could reach it. When your command-line tool has
  a better API than your library, your library is under-extracted.
- Fourteen lines, and five of them are the `Task.new(...)` ceremony because
  `TaskDefinition` (what the planner emits) and `Task` (what the orchestrator
  runs) are near-identical twins with no conversion method between them.
  `task_def.to_task` is begging to exist.

## What I'd do next

Delete the vaporware sections from the architecture documents and make
`Agentic.run` the first code sample in the README. The demo is the product.
The `MetaLearningSystem` is not the product. Ship the sentence.
