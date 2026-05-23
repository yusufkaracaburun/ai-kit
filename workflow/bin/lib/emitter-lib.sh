# shellcheck shell=bash
# Helpers shared by emitters in bin/lib/emitters/*.sh.

# Print value of a YAML frontmatter key from a .mini.md/.nano.md file.
# Returns empty string if not present or no frontmatter block.
_emitter_extract_meta() {
  local path="$1" key="$2"
  awk -v key="$key" '
    BEGIN { in_fm=0; seen=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; seen=1; next }
    seen && in_fm && /^---[[:space:]]*$/ { exit }
    in_fm && $1 == key":" {
      sub(/^[^:]+:[[:space:]]*/, "")
      print
      exit
    }
  ' "$path"
}

# Print rule body with frontmatter (if any) stripped.
_emitter_strip_frontmatter() {
  local path="$1"
  awk '
    BEGIN { in_fm=0; stripped=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
    in_fm && /^---[[:space:]]*$/ { in_fm=0; stripped=1; next }
    in_fm { next }
    { print }
  ' "$path"
}

# Print a frontmatter list value (space-separated). For YAML like:
#   applies_to:
#     frameworks: [laravel, rails]
# call as _emitter_extract_list path frameworks
_emitter_extract_list() {
  local path="$1" key="$2"
  awk -v key="$key" '
    BEGIN { in_fm=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm && $0 ~ "^[[:space:]]*"key":" {
      line=$0
      sub(/^[^\[]*\[/, "", line)
      sub(/\].*/, "", line)
      gsub(/,/, " ", line)
      gsub(/[[:space:]]+/, " ", line)
      sub(/^ /, "", line)
      print line
      exit
    }
  ' "$path"
}
