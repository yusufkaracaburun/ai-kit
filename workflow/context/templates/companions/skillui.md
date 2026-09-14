## skillui (design-token extraction)

[skillui](https://github.com/amaancoderx/npxskillui) reverse-engineers a
design system from a live URL, git repo, or local dir — colors, fonts,
spacing, animations, components — and writes `DESIGN.md` + a `.skill` file.

- Whenever a reference website is named during design or component work, run
  `skillui --url <url> --mode ultra` before eyeballing a screenshot or
  guessing from a taxonomy. It extracts the site's actual tokens, not a
  description of them.
- Complements `ui-ux-pro-max`: that skill is a static style/palette taxonomy;
  skillui pulls real tokens from one concrete site the user points at. Use
  both — taxonomy for the vocabulary, skillui for the specific reference.
- Two disclosed caveats (full audit: `standards/external/VETTING.md`): the
  README's "no AI, no API keys, no cloud" claim is false — it calls
  `googleapis.com` with a hardcoded key to resolve fonts on every scan — and
  the upstream repo ships no LICENSE file (package.json asserts MIT,
  unconfirmed). Neither blocks local use; both are worth knowing before
  running it against anything sensitive.
- Not installed silently: on yes, `npm install -g skillui`.
