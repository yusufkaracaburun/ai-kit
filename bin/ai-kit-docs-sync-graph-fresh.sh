#!/usr/bin/env bash
# Detect a stale graphify knowledge graph.
#
# graphify stamps the commit it indexed into graphify-out/graph.json as
# `built_at_commit`. Nothing read it — so a graph could fall behind HEAD
# silently while CLAUDE.md and the search-delegation hook keep routing the
# agent to it. An agent trusting a stale graph is worse than one grepping:
# it gets a confident answer about code that moved.
#
# Exit codes:
#   0 — graph current, or no graphify-out/ (skip), or not a git repo (skip)
#   1 — graph behind HEAD
#   2 — error (project path missing)
#
# Report-only. Never runs `graphify update` — that is the user's call.
set -uo pipefail

PROJECT_PATH=""

for arg in "$@"; do
  case "$arg" in
    # Accepted for aggregator parity; this check never prompts.
    --no-prompt) ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *)  PROJECT_PATH="$arg" ;;
  esac
done

PROJECT_PATH="${PROJECT_PATH:-$PWD}"
if [ ! -d "$PROJECT_PATH" ]; then
  echo "graph-fresh: project path does not exist: $PROJECT_PATH" >&2
  exit 2
fi
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

GRAPH="$PROJECT_PATH/graphify-out/graph.json"
if [ ! -f "$GRAPH" ]; then
  echo "graph-fresh: no graphify-out/graph.json — skipped."
  exit 0
fi

if ! git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1; then
  echo "graph-fresh: not a git repo — drift is not computable, skipped."
  exit 0
fi

built_at="$(python3 -c "
import json, sys
try:
    print(json.load(open('$GRAPH')).get('built_at_commit', '') or '')
except Exception:
    sys.exit(0)
" 2>/dev/null)"

if [ -z "$built_at" ]; then
  echo "WARN: graph.json has no built_at_commit — drift is not computable."
  echo "Fix: rebuild with \`graphify .\` so future runs can detect staleness."
  exit 1
fi

# A rebase, squash-merge, or branch switch can leave built_at_commit
# unreachable. The graph is then anchored to history that no longer exists.
if ! git -C "$PROJECT_PATH" cat-file -e "${built_at}^{commit}" 2>/dev/null; then
  echo "WARN: graph built at ${built_at:0:7} — commit not in this repo's history (rebased or squashed away)."
  echo "Fix: \`graphify update .\` (AST-only, no API cost)."
  exit 1
fi

head_sha="$(git -C "$PROJECT_PATH" rev-parse HEAD)"
if [ "$built_at" = "$head_sha" ]; then
  echo "graph-fresh: graph current at ${head_sha:0:7}."
  exit 0
fi

# graphify-out/ is the graph's own output — a change there is not code drift.
changed="$(git -C "$PROJECT_PATH" diff --name-only "$built_at" HEAD -- . ':(exclude)graphify-out' 2>/dev/null | grep -cv '^$' || true)"
commits="$(git -C "$PROJECT_PATH" rev-list --count "$built_at".."$head_sha" 2>/dev/null || echo 0)"

if [ "${changed:-0}" -eq 0 ]; then
  echo "graph-fresh: graph at ${built_at:0:7}, HEAD ${head_sha:0:7} — no file changes between them, graph still accurate."
  exit 0
fi

echo "WARN: graph is stale — built at ${built_at:0:7}, HEAD is ${head_sha:0:7} ($changed file(s) changed, $commits commit(s) behind)."
cat <<'HINT'
Fix: run `graphify update .` (AST-only, no API cost).
A stale graph is worse than none: CLAUDE.md and the search-delegation hook
route the agent to `graphify query` instead of grep, so it answers from a map
of code that has already moved.
HINT
exit 1
