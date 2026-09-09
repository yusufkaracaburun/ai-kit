#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== printed recipes survive an interactive shell ==="
# section: printed-recipes

# Scripts in bin/ run under bash, where a user's interactive aliases do not
# apply — a bare `mv` there overwrites and is fine. A recipe those scripts
# *print* for a human to paste is the opposite case: it lands in an interactive
# shell, where macOS setups commonly alias mv/rm/cp to the -i variants. Those
# prompt, decline, and still exit 0, so an `&&` chain reports success while
# nothing happened. That is how v1.53.1 reached a pushed tag with the
# marketplace catalog still resolving v1.53.0 (#129).
#
# Recipe shape: an echo whose payload starts with the command (optionally after
# `&& `) and is followed by a flag, a path, or a lowercase argument. The
# uppercase exclusion is what separates a recipe from prose — `echo "  rm
# FAILED: ..."` is a message, not something anyone pastes. It is a heuristic,
# and it would miss a recipe whose first argument starts with a capital; the
# guard-the-guard checks below exist because the first version of this regex
# only accepted flags and paths and silently matched nothing at all.
RECIPE_RE='echo " *(&& )?(mv|rm|cp) [-"~/.$a-z0-9]'
FORCED_RE='(mv|rm|cp) -[a-zA-Z]*f'

RECIPES="$(grep -rnE "$RECIPE_RE" "$AIKIT"/bin/*.sh || true)"
assert "the sweep finds the printed recipes it is meant to guard" '[ -n "$RECIPES" ]'

UNFORCED="$(echo "$RECIPES" | grep -vE "$FORCED_RE" || true)"
assert "no printed recipe pastes a bare mv/rm/cp" '[ -z "$UNFORCED" ]'

# Guard the guard: a bare recipe must actually be caught, or the sweep above
# passes for the wrong reason once someone edits the regex.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aikit-recipes.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
printf '#!/usr/bin/env bash\necho "  mv a.json b.json"\n' > "$TMP/fake.sh"
CAUGHT="$(grep -rnE "$RECIPE_RE" "$TMP"/*.sh | grep -vE "$FORCED_RE" || true)"
assert "the sweep catches a bare printed mv" '[ -n "$CAUGHT" ]'

printf '#!/usr/bin/env bash\necho "  rm FAILED: something"\n' > "$TMP/prose.sh"
PROSE="$(grep -rnE "$RECIPE_RE" "$TMP/prose.sh" || true)"
assert "the sweep ignores prose that merely contains rm" '[ -z "$PROSE" ]'

print_summary_and_exit
