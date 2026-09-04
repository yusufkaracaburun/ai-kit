#!/usr/bin/env bash
# Shared exclude logic for ai-kit-docs-sync-* scanners (dead-links, repo-hygiene).
#
# Two layers:
#   1. Basename excludes — directory names that get pruned anywhere in the tree
#      (e.g. .git, node_modules, .pnpm-store). Cheap: feeds straight into
#      `find -name X -prune`.
#   2. Path-prefix excludes — absolute paths the scanner must skip. Sources:
#        - active git worktrees (parsed from `git worktree list --porcelain`),
#          excluding the project itself
#        - `.docs-sync-ignore` entries that contain `/`
#      Used as a post-filter against finding paths.
#
# A `.docs-sync-ignore` file at the project root (gitignore-style) adds
# project-local entries:
#   - blank lines and `# comment` lines are ignored
#   - lines without `/` (e.g. `build`) → added to basename excludes
#   - lines with `/` (e.g. `app/test-fixtures/`) → added to path-prefix excludes,
#     resolved relative to the project root, leading + trailing `/` stripped
#
# Globs are NOT interpreted. `**/foo` is treated as basename `foo`. This is the
# minimal subset that covers the issues #98 + #100 reported without adding a
# full gitignore parser to bash.

# Default basename excludes — extended from the v1.37 set with the common
# noise patterns reported in #98 + #100.
DOCS_SYNC_DEFAULT_EXCLUDE_NAMES=(
  .git
  node_modules
  vendor
  .tmp
  dist
  build
  .next
  .turbo
  .cache
  .pnpm-store
  phpunit-storage
  .archive
  _originals
  test-results
  playwright-report
  .vite-temp
  coverage
  .nyc_output
)

# Flutter/iOS/Android build + vendored dirs — gated on pubspec.yaml (#157),
# same signal detect-lib.sh uses for Flutter stack detection.
DOCS_SYNC_FLUTTER_EXCLUDE_NAMES=(
  .dart_tool
  Pods
  .gradle
  ephemeral
  Runner.xcodeproj
  Runner.xcworkspace
)

# Echo one basename per line for use by callers.
dsync_basename_excludes() {
  local project_path="${1:-$PWD}"
  local name
  for name in "${DOCS_SYNC_DEFAULT_EXCLUDE_NAMES[@]}"; do
    printf '%s\n' "$name"
  done

  if [ -f "$project_path/pubspec.yaml" ]; then
    for name in "${DOCS_SYNC_FLUTTER_EXCLUDE_NAMES[@]}"; do
      printf '%s\n' "$name"
    done
  fi

  if [ -f "$project_path/.docs-sync-ignore" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      # strip leading whitespace
      line="${line#"${line%%[![:space:]]*}"}"
      [ -z "$line" ] && continue
      case "$line" in \#*) continue ;; esac
      # trailing slash → strip
      line="${line%/}"
      # literal **/ prefix → strip (treat as basename). Guard so a path entry
      # like tests/fixtures is NOT collapsed to its last component — the glob
      # `${line#**/}` would otherwise strip any `dir/` prefix (issue #105).
      case "$line" in '**/'*) line="${line#**/}" ;; esac
      case "$line" in
        */*) ;;  # path-prefix entry, handled by dsync_path_prefix_excludes
        *)   printf '%s\n' "$line" ;;
      esac
    done < "$project_path/.docs-sync-ignore"
  fi
}

# Echo one absolute path-prefix per line. Caller post-filters findings.
dsync_path_prefix_excludes() {
  local project_path="${1:-$PWD}"
  project_path="$(cd "$project_path" && pwd)"

  if [ -f "$project_path/pubspec.yaml" ]; then
    printf '%s\n' "$project_path/android/.kotlin"
  fi

  # Active git worktrees (skip the project itself). Only when project_path is
  # the toplevel of its own git repo — otherwise we'd inherit the parent repo's
  # worktrees, which would over-exclude when scanning a fixture or subdir.
  #
  # macOS quirk: $TMPDIR is `/var/folders/...` (symlink) while
  # `git rev-parse --show-toplevel` returns the realpath `/private/var/...`.
  # Compare physical paths for equality and rewrite each worktree path back to
  # the caller's logical project_path so the post-filter matches scanner output.
  if command -v git >/dev/null 2>&1; then
    local toplevel project_physical
    toplevel="$(git -C "$project_path" rev-parse --show-toplevel 2>/dev/null || true)"
    project_physical="$(cd "$project_path" && pwd -P 2>/dev/null || printf '%s' "$project_path")"
    if [ -n "$toplevel" ] && [ "$toplevel" = "$project_physical" ]; then
      git -C "$project_path" worktree list --porcelain 2>/dev/null \
        | awk '/^worktree /{print $2}' \
        | while IFS= read -r wt; do
            [ -z "$wt" ] && continue
            [ "$wt" = "$toplevel" ] && continue
            # Rewrite physical → logical prefix so the path matches scanner output.
            case "$wt" in
              "$toplevel"/*) wt="$project_path/${wt#$toplevel/}" ;;
            esac
            printf '%s\n' "$wt"
          done
    fi
  fi

  if [ -f "$project_path/.docs-sync-ignore" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      line="${line#"${line%%[![:space:]]*}"}"
      [ -z "$line" ] && continue
      case "$line" in \#*) continue ;; esac
      line="${line#/}"
      line="${line%/}"
      case "$line" in
        */*) printf '%s\n' "$project_path/$line" ;;
      esac
    done < "$project_path/.docs-sync-ignore"
  fi
}

# Build `-name X -o -name Y ...` snippet for `find` from basename excludes.
dsync_build_prune_args() {
  local project_path="${1:-$PWD}"
  local first=1
  local name
  local out=""
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    if [ "$first" -eq 1 ]; then
      out="-name $name"
      first=0
    else
      out="$out -o -name $name"
    fi
  done < <(dsync_basename_excludes "$project_path" | awk 'NF && !seen[$0]++')
  printf '%s' "$out"
}

# stdin: paths (one per line). stdout: same minus anything under a path-prefix.
dsync_filter_path_prefixes() {
  local project_path="${1:-$PWD}"
  project_path="$(cd "$project_path" && pwd)"
  local -a prefixes=()
  local p
  while IFS= read -r p; do
    [ -n "$p" ] && prefixes+=("$p")
  done < <(dsync_path_prefix_excludes "$project_path" | awk 'NF && !seen[$0]++')
  if [ "${#prefixes[@]}" -eq 0 ]; then
    cat
    return
  fi
  # Pure-bash prefix match — avoids `awk -v` choking on the newline-joined list.
  local line keep
  while IFS= read -r line; do
    keep=1
    for p in "${prefixes[@]}"; do
      case "$line" in "$p"|"$p"/*) keep=0; break ;; esac
    done
    [ "$keep" -eq 1 ] && printf '%s\n' "$line"
  done
}
