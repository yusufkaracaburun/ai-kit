#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=== auto-promote-priority ==="
# section: auto-promote-priority
# Runs the workflow's github-script body under node with stubbed github and
# context objects, so the DoR priority check is tested as shipped.
WORKFLOW="$AIKIT/context/templates/github/workflows/auto-promote-ready.yml"
sed -n '/^          script: |$/,$p' "$WORKFLOW" | sed '1d; s/^            //' > "$TMP/script.js"

# $1 = labels (JSON array), $2 = field|none|error
run_promote() {
  LABELS="$1" FIELD_MODE="$2" SCRIPT_JS="$TMP/script.js" node -e '
const fs = require("fs");
const body = "## Definition of Ready\n- [x] done\n";
const context = {
  payload: { issue: { number: 7, body, labels: JSON.parse(process.env.LABELS).map(name => ({ name })) } },
  repo: { owner: "acme", repo: "demo" },
};
const github = {
  graphql: async (q) => {
    if (q.includes("issueFieldValues")) {
      if (process.env.FIELD_MODE === "error") throw new Error("Field unknown");
      const nodes = process.env.FIELD_MODE === "field" ? [{ name: "High", field: { name: "Priority" } }] : [];
      return { repository: { issue: { issueFieldValues: { nodes } } } };
    }
    if (q.includes("mutation")) return {};
    return { user: { projectV2: { id: "P1", items: { nodes: [{ id: "I1", content: { number: 7 }, fieldValueByName: { name: "Todo" } }] } } } };
  },
  rest: { issues: { createComment: async () => ({}) } },
};
const fn = new (Object.getPrototypeOf(async function(){}).constructor)("github", "context", fs.readFileSync(process.env.SCRIPT_JS, "utf8"));
fn(github, context).catch(e => { console.log("THREW " + e.message); process.exit(1); });
' 2>&1
}

if ! command -v node >/dev/null 2>&1; then
  echo "  SKIP: auto-promote script tests (node not installed)"
else
  OUT="$(run_promote '["epic/core","area/docs"]' field)"
  assert "Priority field without P label promotes" 'echo "$OUT" | grep -q "promoted Todo"'
  OUT="$(run_promote '["P2-medium","epic/core","area/docs"]' none)"
  assert "P label without Priority field promotes" 'echo "$OUT" | grep -q "promoted Todo"'
  OUT="$(run_promote '["area/docs"]' field)"
  assert "card without an epic label promotes" 'echo "$OUT" | grep -q "promoted Todo"'
  OUT="$(run_promote '["epic/core"]' field)"
  assert "card without an area label blocks" 'echo "$OUT" | grep -q "area=false" && ! echo "$OUT" | grep -q "promoted Todo"'
  OUT="$(run_promote '["epic/core","area/docs"]' none)"
  assert "neither field nor P label blocks" 'echo "$OUT" | grep -q "priority=false" && ! echo "$OUT" | grep -q "promoted Todo"'
  OUT="$(run_promote '["P1-high","epic/core","area/docs"]' error)"
  assert "field read failure falls back to the P label" 'echo "$OUT" | grep -q "promoted Todo"'
  OUT="$(run_promote '["epic/core","area/docs"]' error)"
  assert "field read failure without P label blocks" 'echo "$OUT" | grep -q "priority=false"'
fi

echo "=== setup-gh-workflow-board-labels ==="
# section: setup-gh-workflow-board-labels
mkdir -p "$TMP/stub-bin" "$TMP/project"
( cd "$TMP/project" && git init -q && git remote add origin git@github.com:acme/demo.git )
# $1 = number of project items the open issues report, or v2 for a board
# that shows only in projectsV2 (owned by another owner than the repo).
stub_gh() {
  cat > "$TMP/stub-bin/gh" <<STUB
#!/usr/bin/env bash
case "\$*" in
  *"auth status --hostname github.com"*) exit 0 ;;
  *"auth status"*) exit 1 ;;
  *"api graphql"*"projectItems"*)
    if [ "$1" = v2 ]; then
      echo '{"data":{"repository":{"issues":{"nodes":[{"projectItems":{"nodes":[]},"projectsV2":{"nodes":[{"id":"PVT_2"}]}}]}}}}'
    elif [ "$1" -gt 0 ]; then
      echo '{"data":{"repository":{"issues":{"nodes":[{"projectItems":{"nodes":[{"project":{"id":"PVT_1"}}]}}]}}}}'
    else
      echo '{"data":{"repository":{"issues":{"nodes":[{"projectItems":{"nodes":[]}}]}}}}'
    fi ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$TMP/stub-bin/gh"
}
setup_run() {
  PATH="$TMP/stub-bin:$PATH" bash "$AIKIT/bin/setup-gh-workflow.sh" "$TMP/project" \
    --dry-run --no-project --no-protection --no-pr-template 2>&1 || true
}

stub_gh 1
OUT="$(setup_run)"
assert "board: P labels not seeded" '! echo "$OUT" | grep -q "label: P0-critical"'
assert "board: status:in-progress not seeded" '! echo "$OUT" | grep -q "label: status:in-progress"'
assert "board: other labels still seeded" 'echo "$OUT" | grep -q "label: ready-for-agent"'
assert "board: one line says why" '[ "$(echo "$OUT" | grep -c "board found")" -eq 1 ]'

stub_gh v2
OUT="$(setup_run)"
assert "board via projectsV2 only: P labels not seeded" '! echo "$OUT" | grep -q "label: P0-critical"'

stub_gh 0
OUT="$(setup_run)"
assert "no board: P labels seeded" 'echo "$OUT" | grep -q "label: P0-critical"'
assert "no board: status:in-progress seeded" 'echo "$OUT" | grep -q "label: status:in-progress"'

print_summary_and_exit
