# Mirror one source directory into its workflow/ plugin-payload destination,
# or (--check) report drift. Shared by sync-plugin-{bin,standards,context,
# orchestration}.sh — those four mirror an entire directory identically,
# differing only in which directory and the re-stamp hint they print.
#
# sync_mirror <src_dir> <dst_dir> <mode: stamp|check> <restamp_hint>
sync_mirror() {
  local src="$1" dst="$2" mode="$3" hint="$4"

  if [ ! -d "$src" ]; then
    echo "Source missing: $src" >&2
    exit 2
  fi

  if [ "$mode" = "check" ]; then
    if [ ! -d "$dst" ] || ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
      echo "Drift: $dst differs from $src" >&2
      diff -rq "$src" "$dst" 2>&1 | head -20 >&2
      echo "" >&2
      echo "Run $hint to re-stamp." >&2
      exit 1
    fi
    exit 0
  fi

  mkdir -p "$dst"
  rsync -a --delete "$src/" "$dst/"
  echo "Synced: $dst (from $src)"
}
