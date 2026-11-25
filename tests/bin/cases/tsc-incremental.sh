#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

CHECK="$AIKIT/bin/ai-kit-tsc-incremental.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/aikit-tsc-incremental.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "=== ai-kit-tsc-incremental: does the typecheck reuse its last run? ==="
# section: ai-kit-tsc-incremental

track() { git -C "$1" add -A >/dev/null 2>&1 || true; }
# mk <name> <script> [tsconfig] — a tracked repo with one typecheck script.
mk() {
  mkdir -p "$TMP/$1" && git -C "$TMP/$1" init -q 2>/dev/null
  printf '{"scripts":{"typecheck":"%s"}}\n' "$2" > "$TMP/$1/package.json"
  printf 'node_modules/\n*.tsbuildinfo\n' > "$TMP/$1/.gitignore"
  [ -z "${3:-}" ] || printf '%s\n' "$3" > "$TMP/$1/tsconfig.json"
  track "$TMP/$1"
}
run() { OUT="$("$CHECK" "$TMP/$1" 2>&1)" && RC=0 || RC=$?; }

PLAIN='{"compilerOptions":{"strict":true}}'
INC='{"compilerOptions":{"incremental":true}}'

mkdir -p "$TMP/plain"
run plain
assert "tsc-incremental skips outside a git repo" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "not a git repository"'

git init -q "$TMP/nopkg" 2>/dev/null
run nopkg
assert "tsc-incremental skips without a package.json" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "no tsc --noEmit script"'

for cmd in 'tsc -b' 'tsc --build --noEmit' 'tsc' 'tsc --noEmit false' 'astro check' 'next build' 'echo tsc --noEmit' 'tsc-files --noEmit' \
           'pnpm --filter web exec tsc --noEmit' 'tsc --noEmit src/a.ts'; do
  mk "other" "$cmd" "$PLAIN"
  run other
  assert "tsc-incremental does not grade '$cmd'" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "no tsc --noEmit script"'
done

for cmd in 'tsc --noEmit' 'vue-tsc --noEmit' 'paraglide compile --project ./x && tsc --noEmit' 'npx tsc --noemit' \
           'node ./node_modules/.bin/tsc --noEmit' \
           'tsc --noEmit --incremental false'; do
  mk "detect" "$cmd" "$PLAIN"
  run detect
  assert "tsc-incremental warns on '$cmd' without incremental" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "tsconfig.json: incremental is off"'
done
assert "tsc-incremental prints the fix" 'echo "$OUT" | grep -q "\"incremental\": true" && echo "$OUT" | grep -q "keep \*.tsbuildinfo in .gitignore" && echo "$OUT" | grep -q "beside the tsconfig"'

mk flag 'tsc --noEmit --incremental' "$PLAIN"
run flag
assert "tsc-incremental accepts --incremental in the script" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "tsc-incremental: ok"'
mk on 'tsc --noEmit' "$INC"
run on
assert "tsc-incremental accepts incremental in the config" '[ "$RC" -eq 0 ]'
mk composite 'vue-tsc --noEmit' '{"compilerOptions":{"composite":true}}'
run composite
assert "tsc-incremental accepts composite in the config" '[ "$RC" -eq 0 ]'

for flag in -p --project; do
  mk proj "tsc $flag tsconfig.app.json --noEmit" "$INC"
  printf '%s\n' "$PLAIN" > "$TMP/proj/tsconfig.app.json"
  run proj
  assert "tsc-incremental grades the $flag file, not the default" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "tsconfig.app.json: incremental is off"'
done
mk projdir 'tsc -p app --noEmit'
mkdir "$TMP/projdir/app" && printf '%s\n' "$PLAIN" > "$TMP/projdir/app/tsconfig.json"
run projdir
assert "tsc-incremental reads tsconfig.json in a -p directory" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "app/tsconfig.json: incremental"'
mk cdir 'cd web && tsc --noEmit' "$INC"
mkdir "$TMP/cdir/web" && printf '%s\n' "$PLAIN" > "$TMP/cdir/web/tsconfig.json"
run cdir
assert "tsc-incremental follows cd before tsc" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "web/tsconfig.json: incremental"'
for cmd in '(cd web && tsc --noEmit)' '(cd web && tsc --noEmit) && tsc --noEmit'; do
  mk subshell "$cmd" "$INC"
  mkdir -p "$TMP/subshell/web" && printf '%s\n' "$PLAIN" > "$TMP/subshell/web/tsconfig.json"
  run subshell
  assert "tsc-incremental follows cd in '$cmd'" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "web/tsconfig.json: incremental"'
done
mk subroot '(cd web && tsc --noEmit) && tsc --noEmit' "$PLAIN"
mkdir "$TMP/subroot/web" && printf '%s\n' "$INC" > "$TMP/subroot/web/tsconfig.json"
run subroot
assert "tsc-incremental leaves the subshell directory after )" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "WARN: tsconfig.json: incremental"'

# Workspaces: tracked packages count; ignored, even when tracked, and fixtures do not.
git init -q "$TMP/ws" 2>/dev/null
mkdir -p "$TMP/ws/packages/ui" "$TMP/ws/vendor/dep" "$TMP/ws/tests/fixtures/a" "$TMP/ws/node_modules/b"
for d in packages/ui vendor/dep tests/fixtures/a node_modules/b; do
  printf '{"scripts":{"t":"tsc --noEmit"}}\n' > "$TMP/ws/$d/package.json"
  printf '%s\n' "$PLAIN" > "$TMP/ws/$d/tsconfig.json"
done
track "$TMP/ws"
printf 'vendor/\nnode_modules/\n' > "$TMP/ws/.gitignore"
run ws
assert "tsc-incremental grades a tracked workspace package" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "packages/ui/tsconfig.json: incremental is off"'
assert "tsc-incremental skips ignored and fixture packages" '! echo "$OUT" | grep -qE "vendor|fixtures|node_modules/b"'

# --- config resolution: JSONC and extends ---

mk jsonc 'tsc --noEmit' '{
  // "incremental": false, with a trailing comma
  "include": ["src/**/*.ts"], /* "x" */
  "compilerOptions": {
    "paths": { "@/*": ["./src/*"], "u": ["http://x", "a,]", "q\"// "] },
    "incremental": true, // on
  },
}'
run jsonc
assert "tsc-incremental reads comments, trailing commas and /* in strings" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "tsc-incremental: ok"'
mk jsoncoff 'tsc --noEmit' '{"compilerOptions":{"paths":{"@/*":["*/x"]},
  /* "incremental": true, */ // "incremental": true
}}'
run jsoncoff
assert "tsc-incremental does not count a commented-out incremental" '[ "$RC" -eq 1 ]'

# ext <name> <child> <base> — a tsconfig that extends configs/base.json.
ext() {
  mk "$1" 'tsc --noEmit' "$2"
  mkdir -p "$TMP/$1/configs"
  printf '%s\n' "$3" > "$TMP/$1/configs/base.json"
}
ext extstr '{"extends":"./configs/base"}' "$INC"
run extstr
assert "tsc-incremental inherits incremental through extends" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "tsc-incremental: ok"'
ext extchain '{"extends":"./configs/base.json"}' '{"extends":"./root.json"}'
printf '%s\n' "$INC" > "$TMP/extchain/configs/root.json"
run extchain
assert "tsc-incremental follows an extends chain" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "tsc-incremental: ok"'
ext extoff '{"extends":"./configs/base.json","compilerOptions":{"incremental":false}}' "$INC"
run extoff
assert "tsc-incremental lets the child win with false" '[ "$RC" -eq 1 ]'
ext extarr '{"extends":["./configs/base.json","./configs/off.json"]}' "$INC"
printf '{"compilerOptions":{"incremental":false}}\n' > "$TMP/extarr/configs/off.json"
run extarr
assert "tsc-incremental lets the last extends entry win" '[ "$RC" -eq 1 ]'
ext extplain '{"extends":"./configs/base.json"}' "$PLAIN"
run extplain
assert "tsc-incremental warns when no config in the chain sets it" '[ "$RC" -eq 1 ]'

mk extnpm 'tsc --noEmit' '{"extends":"@tsconfig/strictest/tsconfig.json"}'
run extnpm
assert "tsc-incremental gives no finding on an npm extends" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "extends @tsconfig/strictest"'
ext extloop '{"extends":"./configs/base.json"}' '{"extends":"../tsconfig.json"}'
run extloop
assert "tsc-incremental survives a circular extends" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "configs/base.json extends .* circular .* skipped"'
mk extgone 'tsc --noEmit' '{"extends":"./gone.json"}'
run extgone
assert "tsc-incremental gives no finding on a missing extends" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "gone.json"'
ext extbad '{"extends":"./configs/base.json"}' '{"compilerOptions":'
run extbad
assert "tsc-incremental names the malformed base config" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "tsc-incremental: configs/base.json is not readable JSON — skipped"'
mk solution 'tsc --noEmit' '{"files":[],"references":[{"path":"./app"}]}'
run solution
assert "tsc-incremental skips a solution-style config" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "tsconfig.json has no files of its own, only references — skipped"'
mk noconfig 'tsc --noEmit'
run noconfig
assert "tsc-incremental skips a missing tsconfig" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "tsconfig.json not found"'

# --- malformed input: one visible skip note, never a crash ---

for body in '{"compilerOptions":' '[]' '{"compilerOptions":"x","extends":7}'; do
  mk bad 'tsc --noEmit' "$body"
  run bad
  assert "tsc-incremental skips tsconfig $body" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "tsconfig.json .*skipped" && ! echo "$OUT" | grep -q Traceback'
done
mk badpkg 'tsc --noEmit' "$PLAIN"
for body in '{"scripts":' '[]'; do
  printf '%s\n' "$body" > "$TMP/badpkg/package.json"
  run badpkg
  assert "tsc-incremental skips package.json $body" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "package.json is not readable JSON — skipped" && ! echo "$OUT" | grep -q Traceback'
done
for body in '{"scripts":[]}' '{"scripts":{"t":1}}' '{"scripts":{"t":"tsc --noEmit \"x"}}'; do
  printf '%s\n' "$body" > "$TMP/badpkg/package.json"
  run badpkg
  assert "tsc-incremental survives package.json $body" '[ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q Traceback'
done

# --- where the buildinfo lands ---

mk unignored 'tsc --noEmit' "$INC"
printf 'node_modules/\n' > "$TMP/unignored/.gitignore"
run unignored
assert "tsc-incremental warns when the buildinfo is not ignored" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "tsconfig.tsbuildinfo is not ignored"'
printf '*.tsbuildinfo\n' > "$TMP/unignored/.gitignore"
run unignored
assert "tsc-incremental accepts an ignored buildinfo" '[ "$RC" -eq 0 ]'
mk outdir 'tsc --noEmit' '{"compilerOptions":{"incremental":true,"outDir":"dist"}}'
printf 'dist/\n' > "$TMP/outdir/.gitignore"
run outdir
assert "tsc-incremental looks for the buildinfo in outDir" '[ "$RC" -eq 0 ]'
printf '/tsconfig.tsbuildinfo\n' > "$TMP/outdir/.gitignore"
run outdir
assert "tsc-incremental names the outDir buildinfo" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "dist/tsconfig.tsbuildinfo is not ignored"'
mk rootdir 'tsc --noEmit' '{"compilerOptions":{"incremental":true,"outDir":"dist","rootDir":"src"}}'
printf 'dist/\n' > "$TMP/rootdir/.gitignore"
run rootdir
assert "tsc-incremental places the buildinfo relative to rootDir" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "WARN: tsconfig.json: tsconfig.tsbuildinfo is not ignored"'

mk shared 'tsc --noEmit' '{"compilerOptions":{"incremental":true,"tsBuildInfoFile":"./node_modules/.cache/a.tsbuildinfo"}}'
run shared
assert "tsc-incremental warns on a buildinfo in node_modules" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "tsBuildInfoFile points into node_modules"'
assert "tsc-incremental says why node_modules is wrong" 'echo "$OUT" | grep -q "costs more than a cold run"'
ext sharedext '{"extends":"./configs/base.json"}' '{"compilerOptions":{"incremental":true,"tsBuildInfoFile":"../node_modules/a.tsbuildinfo"}}'
run sharedext
assert "tsc-incremental warns on an inherited node_modules buildinfo" '[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "points into node_modules"'
mk cliflag 'tsc --noEmit --incremental --tsBuildInfoFile .cache/x' "$PLAIN"
printf '.cache/\n' > "$TMP/cliflag/.gitignore"
run cliflag
assert "tsc-incremental does not grade a --tsBuildInfoFile script" '[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "no tsc --noEmit script"'
mk custom 'tsc --noEmit' '{"compilerOptions":{"incremental":true,"tsBuildInfoFile":"./build.info"}}'
run custom
assert "tsc-incremental leaves an explicit buildinfo elsewhere alone" '[ "$RC" -eq 0 ]'

# The hygiene runner exposes it as a section, like every other.
HYG_OUT="$("$AIKIT/bin/ai-kit-hygiene.sh" "$TMP/detect" --skip-doctor --skip-dedupe --skip-symmetry --skip-memory --skip-repo-skills --skip-context-lean --skip-secrets-gate --skip-test-ci 2>&1)" && HYG_RC=0 || HYG_RC=$?
assert "hygiene scores the finding as a warning" '[ "$HYG_RC" -eq 1 ] && echo "$HYG_OUT" | grep -q "^Score: 95/100" && echo "$HYG_OUT" | grep -q "ai-kit-tsc-incremental.sh"'

print_summary_and_exit
