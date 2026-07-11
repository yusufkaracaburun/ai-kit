#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

FRESH="$AIKIT/bin/ai-kit-docs-sync-graph-fresh.sh"
SYNC="$AIKIT/bin/ai-kit-docs-sync.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/aikit-graph-fresh.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# Build a git repo with a graphify-out/graph.json stamped at a chosen commit.
# $1 = repo dir, $2 = built_at_commit value (empty → key omitted)
make_repo() {
  local dir="$1" sha="$2"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t.t
  git -C "$dir" config user.name t
  echo one > "$dir/a.txt"
  git -C "$dir" add -A
  git -C "$dir" commit -qm one
}

stamp_graph() {
  local dir="$1" sha="$2"
  mkdir -p "$dir/graphify-out"
  if [ -z "$sha" ]; then
    echo '{"nodes": []}' > "$dir/graphify-out/graph.json"
  else
    printf '{"nodes": [], "built_at_commit": "%s"}\n' "$sha" > "$dir/graphify-out/graph.json"
  fi
}

echo "=== ai-kit-docs-sync-graph-fresh: graphify staleness ==="
# section: ai-kit-docs-sync-graph-fresh

# No graphify-out/ → silent skip, exit 0. Most projects have no graph.
mkdir -p "$TMP/nograph"
OUT_NONE="$("$FRESH" "$TMP/nograph" 2>&1)"; RC_NONE=$?
assert "graph-fresh exits 0 with no graphify-out/" '[ "$RC_NONE" -eq 0 ]'
assert "graph-fresh reports skip with no graph" 'echo "$OUT_NONE" | grep -q "no graphify-out/graph.json — skipped"'

# Graph present, HEAD == built_at_commit → current, exit 0.
make_repo "$TMP/current" ""
CUR_SHA="$(git -C "$TMP/current" rev-parse HEAD)"
stamp_graph "$TMP/current" "$CUR_SHA"
OUT_CUR="$("$FRESH" "$TMP/current" 2>&1)"; RC_CUR=$?
assert "graph-fresh exits 0 when graph is at HEAD" '[ "$RC_CUR" -eq 0 ]'
assert "graph-fresh reports current" 'echo "$OUT_CUR" | grep -q "graph current at"'

# Graph behind HEAD with real file changes → warn, exit 1, counts + fix hint.
make_repo "$TMP/stale" ""
STALE_SHA="$(git -C "$TMP/stale" rev-parse HEAD)"
stamp_graph "$TMP/stale" "$STALE_SHA"
echo two > "$TMP/stale/b.txt"
git -C "$TMP/stale" add -A
git -C "$TMP/stale" commit -qm two
OUT_STALE="$("$FRESH" "$TMP/stale" 2>&1)" && RC_STALE=0 || RC_STALE=$?
assert "graph-fresh exits 1 when graph is behind HEAD" '[ "$RC_STALE" -eq 1 ]'
assert "graph-fresh warns graph is stale" 'echo "$OUT_STALE" | grep -q "WARN: graph is stale"'
assert "graph-fresh reports changed-file count" 'echo "$OUT_STALE" | grep -q "1 file(s) changed, 1 commit(s) behind"'
assert "graph-fresh suggests graphify update" 'echo "$OUT_STALE" | grep -q "graphify update \."'

# Commits since the graph but no file changes (empty commit) → still accurate, exit 0.
make_repo "$TMP/nodiff" ""
NODIFF_SHA="$(git -C "$TMP/nodiff" rev-parse HEAD)"
stamp_graph "$TMP/nodiff" "$NODIFF_SHA"
git -C "$TMP/nodiff" commit -q --allow-empty -m empty
OUT_NODIFF="$("$FRESH" "$TMP/nodiff" 2>&1)"; RC_NODIFF=$?
assert "graph-fresh exits 0 when commits changed no files" '[ "$RC_NODIFF" -eq 0 ]'
assert "graph-fresh reports graph still accurate" 'echo "$OUT_NODIFF" | grep -q "graph still accurate"'

# built_at_commit unreachable (rebased/squashed away) → warn, exit 1.
make_repo "$TMP/rebased" ""
stamp_graph "$TMP/rebased" "0000000000000000000000000000000000000000"
OUT_REB="$("$FRESH" "$TMP/rebased" 2>&1)" && RC_REB=0 || RC_REB=$?
assert "graph-fresh exits 1 on unreachable built_at_commit" '[ "$RC_REB" -eq 1 ]'
assert "graph-fresh names the rebase/squash case" 'echo "$OUT_REB" | grep -q "rebased or squashed away"'

# graph.json without built_at_commit → drift not computable, warn, exit 1.
make_repo "$TMP/nostamp" ""
stamp_graph "$TMP/nostamp" ""
OUT_NOSTAMP="$("$FRESH" "$TMP/nostamp" 2>&1)" && RC_NOSTAMP=0 || RC_NOSTAMP=$?
assert "graph-fresh exits 1 when built_at_commit is absent" '[ "$RC_NOSTAMP" -eq 1 ]'
assert "graph-fresh says drift not computable" 'echo "$OUT_NOSTAMP" | grep -q "no built_at_commit"'

# Graph present but not a git repo → drift not computable, skip cleanly.
mkdir -p "$TMP/nogit"
stamp_graph "$TMP/nogit" "deadbeef"
OUT_NOGIT="$("$FRESH" "$TMP/nogit" 2>&1)"; RC_NOGIT=$?
assert "graph-fresh exits 0 outside a git repo" '[ "$RC_NOGIT" -eq 0 ]'
assert "graph-fresh reports not-a-git-repo skip" 'echo "$OUT_NOGIT" | grep -q "not a git repo"'

echo ""
echo "=== docs-sync integration: graph-fresh section ==="
# section: ai-kit-docs-sync-graph-fresh-integration

OUT_SYNC="$("$SYNC" "$TMP/stale" --skip-dead-links --skip-repo-hygiene --skip-finished-work 2>&1)" || true
assert "docs-sync runs graph-fresh section" 'echo "$OUT_SYNC" | grep -q "=== graph-fresh"'
assert "docs-sync surfaces the stale graph" 'echo "$OUT_SYNC" | grep -q "WARN: graph is stale"'
assert "docs-sync reports findings on stale graph" 'echo "$OUT_SYNC" | grep -q "docs-sync: findings reported"'

OUT_SKIP="$("$SYNC" "$TMP/stale" --skip-dead-links --skip-repo-hygiene --skip-finished-work --skip-graph-fresh 2>&1)"
assert "docs-sync honours --skip-graph-fresh" '! echo "$OUT_SKIP" | grep -q "=== graph-fresh"'
assert "docs-sync clean when graph-fresh skipped" 'echo "$OUT_SKIP" | grep -q "docs-sync: all sections clean"'

print_summary_and_exit
