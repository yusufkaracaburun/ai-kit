#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# install-global.sh symlinks ai-kit's skills/agents/commands from this repo
# into ~/.claude and ~/.agents (skills) and ~/.cursor (commands only). Every case here runs with HOME
# redirected into a temp dir, so the developer's real machine is never
# touched. AI_KIT_ROOT is left unset — the script resolves its own root from
# its own path (bin/..), which is this real repo, so it reads real skills
# but writes only into the sandboxed HOME.
#
# NOT COVERED: the install-global.sh invocation from within a *plugin*
# install (where resolve_primitives_root would pick the non-workflow
# branch) — this dev clone always has workflow/skills/, so that branch
# never runs here.

install_global() {
  # install_global <sandbox_home> — a machine with Claude Code and Cursor, no hosts file, no TTY
  local home="$1"
  mkdir -p "$home/.claude" "$home/.cursor"
  HOME="$home" bash "$AIKIT/bin/install-global.sh" </dev/null
}

echo "=== fresh install ==="
H=$(mktemp -d)
OUT=$(install_global "$H")
assert "links a known skill into ~/.claude/skills" '[ -L "$H/.claude/skills/audit-architecture" ]'
assert "skill symlink resolves into the aikit source tree" \
  'readlink "$H/.claude/skills/audit-architecture" | grep -q "workflow/skills/audit-architecture"'
assert "links a known agent into ~/.claude/agents" '[ -L "$H/.claude/agents/explore.md" ]'
assert "links a known command into ~/.claude/commands" '[ -L "$H/.claude/commands/doctor.md" ]'
assert "also links skills into ~/.agents/skills (Cursor and Copilot read it)" '[ -L "$H/.agents/skills/audit-architecture" ]'
assert "no skills linked into ~/.cursor/skills" '[ ! -e "$H/.cursor/skills/audit-architecture" ]'
assert "also links commands into ~/.cursor/commands" '[ -L "$H/.cursor/commands/doctor.md" ]'
assert "writes the ai-kit root config" 'grep -qx "$AIKIT" "$H/.config/ai-kit/root"'
DOC="$(HOME="$H" bash "$AIKIT/bin/ai-kit-doctor.sh" 2>&1 || true)"
assert "doctor global install checks ~/.agents/skills" 'grep -q "ok .*$H/.agents/skills —" <<<"$DOC"'
assert "doctor global install no longer checks ~/.cursor/skills" '! grep -q "$H/.cursor/skills" <<<"$DOC"'
rm -rf "$H"

echo "=== existing non-aikit entry is skipped, not clobbered ==="
H=$(mktemp -d)
mkdir -p "$H/.claude/skills/audit-architecture"
echo "mine" > "$H/.claude/skills/audit-architecture/marker.txt"
OUT=$(install_global "$H")
assert "reports the existing entry as skipped" \
  'grep -q "Skipped audit-architecture (existing non-aikit entry" <<<"$OUT"'
assert "existing dir stays a real dir, not replaced by a symlink" \
  '[ ! -L "$H/.claude/skills/audit-architecture" ]'
assert "existing dir's contents are untouched" '[ -f "$H/.claude/skills/audit-architecture/marker.txt" ]'
rm -rf "$H"

echo "=== idempotent re-run ==="
H=$(mktemp -d)
install_global "$H" >/dev/null
OUT2=$(install_global "$H")
# Positive assertion first: "Skipped" being absent is also true of empty
# output, so prove the installer ran before checking it left current links alone.
assert "re-run ran the skill install" \
  'grep -q "(~/.agents/skills) ===" <<<"$OUT2"'
assert "re-run leaves an up-to-date link alone" \
  '! grep -q "Linked audit-architecture" <<<"$OUT2"'
assert "re-run does not warn about a foreign symlink" \
  '! grep -q "Skipped audit-architecture" <<<"$OUT2"'
assert "symlink still resolves to the repo after the second run" \
  '[ -L "$H/.claude/skills/audit-architecture" ] && [ -e "$H/.claude/skills/audit-architecture" ]'
rm -rf "$H"

echo "=== prefer-plugin marker: skips ~/.claude, keeps ~/.cursor ==="
H=$(mktemp -d)
mkdir -p "$H/.config/ai-kit"
: > "$H/.config/ai-kit/prefer-plugin"
OUT=$(install_global "$H")
assert "skills skipped for ~/.claude under the marker" '[ ! -e "$H/.claude/skills/audit-architecture" ]'
assert "agents skipped for ~/.claude under the marker" '[ ! -e "$H/.claude/agents/explore.md" ]'
assert "commands skipped for ~/.claude under the marker" '[ ! -e "$H/.claude/commands/doctor.md" ]'
assert "output explains the skip" 'grep -q "skipped (prefer-plugin marker)" <<<"$OUT"'
assert "cursor has no plugin namespace, so its skills still link in ~/.agents/skills" '[ -L "$H/.agents/skills/audit-architecture" ]'
assert "cursor commands still link" '[ -L "$H/.cursor/commands/doctor.md" ]'
rm -rf "$H"

echo "=== ai-kit links leave ~/.cursor/skills, foreign entries stay ==="
H=$(mktemp -d)
mkdir -p "$H/.cursor/skills/ui-ux-pro-max" "$H/elsewhere/hyperframes-x"
ln -s "$AIKIT/workflow/skills/audit-architecture/" "$H/.cursor/skills/audit-architecture"
ln -s "$H/.config/ai-kit/plugin-current/skills/aikit-tdd/" "$H/.cursor/skills/aikit-tdd"
ln -s "$H/elsewhere/hyperframes-x" "$H/.cursor/skills/hyperframes-x"
install_global "$H" >/dev/null
assert "source-mode ai-kit link removed from ~/.cursor/skills" '[ ! -L "$H/.cursor/skills/audit-architecture" ]'
assert "plugin-current ai-kit link removed from ~/.cursor/skills" '[ ! -L "$H/.cursor/skills/aikit-tdd" ]'
assert "foreign link in ~/.cursor/skills kept" '[ -L "$H/.cursor/skills/hyperframes-x" ]'
assert "foreign real dir in ~/.cursor/skills kept" '[ -d "$H/.cursor/skills/ui-ux-pro-max" ]'
rm -rf "$H"

echo "=== dead ai-kit symlinks are reclaimed, foreign dead links are not ==="
H=$(mktemp -d)
GONE="$H/moved-away/ai-kit/workflow"
mkdir -p "$H/.agents/skills" "$H/.cursor/commands"
# A link to a skill that still exists in the source tree, and one to a name
# that no longer does (a rename orphan the entry loop never visits).
ln -s "$GONE/skills/audit-architecture/" "$H/.agents/skills/audit-architecture"
ln -s "$GONE/skills/aikit-tdd/" "$H/.agents/skills/aikit-tdd"
ln -s "$GONE/commands/doctor.md" "$H/.cursor/commands/doctor.md"
# Someone else's dead links — not ours to delete. `qa` collides with a name
# in the source tree, so it also exercises the entry loop's non-clobber arm;
# `mine` does not, so only the sweep ever sees it.
ln -s "/nonexistent/other-tool/skills/qa/" "$H/.agents/skills/qa"
ln -s "/nonexistent/other-tool/skills/mine/" "$H/.agents/skills/mine"
OUT=$(install_global "$H")
assert "relinks a dead ai-kit skill link into the repo" \
  '[ -e "$H/.agents/skills/audit-architecture" ] && readlink "$H/.agents/skills/audit-architecture" | grep -q "workflow/skills/audit-architecture"'
assert "removes a dead ai-kit link whose skill no longer exists" \
  '[ ! -L "$H/.agents/skills/aikit-tdd" ]'
assert "reports the orphan removal" 'grep -q "Removed dead link aikit-tdd" <<<"$OUT"'
assert "relinks a dead ai-kit command link" \
  '[ -e "$H/.cursor/commands/doctor.md" ]'
assert "names the old target when it removes a link" \
  'grep -q "Removed dead link aikit-tdd (was -> $GONE/skills/aikit-tdd/)" <<<"$OUT"'
assert "leaves a foreign dead link alone" \
  '[ -L "$H/.agents/skills/mine" ] && [ ! -e "$H/.agents/skills/mine" ]'
assert "does not report the foreign link as removed" \
  '! grep -q "Removed dead link mine" <<<"$OUT"'
assert "a foreign dead link on a colliding name stays dead" \
  '[ -L "$H/.agents/skills/qa" ] && [ ! -e "$H/.agents/skills/qa" ]'
assert "and is reported as an existing non-aikit entry" \
  'grep -q "Skipped qa (existing non-aikit entry" <<<"$OUT"'
rm -rf "$H"

echo "=== links from a previous root with no /ai-kit/ segment are reclaimed ==="
# A plugin install pins its version into the path
# (~/.claude/plugins/cache/<owner>/ai/<version>), so after an upgrade its
# links are dead and match no /ai-kit/ pattern. ~/.config/ai-kit/root still
# holds the root they were made from.
H=$(mktemp -d)
OLD_PLUGIN="$H/.claude/plugins/cache/owner/ai/1.62.0"
mkdir -p "$H/.config/ai-kit" "$H/.agents/skills" "$H/.cursor/commands"
printf '%s\n' "$OLD_PLUGIN" > "$H/.config/ai-kit/root"
ln -s "$OLD_PLUGIN/skills/audit-architecture/" "$H/.agents/skills/audit-architecture"
ln -s "$OLD_PLUGIN/skills/aikit-tdd/" "$H/.agents/skills/aikit-tdd"
ln -s "$OLD_PLUGIN/commands/doctor.md" "$H/.cursor/commands/doctor.md"
ln -s "/nonexistent/other-tool/skills/mine/" "$H/.agents/skills/mine"
OUT=$(install_global "$H")
assert "relinks a live skill name from the previous root" \
  '[ -e "$H/.agents/skills/audit-architecture" ]'
assert "removes an orphan from the previous root" '[ ! -L "$H/.agents/skills/aikit-tdd" ]'
assert "removes an orphan command from the previous root" \
  '[ -e "$H/.cursor/commands/doctor.md" ]'
assert "still leaves a foreign dead link alone" '[ -L "$H/.agents/skills/mine" ]'
rm -rf "$H"

echo "=== no previous root: the empty value must not match every path ==="
H=$(mktemp -d)
mkdir -p "$H/.agents/skills"
ln -s "/nonexistent/other-tool/skills/mine/" "$H/.agents/skills/mine"
OUT=$(install_global "$H")
assert "foreign dead link survives when ~/.config/ai-kit/root is absent" \
  '[ -L "$H/.agents/skills/mine" ]'
rm -rf "$H"

echo "=== no ~/.claude, no hosts file, no TTY: nothing written for any host ==="
H=$(mktemp -d)
HOME="$H" bash "$AIKIT/bin/install-global.sh" </dev/null >/dev/null
assert "no ~/.claude created" '[ ! -e "$H/.claude" ]'
assert "no ~/.agents created" '[ ! -e "$H/.agents" ]'
assert "no ~/.cursor created" '[ ! -e "$H/.cursor" ]'
assert "no hosts file written without a TTY" '[ ! -e "$H/.config/ai-kit/hosts" ]'
rm -rf "$H"

echo "=== hosts file decides what is linked ==="
H=$(mktemp -d)
mkdir -p "$H/.config/ai-kit"
echo "claude,copilot" > "$H/.config/ai-kit/hosts"
HOME="$H" bash "$AIKIT/bin/install-global.sh" </dev/null >/dev/null
assert "claude,copilot: ~/.claude/skills linked" '[ -L "$H/.claude/skills/audit-architecture" ]'
assert "claude,copilot: ~/.agents/skills linked" '[ -L "$H/.agents/skills/audit-architecture" ]'
assert "claude,copilot: no ~/.cursor/commands" '[ ! -e "$H/.cursor" ]'
echo "claude" > "$H/.config/ai-kit/hosts"
mkdir -p "$H/elsewhere/x"
ln -s "$H/elsewhere/x" "$H/.agents/skills/foreign"
HOME="$H" bash "$AIKIT/bin/install-global.sh" </dev/null >/dev/null
assert "claude only: ai-kit links removed from ~/.agents/skills" '[ ! -L "$H/.agents/skills/audit-architecture" ]'
assert "claude only: foreign link in ~/.agents/skills stays" '[ -L "$H/.agents/skills/foreign" ]'
assert "claude only: ~/.claude/skills still linked" '[ -L "$H/.claude/skills/audit-architecture" ]'
rm -rf "$H"

echo "=== doctor on a clean single-host install without Claude Code ==="
for host in cursor copilot; do
  H=$(mktemp -d)
  mkdir -p "$H/.$host"
  HOME="$H" bash "$AIKIT/bin/install-global.sh" </dev/null >/dev/null
  DOC_EXIT=0
  OUT_DOC="$(cd "$H" && HOME="$H" bash "$AIKIT/bin/ai-kit-doctor.sh" 2>&1)" || DOC_EXIT=$?
  assert "$host only: no ~/.claude created" '[ ! -e "$H/.claude" ]'
  assert "$host only: ~/.agents/skills linked" '[ -L "$H/.agents/skills/audit-architecture" ]'
  assert "$host only: doctor exits 0" '[ "$DOC_EXIT" -eq 0 ]'
  assert "$host only: doctor reports $host installed" 'grep -q "ok .*$host installed" <<<"$OUT_DOC"'
  assert "$host only: doctor reports claude not used" 'grep -q "info .*claude not used" <<<"$OUT_DOC"'
  rm -rf "$H"
done

echo "=== the install-global prompt writes ~/.config/ai-kit/hosts on a TTY ==="
# run_on_tty <home> <typed input>: pty.fork gives install-global a real terminal on stdin.
run_on_tty() {
  HOME="$1" python3 -c '
import os, pty, sys
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash", sys.argv[1]])
os.write(fd, sys.argv[2].encode())
out = b""
while True:
    try:
        chunk = os.read(fd, 4096)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
' "$AIKIT/bin/install-global.sh" "$2" 2>&1
}
H=$(mktemp -d)
mkdir -p "$H/.cursor"
PTY_OUT="$(run_on_tty "$H" $'cursor,codex\n')"
assert "prompt names the detected hosts" 'grep -q "\[cursor\]" <<<"$PTY_OUT"'
assert "answer written to the hosts file" '[ "$(cat "$H/.config/ai-kit/hosts" 2>/dev/null)" = "cursor,codex" ]'
assert "answer applied: ~/.agents/skills linked, no ~/.claude" '[ -L "$H/.agents/skills/audit-architecture" ] && [ ! -e "$H/.claude" ]'
rm -rf "$H"

H=$(mktemp -d)
PTY_TYPO="$(run_on_tty "$H" $'claude,cursr\ncursor\n')"
assert "typo: the unknown token is named" 'grep -q "unknown host .cursr." <<<"$PTY_TYPO"'
assert "typo: asked again, the corrected answer is written" '[ "$(cat "$H/.config/ai-kit/hosts" 2>/dev/null)" = "cursor" ]'
rm -rf "$H"

H=$(mktemp -d)
PTY_EMPTY="$(run_on_tty "$H" $'\n\n\n')"
assert "empty: the refusal is reported" 'grep -q "hosts: empty answer" <<<"$PTY_EMPTY"'
assert "empty: asked three times" '[ "$(grep -o "Which agents do you use" <<<"$PTY_EMPTY" | wc -l | tr -d " ")" -eq 3 ]'
assert "empty: nothing written after three refusals" '[ ! -e "$H/.config/ai-kit/hosts" ]'
assert "empty: falls back to detection, nothing linked" '[ ! -e "$H/.claude" ] && [ ! -e "$H/.agents" ]'
rm -rf "$H"

echo "=== doctor warns about an unknown name in the hosts file ==="
H=$(mktemp -d)
mkdir -p "$H/.config/ai-kit"
echo "cursor,cursr" > "$H/.config/ai-kit/hosts"
OUT_DOC="$(cd "$H" && HOME="$H" bash "$AIKIT/bin/ai-kit-doctor.sh" 2>&1 || true)"
assert "doctor names the unknown token" 'grep -q "warn .*unknown host .cursr." <<<"$OUT_DOC"'
assert "doctor does not flag a valid token" '! grep -q "unknown host .cursor." <<<"$OUT_DOC"'
rm -rf "$H"

echo "=== a hosts file without a trailing newline keeps its last host ==="
H=$(mktemp -d)
mkdir -p "$H/.config/ai-kit"
printf 'claude,cursor' > "$H/.config/ai-kit/hosts"
NO_NL_HOSTS="$(HOME="$H" bash -c 'source "$1/bin/lib/ai-kit-root.sh"; aikit_hosts | paste -sd, -' _ "$AIKIT")"
assert "aikit_hosts returns both hosts" '[ "$NO_NL_HOSTS" = "claude,cursor" ]'
printf 'claude,cursr' > "$H/.config/ai-kit/hosts"
OUT_DOC="$(cd "$H" && HOME="$H" bash "$AIKIT/bin/ai-kit-doctor.sh" 2>&1 || true)"
assert "doctor names an unknown last token" 'grep -q "warn .*unknown host .cursr." <<<"$OUT_DOC"'
EMPTY_TOK="$(HOME="$H" bash -c 'source "$1/bin/lib/ai-kit-root.sh"; write_aikit_hosts "claude,"' _ "$AIKIT" 2>&1 || true)"
assert "an empty token is called an empty host name" 'grep -q "empty host name" <<<"$EMPTY_TOK" && ! grep -q "unknown host" <<<"$EMPTY_TOK"'
rm -rf "$H"

print_summary_and_exit
