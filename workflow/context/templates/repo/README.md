# Repo templates

Drop-in baseline files for any new (or hygiene-deficient) repo. ai-kit's
`/ai:setup` skill can offer these as an optional step, or the user can copy
manually:

```bash
cp "$AI_KIT_ROOT/context/templates/repo/.editorconfig" .
cp "$AI_KIT_ROOT/context/templates/repo/.gitattributes" .
cp "$AI_KIT_ROOT/context/templates/repo/CODEOWNERS" .github/CODEOWNERS
cp "$AI_KIT_ROOT/context/templates/repo/renovate.json" .
cp "$AI_KIT_ROOT/context/templates/repo/.envrc" .
```

## Files

| File | What it sets | Customisation |
| --- | --- | --- |
| `.editorconfig` | Charset (utf-8), line ending (lf), 2-space default with per-language overrides (Python 4, Go tabs, Makefiles tabs, Markdown preserves trailing whitespace). | None for most projects. |
| `.gitattributes` | LF normalisation, binary markers for common formats, `-diff` on lockfiles. | None for most projects. |
| `CODEOWNERS` | Empty template with examples for default, backend/frontend, infra, docs, security-critical paths. | Mandatory — uncomment and replace `@your-org/...` with real teams or users before committing. |
| `renovate.json` | Renovate Bot defaults: weekly schedule, dependency dashboard, semantic commits, lock-file maintenance, automerge for non-major dev-deps, major bumps tagged for human review, GH Actions pinned to SHA. | Adjust schedule + automerge rules per team. |
| `.envrc` | direnv stub: load `.env.local` if present, with commented hooks for Node/Python/PHP version pinning. | Uncomment the lines that apply to your stack. |

## Why these

- **`.editorconfig` + `.gitattributes`** — kill "your editor stripped trailing
  whitespace and now the diff is 400 lines" before it happens once.
- **`CODEOWNERS`** — automatic PR reviewer assignment + blast-radius docs in
  one file. Free if you remember to fill it in.
- **`renovate.json`** — opinionated defaults: weekly cadence (not daily noise),
  dev-dep auto-merge (CI is the gate), majors tagged for review, GH Actions
  pinned to SHA for supply-chain hygiene. Edit per team.
- **`.envrc`** — direnv pattern: project-local env without polluting global
  shell. Pairs with `.env.local` in `.gitignore`.

## Anti-pattern

Don't drop these blindly on a repo that already has them. `/ai:setup`'s
template-offer step checks for existence first; manual copies should too.
