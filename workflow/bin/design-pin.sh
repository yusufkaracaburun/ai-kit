#!/usr/bin/env bash
# Print the judge's pin for one design-to-code unit. Run from the repo root.
#
# Usage: design-pin.sh <unit-id> <measure.json> [computed-styles-file]
#   image mode: hashes reference.files in listed order and reference.values.
#   paper mode: hashes the computed-styles file given as the third argument.
#   open mode:  no reference yet; hashes reference.values only.
# Output: <mode> <ref sha> · values <sha> · HEAD <sha> · worktree <sha> · overlay <sha> · measure <sha>
set -euo pipefail
# Unit paths such as src/[id] are literal directories, never glob patterns.
export GIT_LITERAL_PATHSPECS=1

OVERLAY=.agents/design-to-code.overlay.json
UNIT="${1:-}"
MEASURE="${2:-}"
STYLES="${3:-}"

die() { echo "design-pin: $*" >&2; exit 2; }
sha() { shasum | cut -d' ' -f1; }

[ -n "$UNIT" ] && [ -n "$MEASURE" ] || die "usage: design-pin.sh <unit-id> <measure.json> [computed-styles-file]"
[ -f "$MEASURE" ] || die "$MEASURE not found"
[ -f "$OVERLAY" ] || die "$OVERLAY not found (run from the repo root)"
jq -e --arg u "$UNIT" '.units[$u]' "$OVERLAY" >/dev/null || die "unit '$UNIT' not in $OVERLAY"

field() { jq -r --arg u "$UNIT" ".units[\$u]$1" "$OVERLAY"; }

paths=()
while IFS= read -r p; do paths+=("$p"); done < <(field '.paths[]?')
[ "${#paths[@]}" -gt 0 ] || die "units.$UNIT.paths is empty"
for p in "${paths[@]}"; do [ -e "$p" ] || die "path $p does not exist"; done

mode="$(field '.reference.mode')"
case "$mode" in
  image)
    files=()
    while IFS= read -r f; do files+=("$f"); done < <(field '.reference.files[]?')
    [ "${#files[@]}" -gt 0 ] || die "units.$UNIT.reference.files is empty"
    values="$(field '.reference.values // empty')"
    [ -n "$values" ] || die "units.$UNIT.reference.values is not set"
    ref="$(shasum "${files[@]}" | sha)"
    vals="$(sha < "$values")"
    ;;
  open)
    values="$(field '.reference.values // empty')"
    [ -n "$values" ] || die "units.$UNIT.reference.values is not set"
    ref="-"
    vals="$(sha < "$values")"
    ;;
  paper)
    [ -n "$STYLES" ] || die "paper mode needs the computed-styles file as the third argument"
    ref="$(sha < "$STYLES")"
    vals="-"
    ;;
  *) die "units.$UNIT.reference.mode is '$mode', expected image, paper or open" ;;
esac

head_sha="$(git rev-parse HEAD)"
worktree="$({ git diff HEAD -- "${paths[@]}"; git ls-files -o --exclude-standard -z -- "${paths[@]}" | xargs -0 -r shasum; } | sha)"
overlay="$(jq -S 'del(.units[].pin)' "$OVERLAY" | sha)"
measure="$(sha < "$MEASURE")"

echo "$mode $ref · values $vals · HEAD $head_sha · worktree $worktree · overlay $overlay · measure $measure"
