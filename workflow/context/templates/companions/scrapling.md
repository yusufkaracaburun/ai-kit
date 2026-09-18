## scrapling (anti-bot / multi-page fetch)

[Scrapling](https://github.com/d4vinci/Scrapling) is an adaptive web-scraping
framework with an official MCP server built by the library author — reach
for it when `WebFetch`/browser tools fail on a page.

- Escalation ladder: `make_request`/`bulk_get` (plain HTTP) →
  `fetch`/`bulk_fetch` (JS-rendered/SPA) → `stealthy_fetch`/
  `bulk_stealthy_fetch` (anti-bot, `solve_cloudflare=true` for Turnstile).
  Start cheapest, escalate only when blocked.
- Multi-page on one site: `open_session` → `session_fetch` per page →
  `close_session` keeps one browser alive — this is the fix for "didn't
  fetch all pages" on paginated docs. No JS needed? `open_request_session`
  → `session_make_request` is the same shape without a browser.
- `main_content_only=true` (default) strips hidden/zero-width/comment content
  before it reaches the model — prompt-injection sanitization, not just a
  content filter. Keep it on.
- Complements `skillui`: scrapling fetches the page, skillui extracts design
  tokens from what got fetched. Use both when a reference site is both
  hard to reach and worth reverse-engineering for design.
- Building a Markdown corpus (llm-wiki raw material, RAG): the library's
  `SiteToMarkdownSpider` (≥ 0.4.15) crawls a site into one `.md` per page
  with no LLM in the loop — use it instead of hand-rolling a crawler.
- Writing Scrapling code yourself? Install the official agent skill in
  *that* repo (`agent-skill/Scrapling-Skill` → `.claude/skills/`), not
  globally — 23 KB that only pays off where the library is actually used.
- Not installed silently: on yes, `pip install "scrapling[ai]" && scrapling
  install --force`, then `claude mcp add scrapling -- scrapling mcp`
  (stdio; `--http` needs `--auth-token` since 0.4.15).
