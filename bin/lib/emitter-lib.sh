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

# Print the rule body (frontmatter stripped) with cross-reference links
# rewritten for the flat emitted layout. A "See also" link in a .mini.md points
# at a sibling rule with a .mini.md/.nano.md suffix and sometimes a ../ depth;
# emit writes every rule flat (.claude/rules/<name>.md, .cursor/rules/<name>.mdc),
# so those links would 404 (issue #105). Rewrite rule, per markdown link:
#   - target whose rule IS emitted in this run -> ./<name>.<ext> (sibling)
#   - everything else (rule not emitted, skill, external doc) -> unlinked,
#     label text kept.
# The emitted set is read from $AIKIT_EMITTED_RULES (space-separated, set by
# emit-rules.sh). When unset the set is empty and every relative rule-style link
# is unlinked — conservative, never a dead link. $2 is the sibling extension
# (md for Claude Code, mdc for Cursor); defaults to md.
_emitter_body() {
  local path="$1" ext="${2:-md}"
  _emitter_strip_frontmatter "$path" \
    | AIKIT_EMITTED_RULES="${AIKIT_EMITTED_RULES:-}" SIBLING_EXT="$ext" perl -0777 -pe '
      BEGIN {
        %emit = map { $_ => 1 } grep { length } split /\s+/, ($ENV{AIKIT_EMITTED_RULES} // "");
        $sext = $ENV{SIBLING_EXT} || "md";
      }
      s{(?<!\!)\[([^\]]*)\]\(([^)]+)\)}{
        my ($label, $target) = ($1, $2);
        if ($target =~ m{^(?:https?:|mailto:|tel:|//|#)}) {
          "[$label]($target)";
        } else {
          my $anchor = "";
          if ($target =~ s/(#.*)$//) { $anchor = $1; }
          (my $cand = $target) =~ s{.*/}{};
          $cand =~ s/\.(?:mini|nano)\.md$//;
          $cand =~ s/\.md$//;
          $cand =~ s/\.(?:mini|nano)$//;
          if (length($cand) && $emit{$cand}) {
            my $lbl = $label;
            $lbl =~ s{^(`?)\Q$cand\E(?:\.(?:mini|nano))?\.md(`?)$}{$1$cand$2};
            "[$lbl](./$cand.$sext$anchor)";
          } else {
            $label;
          }
        }
      }ge;
    '
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
