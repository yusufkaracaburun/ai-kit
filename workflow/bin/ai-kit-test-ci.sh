#!/usr/bin/env bash
# Hygiene section: does any workflow actually run this project's test suite?
#
# The DoD checklist ai-kit installs asks for "bewijs (commit-link / screenshot /
# test-run)", and dor-dod-enforcement.yml enforces that the box is ticked. Nothing
# enforces that the box is true. That gap matters most where the kit is aimed:
# an AFK agent draining ready-for-agent issues ticks its own DoD, so "suite green"
# rests on one run on one machine unless CI repeats it.
#
# This grades wiring, not test quality: is there a runner, and does any workflow
# name it? Whether the suite is any good is a question no filesystem check can
# answer, and a generic "run your tests" workflow template cannot be shipped —
# a suite needing a database service and a provisioned tenant is not something
# the kit can guess. Making the absence visible is the part that generalises.
#
# Known misses, all in the false-alarm direction (a WARN on a repo that does run
# its suite), accepted because closing them needs a YAML parser or workspace
# resolution: the runner hidden behind `make test`, a reusable workflow
# (`jobs.<id>.uses:`) doing the running, `yarn workspaces foreach -A run test`,
# and a step disabled by `if: false`. Segmenting on `;&|` also cannot see quote
# context, so a step that names the runner inside a quoted string spanning `&&`
# (`echo "run composer install && ./vendor/bin/pest locally" && exit 1`) reads as
# an invocation; closing that needs a shell-aware parser, and the segmentation it
# would undo is what makes `install && test` one-liners work at all.
# Two further residual false OKs are known —
# a `workflow_dispatch`-only workflow counts as coverage though it is not
# repeated verification, and every package.json collapses into one `npm test`
# runner, so a monorepo running apps/a's suite vouches for apps/b's.
#
# Exit 0 = a workflow runs the suite, or there is nothing to grade. 1 = warning.
# Never above 1: missing test CI is a gap in an optional gate, not a broken
# install, and blocker weight in this repo's score model is reserved for the latter.
set -uo pipefail

PROJECT_PATH="${1:-$PWD}"
TARGET="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
  echo "test-ci: $PROJECT_PATH is not a directory — skipped."
  exit 0
}

# A directory git does not track carries no workflows, and warning about it
# would be noise in every non-repo hygiene run.
if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo "test-ci: not a git repository — skipped."
  exit 0
fi

# Detect the runner from the manifest that declares it. RUNNERS holds the
# human name; PATTERNS holds what an invocation of it looks like in a workflow.
#
# Manifests are found with `git ls-files`, not a root-only look: a monorepo
# keeps them in backend/ or apps/<name>/, and grading only the root would stay
# silent on exactly the repos with the most to verify. ls-files is also already
# gitignore-aware, so vendored copies under node_modules/ never register.
# Test fixtures are excluded — a kit's own fixture manifests are not the
# project's suite, and grading them warns about a runner nobody ships.
RUNNERS=()
PATTERNS=()

manifests() {
  git -C "$TARGET" ls-files -- "$1" "*/$1" 2>/dev/null \
    | grep -vE '(^|/)(tests?|spec)/fixtures?/' || true
}
manifest_has() {
  local pattern="$1" file
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    grep -qE "$pattern" "$TARGET/$file" 2>/dev/null && return 0
  done < <(manifests "$2")
  return 1
}

# Patterns match an *invocation*, not a mention. An unanchored `pest` also hits
# `composer require pestphp/pest-plugin-laravel`, `cp phpunit.xml.dist`, and a
# reminder echoed in prose — each of which would report a suite as verified
# while nothing runs it. A false OK defeats the check silently, so it is the
# direction to design against, even at the cost of missing an exotic invocation.
#
# Laravel's own idiom is `php artisan test`, which drives pest or phpunit
# without naming either, so it counts for both.
PHP_RUN='artisan test|composer (run(-script)? )?test'
if manifest_has '"pestphp/pest"' composer.json; then
  RUNNERS+=("pest"); PATTERNS+=("(vendor/bin/|\./)(pest|paratest)|$PHP_RUN")
elif manifest_has '"phpunit/phpunit"' composer.json; then
  RUNNERS+=("phpunit"); PATTERNS+=("(vendor/bin/|\./)(phpunit|paratest)|$PHP_RUN")
fi

# Each package.json is judged on its own: npm init writes a placeholder "test"
# script that exits 1, and testing the two conditions across the whole set let
# one placeholder in a monorepo blank out a sibling's real suite.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -qE '"test"[[:space:]]*:' "$TARGET/$f" 2>/dev/null || continue
  grep -qE '"test"[[:space:]]*:[[:space:]]*"echo .*no test specified' "$TARGET/$f" 2>/dev/null && continue
  RUNNERS+=("npm test")
  PATTERNS+=("(npm|yarn|pnpm|bun) (run )?test|npx (vitest|jest)|\.bin/(vitest|jest)|(vitest|jest) run")
  break
done < <(manifests package.json)

# pytest.ini / tox.ini are located the same way as the other manifests, so a
# Python service under services/api/ is graded like a PHP one under backend/.
if [ -n "$(manifests pytest.ini)" ] || [ -n "$(manifests tox.ini)" ] \
   || manifest_has '\bpytest\b' pyproject.toml; then
  RUNNERS+=("pytest"); PATTERNS+=("(python -m )?pytest([[:space:]]|$)|tox([[:space:]]|$)")
fi

if [ "${#RUNNERS[@]}" -eq 0 ]; then
  echo "test-ci: no test runner detected (composer/package.json/pytest) — skipped."
  exit 0
fi

shopt -s nullglob
WORKFLOWS=("$TARGET/.github/workflows"/*.yml "$TARGET/.github/workflows"/*.yaml)

# A workflow that installs a runner is not a workflow that runs it, so install
# and setup steps are dropped before the invocation patterns are applied.
#
# Commands are segmented on `;&|` first. Dropping whole *lines* would discard
# `composer install && php artisan test` — one line carrying both an install and
# the run — and that is the common CI idiom, so filtering by line turned the
# Laravel case this check promises to honour into a false alarm. Comments are
# stripped ahead of that, so a commented-out test step (a flaky suite someone
# disabled) reads as absent, which is exactly what it is.
#
# `if:` keys are dropped before segmentation, not after: a GHA expression may
# quote a command (`contains(..., 'artisan test')`) and the fragment no longer
# carries the key once `tr` has cut it. Segments that merely print or search for
# a command (`cat requirements.txt | grep pytest`) are dropped after it.
covers() {
  sed 's/#.*//' "$2" 2>/dev/null \
    | grep -vE '^[[:space:]]*if:' \
    | tr ';&|' '\n' \
    | grep -vE '(pip|pip3|npm|yarn|pnpm|bun|composer|apt-get|brew) (install|require|ci|add)' \
    | grep -vE '^[[:space:]]*(-[[:space:]]*)?(run:[[:space:]]*)?(echo|printf|cat|grep|sed|awk)[[:space:]]' \
    | grep -qE "$1"
}

# Every declared runner must be covered. Exiting on the first hit meant a
# monorepo whose JS suite runs in CI vouched for a PHP suite that does not —
# the false-OK direction, on the shape this check exists for.
join() { local out; out="$(printf '%s, ' "$@")"; echo "${out%, }"; }

COVERED=()
UNCOVERED=()
i=0
while [ "$i" -lt "${#PATTERNS[@]}" ]; do
  hit=""
  if [ "${#WORKFLOWS[@]}" -gt 0 ]; then
    # bash 3.2 (macOS) errors on "${arr[@]}" for an empty array under `set -u`;
    # the ${#arr[@]} length form above is safe, the expansion here is not.
    for wf in "${WORKFLOWS[@]}"; do
      if covers "${PATTERNS[$i]}" "$wf"; then hit="$(basename "$wf")"; break; fi
    done
  fi
  if [ -n "$hit" ]; then
    COVERED+=("${RUNNERS[$i]} runs in $hit")
  else
    UNCOVERED+=("${RUNNERS[$i]}")
  fi
  i=$(( i + 1 ))
done

if [ "${#UNCOVERED[@]}" -eq 0 ]; then
  echo "test-ci: ok — $(join "${COVERED[@]}")."
  exit 0
fi

uncovered_list="$(join "${UNCOVERED[@]}")"
echo "WARN: no workflow runs this project's test suite (uncovered runner: $uncovered_list)."
if [ "${#COVERED[@]}" -gt 0 ]; then
  echo "Covered: $(join "${COVERED[@]}")."
fi
echo
echo "The DoD template asks for evidence of a test run and dor-dod-enforcement.yml"
echo "checks that the box is ticked — but nothing here verifies the run happened."
echo "Where an AFK agent ticks its own DoD, that is the wrong half to be missing."
echo
echo "Fix: add a workflow that runs $uncovered_list on push and pull_request."
echo "If the suite needs services (database, cache) or a provisioned tenant, wire"
echo "those as job services — that part is project-specific and ai-kit ships no"
echo "template for it on purpose."
exit 1
