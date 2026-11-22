#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== scripts call mv/rm/cp past user aliases and functions ==="
# section: no-interactive-aliases

# A user's `mv -i` / `rm -i` / `cp -i` alias or exported function makes a
# script stop on a prompt nobody sees (#207). `command mv -f` skips both.
# shortcut: misses xargs rm, find -exec rm, prefixes like env/time, and any line starting with echo/printf/log; upgrade when a real miss shows up.
BARE_RE='(^|[;&|({)]|(then|do|else|if|!)[[:space:]]|trap '"[\"']"')[[:space:]]*(mv|rm|cp)[[:space:]]'
SKIP_RE='^[^:]*:[0-9]+:[[:space:]]*(#|echo |printf |log )'

bare_calls() {
  find "$1" -name '*.sh' | sort \
    | xargs grep -nE "$BARE_RE" | grep -vE "$SKIP_RE" || true
}

HITS="$(bare_calls "$AIKIT/workflow/bin")"
assert "no script in workflow/bin runs a bare mv/rm/cp" '[ -z "$HITS" ]'
[ -z "$HITS" ] || echo "$HITS" >&2

TMP="$(mktemp -d "${TMPDIR:-/tmp}/aikit-aliases.XXXXXX")"
trap 'command rm -rf "$TMP"' EXIT
printf '#!/usr/bin/env bash\n[ -f a ] && mv a b\nif rm x; then :; fi\ntrap '"'"'rm -f "$t"'"'"' EXIT\n' > "$TMP/bare.sh"
CAUGHT="$(bare_calls "$TMP" | wc -l | tr -d ' ')"
assert "the sweep catches bare calls after &&, if and trap" '[ "$CAUGHT" = 3 ]'

printf '#!/usr/bin/env bash\necho "  rm -f x"\n# mv a b\ncommand mv -f a b\n' > "$TMP/fine.sh"
FINE="$(bare_calls "$TMP" | grep fine.sh || true)"
assert "the sweep ignores echoed hints, comments and command calls" '[ -z "$FINE" ]'

print_summary_and_exit
