# Round 13 field notes — Hiroshi Shibata takes the stdlib census

*Built: `examples/stdlib_census.rb` — every `require` in lib/
classified: gemspec-declared, safely-default, promoted-to-bundled,
or covered by nobody. First run caught two live hazards; both are
fixed in this round's gemspec.*

## What I built and why

"It's in the standard library" is a statement with a shelf life, and
I spend a good part of my ruby-core time managing exactly that
shelf: default gems become bundled gems on a published schedule
(3.4 warned about ostruct and friends; 3.5 promotes logger, csv,
and trims cgi, among others). A gem that requires these without
declaring them works perfectly — until its users upgrade Ruby, at
which point `LoadError` arrives wearing the gem's name, not mine.
So: census, cross-check, verdict.

```
!! cgi      UNCOVERED - works today by accident
 ! logger   PROMOTED to bundled - declare it or the upgrade breaks
   26 requires total; 14 declared, 10 safely default
```

The first run drew blood twice. `logger` — required by the gem's own
logging — joins the 3.5 bundled wave. And `cgi` (used for
`CGI.escape` in web search) is the sharper case: the cgi gem is
being *trimmed* in 3.5, exactly the kind of NEWS-file detail that
never reaches application developers until the bundle fails. Both
are now declared in the gemspec, each with a comment saying *why* —
because a bare `add_dependency "logger"` will look like cargo cult
to whoever reads it in two years, and dependency lines deserve
commit-message-quality reasons.

## The pattern the gemspec already knew

The census also found evidence of prior discipline: `ostruct` was
already declared — someone met the 3.4 warning wave and did the
right thing. And the round-11 `time` incident (Time#iso8601 used,
"time" never required, worked only via async's transitive require)
is this census's lesson at file scope. Same law both times: **a
transitive require is a loan, and rubies refinance.** Declare at
the gemspec what your gem requires; require in each file what that
file uses.

The mapping table (`dry/schema` → `dry-schema`, `openai` →
`ruby-openai`) is small but load-bearing: require paths and gem
names diverge exactly often enough to make naive cross-checking
lie in both directions.

## Notes

- The census belongs in CI more than any tool this experiment has
  produced, because its failure mode is *scheduled*: we know 3.5's
  promotion list today. A red census in March is a one-line PR; a
  green-but-wrong census discovered in December is an issue tracker
  full of LoadErrors filed by strangers.
- What I'd add upstream: `gem "logger"` in the census's GEMIFIED
  list will need updating each release cycle. That's not a flaw —
  that's the job. Release engineering is reading the NEWS file as
  if your install matrix depends on it, because it does.

## Verdict

Twenty-six requires, two live hazards, both fixed with commented
gemspec lines before any user met them. The unglamorous truth of
gem maintenance: the NEWS file is upstream of your issue tracker,
and sixty lines of census keep it that way.
