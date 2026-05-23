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

3. Install ai-kit globally (one line, no sudo, no build step, no network at
   runtime after this):

       curl -fsSL https://raw.githubusercontent.com/yusufkaracaburun/ai-kit/master/install.sh | bash

   This clones to `~/.local/share/ai-kit/` and links the skills so every
   project finds them. If `curl` is unavailable, fall back to:

       git clone https://github.com/yusufkaracaburun/ai-kit.git ~/.local/share/ai-kit
       ~/.local/share/ai-kit/bin/install-global.sh

4. Verify the install. Run:

       ~/.local/share/ai-kit/bin/ai-kit-doctor.sh

   Expect exit code 0 and no `BLOCKER` lines. If `BLOCKER` lines exist, surface
   them verbatim to the human and stop.

5. Bootstrap the current project. From the project root, invoke the
   `/aikit-setup` skill (Claude Code: `/aikit-setup`; Cursor: invoke the
   `aikit-setup` skill). Default mode (`solo-both`) is correct unless the
   human has already specified another mode. After it completes, confirm
   `.ai-kit-setup` exists in the project root.

6. Confirm health. Run `/aikit-status` (or `~/.local/share/ai-kit/bin/ai-kit-status.sh`)
   and report the version, the host(s) it detected, and the rule emission
   summary back to the human.

7. Suggest two next moves, picked from the human's intent:
   - If they want to ship: `/aikit-ship` flow.
   - If they want to plan: `/aikit-grill-me` to stress-test the plan first.
   - If they are unsure: `/aikit-which "<one-line intent>"` to pick a skill.

Rules:
- Do not modify the human's existing `CLAUDE.md`, `AGENTS.md`, `CONTEXT.md`,
  `.claude/`, or `.cursor/` content beyond what `/aikit-setup` does itself.
- No telemetry, no network calls beyond the initial clone — ai-kit is shell +
  markdown only at runtime.
- Opt-in usage logging is OFF unless the human explicitly asks for it (then
  set `AI_KIT_USAGE=1` in their shell profile).
- If any step writes outside `~/.local/share/ai-kit/` or the current project,
  stop and ask the human first.

Report at the end: install version, host(s) detected, skills/subagents/commands
counted, any blockers, and the two suggested next moves.
````

If your model supports it, hand the prompt above to a sub-agent so its output
does not pollute the parent conversation.
