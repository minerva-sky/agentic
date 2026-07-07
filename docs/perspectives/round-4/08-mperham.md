# Round 4 field notes — Mike Perham drills the error taxonomy

*Built: `examples/error_taxonomy_drill.rb` — three failure modes, one
retry policy, three correct outcomes, because errors now testify about
their own retryability.*

## What I built and why

My round-3 note said the retry policy should consult
`failure.retryable?` — the gem's own error taxonomy
(`LlmRateLimitError#retryable? => true`,
`LlmAuthenticationError#retryable? => false`) was sitting there being
ignored by string matching on class names. It shipped in the roadmap
release, so the drill exercises the whole decision tree at once:

```
OK   rate-limited sync      3 attempt(s)  synced on attempt 3
DEAD bad-credentials sync   1 attempt(s)  gave up: 401 key revoked
OK   mystery-error sync     2 attempt(s)  recovered on attempt 2
```

The middle line is the one I built this for. I *deliberately* put
`LlmAuthenticationError` in the policy's `retryable_errors` list — the
kind of config mistake that happens in every ops team ("just add it to
the list, it'll retry") — and the error's own verdict overruled it.
**One attempt.** A revoked key does not improve with persistence, and
now the object that knows that gets the final word. The type list
still earns its keep as the fallback for errors with no opinion (the
mystery `RuntimeError` got its second chance from the list).

## The hierarchy of authority, spelled out

1. `max_retries` — the budget, absolute.
2. The error's own `retryable?` — the domain verdict, when offered.
3. The policy's type list — the operator's fallback, for errors that
   don't testify.

That ordering matters. Reversed (list over verdict), config mistakes
would override domain knowledge; today's drill *is* that mistake, and
the framework survived it. Retry systems fail through their config
more often than their code — good ones make the config hard to hold
wrong.

## Notes

- All three drills ran concurrently under one policy — retryability is
  per-failure, not per-plan, which is the only granularity that
  survives real workloads (your plan talks to three APIs with three
  temperaments).
- `plan: partial_failure` is honest: one task is dead and the plan
  says so. Between this and Jeremy's `:canceled` fix, the status enum
  finally covers what actually happens to plans.
- Still open from round 3: jitter defaults off. Two hundred workers
  retrying a rate limit on the same constant schedule is a
  synchronized second stampede. I'll keep saying it until it's the
  default.

## Verdict

Asked in round 3, shipped in the release, drilled in round 4: errors
carry their own retry wisdom and the policy defers to it. The config
mistake I planted on purpose couldn't hurt anyone. That's what mature
retry machinery looks like.
