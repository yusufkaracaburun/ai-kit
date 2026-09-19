<!-- ai-kit global rule (ADR-0015): Use the ctx7 CLI for live library/framework/SDK documentation lookups instead of relying on training data -->
<!-- Source: standards/rules/context7.mini.md — re-stamp with bin/sync-plugin-rules.sh -->

# context7

For any question about a library, framework, SDK, API, CLI tool or cloud service — even React, Next.js, Prisma, Tailwind, Django — fetch current docs with the `ctx7` CLI before answering (API syntax, configuration, version migration, setup, library-specific debugging, CLI usage); training data lags. Prefer it over web search for library docs. Not for refactoring, scripts from scratch, business-logic debugging, code review or general concepts.

1. `npx ctx7@latest library <name> "<user's full question>"` — official name with punctuation ("Next.js", "Customer.io"); pick by exact name, description, snippet count, source reputation (High/Medium preferred), benchmark score (higher is better); retry with an alternate name or rephrased question if nothing fits.
2. `npx ctx7@latest docs <libraryId> "<user's full question>"` — ID is `/org/project`, `/org/project/version` for version-specific docs.
3. Answer from the fetched docs.

Always `library` first unless the user gave an `/org/project` ID. Max 3 commands per question, no secrets in queries. On a quota error say so and suggest `npx ctx7@latest login` or `CONTEXT7_API_KEY` — never fall back silently to training data.
