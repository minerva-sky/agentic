# Round 5 field notes — Mike Perham simulates the stampede

*Built: `examples/stampede_sim.rb` — twenty workers fail together and
retry; the histogram compares the herd with jitter off versus the
now-default jitter on.*

## What I built and why

I've been muttering "jitter by default" since round 3; it shipped this
round, and defaults this important deserve a demonstration you can
show a skeptical platform team. Twenty workers all fail at t=0 (an
upstream hiccup — the most common failure shape there is, because
outages are *correlated*), all back off 120ms, all return:

```
jitter OFF:   220-240ms  #################### 20
jitter ON:     80-100ms  #                     1
              100-120ms  ###########          11
              120-140ms  ####                  4
              140-160ms  ####                  4
peak herd: 20 -> 11
```

Without jitter, the recovery *is* the second outage: twenty requests
in one 20ms bucket, aimed at an upstream that just told you it was
struggling. With ±25% jitter the same herd spreads across 80ms and the
peak nearly halves. At twenty workers this is a chart; at two thousand
it's the difference between recovery and a cascading failure with your
company's name on the postmortem.

## Honest notes on the experiment

- Both runs are seeded (`srand`) so the comparison is fair and the
  histogram is reproducible — a stampede simulator with
  unreproducible stampedes is weather, not science.
- Peak 11 of 20 still isn't great — uniform ±25% jitter caps how much
  spread you can buy. The literature's answer is *full jitter*
  (`rand(0..delay)`) or decorrelated jitter, which flatten the herd
  much harder. The framework's knob is a boolean today; a
  `backoff_jitter: :full` tier is the natural next notch. Filed.
- The example silences the logger to `:fatal` because forty scripted
  failures are the point, not news — and being *able* to do that in
  one line is Jeremy's round-1 logger work paying rent again.

## Verdict

The default changed, and now there's a picture explaining why nobody
should change it back. Reliability defaults should assume the crowd;
this one finally does.
