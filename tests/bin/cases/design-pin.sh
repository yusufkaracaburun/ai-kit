#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

# design-pin.sh prints the judge's pin for one unit. Every case runs in a
# throwaway git repo, so the real tree is never touched.

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cd "$T"
git init -q
git config user.email t@example.com
git config user.name t
mkdir -p .agents src ref 'src/[id]'
echo 'export const A = 1' > src/a.ts
echo 'export const P = 1' > 'src/[id]/page.ts'
echo '--space: 4px' > ref/tokens.css
echo 'png-one' > ref/shot.png
echo 'png-two' > ref/shot2.png
echo '{"h1": [{"font-size": {"px": 22, "token": "text-xl"}}]}' > ref/measure.json
cat > .agents/design-to-code.overlay.json <<'JSON'
{
  "bar": 100,
  "units": {
    "inv": { "route": "/i", "reference": { "mode": "image", "files": ["ref/shot.png", "ref/shot2.png"], "values": "ref/tokens.css" }, "paths": ["src"], "pin": "" },
    "dyn": { "route": "/d", "reference": { "mode": "image", "files": ["ref/shot.png"], "values": "ref/tokens.css" }, "paths": ["src/[id]"], "pin": "" }
  }
}
JSON
git add -A
git -c commit.gpgsign=false commit -qm init

OVL=.agents/design-to-code.overlay.json
pin() { bash "$AIKIT/bin/design-pin.sh" "$@"; }
slot() { awk -F' · ' -v n="$2" '{print $n}' <<<"$1"; }
overlay_set() { jq "$1" "$OVL" > o.tmp && mv o.tmp "$OVL"; }

echo "=== shape and stability ==="
P1=$(pin inv ref/measure.json)
P2=$(pin inv ref/measure.json)
assert "pin is stable across two runs" '[ "$P1" = "$P2" ]'
assert "pin line has every slot" 'grep -qE "^image [0-9a-f]{40} · values [0-9a-f]{40} · HEAD [0-9a-f]{40} · worktree [0-9a-f]{40} · overlay [0-9a-f]{40} · measure [0-9a-f]{40}$" <<<"$P1"'
assert "HEAD slot is git rev-parse HEAD" '[ "$(slot "$P1" 3)" = "HEAD $(git rev-parse HEAD)" ]'

echo "=== reference, values and measure inputs ==="
echo 'png-one-edited' > ref/shot.png
P=$(pin inv ref/measure.json)
assert "editing a reference file moves the pin" '[ "$(slot "$P" 1)" != "$(slot "$P1" 1)" ]'
echo '--space: 8px' > ref/tokens.css
PV=$(pin inv ref/measure.json)
assert "editing the values file moves the pin" '[ "$(slot "$PV" 2)" != "$(slot "$P" 2)" ]'
overlay_set '.units.inv.reference.files |= reverse'
PS=$(pin inv ref/measure.json)
assert "swapping the order of two reference files moves the ref sha" '[ "$(slot "$PS" 1)" != "$(slot "$PV" 1)" ]'
echo '{"h1": [{"font-size": {"px": 17, "token": null}}]}' > ref/measure.json
PM=$(pin inv ref/measure.json)
assert "editing measure.json moves the pin" '[ "$(slot "$PM" 6)" != "$(slot "$PS" 6)" ]'
git checkout -q -- ref "$OVL"

echo "=== code changes that must move the pin ==="
P1=$(pin inv ref/measure.json)
echo 'export const A = 2' > src/a.ts
P3=$(pin inv ref/measure.json)
assert "pin changes after a working-tree edit" '[ "$P3" != "$P1" ]'
WANT="worktree $(git diff HEAD -- src | shasum | cut -d" " -f1) "
assert "no untracked files: worktree sha is the diff alone" 'grep -qF "$WANT" <<<"$P3"'
# GNU xargs runs the command once on empty input unless -r is given; BSD never does.
mkdir -p "$T/.gnu"
cat > "$T/.gnu/xargs" <<'SH'
#!/usr/bin/env bash
in="$(cat; echo .)"; in="${in%.}"
if [ -z "$in" ]; then
  for a in "$@"; do [ "$a" = -r ] && exit 0; done
  args=(); for a in "$@"; do [ "$a" = -0 ] || args+=("$a"); done
  exec "${args[@]}" </dev/null
fi
printf '%s' "$in" | /usr/bin/xargs "$@"
SH
chmod +x "$T/.gnu/xargs"
P3G=$(PATH="$T/.gnu:$PATH" pin inv ref/measure.json)
assert "no untracked files: GNU-style xargs gives the same pin" '[ "$P3G" = "$P3" ]'
echo 'export const B = 1' > src/b.ts
P4=$(pin inv ref/measure.json)
assert "pin changes after an untracked file" '[ "$P4" != "$P3" ]'
overlay_set '.bar = 90'
P5=$(pin inv ref/measure.json)
assert "pin changes after an overlay edit" '[ "$P5" != "$P4" ]'

echo "=== change that must not move the pin ==="
overlay_set '.units.inv.pin = "stored"'
P6=$(pin inv ref/measure.json)
assert "pin ignores a .units[].pin edit" '[ "$P6" = "$P5" ]'

echo "=== literal paths ==="
D1=$(pin dyn ref/measure.json)
echo 'not part of src/[id]' > src/i
D2=$(pin dyn ref/measure.json)
assert "a src/[id] path does not pull in src/i" '[ "$D1" = "$D2" ]'

echo "=== paper mode and errors ==="
overlay_set '.units.inv.reference = {"mode": "paper", "frame": "F1"}'
echo '{"width": 375}' > ref/styles.json
P7=$(pin inv ref/measure.json ref/styles.json)
assert "paper mode hashes the computed-styles file" 'grep -qE "^paper $(shasum < ref/styles.json | cut -d" " -f1) · values - · " <<<"$P7"'
RC=0; pin inv ref/measure.json >/dev/null 2>&1 || RC=$?
assert "paper mode without a styles file exits 2" '[ "$RC" -eq 2 ]'
RC=0; pin inv >/dev/null 2>&1 || RC=$?
assert "no measure.json argument exits 2" '[ "$RC" -eq 2 ]'
RC=0; pin nope ref/measure.json >/dev/null 2>&1 || RC=$?
assert "unknown unit exits 2" '[ "$RC" -eq 2 ]'
overlay_set '.units.inv.paths = ["src", "nope"]'
RC=0; ERR=$(pin inv ref/measure.json ref/styles.json 2>&1) || RC=$?
assert "a missing path exits non-zero" '[ "$RC" -ne 0 ] && grep -qF "path nope does not exist" <<<"$ERR"'

print_summary_and_exit
