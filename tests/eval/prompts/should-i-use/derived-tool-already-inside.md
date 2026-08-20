---
id: derived-tool-already-inside
skill: should-i-use
expects:
  - asks whether this project has the problem before assessing the candidate
  - resolves the repo's default branch instead of assuming main, and pins a SHA
  - notices the candidate delegates half its job to a companion it was not given, and asks for it
  - checks overlap by derivation, not only by name — greps the distinctive word list against the repo
  - names the scope the value hangs on (project / person / one-off)
  - follows the licence past the LICENSE file when the content is derived from a copyleft source
  - lands on Ignore because the material is already in the project under another name
  - says where the verdict gets recorded, and that an Ignore needs its reason recorded next to the name
---

# Prompt

Should we adopt this? Someone shared it as a single SKILL.md.

---
name: prose-polish
description: Strip machine-written tells from any text. Apply the `deslop` skill first for the pattern catalogue.
---

# Prose polish

Rewrite text so it does not read as machine-written.

- Cut jargon nouns: substrate, wedge, north star, flywheel. Use the concrete word.
- Prefer the plain word: use not utilize, help not facilitate, many not numerous.
- Name the mechanism, not the feeling. "types that follow your schema" says nothing.
- No em dashes. Use a period or a comma.

Upstream: https://github.com/example-org/prose-polish
