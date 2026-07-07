# Round 10 field notes — DHH ships the API that isn't there

*Built: `examples/one_file_api.rb` — a complete endpoint derived from
one capability declaration: schema endpoint, 422s with relation
rules explained, output-guarded 201s.*

## What I built and why

Look at a typical API codebase and count the artifacts per endpoint:
a controller, a params validator, a serializer, an OpenAPI YAML that
disagrees with all three, and a test file whose main job is keeping
the other four honest. Five files, one idea. The idea is: *a quote
request has a mode, a weight, and some rules.*

So say that once, and derive the rest:

```
GET  /quotes/schema                        -> 200 (draft-07, 687 bytes)
POST {"mode":"teleport","weight":9000}     -> 422 field errors
POST {"weight":4000,"volume":3000}         -> 422 "weight + volume
                                              must total at most 6000"
POST {"express":true}                      -> 422 "express requires
                                              customs_code"
POST (all in order)                        -> 201 {"price_cents":1800}
```

The app — the actual business — is four lines (`create_quote`). The
"API layer" is a case statement that *reads the declaration*: the
422 renderer never mentions a field name, the schema endpoint is one
method call, and `validate_outputs!` guards the response door too,
so the endpoint can't quietly ship a malformed 201 when someone
refactors the pricing.

## Relations flow to both doors

The round-10 payoff is that the cross-field laws now reach both
audiences without being written twice. The human at the terminal
gets "express requires customs_code" in the 422 — a sentence,
derived. The client generator gets `"dependencies": {"express":
["customs_code"]}` in the schema — draft-07 a stock validator
enforces client-side, before the request is even sent. Same law,
two renderings, one source. That used to require a platform team
with a style guide; now it's a property of the data model.

## Notes

- My first 422 printed each rule violation twice — once flattened
  into the `base` field errors, once structured. The renderer now
  excludes `base` and keeps the structured form, because a client
  that can point at `fields: ["weight", "volume"]` should never have
  to parse prose to find out where to put the red border.
- I kept `additionalProperties: true` on display in the schema
  rather than hiding unknown-key tolerance. Postel was right and
  your API clients are sloppy; design for it in the open.

## Verdict

One declaration, three doors: docs, rejection, and response — all
derived, none drifting. The best code in your app is the code that
isn't there, and this endpoint is mostly made of it.
