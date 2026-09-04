#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# #114: bootstrap-project.sh links project skills/agents/commands straight into
# the version-pinned plugin cache path (~/.claude/plugins/cache/.../ai/1.43.1).
# The next `/plugin update` deletes that directory and every project link
# bricks at once. Fix: when ai-kit resolves through the plugin cache,
# resolve_ai_kit_root refreshes a stable symlink
# (~/.config/ai-kit/plugin-current) at every ai-kit invocation, and
# bootstrap-project.sh routes project links through it instead of the
# version-pinned path — one repoint heals every project, no bootstrap re-run
# needed.

# shellcheck source=../../../bin/lib/ai-kit-root.sh
source "$AIKIT/bin/lib/ai-kit-root.sh"

H=$(mktemp -d)
trap 'rm -rf "$H"' EXIT

# A fake plugin cache tree: same shape as
# ~/.claude/plugins/cache/<marketplace>/ai/<version>/, with a real workflow/
# tree underneath so bootstrap-project.sh has skills/agents/commands to link.
make_fake_version() {
  local version="$1" marker="$2"
  local root="$H/plugins/cache/mkt/ai/$version"
  mkdir -p "$root/bin" "$root/workflow/skills/demo-skill"
  cp -R "$AIKIT/bin/." "$root/bin/"
  ln -sfn "$AIKIT/context" "$root/context"
  printf '%s\n' "$version" > "$root/VERSION"
  printf '# demo-skill (%s)\n' "$marker" > "$root/workflow/skills/demo-skill/SKILL.md"
  echo "$root"
}

echo "=== resolve_ai_kit_root refreshes plugin-current on plugin-cache resolution ==="
V1="$(make_fake_version 1.0.0 v1)"
unset AI_KIT_ROOT
RESOLVED_1="$(HOME="$H" bash -c "source '$AIKIT/bin/lib/ai-kit-root.sh'; resolve_ai_kit_root '$V1/bin'")"
assert "resolves to the fake version root" '[ "$RESOLVED_1" = "$V1" ]'
assert "plugin-current link created" '[ -L "$H/.config/ai-kit/plugin-current" ]'
assert "plugin-current points at the resolved version" \
  '[ "$(cd "$H/.config/ai-kit/plugin-current" && pwd -P)" = "$(cd "$V1" && pwd -P)" ]'

echo "=== a later invocation from a newer version repoints it ==="
V2="$(make_fake_version 1.0.1 v2)"
HOME="$H" bash -c "source '$AIKIT/bin/lib/ai-kit-root.sh'; resolve_ai_kit_root '$V2/bin'" >/dev/null
assert "plugin-current now points at the newer version" \
  '[ "$(cd "$H/.config/ai-kit/plugin-current" && pwd -P)" = "$(cd "$V2" && pwd -P)" ]'

echo "=== a dev-clone (non-plugin-cache) resolution never touches plugin-current ==="
rm -rf "$H/.config/ai-kit/plugin-current"
HOME="$H" bash -c "source '$AIKIT/bin/lib/ai-kit-root.sh'; resolve_ai_kit_root '$AIKIT/bin'" >/dev/null
assert "no plugin-current link created for a dev clone" '[ ! -e "$H/.config/ai-kit/plugin-current" ]'

echo "=== bootstrap-project.sh routes plugin-cache links through plugin-current ==="
V3="$(make_fake_version 2.0.0 v3)"
P="$H/proj"
HOME="$H" bash "$V3/bin/bootstrap-project.sh" --minimal --no-agents --no-commands --no-rules --no-gh-workflow "$P" >/dev/null
LINK_TARGET="$(readlink "$P/.claude/skills/demo-skill")"
assert "project skill link points through the stable plugin-current path" \
  'case "$LINK_TARGET" in "$H/.config/ai-kit/plugin-current/"*) true ;; *) false ;; esac'
assert "project skill link does NOT pin the version-numbered cache path" \
  'case "$LINK_TARGET" in *"/2.0.0/"*) false ;; *) true ;; esac'
assert "the link still resolves to real content" \
  'grep -q "v3" "$P/.claude/skills/demo-skill/SKILL.md"'

echo "=== an upgrade heals every existing project link without re-running bootstrap ==="
V4="$(make_fake_version 2.0.1 v4)"
# Simulate the cache GC that bricked emeq/naschool: the version bootstrap
# linked through is gone.
rm -rf "$V3"
# Any subsequent ai-kit invocation from the new version — here, running
# doctor — repoints plugin-current; the project itself is never touched.
HOME="$H" bash "$V4/bin/ai-kit-doctor.sh" >/dev/null 2>&1 || true
assert "project skill link (never touched) now resolves again" \
  '[ -e "$P/.claude/skills/demo-skill/SKILL.md" ]'
assert "it resolves to the NEW version's content" \
  'grep -q "v4" "$P/.claude/skills/demo-skill/SKILL.md"'

print_summary_and_exit
