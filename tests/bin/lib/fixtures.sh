# shellcheck shell=bash
# Cache bootstrap-project.sh output within a single case file's process.
#
# bootstrap-project.sh's dominant cost is emit-rules.sh — the same ~44 rules
# fan out across every detected agent on every call, regardless of target
# content. Two calls with the same args produce byte-identical output (the
# only variable content, $AIKIT_VERSION and symlink targets, is stable for
# the whole process), so build once per arg-signature and `cp -R` the rest.
#
# Usage: bootstrap_fixture "$TARGET_DIR" --minimal [...bootstrap-project.sh args]
# Requires $AIKIT to be set (case file convention, set before sourcing harness.sh).
#
# Single-slot cache, not a keyed map: macOS ships bash 3.2 (no associative
# arrays), and every current caller uses one fixed arg-signature per file.

_BOOTSTRAP_FIXTURE_KEY=""
_BOOTSTRAP_FIXTURE_DIR=""
trap 'rm -rf "$_BOOTSTRAP_FIXTURE_DIR"' EXIT

bootstrap_fixture() {
  local target="$1"
  shift
  local key="$*"

  if [ "$key" != "$_BOOTSTRAP_FIXTURE_KEY" ] || [ -z "$_BOOTSTRAP_FIXTURE_DIR" ]; then
    _BOOTSTRAP_FIXTURE_DIR="$(mktemp -d)"
    "$AIKIT/bin/bootstrap-project.sh" "$@" "$_BOOTSTRAP_FIXTURE_DIR" >/dev/null
    _BOOTSTRAP_FIXTURE_KEY="$key"
  fi

  mkdir -p "$target"
  cp -R "$_BOOTSTRAP_FIXTURE_DIR/." "$target"
}
