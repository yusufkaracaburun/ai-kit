# Agent stack guide (for /ai:setup branch 0)

ADR-0012: one auto-detected fact, one question (asked only when it is a
real choice), brownfield unchanged and unrelated to either.

## Explore

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh "$(pwd)" --json
```

Read `agent_stack.needs_doc` for the brownfield signal (see §3) — it has
nothing to do with the skills-merge decision below.

## 1. Auto-detect `global_channel_available` — no question

```bash
source "$AI_KIT_ROOT/bin/lib/ai-kit-root.sh"
global_channel_available && echo yes || echo no
```

True iff the ai-kit plugin is installed (Claude Code only) or the legacy
symlink-install has run (`~/.config/ai-kit/root` present — this half
covers every host, since `install-global.sh` writes `~/.cursor/skills`
too, not just `~/.claude/skills`).

**Running under Cursor:** ignore the plugin half of this fact — Cursor
has no plugin channel, so a plugin-cache hit on this machine (e.g. the
same machine also runs Claude Code) means nothing for a Cursor session.
Only the symlink-install half counts here.

## 2. Ask ONE question — only when `global_channel_available` is true

If false: `project_skills_merged=true`, no question — nothing else would
serve this project's skills.

If true:

> ai-kit's skills are already available globally on this machine (via
> **the plugin** / **the global install** — name whichever was actually
> detected). Should this project also get its own copy in
> `.claude/skills` etc — useful if you (or a teammate) ever open it
> without that install, or on a different host?
> [1] No, just use the global one
> [2] Yes, merge into this project too

Default **[1]** when the symlink-install is the channel found (covers
every host already, safe to skip project-merge). Default **[2]** instead
when the plugin is the *only* channel found — it never covers Cursor, so
defaulting to "no" would risk silently under-serving a teammate or a
future session on a different host with this same repo. Whichever
default is shown, the human's explicit answer wins.

## 3. Brownfield (auto-detected, unrelated to §1-2)

| Signal | When |
| ------ | ---- |
| `needs_doc=true` from `detect-tooling.sh` | Write `agent-stack.md`; Tier-B defaults become lifecycle=`production`, Sandcastle skip, automation-recommender skip, architecture assumes-existing conventions |
| `needs_doc=false` | Skip all of the above — greenfield defaults |

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh "$(pwd)" --write-agent-stack
```

Refine the draft with the user; list what must not be overwritten.

## 4. Record

```bash
$AI_KIT_ROOT/bin/write-setup-marker.sh "$(pwd)" \
  --project-skills-merged=true|false \
  --setup-mode=<derived> --tier=minimal
```

Derive `--setup-mode=` too, for anything still reading the legacy string
(dual-write — see ADR-0012):

| `global_channel_available` | `project_skills_merged` | `brownfield` | derived `setup_mode` |
| --------------------------- | ------------------------ | ------------ | --------------------- |
| true | true | false | `solo-both` |
| true | false | false | `solo-global` |
| false | true | false | `project-only` |
| (any) | (any) | true | `brownfield` |

## Fast path default

Unless the user asks for full setup, use **Tier A** (see SKILL.md): the
fact + the one question (if asked) + bootstrap + dev-env, then
`--tier=minimal`.
