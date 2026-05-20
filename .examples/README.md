# Examples

Three walkthroughs of running `/setup` on real-world repo shapes. Each example documents the **detection snapshot**, the **commands ai-kit ran**, and the **before/after tree**. No live code — the examples are reproducible on paper so they don't rot when upstream tooling changes.

| Example | Repo shape | Setup mode | Tier |
| ------- | ---------- | ---------- | ---- |
| [greenfield-nextjs](greenfield-nextjs/) | Fresh Next.js 14 app, no AI tooling yet | `solo-both` | A |
| [brownfield-laravel](brownfield-laravel/) | Laravel + Inertia with existing `.cursor/rules` and MCP config | `brownfield` | A then B |
| [monorepo-nx](monorepo-nx/) | Nx workspace with libs/ and apps/, Playwright tests | `brownfield` | A |

## Reading order

Read **greenfield-nextjs** first — it shows the happy path. Then **brownfield-laravel** to see how ai-kit coexists with existing agent config. **monorepo-nx** is the most complex case (multi-package detection, custom rules, MCP).

## Upstream provenance (historical)

This directory used to stage upstream clones during initial curation. Those have been removed; see the [root README](../README.md) Provenance section for credits.
