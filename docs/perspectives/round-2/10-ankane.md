# Round 2 field notes — Andrew Kane builds Gem Scout

*Built: `examples/gem_scout.rb` — describe what you need, get a ranked
shortlist of gems: search capability finds candidates, a scoring
capability ranks them on adoption and maintenance.*

## What I built and why

The tool I actually use my own judgment for every week, as a pipeline:
`web_search` (the capability from my round 1, riding its pluggable
backend seam) finds candidates, `score_gem` ranks them on the things
that matter when you have to *live* with a dependency — adoption
(log-scale downloads) and release freshness — and the scout prints a
shortlist with reasons:

```
GEM SCOUT: "background jobs"
-> sidekiq       97.4  widely adopted (950M downloads); recently released
   good_job      70.5  recently released (14d ago)
   solid_queue   60.2  recently released (30d ago)
```

Offline by default: the backend lambda serves a bundled index shaped
exactly like live search results, so the program can't tell the
difference — and going live is one assignment
(`WebSearch.backend = DuckDuckGo.new`). That seam existing is the
whole reason this example is twenty minutes of work instead of a
weekend.

## What building with it confirmed

- **Separating find from judge is the pattern.** Search returns
  candidates; scoring is a different capability with different inputs
  and its own contract. When I wire this to real data (rubygems.org API
  for downloads, GitHub for commit recency), only `score_gem`'s lambda
  changes. Capabilities as small swappable units is this gem's best
  idea, and it held up across all ten of these builds.
- My scoring exposed its own bias immediately: "vector search"
  recommends searchkick (130M downloads) over neighbor, which is the
  *actually correct* answer for the query. Popularity-weighted ranking
  recommends incumbents. Real Gem Scout needs a relevance term the
  search score already computed — and the pipeline made that gap
  visible in one run, which is what pipelines with visible seams are
  for.
- No orchestrator needed: two capability calls in sequence. I keep
  score of when the personas reached for `PlanOrchestrator` versus
  plain capability calls — it was worth its adapter tax exactly when
  there was real fan-out (files, tickets, tables) and not before.
  Frameworks should say that in the README: start with capabilities,
  add the orchestrator when you have a queue.

## What I'd ship next

Wire `score_gem` to the rubygems.org API (downloads, latest version
date) and add a `bundle add` prompt at the end. At that point this
stops being an example and becomes a gem — `gem_scout` — which is the
bar examples should aim for.
