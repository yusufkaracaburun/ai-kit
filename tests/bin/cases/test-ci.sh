#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

CHECK="$AIKIT/bin/ai-kit-test-ci.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/aikit-test-ci.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "=== ai-kit-test-ci: does a workflow run the suite? ==="
# section: ai-kit-test-ci

mkrepo() { mkdir -p "$1" && git -C "$1" init -q 2>/dev/null; }
# Detection reads tracked files (that is what keeps vendored manifests under
# node_modules/ out), so a fixture must stage what it wrote before checking.
track() { git -C "$1" add -A >/dev/null 2>&1 || true; }

# Not a git repository → skipped, never warned. A plain directory carries no
# workflows, so warning about it would be noise in every non-repo hygiene run.
mkdir -p "$TMP/plain"
OUT_PLAIN="$("$CHECK" "$TMP/plain" 2>&1)"; RC_PLAIN=$?
assert "test-ci exits 0 outside a git repo" '[ "$RC_PLAIN" -eq 0 ]'
assert "test-ci reports the non-repo skip" 'echo "$OUT_PLAIN" | grep -q "not a git repository"'

# Git repo with no detectable runner → skipped. Nothing to grade.
mkrepo "$TMP/norunner"
OUT_NONE="$("$CHECK" "$TMP/norunner" 2>&1)"; RC_NONE=$?
assert "test-ci exits 0 when no runner is detected" '[ "$RC_NONE" -eq 0 ]'
assert "test-ci reports the no-runner skip" 'echo "$OUT_NONE" | grep -q "no test runner detected"'

# Runner present, no workflow at all → warn. This is the gap the check exists for.
mkrepo "$TMP/pest-nowf"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/pest-nowf/composer.json"
track "$TMP/pest-nowf"
OUT_GAP="$("$CHECK" "$TMP/pest-nowf" 2>&1)" && RC_GAP=0 || RC_GAP=$?
assert "test-ci exits 1 when pest exists and no workflow runs it" '[ "$RC_GAP" -eq 1 ]'
assert "test-ci names the detected runner" 'echo "$OUT_GAP" | grep -q "uncovered runner: pest"'
assert "test-ci explains the DoD gap it is reporting" 'echo "$OUT_GAP" | grep -q "nothing here verifies the run happened"'

# Runner present, workflows exist but none invokes it → still a warn. A repo
# with gitleaks and no test job is exactly the shape ai-kit ships by default.
mkrepo "$TMP/pest-otherwf"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/pest-otherwf/composer.json"
mkdir -p "$TMP/pest-otherwf/.github/workflows"
printf 'name: gitleaks\njobs:\n  scan:\n    steps:\n      - run: gitleaks detect\n' \
  > "$TMP/pest-otherwf/.github/workflows/gitleaks.yml"
track "$TMP/pest-otherwf"
OUT_OTHER="$("$CHECK" "$TMP/pest-otherwf" 2>&1)" && RC_OTHER=0 || RC_OTHER=$?
assert "test-ci exits 1 when workflows exist but none runs the suite" '[ "$RC_OTHER" -eq 1 ]'

# Runner present and a workflow invokes it → clean, and it names the file so
# the reader can check the claim rather than trust it.
mkrepo "$TMP/pest-wf"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/pest-wf/composer.json"
mkdir -p "$TMP/pest-wf/.github/workflows"
printf 'name: test\njobs:\n  test:\n    steps:\n      - run: ./vendor/bin/pest\n' \
  > "$TMP/pest-wf/.github/workflows/test.yml"
track "$TMP/pest-wf"
OUT_OK="$("$CHECK" "$TMP/pest-wf" 2>&1)"; RC_OK=$?
assert "test-ci exits 0 when a workflow runs pest" '[ "$RC_OK" -eq 0 ]'
assert "test-ci names the workflow that runs it" 'echo "$OUT_OK" | grep -q "pest runs in test.yml"'

# npm init's placeholder "test" script is not a suite — detecting it would warn
# every scaffolded JS project about a test run that was never going to happen.
mkrepo "$TMP/npm-placeholder"
printf '{"scripts":{"test":"echo \\"Error: no test specified\\" && exit 1"}}\n' \
  > "$TMP/npm-placeholder/package.json"
track "$TMP/npm-placeholder"
OUT_PH="$("$CHECK" "$TMP/npm-placeholder" 2>&1)"; RC_PH=$?
assert "test-ci exits 0 on npm's placeholder test script" '[ "$RC_PH" -eq 0 ]'
assert "test-ci treats the placeholder as no runner" 'echo "$OUT_PH" | grep -q "no test runner detected"'

# Real npm suite with a workflow that runs vitest → clean.
mkrepo "$TMP/npm-wf"
printf '{"scripts":{"test":"vitest run"}}\n' > "$TMP/npm-wf/package.json"
mkdir -p "$TMP/npm-wf/.github/workflows"
printf 'name: ci\njobs:\n  t:\n    steps:\n      - run: npm test\n' \
  > "$TMP/npm-wf/.github/workflows/ci.yml"
track "$TMP/npm-wf"
OUT_NPM="$("$CHECK" "$TMP/npm-wf" 2>&1)"; RC_NPM=$?
assert "test-ci exits 0 when a workflow runs npm test" '[ "$RC_NPM" -eq 0 ]'

# The hygiene runner exposes it as a section with a skip flag, like every other.
assert "hygiene wires the test-ci section" 'grep -q "ai-kit-test-ci.sh" "$AIKIT/bin/ai-kit-hygiene.sh"'
assert "hygiene accepts --skip-test-ci" 'grep -q -- "--skip-test-ci" "$AIKIT/bin/ai-kit-hygiene.sh"'

# --- regressions found by running this check against real repos, not fixtures ---

# Monorepo: manifests live one level down (backend/, frontend/). Grading only
# the repo root stayed silent on naschool, which is the shape with the most to
# verify. Detection walks tracked files instead.
mkrepo "$TMP/monorepo"
mkdir -p "$TMP/monorepo/backend"
echo '{"require-dev":{"phpunit/phpunit":"^11.0"}}' > "$TMP/monorepo/backend/composer.json"
track "$TMP/monorepo"
OUT_MONO="$("$CHECK" "$TMP/monorepo" 2>&1)" && RC_MONO=0 || RC_MONO=$?
assert "test-ci detects a runner in a monorepo subdir" '[ "$RC_MONO" -eq 1 ]'
assert "test-ci names the subdir runner" 'echo "$OUT_MONO" | grep -q "uncovered runner: phpunit"'

# `php artisan test` drives pest/phpunit without naming either. Matching only
# the binary warned at naschool, whose CI does run the suite — a false alarm
# teaches the reader to ignore the section, so it is the worse failure.
mkrepo "$TMP/artisan"
mkdir -p "$TMP/artisan/backend" "$TMP/artisan/.github/workflows"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/artisan/backend/composer.json"
printf 'name: ci\njobs:\n  t:\n    steps:\n      - run: php artisan test --parallel\n' \
  > "$TMP/artisan/.github/workflows/ci.yml"
track "$TMP/artisan"
OUT_ART="$("$CHECK" "$TMP/artisan" 2>&1)"; RC_ART=$?
assert "test-ci accepts php artisan test as running the suite" '[ "$RC_ART" -eq 0 ]'
assert "test-ci names the workflow for artisan test" 'echo "$OUT_ART" | grep -q "runs in ci.yml"'

# Files git does not track cannot be graded — a vendored composer.json under
# node_modules/ must not register as this project's runner.
mkrepo "$TMP/ignored"
mkdir -p "$TMP/ignored/node_modules/dep"
echo 'node_modules/' > "$TMP/ignored/.gitignore"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/ignored/node_modules/dep/composer.json"
track "$TMP/ignored"
OUT_IGN="$("$CHECK" "$TMP/ignored" 2>&1)"; RC_IGN=$?
assert "test-ci ignores manifests git does not track" '[ "$RC_IGN" -eq 0 ]'
assert "test-ci reports no runner for a vendored manifest" 'echo "$OUT_IGN" | grep -q "no test runner detected"'

# --- regressions from the pre-release review: every one of these was a false OK ---

# A covered runner must not vouch for an uncovered one. Monorepo with a JS suite
# in CI and a PHP suite nowhere used to report clean.
mkrepo "$TMP/partial"
mkdir -p "$TMP/partial/backend" "$TMP/partial/frontend" "$TMP/partial/.github/workflows"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/partial/backend/composer.json"
printf '{"scripts":{"test":"vitest run"}}\n' > "$TMP/partial/frontend/package.json"
printf 'name: ci\njobs:\n  t:\n    steps:\n      - run: npm test\n' \
  > "$TMP/partial/.github/workflows/ci.yml"
track "$TMP/partial"
OUT_PART="$("$CHECK" "$TMP/partial" 2>&1)" && RC_PART=0 || RC_PART=$?
assert "test-ci warns when only some runners are covered" '[ "$RC_PART" -eq 1 ]'
assert "test-ci names the uncovered runner" 'echo "$OUT_PART" | grep -q "uncovered runner: pest"'
assert "test-ci still credits the covered one" 'echo "$OUT_PART" | grep -q "Covered: npm test runs in ci.yml"'

# One placeholder package.json must not blank out a sibling's real suite.
mkrepo "$TMP/mixed-js"
mkdir -p "$TMP/mixed-js/apps/web" "$TMP/mixed-js/packages/util"
printf '{"scripts":{"test":"vitest run"}}\n' > "$TMP/mixed-js/apps/web/package.json"
printf '{"scripts":{"test":"echo \\"Error: no test specified\\" && exit 1"}}\n' \
  > "$TMP/mixed-js/packages/util/package.json"
track "$TMP/mixed-js"
OUT_MIX="$("$CHECK" "$TMP/mixed-js" 2>&1)" && RC_MIX=0 || RC_MIX=$?
assert "test-ci still detects a real suite beside a placeholder" '[ "$RC_MIX" -eq 1 ]'
assert "test-ci names npm test despite the placeholder sibling" 'echo "$OUT_MIX" | grep -q "npm test"'

# Installing a runner is not running it.
mkrepo "$TMP/install-only"
mkdir -p "$TMP/install-only/.github/workflows"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/install-only/composer.json"
printf 'name: static\njobs:\n  s:\n    steps:\n      - run: composer require --dev pestphp/pest-plugin-laravel\n' \
  > "$TMP/install-only/.github/workflows/static.yml"
track "$TMP/install-only"
OUT_INST="$("$CHECK" "$TMP/install-only" 2>&1)" && RC_INST=0 || RC_INST=$?
assert "test-ci does not count an install step as a test run" '[ "$RC_INST" -eq 1 ]'

# Naming a config file is not running it.
mkrepo "$TMP/config-copy"
mkdir -p "$TMP/config-copy/.github/workflows"
echo '{"require-dev":{"phpunit/phpunit":"^11.0"}}' > "$TMP/config-copy/composer.json"
printf 'name: setup\njobs:\n  s:\n    steps:\n      - run: cp phpunit.xml.dist phpunit.xml\n' \
  > "$TMP/config-copy/.github/workflows/setup.yml"
track "$TMP/config-copy"
OUT_CFG="$("$CHECK" "$TMP/config-copy" 2>&1)" && RC_CFG=0 || RC_CFG=$?
assert "test-ci does not count copying phpunit.xml as a test run" '[ "$RC_CFG" -eq 1 ]'

# Mentioning a runner in prose is not running it.
mkrepo "$TMP/prose"
mkdir -p "$TMP/prose/.github/workflows"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/prose/composer.json"
printf 'name: hygiene\njobs:\n  h:\n    steps:\n      - run: echo "Reminder: run pest locally before review"\n' \
  > "$TMP/prose/.github/workflows/hygiene.yml"
track "$TMP/prose"
OUT_PROSE="$("$CHECK" "$TMP/prose" 2>&1)" && RC_PROSE=0 || RC_PROSE=$?
assert "test-ci does not count a prose mention as a test run" '[ "$RC_PROSE" -eq 1 ]'

# Python config is located like every other manifest, not root-only.
mkrepo "$TMP/py-mono"
mkdir -p "$TMP/py-mono/services/api"
printf '[pytest]\n' > "$TMP/py-mono/services/api/pytest.ini"
track "$TMP/py-mono"
OUT_PY="$("$CHECK" "$TMP/py-mono" 2>&1)" && RC_PY=0 || RC_PY=$?
assert "test-ci detects pytest config in a subdir" '[ "$RC_PY" -eq 1 ]'
assert "test-ci names pytest as uncovered" 'echo "$OUT_PY" | grep -q "uncovered runner: pytest"'

# `pip install pytest` is an install step, not a run.
mkrepo "$TMP/py-install"
mkdir -p "$TMP/py-install/.github/workflows"
printf '[pytest]\n' > "$TMP/py-install/pytest.ini"
printf 'name: ci\njobs:\n  t:\n    steps:\n      - run: pip install pytest\n' \
  > "$TMP/py-install/.github/workflows/ci.yml"
track "$TMP/py-install"
OUT_PYI="$("$CHECK" "$TMP/py-install" 2>&1)" && RC_PYI=0 || RC_PYI=$?
assert "test-ci does not count pip install pytest as a run" '[ "$RC_PYI" -eq 1 ]'

# A repo's own test fixtures are not its suite.
mkrepo "$TMP/fixtures"
mkdir -p "$TMP/fixtures/tests/fixtures/sample"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/fixtures/tests/fixtures/sample/composer.json"
track "$TMP/fixtures"
OUT_FIX="$("$CHECK" "$TMP/fixtures" 2>&1)"; RC_FIX=$?
assert "test-ci ignores fixture manifests" '[ "$RC_FIX" -eq 0 ]'
assert "test-ci reports no runner for fixtures only" 'echo "$OUT_FIX" | grep -q "no test runner detected"'

# --- install-and-run on one line: the common CI idiom, and a regression the
# --- first version of the install filter introduced by dropping whole lines ---

wf() { mkdir -p "$1/.github/workflows"; printf 'name: ci\njobs:\n  t:\n    steps:\n      - run: %s\n' "$2" > "$1/.github/workflows/ci.yml"; }

mkrepo "$TMP/php-oneline"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/php-oneline/composer.json"
wf "$TMP/php-oneline" 'composer install --no-interaction && php artisan test'
track "$TMP/php-oneline"
OUT_P1="$("$CHECK" "$TMP/php-oneline" 2>&1)"; RC_P1=$?
assert "test-ci sees the run half of 'composer install && php artisan test'" '[ "$RC_P1" -eq 0 ]'

mkrepo "$TMP/npm-oneline"
printf '{"scripts":{"test":"vitest run"}}\n' > "$TMP/npm-oneline/package.json"
wf "$TMP/npm-oneline" 'npm ci && npm test'
track "$TMP/npm-oneline"
OUT_N1="$("$CHECK" "$TMP/npm-oneline" 2>&1)"; RC_N1=$?
assert "test-ci sees the run half of 'npm ci && npm test'" '[ "$RC_N1" -eq 0 ]'

mkrepo "$TMP/pnpm-oneline"
printf '{"scripts":{"test":"vitest run"}}\n' > "$TMP/pnpm-oneline/package.json"
wf "$TMP/pnpm-oneline" 'pnpm install --frozen-lockfile && pnpm test'
track "$TMP/pnpm-oneline"
OUT_PN="$("$CHECK" "$TMP/pnpm-oneline" 2>&1)"; RC_PN=$?
assert "test-ci sees the run half of 'pnpm install && pnpm test'" '[ "$RC_PN" -eq 0 ]'

mkrepo "$TMP/py-oneline"
printf '[pytest]\n' > "$TMP/py-oneline/pytest.ini"
wf "$TMP/py-oneline" 'pip install -e .[dev] && pytest -q'
track "$TMP/py-oneline"
OUT_PY1="$("$CHECK" "$TMP/py-oneline" 2>&1)"; RC_PY1=$?
assert "test-ci sees the run half of 'pip install && pytest -q'" '[ "$RC_PY1" -eq 0 ]'

# --- pytest/tox needed a trailing boundary: both of these were false OKs ---

mkrepo "$TMP/py-cachekey"
printf '[pytest]\n' > "$TMP/py-cachekey/pytest.ini"
wf "$TMP/py-cachekey" 'ruff check .'
printf '      - uses: actions/cache@v4\n        with:\n          key: pytest-cache-abc123\n' \
  >> "$TMP/py-cachekey/.github/workflows/ci.yml"
track "$TMP/py-cachekey"
OUT_PCK="$("$CHECK" "$TMP/py-cachekey" 2>&1)" && RC_PCK=0 || RC_PCK=$?
assert "test-ci does not count a pytest-prefixed cache key as a run" '[ "$RC_PCK" -eq 1 ]'

mkrepo "$TMP/py-toxpath"
printf '[tox]\n' > "$TMP/py-toxpath/tox.ini"
mkdir -p "$TMP/py-toxpath/.github/workflows"
printf 'name: lint\non:\n  push:\n    paths:\n      - tox.ini\njobs:\n  l:\n    steps:\n      - run: ruff check .\n' \
  > "$TMP/py-toxpath/.github/workflows/lint.yml"
track "$TMP/py-toxpath"
OUT_PTP="$("$CHECK" "$TMP/py-toxpath" 2>&1)" && RC_PTP=0 || RC_PTP=$?
assert "test-ci does not count a 'paths: tox.ini' trigger as a run" '[ "$RC_PTP" -eq 1 ]'

# --- a commented-out test step is an absent test step, which is the point ---

mkrepo "$TMP/commented"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/commented/composer.json"
mkdir -p "$TMP/commented/.github/workflows"
printf 'name: ci\njobs:\n  t:\n    steps:\n      - run: vendor/bin/pint --test\n      # - run: ./vendor/bin/pest   # disabled, flaky\n' \
  > "$TMP/commented/.github/workflows/ci.yml"
track "$TMP/commented"
OUT_CMT="$("$CHECK" "$TMP/commented" 2>&1)" && RC_CMT=0 || RC_CMT=$?
assert "test-ci does not count a commented-out test step" '[ "$RC_CMT" -eq 1 ]'

# --- searching for a runner is not running it, and a GHA expression quoting a
# --- command is not running it either: both were false OKs ---

mkrepo "$TMP/grep-only"
printf '[pytest]\n' > "$TMP/grep-only/pytest.ini"
mkdir -p "$TMP/grep-only/.github/workflows"
printf 'name: lint\njobs:\n  l:\n    steps:\n      - run: ruff check .\n      - run: cat requirements.txt | grep pytest || true\n' \
  > "$TMP/grep-only/.github/workflows/lint.yml"
track "$TMP/grep-only"
OUT_GREP="$("$CHECK" "$TMP/grep-only" 2>&1)" && RC_GREP=0 || RC_GREP=$?
assert "test-ci does not count grepping for a runner as running it" '[ "$RC_GREP" -eq 1 ]'

mkrepo "$TMP/if-expr"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/if-expr/composer.json"
mkdir -p "$TMP/if-expr/.github/workflows"
printf 'name: ci\njobs:\n  t:\n    steps:\n      - run: vendor/bin/pint --test\n' \
  > "$TMP/if-expr/.github/workflows/ci.yml"
printf "        if: \${{ github.event_name == 'push' || contains(github.event.head_commit.message, 'artisan test') }}\n" \
  >> "$TMP/if-expr/.github/workflows/ci.yml"
track "$TMP/if-expr"
OUT_IF="$("$CHECK" "$TMP/if-expr" 2>&1)" && RC_IF=0 || RC_IF=$?
assert "test-ci does not count a runner named in an if: expression" '[ "$RC_IF" -eq 1 ]'

# Guard the trade the segmentation buys: printers are dropped, real runs are not.
mkrepo "$TMP/still-runs"
printf '[pytest]\n' > "$TMP/still-runs/pytest.ini"
wf "$TMP/still-runs" 'pip install -e .[dev] && pytest -q'
track "$TMP/still-runs"
OUT_SR="$("$CHECK" "$TMP/still-runs" 2>&1)"; RC_SR=$?
assert "test-ci still sees a real run after the printer filter" '[ "$RC_SR" -eq 0 ]'

mkrepo "$TMP/block-scalar"
echo '{"require-dev":{"pestphp/pest":"^3.0"}}' > "$TMP/block-scalar/composer.json"
mkdir -p "$TMP/block-scalar/.github/workflows"
printf 'name: ci\njobs:\n  t:\n    steps:\n      - run: |\n          composer install --no-interaction\n          php artisan test\n' \
  > "$TMP/block-scalar/.github/workflows/ci.yml"
track "$TMP/block-scalar"
OUT_BS="$("$CHECK" "$TMP/block-scalar" 2>&1)"; RC_BS=$?
assert "test-ci sees a run inside a 'run: |' block scalar" '[ "$RC_BS" -eq 0 ]'

print_summary_and_exit
