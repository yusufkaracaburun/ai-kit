---
paths: ["**/.gitignore"]
---
<!-- ai-kit global rule (ADR-0015): Don't blanket-gitignore paths under public/ (or equivalent web-root); many assets are source-controlled and required at build time -->
<!-- Source: standards/rules/feedback/gitignore-public-assets-trap.mini.md — re-stamp with bin/sync-plugin-rules.sh -->


# Gitignore public-assets trap

When tidying a project's `.gitignore`, the directory most often
mis-handled is the web root (`public/`, `static/`, `assets/`, `wwwroot/`,
`docroot/`). It contains a mix of:

- **Source-controlled assets** — icons, favicons, manifests, base CSS,
  marketing images. These must ship with the repo or the build fails in
  CI.
- **Generated artefacts** — bundler output, hashed JS/CSS, build
  manifests. These should not ship and belong in `.gitignore`.

A blanket `public/` ignore drops both and breaks the next clean clone.

## Why

The mistake usually arrives via an LLM-generated `.gitignore` template
or via copy-pasting a stack-overflow snippet "to clean up the repo".
Symptom: the project deploys, CI passes locally because the assets
exist on the developer machine, then production 404s on the favicon and
half the icons because the assets never landed in git.

A 30-second `git ls-files public/ | head` audit before any ignore-rule
change surfaces what is actually source-controlled and prevents the
trap entirely.

## How to apply

1. **Before adding a `public/`-shaped ignore rule, list what's there:**
   ```bash
   git ls-files public/ | head -50
   ```
   The output is the set of files that must stay tracked.
2. **Ignore only the generated subpath**, not the parent:
   ```gitignore
   public/build/        # bundler output
   public/hot           # vite dev-server marker
   public/storage       # Laravel symlinked storage
   # public/            <-- never the parent alone
   ```
3. **If unsure which files are generated**, run a clean build in a fresh
   clone and `git status` — the new untracked files under `public/` are
   the candidates for ignoring.
4. **Cross-stack hits**: same pattern applies to `static/`, `assets/`,
   `wwwroot/`, `dist/` (when partially source-controlled), and Next.js
   `public/`.

## When to skip

- The project deliberately treats `public/` as fully generated (rare —
  e.g. a static-site generator that builds into a separate output dir
  but mounts it under `public/`). Verify before relying on this.

## See also

- [`secrets-hygiene`](./secrets-hygiene.md) — related
  ignore-rule discipline for credentials.
- [`git-hygiene`](./git-hygiene.md) — wider git workflow
  conventions.
