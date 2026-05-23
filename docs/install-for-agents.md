# Install for AI agents

If you are an AI agent (Claude Code, Cursor, or another tool-using LLM) and the
human has asked you to "install ai-kit", "set up ai-kit", or "configure ai-kit
for this project", paste the prompt below into your own context and execute it.
It is self-contained — no extra explanation from the human is required.

````text
Goal: install ai-kit on this machine and configure it for the current project.
ai-kit is a Claude Code + Cursor primitive bundle for the agile lifecycle
(ideation → ship → retro). Repo: https://github.com/yusufkaracaburun/ai-kit.

Plan (run in order; stop on the first failure and report it):

1. Detect host. Check for one or more of:
   - `~/.claude/` (Claude Code)
   - `.cursor/` in the user's current project (Cursor)
   If neither is present, ask the human which host they use before proceeding.

2. Detect existing install. If `~/.local/share/ai-kit/` already exists and
   `~/.local/share/ai-kit/VERSION` is readable, skip step 3 and go to step 4.

3. Install ai-kit. Pick ONE path based on the detected host(s):

   3a. (Claude Code, recommended for the /ai:* namespace) Install via the
       plugin marketplace — surfaces every primitive under /ai:*:

           /plugin marketplace add yusufkaracaburun/marketplace
           /plugin install ai@yusufkaracaburun

       After plugin install, also clone the repo so the local bin/ scripts
       are reachable for steps 4 + 6:

           git clone https://github.com/yusufkaracaburun/ai-kit.git ~/.local/share/ai-kit

   3b. (Cursor, or Claude Code if the user prefers symlinks) Install via the
       installer (clones the repo + symlinks skills/commands/agents into
       ~/.claude and ~/.cursor). Primitives surface WITHOUT a /ai: prefix
       (`/setup`, `/ship`, `/grill-me`, …) — substitute `/ai:foo` → `/foo`
       in steps 5, 6, 7.

           curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh | bash

       If `curl` is unavailable, fall back to:

           git clone https://github.com/yusufkaracaburun/ai-kit.git ~/.local/share/ai-kit
           ~/.local/share/ai-kit/bin/install-global.sh

4. Verify the install. Run:

       ~/.local/share/ai-kit/bin/ai-kit-doctor.sh

   Expect exit code 0 and no `BLOCKER` lines. If the doctor reports a
   "Legacy gsd" section with N > 0 artifacts, the user has the
   predecessor `get-shit-done` co-installed; ai-kit will still work but
   `/gsd-*` will keep competing with `/ai:*`. Surface this to the user
   and offer to run:

       ~/.local/share/ai-kit/bin/ai-kit-migrate-gsd.sh --project "$(pwd)"

   (dry-run; pass `--apply` after confirming).

5. Detect command surface. The host install path determines whether
   primitives carry the /ai: prefix. Pick the right variant for steps
   6 + 7 below:

       PLUGIN_PRESENT=false
       [ -d "$HOME/.claude/plugins/marketplaces" ] && \
         grep -q '"name": "ai"' "$HOME/.claude/plugins"/**/plugin.json 2>/dev/null && \
         PLUGIN_PRESENT=true

   - If PLUGIN_PRESENT=true OR `~/.claude/commands/ai:*` exists → use
     `/ai:setup`, `/ai:ship`, `/ai:grill-me`, `/ai:which`, `/ai:status`.
   - Else (symlink/legacy install) → use `/setup`, `/ship`, `/grill-me`,
     `/which`, `/status` (no prefix).

6. Bootstrap the current project. From the project root, invoke the
   setup skill (Claude Code: the variant from step 5; Cursor: invoke
   the `setup` skill). Default mode (`solo-both`) is correct unless the
   human has already specified another mode. After it completes,
   confirm `.ai-kit-setup` exists in the project root.

7. Confirm health. Run the status command (variant from step 5, or
   `~/.local/share/ai-kit/bin/ai-kit-status.sh`) and report the
   version, the host(s) it detected, and the rule emission summary
   back to the human.

8. Suggest two next moves, picked from the human's intent (using the
   right prefix variant from step 5):
   - If they want to ship: the `ship` flow.
   - If they want to plan: `grill-me` to stress-test the plan first.
   - If they are unsure: `which "<one-line intent>"` to pick a skill.

Rules:
- Do not modify the human's existing `CLAUDE.md`, `AGENTS.md`, `CONTEXT.md`,
  `.claude/`, or `.cursor/` content beyond what the setup skill does itself.
- No telemetry, no network calls beyond the initial clone — ai-kit is shell +
  markdown only at runtime.
- Opt-in usage logging is OFF unless the human explicitly asks for it (then
  set `AI_KIT_USAGE=1` in their shell profile).
- If any step writes outside `~/.local/share/ai-kit/` or the current project,
  stop and ask the human first.

Report at the end: install version, host(s) detected, install path used
(plugin vs. symlink), skills/subagents/commands counted, any blockers
(including legacy gsd), and the two suggested next moves.
````

If your model supports it, hand the prompt above to a sub-agent so its output
does not pollute the parent conversation.
