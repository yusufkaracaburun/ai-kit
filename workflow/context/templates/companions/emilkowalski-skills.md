## emilkowalski-skills (animation taste + Sonner)

[emilkowalski/skills](https://github.com/emilkowalski/skills) is a set of
Claude Code skills from Emil Kowalski (Vaul/Sonner/cmdk author, ex-Vercel/Linear)
encoding concrete animation rules — exact easings, durations, spring configs —
instead of guessed values.

Two independently-gated tiers; a project can have one, both, or neither wired:

- **animation tier** — `animate` (build motion against a strict decision
  table), `review-animations` (critique a diff against the same standards),
  `improve-animations` (read-only audit-then-plan: recon → per-category audit
  → vet → self-contained plans, one per finding), `find-animation-opportunities`
  (where motion is missing, with a required rejection list), and
  `animation-vocabulary` (reverse-lookup glossary — "the bouncy thing when a
  popover opens" → the term). Offered only when the project has a frontend
  framework and real transition/animate/`@keyframes`/framer-motion code.
- **sonner tier** — `ask-sonner` (setup, API reference, troubleshooting for
  the Sonner toast library). Gated on the `sonner` dependency alone, whether
  or not the animation tier fired.
- Complements, does not overlap, `ui-ux-pro-max`/`impeccable`/`skillui`/
  `inspo-mcp` — those cover palette/tokens/anti-slop-detection/reference-sites;
  none cover animation-specific taste.
- Not installed silently: on yes, `npx skills@latest add emilkowalski/skills
  -a claude-code -y -s <skills for the tier(s) that fired>` — never the bare
  `add emilkowalski/skills` (installs all 13, including Swift/Expo/prototype
  skills this project may not need).
