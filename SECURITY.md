# Security

## Surface

ai-kit ships **Bash scripts and Markdown only**. No runtime daemon, no network listener, no credential store, no auto-update channel. Scripts run as the invoking user, against the invoking user's project tree.

## Local data ai-kit may write

| File | When | What |
| ---- | ---- | ---- |
| `.ai-kit-setup` (per project) | `/setup` runs | Setup mode + branch choices. No paths outside the project. |
| `~/.config/ai-kit/root` | `install-global.sh` | Absolute path to the ai-kit clone. |
| `~/.local/state/ai-kit/usage.jsonl` | only when `AI_KIT_USAGE=1` | One JSON line per skill invocation: `ts`, `skill`, `event`, `project` (basename), `cwd_hash` (sha1). **No absolute paths, no prompt contents, no file contents.** |

The usage log is **opt-in via `AI_KIT_USAGE=1`** and never leaves the machine. There is no telemetry, analytics, or remote sync. Run `bin/usage-purge.sh` to wipe it.

## Reporting a vulnerability

Open a private security advisory on GitHub: https://github.com/yusufkaracaburun/ai-kit/security/advisories/new

Or email the maintainer (see the GitHub profile). Please do not file public issues for security reports.

In scope: shell injection in any `bin/**/*.sh`, path traversal, unintended file writes outside the target project, leakage of secrets or absolute paths into committed artifacts.

Out of scope: behaviour of third-party tools ai-kit configures (Claude Code, Cursor, MCP servers); upstream issues in skills derived from `mattpocock/skills` (report there).

## Hardening notes

- `bin/log-skill.sh` and `bin/usage-stats.sh` must remain network-free. CI greps for `curl|wget|/dev/tcp|nc` in these files.
- Detection scripts (`detect-tooling.sh`, `detect-lib.sh`) only read; they never modify the target project unless invoked with explicit `--write*` flags.
- `bootstrap-project.sh` only writes inside the target project root.
