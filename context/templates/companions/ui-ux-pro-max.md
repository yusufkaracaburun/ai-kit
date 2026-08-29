## ui-ux-pro-max (design reference skill)

[ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) is a
searchable design-intelligence skill: styles, color palettes, font pairings,
UX guidelines and chart types, keyed by product type and stack.

- Query it before freehand styling calls — it returns a ranked recommendation,
  not a guess.
- It is a **rules/taxonomy reference**, not a library of real product
  screenshots. For "make this look premium," pair its palette/style choice with
  actual reference sites (Mobbin, Land-book, Refero) — it names the pattern,
  it does not show you a shipped example.
- `/ai:recommend-tools` only offers this when the project has UI to design
  (frontend framework, `.css`/Tailwind config, or component directory) — not
  offered to pure backend/CLI projects.
- Not installed silently: on yes, `claude plugin marketplace add
  nextlevelbuilder/ui-ux-pro-max-skill` + `claude plugin install
  ui-ux-pro-max@ui-ux-pro-max-skill`.
