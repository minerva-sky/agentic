# Round 9 field notes — DHH turns the traffic dial

*Built: `examples/traffic_dial.rb` — a canary rollout as a single
resized `RateLimit`: dial up on health, dial back on a burned SLO,
hold and page a human after two burns.*

## What I built and why

Everyone's rollout story has become a platform: a feature-flag
service, a progressive-delivery controller, a Slack app that asks
permission to proceed. Meanwhile the actual idea is one sentence —
*give the new code a little traffic, and more only if it behaves.*

That sentence is a `RateLimit` with a `resize` method:

```
1        1 lane     20.1ms   healthy - dial up to 3
2        3 lanes    20.1ms   healthy - dial up to 6
3        6 lanes    80.1ms   SLO burned - dial BACK to 3
5        6 lanes    80.1ms   SLO burned - dial BACK to 3
6        3 lanes    20.2ms   holding at 3 - stage 6 burned twice;
                             page the author, not the dial
```

v2 hides the classic regression: fine at staging concurrency,
quadruple the latency above 3 in flight. The dial found it at stage
3, backed off, gave it one more honest chance, and then *stopped
experimenting*. That last part matters as much as the backoff. A
controller that keeps re-running a failed experiment isn't
persistent, it's a metronome. Two burns means the code is wrong, and
no amount of dialing fixes wrong code — that's a human's job now.

## Conceptual compression

Count the concepts: one limiter, one SLO number, one stage ladder,
one burn counter. That's the entire deployment strategy, and every
piece is visible in forty lines you own. The platform version has the
same four concepts — it just distributes them across three vendors
and a YAML dialect, and then charges you to see the burn counter.

`resize` is what made this a knob instead of an architecture. Before
this round you'd rebuild the limiter each stage and re-share it with
every client — plumbing pretending to be a feature. Now the clients
hold one object for the lifetime of the rollout and the *controller
moves the ceiling under them*, mid-flight. That's the correct
division: clients know nothing about rollouts; the rollout knows
nothing about clients.

## Notes

- The SLO is p50 against a budget, per stage. I resisted p99 —
  twelve requests per stage is a demo; pretending to a p99 with
  n=12 is how dashboards lie. Use the statistic your sample size
  can carry.
- Stage ladder `[1, 3, 6, 10]`, not linear. Rollouts should spend
  their caution early, where the blast radius is small and the
  information per request is highest.

## Verdict

Gradual rollout is a solved problem that keeps getting unsolved by
tooling. One resized limiter did the whole job: found the hidden
regression, contained it to 6 lanes for two brief windows, and ended
the day with a specific bug report instead of an outage. Ship the
fix, turn the dial again tomorrow.
