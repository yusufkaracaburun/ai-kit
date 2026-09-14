## scrapling (anti-bot / multi-page fetch)

[Scrapling](https://github.com/d4vinci/Scrapling) is an adaptive web-scraping
framework with an official MCP server built by the library author — reach
for it when `WebFetch`/browser tools fail on a page.

- Escalation ladder: `get`/`bulk_get` (plain HTTP) → `fetch`/`bulk_fetch`
  (JS-rendered/SPA) → `stealthy_fetch`/`bulk_stealthy_fetch` (anti-bot,
  `solve_cloudflare=true` for Turnstile). Start cheapest, escalate only when
  blocked.
- `open_session` + `fetch`/`stealthy_fetch` with a `session_id` keeps one
  browser alive across multiple pages of the same site — this is the fix for
  "didn't fetch all pages": use it for paginated docs instead of one-shot
  fetches.
- `main_content_only=true` (default) strips hidden/zero-width/comment content
  before it reaches the model — prompt-injection sanitization, not just a
  content filter. Keep it on.
- Complements `skillui`: scrapling fetches the page, skillui extracts design
  tokens from what got fetched. Use both when a reference site is both
  hard to reach and worth reverse-engineering for design.
- Not installed silently: on yes, `pip install "scrapling[ai]" && scrapling
  install --force`, then `claude mcp add scrapling -- scrapling mcp`.
