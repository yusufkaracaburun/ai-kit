#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

echo "=== secrets-gate ==="
# CI is emitted unconditionally: it is the one uniform surface and the one
# nothing bypasses. Pre-commit is appended only to a mechanism the project
# already runs — the six projects surveyed for #120 use four different ones
# and none uses the pre-commit framework, so emitting its config would add a
# fifth mechanism plus a Python dependency to repos that already have a
# working hook. Where nothing exists we print the command and write nothing.

APPLY="$AIKIT/bin/apply-secrets-gate.sh"
GUARD='gitleaks protect --staged'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

new_repo() {
  local p="$TMP/$1"
  mkdir -p "$p"
  git -C "$p" init -q
  git -C "$p" config user.email test@example.invalid
  git -C "$p" config user.name test
  echo "$p"
}

# --- husky: hooks path points inside the husky directory
HUSKY="$(new_repo husky)"
mkdir -p "$HUSKY/.husky/_"
printf '#!/bin/sh\nnpx lint-staged\n' > "$HUSKY/.husky/pre-commit"
chmod +x "$HUSKY/.husky/pre-commit"
git -C "$HUSKY" config core.hooksPath .husky/_

# --- tracked hooks directory committed to the repo
TRACKED="$(new_repo tracked)"
mkdir -p "$TRACKED/.githooks"
printf '#!/bin/sh\nphp artisan test --parallel\n' > "$TRACKED/.githooks/pre-commit"
chmod +x "$TRACKED/.githooks/pre-commit"
git -C "$TRACKED" config core.hooksPath .githooks

# --- plain: default hooks dir, hook present
PLAIN="$(new_repo plain)"
printf '#!/bin/sh\nmake lint\n' > "$PLAIN/.git/hooks/pre-commit"
chmod +x "$PLAIN/.git/hooks/pre-commit"

# --- husky configured but no pre-commit hook written yet. The mechanism
# --- exists; only the hook file is missing. Using it is not introducing it,
# --- and reporting "no mechanism" here states something false about the
# --- project while declining a hook the maintainer already opted into.
FRESH="$(new_repo husky-fresh)"
mkdir -p "$FRESH/.husky/_"
git -C "$FRESH" config core.hooksPath .husky/_

# --- none: no hooks path, no husky, no hook of any kind
NONE="$(new_repo none)"

for r in "$HUSKY" "$TRACKED" "$PLAIN" "$FRESH" "$NONE"; do
  "$APPLY" "$r" >"$TMP/out.$(basename "$r")" 2>&1 || true
done

assert "husky mechanism is named in output" 'grep -qi husky "$TMP/out.husky"'
assert "husky hook gains the guard" 'grep -qF "$GUARD" "$HUSKY/.husky/pre-commit"'
assert "husky hook keeps what it had" 'grep -q "lint-staged" "$HUSKY/.husky/pre-commit"'

assert "tracked hooks dir gains the guard" 'grep -qF "$GUARD" "$TRACKED/.githooks/pre-commit"'
assert "tracked hook keeps what it had" 'grep -q "artisan test" "$TRACKED/.githooks/pre-commit"'

assert "plain hook gains the guard" 'grep -qF "$GUARD" "$PLAIN/.git/hooks/pre-commit"'
assert "plain hook keeps what it had" 'grep -q "make lint" "$PLAIN/.git/hooks/pre-commit"'

assert "husky without a hook file still gets the guard" 'grep -qF "$GUARD" "$FRESH/.husky/pre-commit"'
assert "husky without a hook file is not called mechanism-less" '! grep -qi "no pre-commit mechanism" "$TMP/out.husky-fresh"'

# Standing up a hook framework for one guard is a decision the maintainer
# makes deliberately, not a side effect of running this.
assert "no mechanism: nothing is written" '[ ! -e "$NONE/.git/hooks/pre-commit" ]'
assert "no mechanism: the command is printed instead" 'grep -qF "$GUARD" "$TMP/out.none"'

# The framework config is never the answer — emitting it would add a fifth
# mechanism to projects that already have a working hook.
assert "pre-commit framework config is never created" '[ -z "$(find "$TMP" -name ".pre-commit-config.yaml" -print -quit)" ]'

# CI is the half nothing bypasses, so it lands everywhere including the
# project with no pre-commit mechanism at all.
assert "CI workflow emitted for husky project" '[ -f "$HUSKY/.github/workflows/gitleaks.yml" ]'
assert "CI workflow emitted where no hook mechanism exists" '[ -f "$NONE/.github/workflows/gitleaks.yml" ]'
assert "CI workflow runs gitleaks" 'grep -qi gitleaks "$NONE/.github/workflows/gitleaks.yml"'

# --- never overwrite without --force
mkdir -p "$PLAIN/.github/workflows"
printf 'name: mine\n' > "$PLAIN/.github/workflows/gitleaks.yml"
"$APPLY" "$PLAIN" >/dev/null 2>&1 || true
assert "existing workflow is not overwritten" 'grep -q "name: mine" "$PLAIN/.github/workflows/gitleaks.yml"'
"$APPLY" "$PLAIN" --force >/dev/null 2>&1 || true
assert "--force replaces the workflow" '! grep -q "name: mine" "$PLAIN/.github/workflows/gitleaks.yml"'

# --- idempotent: a second run must not stack a second guard line
"$APPLY" "$HUSKY" >/dev/null 2>&1 || true
assert "guard is appended exactly once" '[ "$(grep -cF "$GUARD" "$HUSKY/.husky/pre-commit")" -eq 1 ]'

print_summary_and_exit
