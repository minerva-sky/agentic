# Round 9 field notes — Matz reads the weather

*Built: `examples/failure_weather.rb` — three journaled days of
failures, read back as a forecast that knows weather from climate.*

## What I built and why

Japanese has a word, 天気雨 — rain falling from a sunny sky. Systems
have it too: the retry that would have succeeded if you'd only waited,
falling right next to the 401 that will never succeed no matter how
long you wait. Operators get soaked by both and can't always tell
which one is on their shoulders.

The new journal field settles it. Every `task_failed` line now carries
`retryable:`, recorded at the moment the drop fell, from the error's
own testimony. So the report can say something a list of stack traces
never could:

```
Monday     storm damage (1 structural)  digest, backup, invoice
Tuesday    storm damage (1 structural)  backup, invoice
Wednesday  drought continues            invoice

digest:  rained earlier this week, clear now - weather does that
invoice: this is not weather, it is climate - 401 key expired
```

**Weather passes; climate persists.** A retryable failure is weather —
bring an umbrella (a retry policy) and go about your day. A
non-retryable failure is climate — no forecast fixes a drought;
someone must dig a well (rotate the key). The six rainy events split
exactly: three weather, three reports of the same drought.

## What pleased me

The metaphor required no force. I did not bend the framework to fit
the weather report; the framework's own distinction — `retryable?`,
asked of every error, journaled when fresh — *is* the
weather/climate distinction. When a metaphor maps without residue,
that usually means the underlying concept was carved at a real joint.

And the kindness of it: "digest: rained earlier this week, clear now"
is a sentence that lowers a reader's heart rate. The same information
as `LlmRateLimitError (resolved)`, but it treats the operator as a
person who was worried, not a parser of taxonomies. Error messages
are the user interface of failure; they should be written by hosts,
not by stack traces.

## Notes

- I triaged Wednesday's sky by mixing counts: `climate > 0 && weather > 0`
  is storm damage, climate alone is drought, weather alone is showers.
  Four skies covered every day I could script. Small vocabularies
  that cover the space completely are a joy.
- The one wrinkle: a `nil` verdict (an error with no opinion) is
  neither weather nor climate. My report would silently drop it —
  fine for a demo, rude in production. Fog, perhaps. A forecast
  should admit when it does not know.

## Verdict

The journal learned to say *why it rained*, so the report can say
*whether to wait or to dig*. That is the whole art of operating
systems under failure, expressed as a weather segment. I smiled
writing it, which remains my favorite metric.
