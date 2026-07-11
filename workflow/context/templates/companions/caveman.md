## caveman (token-compressed mode)

[caveman](https://github.com/JuliusBrussee/caveman) compresses agent responses —
drops articles, filler, and hedging — for roughly 65% fewer output tokens, with
technical content and code intact.

- `/ai:setup` **asks** before installing it (Branch 2e, default yes). It is never
  enabled behind your back, and never installed silently.
- Activation is **machine-wide**: it changes the agent's output style in every
  project on this machine, not only this one.
- Switch level with `/caveman lite|full|ultra`. Turn it off for the session with
  `stop caveman` or `normal mode`; remove it entirely with
  `bin/apply-caveman.sh --uninstall`.
- Commit messages, PR descriptions, and security notes stay in normal prose
  regardless of mode.
- It also ships the `cavecrew-*` sub-agents (investigator / builder / reviewer).
  `cavecrew-investigator` is the one that matters for context budget: it returns a
  compressed `file:line` table instead of prose, so a wide search costs the main
  conversation far less.
