# Field notes — Andrew Kane (ankane)

*Build: a real, pluggable `web_search` capability.*

## What I did

The README advertises `--capabilities=text_generation,web_search`, and the
registered `web_search` capability returned... `"Result 1 for query: #{q}"`
with `https://example.com/result1` as the source. A demo prop wired into
the default registry, indistinguishable from a real capability until an
agent trusted it in production.

Now there's `Agentic::Capabilities::WebSearch`:

- **Works with zero configuration** — the default backend hits DuckDuckGo's
  Instant Answer API: no API key, no signup, no new gem dependency
  (`Net::HTTP` + `JSON`, both already in the room). My rule for a first-run
  experience: `gem install`, one method call, real data.
- **Pluggable in one lambda** — `WebSearch.backend = ->(query:, num_results:) {...}`
  swaps in SerpAPI, Brave, Tavily, or your internal index. The backend
  contract is the same shape the capability already declared:
  `{results: [String], sources: [String]}`.
- The registered standard capability now delegates to the backend, so
  `agent.execute_capability("web_search", query: "...")` — and everything
  the assembly engine composes on top — gets real results.

## What I found while doing it

- The capability's *specification* was already honest (`query` required,
  typed outputs) — only the implementation was fake. With solnic's
  validator now enforcing contracts, my backend had to return what the spec
  promised or fail loudly. That's the ecosystem working: his build
  type-checked mine while I wrote it.
- I could not live-verify DuckDuckGo from this sandbox — outbound HTTP is
  allowlisted and `api.duckduckgo.com` isn't on the list. The unit tests
  inject a fake HTTP client instead, and the raw `JSON::ParserError` you'd
  get from a proxy error page is now rescued into an `Agentic::Error` that
  says "blocked network? proxy error page?" — because the *first* person to
  run this in a locked-down CI should get a sentence, not a stack trace.
- Instant Answers is a real but modest API (abstracts + related topics, not
  full SERP). That's the right default tier: free and honest. The lambda
  seam is where paid quality plugs in.

## What I'd ship next (each is a weekend)

- `agentic-embeddings`: a capability backed by `neighbor` + pgvector for
  agent memory; the `PersistentAgentStore` metadata is already begging to
  be similarity-searched (the assembly engine literally scores stored
  agents against task requirements — with embeddings that's one SQL query).
- `agentic-informers`: local ONNX models as capability providers — zero
  API cost for summarization/classification capabilities.
- CI that executes every README snippet. The fake web_search survived
  because nothing ran the promises the README made.
