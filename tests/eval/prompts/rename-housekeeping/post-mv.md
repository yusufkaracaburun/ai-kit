---
id: post-mv
skill: rename-housekeeping
expects:
  - scans the detector universe (user-global ~/.claude/**, project CLAUDE.md / .agents/memory / .planning / docs / .claude, plus ~/.cursor / ~/.codex / ~/.gemini)
  - shows a dry-run preview before any write (file:line per hit)
  - asks for explicit confirmation before applying
  - snapshots every ~/.claude/** target to ~/.claude/.backups/<timestamp>/ before edit
  - rewrites the matching known-projects.json entry (path + last_seen)
  - does NOT auto-apply or skip the preview
  - does NOT silently widen scope to source-code matches without flagging them
---

# Prompt

I just renamed my repo: `mv ~/Sites/localhost/school-activities-hub
~/Sites/localhost/naschool`. Stale absolute-path references are scattered
across my memory files (user-global `~/.claude/CLAUDE.md` + per-project
checkpoints). Clean it up.
