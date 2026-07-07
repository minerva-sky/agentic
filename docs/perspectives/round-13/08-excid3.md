# Round 13 field notes — Chris Oliver ships the familiar costume

*Built: `examples/job_adapter.rb` — an ActiveJob-shaped adapter:
`retry_on` maps to the retry policy, `discard_on` maps to the
hopeless convention, and the team's existing vocabulary just works.*

## What I built and why

After a decade of GoRails episodes, I can tell you the moment a
tutorial loses people: it's not the hard concept — it's the *third
new word*. A team adopting an agent framework already knows how they
talk about background work: `perform_later`, `retry_on`,
`discard_on`. The fastest adoption path isn't teaching them Agentic's
vocabulary; it's letting Agentic speak theirs:

```ruby
class DigestJob < PlanJob
  retry_on Agentic::Errors::LlmRateLimitError, attempts: 3
  discard_on Agentic::Errors::LlmAuthenticationError
  def build_plan(orchestrator, user:) ... end
end
```

```
DigestJob(user: rosa)             -> {status: :ok}
DigestJob(user: sam, flaky: 2)    -> {status: :ok}         (healed in-plan)
DigestJob(user: kim, revoked: true) -> {status: :discarded}
```

## The mapping is the example

Forty lines, because both vocabularies were already talking about
the same three ideas: try again, give up, or ask a human.

- **`retry_on` → `retry_policy`**, with ActiveJob's accounting
  preserved (`attempts: 3` means two retries — get this off-by-one
  wrong and every runbook on the team silently lies). The payoff is
  *where* the healing happens: sam's double-429 recovered inside the
  plan, without bouncing off the queue and re-running the tasks that
  already succeeded. Queue-level retry re-does work; plan-level
  retry resumes it.
- **`discard_on` → failure type OR `hopeless?`**. The macro lists
  what the team knows about; the round-10 nil convention backstops
  what they forgot. Kim's revoked key discards even if nobody had
  listed AuthenticationError, because the error's own testimony
  outranks the allowlist. Belt from the team, suspenders from the
  framework.
- **`perform_later` → an array**, because the example's queue isn't
  the point — in your app it's Sidekiq or SolidQueue, and this class
  slots in as an actual ActiveJob with `execute` called from
  `perform`.

## Notes

- The adapter deliberately returns outcome hashes instead of raising
  through the queue — real job backends interpret raises their own
  way, and an adapter's job is to hand each backend the verdict in
  the form it expects.
- What I'd teach in the follow-up episode: the journal as the job's
  idempotency layer (descriptions are resume keys — reruns skip paid
  work), which is the part ActiveJob never gave anyone.

## Verdict

Meet your team where they are; the framework doesn't mind the
costume. Three macros, forty lines, zero new vocabulary on day one —
and the good stuff (in-plan healing, testimony-backed discards, the
journal) arrives underneath the words they already knew.
