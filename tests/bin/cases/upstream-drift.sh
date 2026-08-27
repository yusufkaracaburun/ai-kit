#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== upstream-drift ==="
# section: upstream-drift

# --- the shipped manifest itself -------------------------------------------
# A pin that goes empty is the failure this whole feature exists to prevent:
# the drift check silently stops checking that source.
assert "vendored.json is valid JSON" \
  'python3 -c "import json;json.load(open(\"$AIKIT/standards/external/vendored.json\"))"'
assert "every source has a 40-hex pinned_sha, repo and paths" '
python3 - <<PY
import json, re, sys
d = json.load(open("'"$AIKIT"'/standards/external/vendored.json"))
srcs = d.get("sources", [])
assert srcs, "no sources"
for s in srcs:
    assert re.fullmatch(r"[0-9a-f]{40}", s.get("pinned_sha","")), s.get("name")
    assert s.get("repo","").startswith("http"), s.get("name")
    assert s.get("paths"), s.get("name")
    assert s.get("local_deltas"), s.get("name")
PY'
# A vendored file that carries its own provenance frontmatter (the external
# rules do) records the pin twice. Two records of the same fact drift — which
# is the exact failure this whole feature exists to catch.
assert "frontmatter pinned_sha matches the manifest pin" '
python3 - <<PY
import json, os, re
root = "'"$AIKIT"'"
for s in json.load(open(root + "/standards/external/vendored.json"))["sources"]:
    for rel in s["paths"]:
        f = os.path.join(root, rel)
        if not os.path.isfile(f) or not f.endswith(".md"):
            continue
        head = open(f, encoding="utf-8").read(2000)
        m = re.search(r"^pinned_sha:\s*([0-9a-f]{40})\s*$", head, re.M)
        if m:
            assert m.group(1) == s["pinned_sha"], (rel, m.group(1), s["pinned_sha"])
PY'

assert "vendored paths actually exist on disk" '
python3 - <<PY
import json, os
root = "'"$AIKIT"'"
for s in json.load(open(root + "/standards/external/vendored.json"))["sources"]:
    for p in s["paths"]:
        assert os.path.exists(os.path.join(root, p)), p
PY'

# --- behaviour, driven off a local file:// upstream (no network) ------------
T=$(mktemp -d)
mkdir -p "$T/bin" "$T/standards/external"
cp "$AIKIT/bin/ai-kit-upstream-drift.sh" "$T/bin/"

UP="$T/up"
git -c init.defaultBranch=main init --quiet "$UP"
git -C "$UP" -c user.email=t@t -c user.name=t commit --quiet --allow-empty -m one
SHA1="$(git -C "$UP" rev-parse HEAD)"

write_manifest() {
  cat > "$T/standards/external/vendored.json" <<JSON
{"_meta":{"title":"t"},"sources":[{"name":"local","repo":"$1","ref":"HEAD",
 "pinned_sha":"$2","vendored_at":"2026-01-01","paths":["x"],"local_deltas":"none"}]}
JSON
}

write_manifest "$UP" "$SHA1"
OUT="$("$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?
assert "pin matches remote -> OK"        '[ "$RC" = "0" ]'
assert "pin matches remote -> reports current" 'grep -q "^OK local" <<< "$OUT"'
assert "clean run counts 1 current"      'grep -q "1 current, 0 moved" <<< "$OUT"'

git -C "$UP" -c user.email=t@t -c user.name=t commit --quiet --allow-empty -m two
SHA2="$(git -C "$UP" rev-parse HEAD)"
OUT="$("$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?
assert "upstream moved -> still exit 0 (report-only)" '[ "$RC" = "0" ]'
assert "upstream moved -> flags the source"  'grep -q "^-> local" <<< "$OUT"'
assert "upstream moved -> prints compare URL" 'grep -q "compare/'"$SHA1"'...'"$SHA2"'" <<< "$OUT"'
assert "upstream moved -> points at local_deltas" 'grep -q "local_deltas" <<< "$OUT"'

set +e; "$T/bin/ai-kit-upstream-drift.sh" --strict >/dev/null 2>&1; RC_STRICT=$?; set -e
assert "--strict exits 1 on drift" '[ "$RC_STRICT" = "1" ]'

write_manifest "$T/does-not-exist" "$SHA1"
OUT="$("$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?
assert "unreachable upstream -> exit 0, never a build break" '[ "$RC" = "0" ]'
assert "unreachable upstream -> counted as unchecked" 'grep -q "0 current, 0 moved, 1 unchecked" <<< "$OUT"'

rm -rf "$T"

# --- hygiene guard ----------------------------------------------------------
# Consumer projects vendor nothing; the section must stay silent there.
TP=$(mktemp -d)
OUT="$("$AIKIT/bin/ai-kit-hygiene.sh" "$TP" --skip-doctor --skip-dedupe --skip-symmetry \
        --skip-memory --skip-repo-skills --skip-context-lean --skip-secrets-gate 2>&1 || true)"
assert "hygiene skips upstream-drift without vendored.json" '! grep -q "upstream-drift" <<< "$OUT"'
mkdir -p "$TP/standards/external"
cp "$AIKIT/standards/external/vendored.json" "$TP/standards/external/"
OUT="$("$AIKIT/bin/ai-kit-hygiene.sh" "$TP" --skip-doctor --skip-dedupe --skip-symmetry \
        --skip-memory --skip-repo-skills --skip-context-lean --skip-secrets-gate 2>&1 || true)"
assert "hygiene runs upstream-drift when vendored.json present" 'grep -q "upstream-drift" <<< "$OUT"'
rm -rf "$TP"

print_summary_and_exit
