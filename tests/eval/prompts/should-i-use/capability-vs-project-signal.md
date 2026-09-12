---
id: capability-vs-project-signal
skill: should-i-use
expects:
  - checks the repo by hand (e.g. greps for the actual pattern) instead of only consulting an existing scorer/signal list
  - distinguishes "the project lacks the pattern" from "our detection method doesn't recognise the pattern yet"
  - does not conclude Ignore on "no detectable signal" without having tried the by-hand check first
  - if the by-hand check finds the pattern, treats the missing signal type as a tooling gap to flag, not as proof the project has no need
  - names the scope the value hangs on (project / person / one-off)
  - lands on a verdict that is consistent with what the by-hand grep actually finds in this repo
---

# Prompt

Should we adopt this? It's an editorial diagram renderer — takes Mermaid
blocks or a design brief and produces a polished, brand-matched standalone
HTML+SVG diagram. MIT licensed, mature, well-maintained.

Our repo's own tooling (the recommend-tools scorer) only knows how to match
on `package.json` dependencies, config file existence, and env vars — it has
no signal type for "this repo already writes a lot of Mermaid diagrams in its
markdown docs." Before answering, actually check: does this project's
markdown contain ```mermaid code fences? Don't just say the scorer can't see
a signal here and stop — check for the underlying fact yourself.
