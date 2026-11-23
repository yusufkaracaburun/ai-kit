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

assert "every pinned .md under standards/rules/external is registered in the manifest" '
python3 - <<PY
import glob, json, os, re
root = "'"$AIKIT"'"
claimed = set()
for s in json.load(open(root + "/standards/external/vendored.json"))["sources"]:
    claimed.update(os.path.normpath(p) for p in s["paths"])
for f in glob.glob(root + "/standards/rules/external/*.md"):
    if not re.search(r"^pinned_sha:", open(f, encoding="utf-8").read(2000), re.M):
        continue
    rel = os.path.relpath(f, root)
    assert rel in claimed, rel
PY'

assert "vendored paths actually exist on disk" '
python3 - <<PY
import json, os
root = "'"$AIKIT"'"
for s in json.load(open(root + "/standards/external/vendored.json"))["sources"]:
    for p in s["paths"]:
        assert os.path.exists(os.path.join(root, p)), p
PY'

assert "distilled: pin is 40-hex and every skills entry has exactly one of ai_kit/skip" '
python3 - <<PY
import json, os, re
root = "'"$AIKIT"'"
dist = json.load(open(root + "/standards/external/vendored.json")).get("distilled", [])
assert dist, "no distilled"
for s in dist:
    assert re.fullmatch(r"[0-9a-f]{40}", s.get("pinned_sha", "")), s.get("name")
    assert s.get("skills"), s.get("name")
    for k, v in s["skills"].items():
        assert len(set(v) & {"ai_kit", "skip"}) == 1 and len(v) == 1, k
        if "ai_kit" in v:
            assert os.path.isfile(os.path.join(root, v["ai_kit"])), (k, v["ai_kit"])
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
set +e; OUT="$("$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?; set -e
assert "pin matches remote -> OK"        '[ "$RC" = "0" ]'
assert "pin matches remote -> reports current" 'grep -q "^OK local" <<< "$OUT"'
assert "clean run counts 1 current"      'grep -q "1 current, 0 moved" <<< "$OUT"'

git -C "$UP" -c user.email=t@t -c user.name=t commit --quiet --allow-empty -m two
SHA2="$(git -C "$UP" rev-parse HEAD)"
set +e; OUT="$("$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?; set -e
assert "upstream moved -> still exit 0 (report-only)" '[ "$RC" = "0" ]'
assert "upstream moved -> flags the source"  'grep -q "^-> local" <<< "$OUT"'
assert "upstream moved -> prints compare URL" 'grep -q "compare/'"$SHA1"'...'"$SHA2"'" <<< "$OUT"'
assert "upstream moved -> points at local_deltas" 'grep -q "local_deltas" <<< "$OUT"'

set +e; "$T/bin/ai-kit-upstream-drift.sh" --strict >/dev/null 2>&1; RC_STRICT=$?; set -e
assert "--strict exits 1 on drift" '[ "$RC_STRICT" = "1" ]'

# Argument injection: without `--`, git reads a repo starting with `-` as an
# option, and `--upload-pack=<cmd>` turns a manifest edit into command
# execution. Verified vulnerable before the fix.
PWN="$T/PWNED"
write_manifest "--upload-pack=touch $PWN; git-upload-pack" "$SHA1"
set +e; "$T/bin/ai-kit-upstream-drift.sh" >/dev/null 2>&1; RC=$?; set -e
assert "leading-dash repo cannot execute a command" '[ ! -e "$PWN" ]'
assert "leading-dash repo is reported, not fatal" '[ "$RC" = "0" ]'

# A tab in a field would split the row and silently drop a source from the
# check — the emitter must refuse rather than pass it through.
cat > "$T/standards/external/vendored.json" <<JSON
{"_meta":{"title":"t"},"sources":[{"name":"bad\tname","repo":"$UP","ref":"HEAD",
 "pinned_sha":"$SHA1","vendored_at":"2026-01-01","paths":["x"],"local_deltas":"n"}]}
JSON
set +e; OUT="$("$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?; set -e
assert "control character in a manifest field is refused" '[ "$RC" = "2" ]'
assert "control-character refusal says which field" 'grep -q "control character" <<< "$OUT"'

write_manifest "$T/does-not-exist" "$SHA1"
set +e; OUT="$("$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?; set -e
assert "unreachable upstream -> exit 0, never a build break" '[ "$RC" = "0" ]'
assert "unreachable upstream -> counted as unchecked" 'grep -q "0 current, 0 moved, 1 unchecked" <<< "$OUT"'

# --- distilled: release tracking against a file:// fixture API --------------
PIN="1111111111111111111111111111111111111111"
fixture_api() { # dir tag status
  mkdir -p "$1/repos/o/r/releases" "$1/repos/o/r/compare"
  printf '{"tag_name":"%s"}' "$2" > "$1/repos/o/r/releases/latest"
  cat > "$1/repos/o/r/compare/$PIN...$2" <<JSON
{"status":"$3","files":[
 {"filename":"skills/engineering/tdd/SKILL.md"},
 {"filename":"skills/misc/teach/SKILL.md"},
 {"filename":"skills/engineering/brand-new/SKILL.md"},
 {"filename":"README.md"}]}
JSON
}
fixture_api "$T/api-old" v1.0.0 behind
fixture_api "$T/api-new" v2.0.0 ahead
fixture_api "$T/api-same" v1.0.0 identical

cat > "$T/standards/external/vendored.json" <<JSON
{"_meta":{"title":"t"},"sources":[{"name":"local","repo":"$UP","ref":"HEAD",
 "pinned_sha":"$SHA2","vendored_at":"2026-01-01","paths":["x"],"local_deltas":"none"}],
 "distilled":[{"name":"o/r","repo":"https://github.com/o/r","pinned_sha":"$PIN",
  "pinned_release":"v1.0.0","track":"release","skills":{
   "engineering/tdd":{"ai_kit":"workflow/skills/tdd/SKILL.md"},
   "misc/teach":{"skip":"course authoring"}}}]}
JSON

set +e; OUT="$(AI_KIT_GITHUB_API="file://$T/api-old" "$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?; set -e
assert "distilled: tag behind pin -> exit 0" '[ "$RC" = "0" ]'
assert "distilled: tag behind pin -> OK line" 'grep -q "^OK o/r" <<< "$OUT"'
assert "distilled: current counts alongside sources" 'grep -q "2 current, 0 moved, 0 unchecked" <<< "$OUT"'
set +e; OUT="$(AI_KIT_GITHUB_API="file://$T/api-same" "$T/bin/ai-kit-upstream-drift.sh" --distilled-only 2>&1)"; set -e
assert "distilled: compare status identical -> current" 'grep -q "^OK o/r" <<< "$OUT"'

set +e; OUT="$(AI_KIT_GITHUB_API="file://$T/api-new" "$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?; set -e
assert "distilled: new release -> exit 0" '[ "$RC" = "0" ]'
assert "distilled: new release -> flagged with tag and pin" 'grep -q "^-> o/r .*new release v2.0.0 (pinned v1.0.0, 1111111)" <<< "$OUT"'
assert "distilled: new release -> compare URL" 'grep -q "https://github.com/o/r/compare/$PIN...v2.0.0" <<< "$OUT"'
assert "distilled: mapped skill -> sharpens" 'grep -q "skills/engineering/tdd/SKILL.md .*sharpens workflow/skills/tdd/SKILL.md" <<< "$OUT"'
assert "distilled: skipped skill -> skip reason" 'grep -q "skills/misc/teach/SKILL.md .*skip: course authoring" <<< "$OUT"'
assert "distilled: unmapped skill -> new skill" 'grep -q "skills/engineering/brand-new/SKILL.md .*new skill: park until an app needs it" <<< "$OUT"'
assert "distilled: non-SKILL.md files are not listed" '! grep -q "README.md" <<< "$OUT"'
assert "distilled: new release counts as moved" 'grep -q "1 current, 1 moved, 0 unchecked" <<< "$OUT"'

set +e; AI_KIT_GITHUB_API="file://$T/api-new" "$T/bin/ai-kit-upstream-drift.sh" --strict >/dev/null 2>&1; RC=$?; set -e
assert "distilled: --strict exits 1 on a new release" '[ "$RC" = "1" ]'

set +e; OUT="$(AI_KIT_GITHUB_API="file://$T/nope" "$T/bin/ai-kit-upstream-drift.sh" 2>&1)"; RC=$?; set -e
assert "distilled: unreachable API -> exit 0" '[ "$RC" = "0" ]'
assert "distilled: unreachable API -> unchecked" 'grep -q "^?? o/r" <<< "$OUT" && grep -q "1 current, 0 moved, 1 unchecked" <<< "$OUT"'

set +e; OUT="$(AI_KIT_GITHUB_API="file://$T/api-old" "$T/bin/ai-kit-upstream-drift.sh" --distilled-only 2>&1)"; RC=$?; set -e
assert "--distilled-only skips the sources rows" '! grep -q "local" <<< "$OUT" && grep -q "^OK o/r" <<< "$OUT"'

# --- SessionStart hook --------------------------------------------------------
HOOK="$AIKIT/bin/hooks/upstream-release-check.sh"
export XDG_CACHE_HOME="$T/cache"
NOREPO="$T/norepo"; mkdir -p "$NOREPO"; git init --quiet "$NOREPO"
set +e; OUT="$(cd "$NOREPO" && "$HOOK" </dev/null 2>&1)"; RC=$?; set -e
assert "hook: silent and exit 0 without the manifest" '[ "$RC" = "0" ] && [ -z "$OUT" ]'
set +e; OUT="$(cd "$T/api-new" && "$HOOK" </dev/null 2>&1)"; RC=$?; set -e
assert "hook: silent outside a git repo" '[ "$RC" = "0" ] && [ -z "$OUT" ]'

git init --quiet "$T"
OUT="$(cd "$T" && AI_KIT_GITHUB_API="file://$T/api-old" "$HOOK" </dev/null 2>&1 || true)"
assert "hook: silent when the release is current" '[ -z "$OUT" ]'
rm -rf "$XDG_CACHE_HOME"
set +e; OUT="$(cd "$T" && AI_KIT_GITHUB_API="file://$T/api-new" "$HOOK" </dev/null 2>&1)"; RC=$?; set -e
assert "hook: exit 0 on a new release" '[ "$RC" = "0" ]'
assert "hook: notice names the release and the merge pattern" 'grep -q "new mattpocock/skills release" <<< "$OUT" && grep -q "#297" <<< "$OUT" && grep -q "v2.0.0" <<< "$OUT"'
assert "hook: notice lists the classified skill" 'grep -q "sharpens workflow/skills/tdd/SKILL.md" <<< "$OUT"'
assert "hook: notice leaves out the sources rows" '! grep -q "local" <<< "$OUT"'
OUT2="$(cd "$T" && AI_KIT_GITHUB_API="file://$T/missing" "$HOOK" </dev/null 2>&1 || true)"
assert "hook: second run within 24 h is served from cache" '[ -n "$OUT2" ] && [ "$OUT2" = "$OUT" ]'

CACHE="$XDG_CACHE_HOME/ai-kit/upstream-release.txt"
touch -t 201901010000 "$T/standards/external/vendored.json"
touch -t 202001010000 "$CACHE"
OUT="$(cd "$T" && AI_KIT_GITHUB_API="file://$T/api-old" "$HOOK" </dev/null 2>&1 || true)"
assert "hook: cache older than 24 h is re-run" '[ -z "$OUT" ]'

rm -rf "$XDG_CACHE_HOME"
OUT="$(cd "$T" && AI_KIT_GITHUB_API="file://$T/api-new" "$HOOK" </dev/null 2>&1 || true)"
assert "hook: new release is cached" '[ -s "$CACHE" ]'
touch -t 203001010000 "$T/standards/external/vendored.json"
OUT="$(cd "$T" && AI_KIT_GITHUB_API="file://$T/api-old" "$HOOK" </dev/null 2>&1 || true)"
assert "hook: manifest newer than the cache is re-run" '[ -z "$OUT" ]'

rm -rf "$XDG_CACHE_HOME"
OUT="$(cd "$T" && AI_KIT_GITHUB_API="file://$T/missing" "$HOOK" </dev/null 2>&1 || true)"
assert "hook: unreachable API is silent and not cached" '[ -z "$OUT" ] && [ ! -e "$CACHE" ]'

OUT="$(cd "$NOREPO" && echo "{\"cwd\":\"$T\"}" | AI_KIT_GITHUB_API="file://$T/api-new" "$HOOK" 2>&1 || true)"
assert "hook: payload cwd is honoured" 'grep -q "v2.0.0" <<< "$OUT"'

# A plugin-wide hook must never run code the opened repo supplies.
PLANT="$T/planted"; MARK="$T/PLANTED-RAN"
mkdir -p "$PLANT/bin" "$PLANT/standards/external"
git init --quiet "$PLANT"
cp "$T/standards/external/vendored.json" "$PLANT/standards/external/"
printf '#!/bin/sh\ntouch "%s"\n' "$MARK" > "$PLANT/bin/ai-kit-upstream-drift.sh"
chmod +x "$PLANT/bin/ai-kit-upstream-drift.sh"
rm -rf "$XDG_CACHE_HOME"
OUT="$(cd "$PLANT" && AI_KIT_GITHUB_API="file://$T/api-new" "$HOOK" </dev/null 2>&1 || true)"
assert "hook: never runs the repo's own drift script" '[ ! -e "$MARK" ]'
assert "hook: uses its own drift script against the repo manifest" 'grep -q "v2.0.0" <<< "$OUT"'
unset XDG_CACHE_HOME

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
