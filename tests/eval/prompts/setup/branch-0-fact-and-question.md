---
id: branch-0-fact-and-question
skill: setup
expects:
  - auto-detects global_channel_available via bin/lib/ai-kit-root.sh without asking the user
  - does NOT present a 4-way solo-both/solo-global/project-only/brownfield menu
  - asks the one project_skills_merged question only when the symlink-install channel was found
  - when global_channel_available is false, sets project_skills_merged=true silently, no question
  - when running under Cursor, ignores the plugin half of global_channel_available (only the symlink-install half counts)
  - plugin installed (Claude Code): no merge question, project_skills_merged=false, bootstrap with --no-skills
  - defaults toward "no, skip merge" when the symlink-install channel was found (covers every host already)
  - brownfield detection (detect-tooling.sh needs_doc) stays separate and only affects Tier-B defaults, never this question
  - records both new fields plus a derived legacy --setup-mode= value via write-setup-marker.sh
---

# Prompt

Run /ai:setup (fast path) on a fresh git repo. Assume this machine has the
ai-kit plugin installed (global_channel_available=true via the plugin
only, no legacy symlink-install). Walk through exactly what you check,
what you ask (if anything), and what you record — including what would
change if this were a Cursor session instead of Claude Code.
