#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== ai-kit-next: help + empty repo ==="
OUT_HELP="$("$AIKIT/bin/ai-kit-next.sh" --help 2>&1)"
assert "next: help mentions sources" 'echo "$OUT_HELP" | grep -q "gh issue list"'
assert "next: help mentions --limit" 'echo "$OUT_HELP" | grep -q -- "--limit"'

# Empty dir — no GH remote, no roadmap, no marker.
TMP_EMPTY=$(mktemp -d)
OUT_EMPTY="$("$AIKIT/bin/ai-kit-next.sh" "$TMP_EMPTY" --no-gh 2>&1)"
assert "next: empty repo says nothing open" 'echo "$OUT_EMPTY" | grep -q "nothing open"'
rm -rf "$TMP_EMPTY"

echo ""
echo "=== ai-kit-next: roadmap parsing ==="
TMP_RM=$(mktemp -d)
mkdir -p "$TMP_RM/docs"
cat > "$TMP_RM/docs/roadmap.md" <<'EOF'
# Roadmap

## 1. Section header (must be ignored)

> Block quote bullet should also be ignored.

**Bold prose** with - dashes in it.

- This is a free bullet — must NOT count as a task.
- [x] Closed task — must NOT count.
- [ ] OPEN TASK ONE — should count (P1).
- [ ] Open task two without priority hint.
- [ ] Refers to existing GH #999 — should be deduped against gh list.

```
- [ ] Inside code fence — must NOT count.
```

- [ ] After code fence — should count.
EOF
OUT_RM="$("$AIKIT/bin/ai-kit-next.sh" "$TMP_RM" --no-gh --json 2>&1)"
ROADMAP_COUNT="$(echo "$OUT_RM" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for x in d['items'] if x['kind']=='roadmap'))")"
assert "next: counts exactly 4 open roadmap tasks (skips closed + prose + code + fence)" '[ "$ROADMAP_COUNT" -eq 4 ]'
assert "next: picks up P-hint from task" 'echo "$OUT_RM" | grep -q "\"priority\": \"P1\""'
assert "next: open task one surfaced" 'echo "$OUT_RM" | grep -q "OPEN TASK ONE"'
assert "next: closed task suppressed" '! echo "$OUT_RM" | grep -q "Closed task"'
assert "next: free bullet suppressed" '! echo "$OUT_RM" | grep -q "free bullet"'
rm -rf "$TMP_RM"

echo ""
echo "=== ai-kit-next: setup-marker deferred branches ==="
TMP_MK=$(mktemp -d)
cat > "$TMP_MK/.ai-kit-setup" <<'JSON'
{
  "ai_kit_version": "3.1.0",
  "branches": {
    "setup_mode": "solo-both",
    "automation_recommender": "deferred",
    "rule_recommendation": "deferred",
    "architecture": "documented"
  }
}
JSON
OUT_MK="$("$AIKIT/bin/ai-kit-next.sh" "$TMP_MK" --no-gh --json 2>&1)"
DEFERRED_COUNT="$(echo "$OUT_MK" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for x in d['items'] if x['kind']=='deferred'))")"
assert "next: 2 deferred branches surfaced" '[ "$DEFERRED_COUNT" -eq 2 ]'
assert "next: automation_recommender surfaced" 'echo "$OUT_MK" | grep -q "automation_recommender"'
assert "next: documented branch NOT surfaced" '! echo "$OUT_MK" | grep -q "Setup branch: architecture"'
rm -rf "$TMP_MK"

echo ""
echo "=== ai-kit-next: GH JSON scoring (stubbed) ==="
TMP_GH=$(mktemp -d)
mkdir -p "$TMP_GH/stubs"
cat > "$TMP_GH/stubs/gh" <<'STUB'
#!/usr/bin/env bash
# Stub gh CLI returning two issues with different priorities + flags.
cat <<'JSON'
[
  {"number": 1, "title": "Critical bug", "labels": [{"name":"P0-critical"},{"name":"status:in-progress"}], "updatedAt": "2026-05-23T10:00:00Z", "url": "https://github.com/x/y/issues/1", "assignees": []},
  {"number": 2, "title": "Nice to have", "labels": [{"name":"P3-low"}], "updatedAt": "2026-05-20T10:00:00Z", "url": "https://github.com/x/y/issues/2", "assignees": []},
  {"number": 3, "title": "Queue ready", "labels": [{"name":"P2-medium"},{"name":"ready-for-agent"}], "updatedAt": "2026-05-22T10:00:00Z", "url": "https://github.com/x/y/issues/3", "assignees": []}
]
JSON
STUB
chmod +x "$TMP_GH/stubs/gh"
# Init a git repo so the ranker recognises the dir as a git working tree.
(cd "$TMP_GH" && git init -q && git remote add origin git@github.com:x/y.git)
OUT_GH="$(PATH="$TMP_GH/stubs:$PATH" "$AIKIT/bin/ai-kit-next.sh" "$TMP_GH" --no-roadmap 2>&1)"
assert "next: P0 in-progress ranks first" 'echo "$OUT_GH" | grep -A1 "^   1\." | grep -q "Critical bug"'
assert "next: P2 ready-for-agent ranks second" 'echo "$OUT_GH" | grep -A1 "^   2\." | grep -q "Queue ready"'
assert "next: P3 ranks last" 'echo "$OUT_GH" | grep -A1 "^   3\." | grep -q "Nice to have"'
rm -rf "$TMP_GH"

print_summary_and_exit
