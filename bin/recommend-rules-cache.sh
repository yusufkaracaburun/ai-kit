#!/usr/bin/env bash
# Cache helper for /aikit-recommend-rules Phase 2 web-search results.
#
# Phase 2 (community-rule discovery) is performed by the AI agent invoking the
# skill, not by this script — but we want repeated invocations on the same
# stack to skip the live search. This helper exposes three subcommands the
# skill calls:
#
#   key   <project>      Print a stable stack-fingerprint (sha256, hex).
#   read  <key>          Print cached JSON to stdout if fresh; exit 0.
#                        Miss / stale / corrupt: exit 1, no stdout.
#   write <key>          Read JSON from stdin, store atomically.
#
# Cache lives under ${XDG_CACHE_HOME:-$HOME/.cache}/ai-kit/recommend-rules/.
# Default TTL: 7 days. Override with --ttl <days> or AIKIT_CACHE_TTL_DAYS env.
# --no-cache on read returns miss without checking the file; on write skips
# the write. Useful for the skill's --refresh path.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"

usage() {
  cat <<EOF
Usage:
  $0 key   <project>            Print stack-fingerprint for project
  $0 read  <key> [--ttl N]      Print cached JSON if fresh (<N days); exit 1 on miss
  $0 write <key>                Store JSON from stdin under <key>
  $0 path  [<key>]              Print cache dir, or full path for <key>
  $0 clear [<key>]              Remove cached entry for <key>, or wipe all

Flags:
  --ttl N        Override TTL in days (default 7, also env AIKIT_CACHE_TTL_DAYS)
  --no-cache     Bypass cache: read returns miss, write is no-op
EOF
  exit 1
}

cache_dir() {
  local base="${XDG_CACHE_HOME:-$HOME/.cache}"
  printf '%s/ai-kit/recommend-rules' "$base"
}

ttl_days() {
  local override="${1:-}"
  if [ -n "$override" ]; then
    printf '%s' "$override"
    return
  fi
  printf '%s' "${AIKIT_CACHE_TTL_DAYS:-7}"
}

# fingerprint <project>
# Hash sorted detected frameworks + frontend/backend architecture from
# detect-tooling.sh --json. Stable for a given stack, regardless of repo path.
fingerprint() {
  local project="$1"
  local json
  json="$("$AIKIT/bin/detect-tooling.sh" "$project" --json)"
  python3 - "$json" <<'PY'
import json, sys, hashlib
data = json.loads(sys.argv[1])
fw = sorted(data.get("frameworks") or [])
arch = data.get("architecture") or {}
fe = (arch.get("frontend") or {}).get("detected") or ""
be = (arch.get("backend")  or {}).get("detected") or ""
payload = "|".join(["fw=" + ",".join(fw), "fe=" + fe, "be=" + be])
print(hashlib.sha256(payload.encode("utf-8")).hexdigest())
PY
}

key_path() {
  printf '%s/%s.json' "$(cache_dir)" "$1"
}

# read_cache <key> <ttl_days>
read_cache() {
  local key="$1" ttl="$2"
  local path
  path="$(key_path "$key")"
  [ -f "$path" ] || return 1

  local now mtime age_sec ttl_sec
  now="$(date +%s)"
  if mtime="$(stat -f %m "$path" 2>/dev/null)"; then
    :
  else
    mtime="$(stat -c %Y "$path")"
  fi
  age_sec=$((now - mtime))
  ttl_sec=$((ttl * 86400))
  [ "$age_sec" -le "$ttl_sec" ] || return 1

  # Validate JSON before emitting — refuse to feed garbage to the caller.
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$path" >/dev/null 2>&1 || return 1
  cat "$path"
}

# write_cache <key> (reads stdin)
write_cache() {
  local key="$1"
  local dir
  dir="$(cache_dir)"
  mkdir -p "$dir"
  local path tmp
  path="$(key_path "$key")"
  tmp="$(mktemp "${path}.XXXXXX")"
  cat > "$tmp"
  # Validate before committing — never persist garbage.
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    echo "Refusing to cache invalid JSON for key $key" >&2
    return 2
  fi
  mv "$tmp" "$path"
}

main() {
  [ $# -ge 1 ] || usage
  local sub="$1"; shift

  local ttl_override=""
  local no_cache=false
  local pos=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --ttl) ttl_override="$2"; shift 2 ;;
      --no-cache) no_cache=true; shift ;;
      -h|--help) usage ;;
      -*) echo "Unknown flag: $1" >&2; usage ;;
      *) pos+=("$1"); shift ;;
    esac
  done

  local ttl
  ttl="$(ttl_days "$ttl_override")"

  case "$sub" in
    key)
      [ "${#pos[@]}" -eq 1 ] || usage
      local project="${pos[0]}"
      [ -d "$project" ] || { echo "Project not found: $project" >&2; exit 2; }
      project="$(cd "$project" && pwd)"
      fingerprint "$project"
      ;;
    read)
      [ "${#pos[@]}" -eq 1 ] || usage
      [ "$no_cache" = true ] && exit 1
      read_cache "${pos[0]}" "$ttl"
      ;;
    write)
      [ "${#pos[@]}" -eq 1 ] || usage
      if [ "$no_cache" = true ]; then
        cat >/dev/null
        exit 0
      fi
      write_cache "${pos[0]}"
      ;;
    path)
      if [ "${#pos[@]}" -eq 0 ]; then
        cache_dir
      else
        key_path "${pos[0]}"
      fi
      ;;
    clear)
      local dir
      dir="$(cache_dir)"
      if [ "${#pos[@]}" -eq 0 ]; then
        [ -d "$dir" ] && rm -rf "$dir"
      else
        rm -f "$(key_path "${pos[0]}")"
      fi
      ;;
    *) usage ;;
  esac
}

main "$@"
