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
# Re-vendoring is never automatic. Every entry carries `local_deltas` —
# deliberate ai-kit edits that a blind overwrite would destroy.
#
# Exit codes:
#   0 — report emitted (default, report-only contract — matches dedupe/audit)
#   1 — drift found AND --strict was passed (for CI)
#   2 — error (manifest missing or malformed)
#
# Usage:
#   ai-kit-upstream-drift.sh            # report, always exit 0
#   ai-kit-upstream-drift.sh --strict   # exit 1 when any upstream has moved
set -uo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
AIKIT="$(cd "$SCRIPT_BIN/.." && pwd)"
MANIFEST="$AIKIT/standards/external/vendored.json"

STRICT=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    -h|--help) sed -n '1,27p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

if [ ! -f "$MANIFEST" ]; then
  echo "upstream-drift: no standards/external/vendored.json — nothing pinned." >&2
  exit 2
fi

# name<TAB>repo<TAB>ref<TAB>pinned_sha<TAB>vendored_at, one line per source.
ENTRIES="$(python3 -c "
import json, sys
try:
    d = json.load(open('$MANIFEST'))
except Exception as e:
    print('PARSE_ERROR ' + str(e), file=sys.stderr); sys.exit(2)
for s in d.get('sources', []):
    print('\t'.join([s.get('name',''), s.get('repo',''), s.get('ref','HEAD'),
                     s.get('pinned_sha',''), s.get('vendored_at','')]))
")" || exit 2

[ -z "$ENTRIES" ] && { echo "upstream-drift: manifest lists no sources."; exit 0; }

DRIFTED=0
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

  remote="$(git ls-remote "$repo" "$ref" 2>/dev/null | awk 'NR==1{print $1}')"
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
  fi
done <<< "$ENTRIES"

echo ""
echo "upstream-drift: $CURRENT current, $DRIFTED moved, $UNREACHABLE unchecked."
if [ "$DRIFTED" -gt 0 ]; then
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
