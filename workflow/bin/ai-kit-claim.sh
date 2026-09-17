#!/usr/bin/env bash
# Peer-session claims: "who owns X" as a file read instead of a broadcast.
#
# One claim per live Claude Code session, ~/.config/ai-kit/claims/<session_id>.md
# — YAML frontmatter, nothing else:
#
#   name, repo, cwd, branch      where the session works (hook writes these)
#   role                         lead | build | design | e2e | review
#   owns                         [paths, .pen frames, devices]
#   provides                     [api version, plugin release, ...]
#   depends_on                   [repos, resources]
#   updated                      ISO-8601, set on every write
#
# Liveness comes from Claude Code's own session registry
# (~/.claude/sessions/<pid>.json — the data behind `ListAgents`): a session is
# live iff its registry pid answers `kill -0`. A claim whose session is not
# live is stale; `show` marks it, `prune` deletes it.
#
# Usage:
#   ai-kit-claim.sh [--session ID] set key=value ...   create or update own claim
#   ai-kit-claim.sh [--session ID] show                live peers as a table (own row omitted)
#   ai-kit-claim.sh [--session ID] release             delete own claim
#   ai-kit-claim.sh prune                              delete every stale claim
#
# --session beats $AI_KIT_SESSION_ID, which bin/hooks/peer-sessions-check.sh
# exports for the session via CLAUDE_ENV_FILE. No dependencies beyond
# coreutils: this file is copied next to the hook into a project's
# .claude/hooks/, so it must not source ai-kit libs.
set -euo pipefail

CLAIMS_DIR="${HOME}/.config/ai-kit/claims"
REGISTRY_DIR="${HOME}/.claude/sessions"
KEYS="name repo cwd branch role owns provides depends_on"
LIST_KEYS="owns provides depends_on"
ROLES="lead build design e2e review"

usage() {
  cat >&2 <<'EOF'
Usage: ai-kit-claim.sh [--session ID] set key=value ...   create or update own claim
       ai-kit-claim.sh [--session ID] show                live peers as a table (own row omitted)
       ai-kit-claim.sh [--session ID] release             delete own claim
       ai-kit-claim.sh prune                              delete every stale claim
Keys: name repo cwd branch role owns provides depends_on. ID defaults to $AI_KIT_SESSION_ID.
EOF
  exit 2
}

SESSION="${AI_KIT_SESSION_ID:-}"
if [ "${1:-}" = "--session" ]; then
  SESSION="${2:-}"
  shift 2 || usage
fi
CMD="${1:-}"
[ $# -gt 0 ] && shift

need_session() {
  [ -n "$SESSION" ] || { echo "ai-kit-claim: no session id (--session ID or AI_KIT_SESSION_ID)" >&2; exit 2; }
}

# Frontmatter value of <key> in <file>; empty when absent.
claim_get() {
  [ -f "$2" ] || return 0
  awk -v k="$1" '
    NR==1 && /^---$/ { fm=1; next }
    fm && /^---$/ { exit }
    fm && index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }
  ' "$2" 2>/dev/null
}

# Flat single-line JSON written by Claude Code; string or number value.
registry_get() {
  sed -n 's/.*"'"$1"'":"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/p' "$2" 2>/dev/null | head -1
}

# One line per live registry entry: session<TAB>name<TAB>cwd<TAB>status<TAB>updatedAt
# ponytail: kill -0 trusts the pid; pid reuse across a reboot would show a
# ghost — compare procStart against `ps -o lstart` if that ever bites.
live_sessions() {
  local f pid
  for f in "$REGISTRY_DIR"/*.json; do
    [ -f "$f" ] || continue
    pid="$(registry_get pid "$f")"
    [ -n "$pid" ] || continue
    kill -0 "$pid" 2>/dev/null || continue
    printf '%s\t%s\t%s\t%s\t%s\n' "$(registry_get sessionId "$f")" "$(registry_get name "$f")" \
      "$(registry_get cwd "$f")" "$(registry_get status "$f")" "$(registry_get updatedAt "$f")"
  done
}

claim_set() {
  need_session
  local arg key val file tmp
  for arg in "$@"; do
    key="${arg%%=*}"
    case " $KEYS " in *" $key "*) ;; *) echo "ai-kit-claim: unknown key '$key' (one of: $KEYS)" >&2; exit 2 ;; esac
    if [ "$key" = role ]; then
      case " $ROLES " in *" ${arg#*=} "*) ;; *) echo "ai-kit-claim: role must be one of: $ROLES" >&2; exit 2 ;; esac
    fi
  done
  file="$CLAIMS_DIR/$SESSION.md"
  mkdir -p "$CLAIMS_DIR"
  tmp="$(mktemp)"
  echo '---' > "$tmp"
  for key in $KEYS; do
    val=""
    for arg in "$@"; do
      [ "${arg%%=*}" = "$key" ] && val="${arg#*=}"
    done
    [ -n "$val" ] || val="$(claim_get "$key" "$file")"
    [ -n "$val" ] || continue
    case " $LIST_KEYS " in *" $key "*)
      val="${val#[}"
      val="[${val%]}]" ;;
    esac
    printf '%s: %s\n' "$key" "$val" >> "$tmp"
  done
  printf 'updated: %s\n---\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$tmp"
  mv "$tmp" "$file"
  cat "$file"
}

claim_cells() {
  # claim_cells <file> -> "| branch | role | owns | depends_on" (lists unbracketed)
  local v val out=""
  for v in branch role owns depends_on; do
    val="$(claim_get "$v" "$1")"
    val="${val#[}"
    out+=" | ${val%]}"
  done
  printf '%s' "$out"
}

# Markdown table of every live session except own, then every stale claim.
# Prints nothing when there is nobody else — callers test for emptiness.
claim_show() {
  local rows="" sid name cwd status upd file live now
  now="$(date +%s)"
  live="$(live_sessions)"
  while IFS=$'\t' read -r sid name cwd status upd; do
    [ -n "$sid" ] && [ "$sid" != "$SESSION" ] || continue
    file="$CLAIMS_DIR/$sid.md"
    [ -n "$name" ] || name="$(claim_get name "$file")"
    [ -n "$upd" ] || upd="${now}000"
    rows+="| ${name:-${sid:0:8}} | $(basename "$cwd")$(claim_cells "$file") | ${status:--} $(( (now - upd / 1000) / 60 ))m ago |"$'\n'
  done < <(sort -t $'\t' -k2 <<<"$live")
  for file in "$CLAIMS_DIR"/*.md; do
    [ -f "$file" ] || continue
    sid="$(basename "$file" .md)"
    [ "$sid" != "$SESSION" ] || continue
    cut -f1 <<<"$live" | grep -qxF "$sid" && continue
    name="$(claim_get name "$file")"
    rows+="| ${name:-${sid:0:8}} | $(claim_get repo "$file")$(claim_cells "$file") | stale |"$'\n'
  done
  [ -n "$rows" ] || return 0
  printf '| name | repo | branch | role | owns | depends_on | last-active |\n| --- | --- | --- | --- | --- | --- | --- |\n%s' "$rows"
}

claim_prune() {
  local file sid live
  live="$(live_sessions | cut -f1)"
  for file in "$CLAIMS_DIR"/*.md; do
    [ -f "$file" ] || continue
    sid="$(basename "$file" .md)"
    grep -qxF "$sid" <<<"$live" || rm -f "$file"
  done
}

case "$CMD" in
  set) claim_set "$@" ;;
  show) claim_show ;;
  release) need_session; rm -f "$CLAIMS_DIR/$SESSION.md" ;;
  prune) claim_prune ;;
  *) usage ;;
esac
