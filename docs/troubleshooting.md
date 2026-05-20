# Troubleshooting

## Setup

### `/setup` not found in the agent UI

The skill is not installed globally. Re-run:

```bash
$AI_KIT_ROOT/bin/install-global.sh
```

Then verify:

```bash
ls -la ~/.agents/skills/setup ~/.cursor/skills/setup
```

Both should resolve to `$AI_KIT_ROOT/workflow/skills/setup`. If they don't, the symlink target is stale — delete the symlinks and re-run `install-global.sh`.

### `ai-kit root not found`

`AI_KIT_ROOT` is not set and `~/.config/ai-kit/root` doesn't exist. Either:

```bash
export AI_KIT_ROOT="/path/to/your/ai-kit/clone"
```

…or run `install-global.sh` once from the clone — it writes `~/.config/ai-kit/root` for you.

### Skills missing in Cursor

1. Check the project symlink: `ls -la .cursor/skills` — should resolve to a directory containing the skill folders (either ai-kit's symlink-merge layout or `--link-all` style).
2. Reload the Cursor window (Cmd-R / `Developer: Reload Window`).
3. If symlinks point to `/Users/<other-name>/...`, the project was set up under a different user; re-run `bootstrap-project.sh` here.

### `verify-setup.sh` fails with "missing AGENTS.md"

Run `bootstrap-project.sh` first. `verify-setup` checks the post-setup state; it doesn't create files.

## Brownfield coexistence

### Existing custom rule got "lost"

ai-kit never deletes rules. Two real causes:

1. You ran `bootstrap-project.sh --link-all` (replaces the whole `.cursor/skills` directory). Use `--merge-skills` (default since v0.4).
2. The custom rule lived at the *same path* as an ai-kit rule (e.g. `legacy-code.mdc`). Rename your version.

### Two `mcp.json` files now exist

That's intentional. ai-kit recognises `.mcp.json` (Claude Code), `.cursor/mcp.json` (Cursor), and `.vscode/mcp.json` (VS Code) as parallel valid configs and never merges them.

If `--with-mcp` was passed to bootstrap, it skips when *any* of the three already exists.

## Sandcastle

### `apply-sandcastle.sh` fails / produces `{{INSTALL_CMD}}` placeholder

Package-manager detection couldn't find a lockfile. Either the project has none, or it uses something not yet supported. Workaround: edit `.sandcastle/main.mts` and replace the placeholder manually with `pnpm install` / `yarn install` / `npm install` / `composer install`.

## Tests

### `run-tests.sh` fails with "unbound variable" on macOS

Bash 3.2 (macOS default) is sensitive to empty arrays under `set -u`. We already use the safe-expansion pattern (`${ARR[@]+"${ARR[@]}"}`) at every call site. If a NEW failure surfaces:

1. The new array is consumed without the safe pattern.
2. Patch it the same way the v1.1.0 audit did (see `bin/detect-tooling.sh` for examples).

Or upgrade to bash 5 via Homebrew:

```bash
brew install bash
```

…and set it as your interactive shell — Bash 5 doesn't have this quirk.

### `eval-structure.sh` fails on a new skill

Read the failure message — each check is named (`description missing trigger phrase`, `missing ## Process or ## Phase heading`, …). The most common new-skill failure is a description that lacks a trigger phrase like "Use when …". Add one.

For skills under 20 lines (`zoom-out`-style), the `## Process` check is skipped automatically.

## Usage logging

### `usage-stats.sh` says "no usage log"

Logging is opt-in. Set `AI_KIT_USAGE=1` in your shell profile (`~/.zshrc` / `~/.bashrc`):

```bash
export AI_KIT_USAGE=1
```

Open a new shell, run a skill, then re-check.

### I want to log when invoking a skill manually

Each SKILL.md has a `## Usage logging (opt-in)` appendix with the exact command, e.g.:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" diagnose start
# ...do the work...
bash "$AI_KIT_ROOT/bin/log-skill.sh" diagnose done
```

### Wipe everything

```bash
bin/usage-purge.sh --yes
```

The log is `${XDG_STATE_HOME:-~/.local/state}/ai-kit/usage.jsonl`. Nothing else, nowhere else.

## Reconfiguring

### `/setup` says "already configured"

The `.ai-kit-setup` marker exists. Either:

- Re-run `/setup` and pick `change` per branch you want to redo.
- Delete the marker to restart from scratch: `rm .ai-kit-setup`.

### Skill behaviour changed unexpectedly

Run the structural eval to confirm nothing in the kit drifted:

```bash
./tests/bin/eval-structure.sh
```

Then check the manual rubric for the affected skill (see [eval.md](eval.md)).

## Reporting bugs

Use the `bug` issue template at https://github.com/yusufkaracaburun/ai-kit/issues/new/choose. Include:

- `cat VERSION`
- Agent tool (Claude Code / Cursor / both)
- OS + shell + Bash version
- Output of `bin/detect-tooling.sh . --json` if setup-related
