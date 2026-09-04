#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #114 (naschool comment): "verify-setup.sh --strict reports 19/19 green
# while every link is pinned" — presence-only checking makes a project whose
# skill links are pinned directly into a version-numbered plugin cache path
# (rather than through the plugin-current indirection, #114 slice A) look
# perfectly healthy right up until a cache GC bricks all of them at once,
# with zero prior warning. --strict now also flags any such link.

# shellcheck source=../../../bin/lib/ai-kit-root.sh
source "$AIKIT/bin/lib/ai-kit-root.sh"

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT

make_fake_version() {
  local version="$1"
  local root="$H/plugins/cache/mkt/ai/$version"
  mkdir -p "$root/bin" "$root/workflow/skills/demo-skill" "$root/workflow/agents" "$root/workflow/commands"
  cp -R "$AIKIT/bin/." "$root/bin/"
  ln -sfn "$AIKIT/context" "$root/context"
  printf '%s\n' "$version" > "$root/VERSION"
  printf '# demo-skill\n' > "$root/workflow/skills/demo-skill/SKILL.md"
  echo "$root"
}

write_marker() {
  local target="$1" version="$2"
  printf '{\n  "ai_kit_version": "%s",\n  "completed_at": "2026-01-01T00:00:00Z",\n  "branches": {"setup_mode": "solo-both"}\n}\n' \
    "$version" > "$target/.ai-kit-setup"
}

V1="$(make_fake_version 1.0.0)"
P="$H/proj"
HOME="$H" bash "$V1/bin/bootstrap-project.sh" --minimal --no-agents --no-commands --no-rules --no-gh-workflow "$P" >/dev/null
write_marker "$P" "1.0.0"

echo "=== a project bootstrapped through plugin-current is clean under --strict ==="
OUT_CLEAN="$(HOME="$H" bash "$V1/bin/verify-setup.sh" "$P" --strict --minimal 2>&1)" || true
assert "no stale-link failure reported" '! echo "$OUT_CLEAN" | grep -qi "version-pinned"'

echo "=== a legacy link pinned straight into the version dir is caught ==="
ln -sfn "$V1/workflow/skills/demo-skill" "$P/.claude/skills/demo-skill"
OUT_STALE="$(HOME="$H" bash "$V1/bin/verify-setup.sh" "$P" --strict --minimal 2>&1)" || true
assert "stale-link failure reported" 'echo "$OUT_STALE" | grep -qi "version-pinned"'

echo "=== repairing via /ai:upgrade clears the finding ==="
V2="$(make_fake_version 1.0.1)"
HOME="$H" bash "$V2/bin/ai-kit-upgrade.sh" "$P" >/dev/null
OUT_FIXED="$(HOME="$H" bash "$V2/bin/verify-setup.sh" "$P" --strict --minimal 2>&1)" || true
assert "clean again after repair" '! echo "$OUT_FIXED" | grep -qi "version-pinned"'

print_summary_and_exit
