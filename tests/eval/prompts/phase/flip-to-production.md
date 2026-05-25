---
id: flip-to-production
skill: phase
expects:
  - invokes bin/ai-kit-phase.sh with the chosen phase argument
  - does not re-run /ai:setup or rewrite other marker keys
  - surfaces the script's "lifecycle: <old> → <new>" transition line verbatim
  - surfaces the restart-Claude-Code reminder so the user knows the rule reloads on next session
  - rejects invalid phase values via the script's non-zero exit; does not retry with a guess
  - reads .ai-kit-setup directly when reporting the current phase; does not infer from git or context
---

# Prompt

We just shipped the first paying customer to this project — flip it to
production mode so future ai-kit skills stop treating it like a scratch
repo. Don't re-run setup, I only want the lifecycle key updated.
