#!/usr/bin/env bash
# Log a skill invocation locally. No-op unless AI_KIT_USAGE=1.
#
# Usage: log-skill.sh <skill-name> <event>
#   event: start | done | abort
#
# Writes one JSON line per call to:
#   ${XDG_STATE_HOME:-$HOME/.local/state}/ai-kit/usage.jsonl
#
# Never logs: absolute paths, prompt content, file content, branch names.
# Never sends data over the network.

set -euo pipefail

# Hard opt-in: silent no-op unless explicitly enabled.
if [ "${AI_KIT_USAGE:-0}" != "1" ]; then
  exit 0
fi

if [ $# -lt 2 ]; then
  echo "Usage: $0 <skill-name> <start|done|abort>" >&2
  exit 2
fi

skill="$1"
event="$2"

case "$event" in
  start|done|abort) ;;
  *)
    echo "Unknown event '$event' (expected start|done|abort)" >&2
    exit 2
    ;;
esac

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ai-kit"
mkdir -p "$state_dir"
log_file="$state_dir/usage.jsonl"

ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Project = basename of the git root if available, else basename of $PWD.
# We hash the absolute path so distinct projects are countable without
# leaking their names or locations.
project="$(basename "$PWD")"
if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  project="$(basename "$git_root")"
  abs_path="$git_root"
else
  abs_path="$PWD"
fi

# sha1 is plenty for a non-cryptographic project bucket.
if command -v shasum >/dev/null 2>&1; then
  cwd_hash="$(printf '%s' "$abs_path" | shasum -a 1 | cut -c1-12)"
elif command -v sha1sum >/dev/null 2>&1; then
  cwd_hash="$(printf '%s' "$abs_path" | sha1sum | cut -c1-12)"
else
  cwd_hash="nohash"
fi

# Minimal escaping: only the skill and project names go in; both are
# expected to be safe identifiers. We still strip quotes/backslashes
# defensively to keep the JSONL strictly parseable.
sanitize() { printf '%s' "$1" | tr -d '"\\'; }

skill_s="$(sanitize "$skill")"
project_s="$(sanitize "$project")"

printf '{"ts":"%s","skill":"%s","event":"%s","project":"%s","cwd_hash":"%s"}\n' \
  "$ts" "$skill_s" "$event" "$project_s" "$cwd_hash" \
  >> "$log_file"
