# Round 9 field notes — Mike Perham installs the breaker

*Built: `examples/circuit_breaker.rb` — a closed/open/half-open
breaker in two acts: a 503 outage handled with three strikes, and a
revoked key handled with one.*

## What I built and why

Retries handle failures one call at a time. But an outage isn't one
call's problem — it's a *condition*, and treating a condition with
per-call optimism means every request pays the full timeout to
rediscover what the last request just learned. The breaker is the
missing memory: after enough strikes, stop asking.

```
act one: 503s, ticks 4-9      act two: 401, tick 2 onward
  4  failed (retryable: true)   2  failed (retryable: false)
  5  failed (retryable: true)          - breaker TRIPS
  6  failed - breaker TRIPS     3  SKIPPED
  7  SKIPPED                    4  SKIPPED
  ...                           ...
  10 probe SUCCEEDED - closes   6  probe fails - TRIPS again
```

Act one is the textbook: three strikes, trip, eat the middle of the
outage as skips (nothing sent, nothing billed, no timeout waited
out), one probe to discover the recovery. Six ticks of outage, three
calls felt it. The gap is the money — and at LLM prices, the gap is
real money.

## The verdict feeds the trip decision

Act two is why this example belongs in round 9. Strike counts exist
because a 503 *might* pass — you give it three chances to be
transient. But the 401's journaled verdict says `retryable: false`:
the error itself testified that no retry can ever help. Giving that
error three strikes isn't caution, it's ritual. The breaker trips on
first contact, and each half-open probe re-trips on the same wall
until a human rotates the key.

The breaker reads the verdict from the journal — recorded at write
time, this round's release — rather than re-deriving it from a
class-name table. Same argument as the dead letter office: the
moment of failure is when retryability is known most precisely;
everything derived later is reconstruction.

## Notes

- My first draft read `events.last[:retryable]` and got nil — the
  last event after a failed run is `plan_completed`, which has no
  verdict. The nil then hit the `retryable ? 1 : TRIP_AFTER` branch
  and instantly tripped on a *transient* 503. Two lessons in one bug:
  scan for the event you mean, and never let "no opinion" silently
  mean "hopeless." A production breaker should treat a nil verdict
  as retryable-with-suspicion, not as a death sentence.
- Half-open admits exactly one probe. Letting the whole queue through
  on recovery is how you re-kill the thing that just got back up.

## Verdict

Retry policies answer "should THIS call try again?"; breakers answer
"should ANYONE?" With retryability journaled at the moment of
failure, both answers now come from the error's own testimony —
counted strikes for the maybes, an instant trip for the nevers.
