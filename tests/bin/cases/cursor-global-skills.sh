#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# Cursor and VS Code Copilot have no plugin channel, so a plugin-only machine
# (no-globals + prefer-plugin) used to get ~35 skill symlinks per repo in
# .cursor/skills. Bootstrap now links them once into ~/.agents/skills, which
# both hosts read; upgrade prunes the per-repo copies; the SessionEnd hook
# keeps the global dir current and removes ai-kit links from ~/.cursor/skills.

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT
mkdir -p "$H/.config/ai-kit"
: > "$H/.config/ai-kit/no-globals"
: > "$H/.config/ai-kit/prefer-plugin"

make_fake_version() {
  local version="$1"
  local root="$H/.claude/plugins/cache/mkt/ai/$version"
  mkdir -p "$root/bin" "$root/workflow/skills/demo-skill" "$root/workflow/skills/review" "$root/workflow/agents" "$root/workflow/commands"
  cp -R "$AIKIT/bin/." "$root/bin/"
  ln -sfn "$AIKIT/context" "$root/context"
  printf '%s\n' "$version" > "$root/VERSION"
  printf '# demo-skill (%s)\n' "$version" > "$root/workflow/skills/demo-skill/SKILL.md"
  printf '# review (%s)\n' "$version" > "$root/workflow/skills/review/SKILL.md"
  echo "$root"
}

write_marker() {
  printf '{\n  "ai_kit_version": "%s",\n  "completed_at": "2026-01-01T00:00:00Z"\n}\n' "$2" > "$1/.ai-kit-setup"
}

mkdir -p "$H/elsewhere/hyperframes-x" "$H/.cursor/skills/ui-ux-pro-max" "$H/.agents/skills/ui-ux-pro-max"
ln -s "$H/elsewhere/hyperframes-x" "$H/.cursor/skills/hyperframes-x"
ln -s "$H/elsewhere/hyperframes-x" "$H/.agents/skills/hyperframes-x"
# Cursor mirrors its built-in `review` here as a real dir; it collides with ai-kit's review.
mkdir -p "$H/.agents/skills/review"
: > "$H/.agents/skills/review/SKILL.md"
ln -s "/nonexistent/other-tool/skills/gone" "$H/.agents/skills/gone"
printf '{}\n' > "$H/.agents/skills/.skill-lock.json"

echo "=== bootstrap (plugin mode, no-globals set) links ~/.agents/skills, not the project ==="
# section: cursor-global-bootstrap
V1="$(make_fake_version 1.0.0)"
P="$H/proj"
HOME="$H" bash "$V1/bin/bootstrap-project.sh" --minimal --no-agents --no-commands --no-rules --no-gh-workflow "$P" >/dev/null
assert "global .agents/skills/demo-skill linked through plugin-current" \
  '[ -L "$H/.agents/skills/demo-skill" ] && readlink "$H/.agents/skills/demo-skill" | grep -q "/.config/ai-kit/plugin-current/"'
assert "the global link resolves" '[ -f "$H/.agents/skills/demo-skill/SKILL.md" ]'
assert "nothing new linked into ~/.cursor/skills" '[ ! -e "$H/.cursor/skills/demo-skill" ]'
assert "project .cursor/skills not created" '[ ! -e "$P/.cursor/skills" ]'
assert "project .claude/skills still merged" '[ -L "$P/.claude/skills/demo-skill" ]'
assert "colliding real dir review in ~/.agents/skills untouched" '[ -d "$H/.agents/skills/review" ] && [ ! -L "$H/.agents/skills/review" ]'
assert "foreign link in ~/.agents/skills untouched" '[ "$(readlink "$H/.agents/skills/hyperframes-x")" = "$H/elsewhere/hyperframes-x" ]'
assert "foreign dangling link in ~/.agents/skills untouched" '[ "$(readlink "$H/.agents/skills/gone")" = "/nonexistent/other-tool/skills/gone" ]'
assert ".skill-lock.json untouched" '[ "$(cat "$H/.agents/skills/.skill-lock.json")" = "{}" ]'
assert "foreign entries in ~/.cursor/skills untouched" '[ -L "$H/.cursor/skills/hyperframes-x" ] && [ -d "$H/.cursor/skills/ui-ux-pro-max" ]'

echo "=== doctor / verify-setup / status do not flag the absent project .cursor/skills ==="
# section: cursor-global-reporting
DOC="$(HOME="$H" bash "$V1/bin/ai-kit-doctor.sh" "$P" --project-only 2>&1 || true)"
assert "doctor: no .cursor/skills absent warning" '! grep -q "\.cursor/skills absent (run bootstrap-project.sh)" <<<"$DOC"'
assert "doctor: names ~/.agents/skills as the served dir" 'grep -q "served by ~/.agents/skills" <<<"$DOC"'
assert "doctor: reports review as shadowed on an info line" 'grep -q "info .*review shadowed" <<<"$DOC"'
assert "doctor: shadowed is not a warning" '! grep -q "warn .*shadowed" <<<"$DOC"'
assert "doctor: the only warning counted is the absent marker" \
  'grep -q "Summary: 1 warning(s)" <<<"$DOC" && [ "$(grep -c "^  warn" <<<"$DOC")" -eq 1 ] && grep -q "warn .*\.ai-kit-setup absent" <<<"$DOC"'
assert "doctor: shadowed is not an error" '! grep -q "ERR .*review" <<<"$DOC"'
assert "doctor: an ai-kit link is not called shadowed" '! grep -q "demo-skill shadowed" <<<"$DOC"'
printf '{"ai_kit_version":"1.0.0","branches":{"project_skills_merged":true}}\n' > "$P/.ai-kit-setup"
VER="$(HOME="$H" bash "$V1/bin/verify-setup.sh" "$P" 2>&1 || true)"
assert "verify-setup: .cursor/skills check not failed" '! grep -q "\.cursor/skills present" <<<"$VER"'
STATUS="$(HOME="$H" bash "$V1/bin/ai-kit-status.sh" "$P" 2>&1 || true)"
assert "status: .cursor/skills not listed missing" '! grep "missing:" <<<"$STATUS" | grep -q "\.cursor/skills"'

echo "=== upgrade removes project .cursor/skills links into ai-kit, nothing else ==="
# section: cursor-global-upgrade
PU="$H/proj-upgrade"
mkdir -p "$PU/.cursor/skills/boost-skill"
ln -s "$H/.config/ai-kit/plugin-current/workflow/skills/demo-skill/" "$PU/.cursor/skills/demo-skill"
ln -s "$H/elsewhere/hyperframes-x" "$PU/.cursor/skills/foreign"
write_marker "$PU" "1.0.0"
HOME="$H" bash "$V1/bin/ai-kit-upgrade.sh" "$PU" >/dev/null 2>&1
assert "ai-kit link removed" '[ ! -L "$PU/.cursor/skills/demo-skill" ]'
assert "real dir kept" '[ -d "$PU/.cursor/skills/boost-skill" ]'
assert "foreign link kept" '[ -L "$PU/.cursor/skills/foreign" ]'

PE="$H/proj-empty"
mkdir -p "$PE/.cursor/skills"
ln -s "$H/.config/ai-kit/plugin-current/workflow/skills/demo-skill/" "$PE/.cursor/skills/demo-skill"
write_marker "$PE" "1.0.0"
HOME="$H" bash "$V1/bin/ai-kit-upgrade.sh" "$PE" >/dev/null 2>&1
assert "dir holding only ai-kit links is removed" '[ ! -e "$PE/.cursor/skills" ] && [ -d "$PE/.cursor" ]'

PL="$H/proj-linkall"
mkdir -p "$PL/.cursor"
ln -s "$H/.config/ai-kit/plugin-current/workflow/skills" "$PL/.cursor/skills"
write_marker "$PL" "1.0.0"
HOME="$H" bash "$V1/bin/ai-kit-upgrade.sh" "$PL" >/dev/null 2>&1
assert "link-all whole-dir symlink into ai-kit is removed" '[ ! -e "$PL/.cursor/skills" ] && [ ! -L "$PL/.cursor/skills" ]'

H2=$(mktemp -d)
PK="$H2/proj-keep"
mkdir -p "$PK/.cursor/skills"
ln -s "$V1/workflow/skills/demo-skill" "$PK/.cursor/skills/demo-skill"
write_marker "$PK" "1.0.0"
HOME="$H2" bash "$V1/bin/ai-kit-upgrade.sh" "$PK" >/dev/null 2>&1
assert "without global Cursor skills the project link is repaired, not removed" '[ -L "$PK/.cursor/skills/demo-skill" ] && [ -e "$PK/.cursor/skills/demo-skill" ]'
rm -rf "$H2"

echo "=== upgrade false positives: only real ai-kit links count ==="
# section: cursor-global-false-positives
mkdir -p "$H/elsewhere/ai-kit-fork/demo-skill" "$H/elsewhere/ai-kit-skills"
PF="$H/proj-foreign-aikit"
mkdir -p "$PF/.cursor/skills"
ln -s "$H/elsewhere/ai-kit-fork/demo-skill" "$PF/.cursor/skills/demo-skill"
ln -s "$H/.config/ai-kit/plugin-current/workflow/skills/review/" "$PF/.cursor/skills/review"
write_marker "$PF" "1.0.0"
HOME="$H" bash "$V1/bin/ai-kit-upgrade.sh" "$PF" >/dev/null 2>&1
assert "link to a foreign path containing ai-kit is kept" '[ "$(readlink "$PF/.cursor/skills/demo-skill")" = "$H/elsewhere/ai-kit-fork/demo-skill" ]'
assert "ai-kit link kept when the global same-named entry is a foreign real dir" '[ -L "$PF/.cursor/skills/review" ]'

PW="$H/proj-foreign-wholedir"
mkdir -p "$PW/.cursor"
ln -s "$H/elsewhere/ai-kit-skills" "$PW/.cursor/skills"
write_marker "$PW" "1.0.0"
HOME="$H" bash "$V1/bin/ai-kit-upgrade.sh" "$PW" >/dev/null 2>&1
assert "whole-dir link to a foreign path containing ai-kit is kept" '[ "$(readlink "$PW/.cursor/skills")" = "$H/elsewhere/ai-kit-skills" ]'

H3=$(mktemp -d)
OTHER="$H3/.claude/plugins/cache/other/ai-kit/1.0.0/skills/demo-skill"
mkdir -p "$OTHER" "$H3/.agents/skills"
ln -s "$OTHER" "$H3/.agents/skills/demo-skill"
PO="$H3/proj-other-marketplace"
mkdir -p "$PO/.cursor/skills"
ln -s "$H3/.config/ai-kit/plugin-current/workflow/skills/demo-skill/" "$PO/.cursor/skills/demo-skill"
write_marker "$PO" "1.0.0"
HOME="$H3" bash "$V1/bin/ai-kit-upgrade.sh" "$PO" >/dev/null 2>&1
assert "global link into another marketplace: upgrade prunes nothing" '[ -L "$PO/.cursor/skills/demo-skill" ]'
PD="$H3/proj-doctor"
mkdir -p "$PD/.claude"
DOC3="$(HOME="$H3" bash "$V1/bin/ai-kit-doctor.sh" "$PD" --project-only 2>&1 || true)"
assert "global link into another marketplace: doctor still warns" 'grep -q "\.cursor/skills absent (run bootstrap-project.sh)" <<<"$DOC3"'
rm -rf "$H3"

echo "=== bootstrap without ~/.cursor and ~/.agents keeps the project .cursor/skills ==="
# section: cursor-global-no-cursor
H4=$(mktemp -d)
P4="$H4/proj"
HOME="$H4" bash "$V1/bin/bootstrap-project.sh" --minimal --no-agents --no-commands --no-rules --no-gh-workflow "$P4" >/dev/null
assert "no ~/.cursor created" '[ ! -e "$H4/.cursor" ]'
assert "no ~/.agents created" '[ ! -e "$H4/.agents" ]'
assert "project .cursor/skills linked instead" '[ -L "$P4/.cursor/skills/demo-skill" ]'
rm -rf "$H4"

H6=$(mktemp -d)
mkdir -p "$H6/.agents"
HOME="$H6" bash "$V1/bin/bootstrap-project.sh" --minimal --no-agents --no-commands --no-rules --no-gh-workflow "$H6/proj" >/dev/null
assert "only ~/.agents present: ~/.agents/skills created and linked" '[ -L "$H6/.agents/skills/demo-skill" ]'
assert "only ~/.agents present: no ~/.cursor created" '[ ! -e "$H6/.cursor" ]'
rm -rf "$H6"

echo "=== install_dir_to leaves a current link alone ==="
# section: cursor-global-idempotent
BEFORE="$(stat -c '%i' "$H/.agents/skills/demo-skill" 2>/dev/null || stat -f '%i' "$H/.agents/skills/demo-skill")"
HOME="$H" bash -c "source '$AIKIT/bin/lib/link-primitives.sh'; install_dir_to '$H/.config/ai-kit/plugin-current/workflow/skills' '$H/.agents/skills'" >/dev/null
AFTER="$(stat -c '%i' "$H/.agents/skills/demo-skill" 2>/dev/null || stat -f '%i' "$H/.agents/skills/demo-skill")"
assert "an up-to-date link is not recreated" '[ "$BEFORE" = "$AFTER" ]'

echo "=== SessionEnd hook adds new and prunes dead ai-kit entries in ~/.agents/skills ==="
# section: cursor-global-hook
CACHE="$H/.claude/plugins/cache/yusufkaracaburun/ai"
for v in 2.0.0 2.0.1; do
  mkdir -p "$CACHE/$v/hooks" "$CACHE/$v/rules" "$CACHE/$v/bin"
  cp -R "$AIKIT/bin/." "$CACHE/$v/bin/"
  cp "$AIKIT/workflow/hooks/global-rules-link.sh" "$CACHE/$v/hooks/"
done
mkdir -p "$CACHE/2.0.0/skills/old-skill" "$CACHE/2.0.1/skills/new-skill"
ln -sfn "$CACHE/2.0.0" "$H/.config/ai-kit/plugin-current"
ln -s "$H/.config/ai-kit/plugin-current/skills/old-skill/" "$H/.agents/skills/old-skill"
# Links v2.10.1 made in ~/.cursor/skills: one live, one dead.
ln -s "$H/.config/ai-kit/plugin-current/skills/new-skill/" "$H/.cursor/skills/new-skill"
ln -s "$H/.config/ai-kit/plugin-current/skills/old-skill/" "$H/.cursor/skills/old-skill"
OUT="$(HOME="$H" bash "$CACHE/2.0.0/hooks/global-rules-link.sh" </dev/null)"
assert "hook is silent" '[ -z "$OUT" ]'
assert "new skill linked through plugin-current" \
  '[ "$(readlink "$H/.agents/skills/new-skill")" = "$H/.config/ai-kit/plugin-current/skills/new-skill/" ] && [ -d "$H/.agents/skills/new-skill" ]'
assert "skill gone from the new version is pruned" '[ ! -L "$H/.agents/skills/old-skill" ]'
assert "foreign link still untouched" '[ "$(readlink "$H/.agents/skills/hyperframes-x")" = "$H/elsewhere/hyperframes-x" ]'
assert "foreign dangling link survives the reap" '[ -L "$H/.agents/skills/gone" ]'
assert ".skill-lock.json survives the reap" '[ -f "$H/.agents/skills/.skill-lock.json" ]'
assert "real dir review survives" '[ -d "$H/.agents/skills/review" ] && [ ! -L "$H/.agents/skills/review" ]'
assert "migration: live ai-kit link removed from ~/.cursor/skills" '[ ! -L "$H/.cursor/skills/new-skill" ]'
assert "migration: dead ai-kit link removed from ~/.cursor/skills" '[ ! -L "$H/.cursor/skills/old-skill" ]'
assert "migration: foreign entries in ~/.cursor/skills stay" '[ -L "$H/.cursor/skills/hyperframes-x" ] && [ -d "$H/.cursor/skills/ui-ux-pro-max" ]'
assert "rules link still made" '[ "$(readlink "$H/.claude/rules/ai-kit")" = "$(cd "$CACHE/2.0.1/rules" && pwd -P)" ]'

H5=$(mktemp -d)
HOME="$H5" bash "$CACHE/2.0.0/hooks/global-rules-link.sh" </dev/null >/dev/null
assert "hook without ~/.cursor and ~/.agents writes no skill dir" '[ ! -e "$H5/.agents" ] && [ ! -e "$H5/.cursor" ]'
rm -rf "$H5"
H7=$(mktemp -d)
mkdir -p "$H7/.agents"
HOME="$H7" bash "$CACHE/2.0.0/hooks/global-rules-link.sh" </dev/null >/dev/null
assert "hook with only ~/.agents creates ~/.agents/skills" '[ -L "$H7/.agents/skills/new-skill" ]'
rm -rf "$H7"
H8=$(mktemp -d)
mkdir -p "$H8/.agents/skills" "$H8/.cursor"
ln -s "$H8/.agents/skills" "$H8/.cursor/skills"
HOME="$H8" bash "$CACHE/2.0.0/hooks/global-rules-link.sh" </dev/null >/dev/null
assert "hook keeps its own links when ~/.cursor/skills is a symlink to ~/.agents/skills" '[ -L "$H8/.agents/skills/new-skill" ] && [ -e "$H8/.agents/skills/new-skill" ]'
rm -rf "$H8"

echo "=== ~/.config/ai-kit/hosts, or detection, decides the ~/.agents/skills link set ==="
# section: cursor-global-hosts
run_hook() { HOME="$1" bash "$CACHE/2.0.0/hooks/global-rules-link.sh" </dev/null >/dev/null; }
H9=$(mktemp -d)
mkdir -p "$H9/.config/ai-kit"
echo "claude,copilot" > "$H9/.config/ai-kit/hosts"
run_hook "$H9"
assert "hosts claude,copilot: hook links ~/.agents/skills" '[ -L "$H9/.agents/skills/new-skill" ]'
rm -rf "$H9"

H10=$(mktemp -d)
mkdir -p "$H10/.config/ai-kit" "$H10/.agents/skills/own-dir" "$H10/elsewhere/x" "$H10/.cursor"
echo "claude" > "$H10/.config/ai-kit/hosts"
ln -s "$H10/.config/ai-kit/plugin-current/skills/old-skill/" "$H10/.agents/skills/old-skill"
ln -s "$H10/elsewhere/x" "$H10/.agents/skills/foreign"
run_hook "$H10"
assert "hosts claude only: hook links nothing into ~/.agents/skills" '[ ! -e "$H10/.agents/skills/new-skill" ]'
assert "hosts claude only: existing ai-kit link removed" '[ ! -L "$H10/.agents/skills/old-skill" ]'
assert "hosts claude only: foreign link stays" '[ -L "$H10/.agents/skills/foreign" ]'
assert "hosts claude only: foreign dir stays" '[ -d "$H10/.agents/skills/own-dir" ]'
HOME="$H10" bash "$V1/bin/bootstrap-project.sh" --minimal --no-agents --no-commands --no-rules --no-gh-workflow "$H10/proj" >/dev/null
assert "hosts claude only: bootstrap links nothing into ~/.agents/skills" '[ ! -e "$H10/.agents/skills/demo-skill" ]'
assert "hosts claude only: bootstrap keeps the project .cursor/skills" '[ -L "$H10/proj/.cursor/skills/demo-skill" ]'
rm -rf "$H10"

H11=$(mktemp -d)
mkdir -p "$H11/.copilot"
run_hook "$H11"
assert "no hosts file, only ~/.copilot: hook links ~/.agents/skills" '[ -L "$H11/.agents/skills/new-skill" ]'
rm -rf "$H11"
H12=$(mktemp -d)
mkdir -p "$H12/.copilot"
HOME="$H12" bash "$V1/bin/bootstrap-project.sh" --minimal --no-agents --no-commands --no-rules --no-gh-workflow "$H12/proj" >/dev/null
assert "no hosts file, only ~/.copilot: bootstrap links ~/.agents/skills" '[ -L "$H12/.agents/skills/demo-skill" ]'
rm -rf "$H12"
H13=$(mktemp -d)
mkdir -p "$H13/vscode.app"
AIKIT_VSCODE_APP="$H13/vscode.app" run_hook "$H13"
assert "no hosts file, VS Code installed: hook links ~/.agents/skills" '[ -L "$H13/.agents/skills/new-skill" ]'
rm -rf "$H13"

print_summary_and_exit
