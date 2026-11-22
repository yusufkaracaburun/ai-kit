#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=== setup-gh-workflow-board-json ==="
# section: setup-gh-workflow-board-json
mkdir -p "$TMP/stub-bin" "$TMP/project"
( cd "$TMP/project" && git init -q && git remote add origin git@github.com:acme/demo.git )
# $1 = ok|fail for gh project list
stub_gh() {
  cat > "$TMP/stub-bin/gh" <<STUB
#!/usr/bin/env bash
case "\$*" in
  *"auth status"*) exit 0 ;;
  *"project list"*)
    if [ "$1" = fail ]; then
      echo "HTTP 401: Bad credentials (https://api.github.com/graphql)" >&2
      echo "second line" >&2
      exit 1
    fi
    cat <<'JSON'
{"projects":[{"number":7,"title":"demo board ''' with a \\\\ backslash"}]}
JSON
    ;;
  *"api graphql"*)
    cat <<'JSON'
{"data":{"user":{"projectV2":{"id":"PVT_7","field":{"id":"F1","options":[{"id":"O1","name":"Todo"},{"id":"O2","name":"Ready"}]}}}}}
JSON
    ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$TMP/stub-bin/gh"
}
setup_run() {
  PATH="$TMP/stub-bin:$PATH" bash "$AIKIT/bin/setup-gh-workflow.sh" "$TMP/project" \
    --dry-run --no-labels --no-protection --no-pr-template 2>&1 || true
}

stub_gh ok
assert "stub title carries ''' and a backslash" \
  '"$TMP/stub-bin/gh" project list | python3 -c "import json,sys; t=json.load(sys.stdin)[\"projects\"][0][\"title\"]; sys.exit(0 if chr(39)*3 in t and chr(92) in t else 1)"'
OUT="$(setup_run)"
assert "board JSON with ''' and a backslash parses" 'echo "$OUT" | grep -q "found project #7"'
assert "Status field resolves" 'echo "$OUT" | grep -q "STATUS_FIELD_ID=F1 READY=O2 TODO=O1"'

stub_gh fail
OUT="$(setup_run)"
assert "gh error shows gh's first stderr line" 'echo "$OUT" | grep -qF "HTTP 401: Bad credentials"'
assert "gh error does not print gh's later lines" '! echo "$OUT" | grep -q "second line"'
assert "gh error is not reported as no board" '! echo "$OUT" | grep -q "no existing project board"'

print_summary_and_exit
