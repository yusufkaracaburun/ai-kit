#!/usr/bin/env bash
# Report when a verbatim-vendored upstream has moved past the SHA ai-kit pinned.
#
# ai-kit carries copies of a few upstream files (sandcastle templates, the
# copywriter skill, external rules). The provenance convention in
# standards/external/VETTING.md already asks for source_url / source_license /
# pinned_sha / vendored_at — but until now nothing READ those fields, so a pin
# could sit unchanged for months while upstream shipped bug fixes. A pin nobody
# checks is decoration.
#
# This reads standards/external/vendored.json and asks each upstream for the
# current SHA of the tracked ref. Different SHA means upstream moved; the
# compare URL shows exactly what changed so a human decides whether to
# re-vendor.
#
# `distilled` entries (idea sources such as mattpocock/skills) are tracked by
# GitHub release instead: a release newer than the pin lists each changed
# upstream SKILL.md with the ai-kit file it sharpens, a skip reason, or "new
# skill". The API base comes from AI_KIT_GITHUB_API so tests can serve
# file:// fixtures.
#
# Re-vendoring is never automatic. Every entry carries `local_deltas` —
# deliberate ai-kit edits that a blind overwrite would destroy.
#
# Exit codes:
#   0 — report emitted (default, report-only contract — matches dedupe/audit)
#   1 — drift or a new distilled release found AND --strict was passed (CI)
#   2 — error (manifest missing or malformed)
#
# Usage:
#   ai-kit-upstream-drift.sh [ai-kit-root]   # report, always exit 0
#   ai-kit-upstream-drift.sh --strict        # exit 1 when any upstream has moved
#   ai-kit-upstream-drift.sh --distilled-only  # skip the sources (SessionStart hook)
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"

STRICT=0
DISTILLED_ONLY=0
ROOT=""
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --distilled-only) DISTILLED_ONLY=1 ;;
    -h|--help) sed -n '1,33p' "$0"; exit 0 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) ROOT="$arg" ;;
  esac
done

# The manifest describes the ai-kit checkout being audited, which is not always
# the checkout this script lives in: /ai:hygiene runs the installed copy against
# a project path. Reading $AIKIT there would report the wrong repo's pins.
ROOT="${ROOT:-$AIKIT}"
MANIFEST="$ROOT/standards/external/vendored.json"

if [ ! -f "$MANIFEST" ]; then
  echo "upstream-drift: no standards/external/vendored.json — nothing pinned." >&2
  exit 2
fi

# name<TAB>repo<TAB>ref<TAB>pinned_sha<TAB>vendored_at, one line per source.
# A tab or newline inside a field would split or merge rows here, silently
# dropping a source from the check — the precise failure this exists to
# prevent — so the emitter rejects them rather than passing them through.
EMIT_ROWS='
import json, sys
path = sys.argv[1]
try:
    d = json.load(open(path))
except Exception as e:
    print("upstream-drift: cannot parse manifest: %s" % e, file=sys.stderr)
    sys.exit(2)
kind, rows = sys.argv[2], []
for s in d.get(kind, []):
    if kind == "sources":
        f = [s.get("name", ""), s.get("repo", ""), s.get("ref", "HEAD"),
             s.get("pinned_sha", ""), s.get("vendored_at", "")]
    else:
        f = [s.get("name", ""), s.get("repo", ""), s.get("pinned_sha", ""),
             s.get("pinned_release", "")]
    for v in f:
        if "\t" in v or "\n" in v:
            print("upstream-drift: control character in field for %r" % f[0],
                  file=sys.stderr)
            sys.exit(2)
    rows.append("\t".join(f))
print("\n".join(rows))
'
ENTRIES=""
[ "$DISTILLED_ONLY" = "1" ] || { ENTRIES="$(python3 -c "$EMIT_ROWS" "$MANIFEST" sources)" || exit 2; }
DISTILLED="$(python3 -c "$EMIT_ROWS" "$MANIFEST" distilled)" || exit 2

[ -z "$ENTRIES$DISTILLED" ] && { echo "upstream-drift: manifest lists no sources."; exit 0; }

DRIFTED=0
VENDOR_MOVED=0
CURRENT=0
UNREACHABLE=0

while IFS=$'\t' read -r name repo ref pinned vendored; do
  [ -z "$name" ] && continue

  if [ -z "$pinned" ]; then
    echo "?? $name — no pinned_sha, drift is not computable."
    echo "   Fix: record the upstream SHA the copy was taken from in vendored.json."
    UNREACHABLE=$((UNREACHABLE + 1))
    continue
  fi

  # `--` so a repo value starting with `-` cannot be read as a git option:
  # `--upload-pack=<cmd>` turns a data-file edit into command execution.
  # GIT_TERMINAL_PROMPT=0 + an empty credential helper so a repo that went
  # private (401) cannot block this report-only script on an auth dialog.
  remote="$(GIT_TERMINAL_PROMPT=0 git -c credential.helper= \
              ls-remote -- "$repo" "$ref" 2>/dev/null | awk 'NR==1{print $1}')"
  if [ -z "$remote" ]; then
    echo "?? $name — could not reach $repo (offline, or ref '$ref' is gone)."
    UNREACHABLE=$((UNREACHABLE + 1))
    continue
  fi

  if [ "$remote" = "$pinned" ]; then
    echo "OK $name — current (pinned ${pinned:0:7}, vendored $vendored)"
    CURRENT=$((CURRENT + 1))
  else
    slug="${repo#https://github.com/}"
    echo "-> $name — upstream moved since $vendored"
    echo "   pinned ${pinned:0:7} -> remote ${remote:0:7}"
    echo "   compare: $repo/compare/${pinned}...${remote}"
    echo "   re-vendor only after reading local_deltas for '$name' in vendored.json ($slug)"
    DRIFTED=$((DRIFTED + 1))
    VENDOR_MOVED=$((VENDOR_MOVED + 1))
  fi
done <<< "$ENTRIES"

# Compare status is pin relative to tag: "behind"/"identical" means the release
# holds nothing past the pin (ours sits ahead of the v1.3.2 tag commit).
CLASSIFY='
import json, re, sys
try:
    c = json.load(sys.stdin)
except Exception:
    sys.exit(3)
st = c.get("status") if isinstance(c, dict) else None
if st in ("behind", "identical"):
    sys.exit(0)
if st not in ("ahead", "diverged"):
    sys.exit(3)
skills = next(s for s in json.load(open(sys.argv[1]))["distilled"]
              if s.get("name") == sys.argv[2]).get("skills", {})
for f in c.get("files", []):
    m = re.fullmatch(r"skills/([A-Za-z0-9._/-]+)/SKILL\.md", f.get("filename", ""))
    if not m:
        continue
    e = skills.get(m.group(1), {})
    if "ai_kit" in e:
        verdict = "sharpens " + e["ai_kit"]
    elif "skip" in e:
        verdict = "skip: " + e["skip"]
    else:
        verdict = "new skill: park until an app needs it"
    print("   %s — %s" % (m.group(0), verdict))
sys.exit(10)
'
API="${AI_KIT_GITHUB_API:-https://api.github.com}"

while IFS=$'\t' read -r name repo pinned release; do
  [ -z "$name" ] && continue
  slug="${repo#https://github.com/}"
  # Slug, SHA and tag land in a URL; anything outside this charset is refused.
  if ! [[ "$slug" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ && "$pinned" =~ ^[0-9a-f]{40}$ ]]; then
    echo "?? $name — repo is not a github.com slug or pinned_sha is not 40-hex, not checked."
    UNREACHABLE=$((UNREACHABLE + 1))
    continue
  fi
  tag="$(curl -s --max-time 3 "$API/repos/$slug/releases/latest" 2>/dev/null | python3 -c '
import json, sys
try:
    t = json.load(sys.stdin).get("tag_name")
except Exception:
    t = None
print(t if isinstance(t, str) else "")' 2>/dev/null)"
  if ! [[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "?? $name — no release tag from $API (offline, rate-limited or no release)."
    UNREACHABLE=$((UNREACHABLE + 1))
    continue
  fi
  # shortcut: GitHub compare lists at most 300 files, enough for one skills release; page it if a release ever exceeds that.
  files="$(curl -s --max-time 3 "$API/repos/$slug/compare/$pinned...$tag" 2>/dev/null \
           | python3 -c "$CLASSIFY" "$MANIFEST" "$name" 2>/dev/null)"
  case $? in
    0) echo "OK $name — current (release $tag, pinned $release, ${pinned:0:7})"
       CURRENT=$((CURRENT + 1)) ;;
    10) echo "-> $name — new release $tag (pinned $release, ${pinned:0:7})"
        echo "   compare: https://github.com/$slug/compare/$pinned...$tag"
        [ -n "$files" ] && echo "$files"
        echo "   merge ideas into the mapped skills, never resync verbatim"
        DRIFTED=$((DRIFTED + 1)) ;;
    *) echo "?? $name — could not read the compare $pinned...$tag from $API."
       UNREACHABLE=$((UNREACHABLE + 1)) ;;
  esac
done <<< "$DISTILLED"

echo ""
echo "upstream-drift: $CURRENT current, $DRIFTED moved, $UNREACHABLE unchecked."
if [ "$VENDOR_MOVED" -gt 0 ]; then
  echo "Moved upstream is not automatically a problem — read the compare first."
  echo "Re-vendor: reapply the local_deltas, then bump pinned_sha + vendored_at."
fi

# ponytail: HEAD-SHA comparison only — it says THAT upstream moved, not whether
# the vendored paths were touched. Path-scoped counting needs a clone (upstream
# sandcastle is ~1200 commits); the compare URL carries that for a human. Add
# path filtering here only if the compare proves too noisy to act on.

if [ "$STRICT" = "1" ] && [ "$DRIFTED" -gt 0 ]; then
  exit 1
fi
exit 0
