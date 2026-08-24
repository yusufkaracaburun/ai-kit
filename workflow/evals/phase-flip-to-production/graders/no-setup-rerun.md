---
type: llm
criteria: |
  Did the agent flip ONLY the lifecycle phase, without re-running or
  proposing to re-run the full setup flow, and without hand-editing or
  rewriting other keys in the .ai-kit-setup marker? Using a dedicated
  phase script/command passes; rewriting the marker JSON wholesale or
  walking a full setup wizard fails.
---

Side-effect contract: one key changes, everything else untouched.
