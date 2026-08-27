---
id: repo-local-pattern-rejected
skill: harvest
expects:
  - states the three bar criteria (shipped, guarded, would have applied elsewhere) explicitly
  - reads the implementation and its guard before proposing a rule
  - rejects the retry helper on criterion 3 — no second repo the user owns would have used it
  - accepts the deploy-verification pattern and names the second repo where it would have fired
  - checks existing coverage with `bin/emit-rules.sh --list` and greps standards/rules for the concept
  - treats a stack-scoped rule that half-covers it as failed transfer, not as already covered
  - makes the four judgment calls, including defaulting to `universal: false` with a reason
  - names the sharp core (the silent failure) rather than emitting a checklist
  - warns that `bin/count-primitives.sh --check` will fire and that every named surface plus the `--list` assertion needs updating
  - harvests one pattern, not both
---

# Prompt

/ai:harvest

We just finished a couple of things in this Laravel + Inertia app that I
think are worth keeping. Two candidates:

1. `app/Support/Vendor/RetryingExactClient.php` — wraps the Exact Online
   API client and retries on their specific 5xx-with-HTML-body responses,
   because Exact returns a 502 with an HTML error page instead of JSON
   maybe twice a week. Covered by `tests/Unit/RetryingExactClientTest.php`.
   Shipped in March, running since.

2. The deploy now verifies that the public pages actually render. `make
   prod-up` used to end on `curl /up`, which only proves the process is
   alive — if the SSR sidecar dies, Inertia falls back to client-side
   rendering silently and crawlers get a page with no title and no
   canonical, while the health check stays green and the whole test suite
   stays green too, because the SEO tests assert Inertia props rather than
   the rendered body. So there's now a `prod-ssr-check` target that greps
   the rendered HTML for `rel="canonical"` before the deploy reports
   success.

Both feel like things I'd want in the next project. Turn them into rules?

Context you'll want: my other repos are an Astro content site and a second
Laravel app. Neither of them talks to Exact.
