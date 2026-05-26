#!/usr/bin/env bash
set -euo pipefail
AIKIT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../lib/harness.sh
source "$AIKIT/tests/bin/lib/harness.sh"

LOADER="$AIKIT/bin/audit-extension-loader.sh"

echo "=== loader-exists ==="
assert "loader script exists + executable" '[ -x "$LOADER" ]'

# Build an isolated fake skills directory so test is independent of any real
# extensions that ship in workflow/skills/.
FAKE_ROOT=$(mktemp -d)
trap 'rm -rf "$FAKE_ROOT"' EXIT

mkdir -p "$FAKE_ROOT/workflow/skills/audit-architecture-laravel"
cat > "$FAKE_ROOT/workflow/skills/audit-architecture-laravel/SKILL.md" <<'SKILL_EOF'
---
name: audit-architecture-laravel
description: fake laravel ext
extends: audit-architecture
applies_to:
  frameworks: ["laravel"]
  languages: []
---
fake body
SKILL_EOF

mkdir -p "$FAKE_ROOT/workflow/skills/audit-architecture-react"
cat > "$FAKE_ROOT/workflow/skills/audit-architecture-react/SKILL.md" <<'SKILL_EOF'
---
name: audit-architecture-react
description: fake react ext
extends: audit-architecture
applies_to:
  frameworks: ["react", "nextjs"]
  languages: []
---
fake body
SKILL_EOF

# Orphan extension: extends field missing.
mkdir -p "$FAKE_ROOT/workflow/skills/audit-architecture-orphan"
cat > "$FAKE_ROOT/workflow/skills/audit-architecture-orphan/SKILL.md" <<'SKILL_EOF'
---
name: audit-architecture-orphan
description: missing extends field on purpose
applies_to:
  frameworks: ["laravel"]
  languages: []
---
fake body
SKILL_EOF

# Bad extends: not pointing at audit-architecture.
mkdir -p "$FAKE_ROOT/workflow/skills/audit-architecture-imposter"
cat > "$FAKE_ROOT/workflow/skills/audit-architecture-imposter/SKILL.md" <<'SKILL_EOF'
---
name: audit-architecture-imposter
description: extends points at the wrong skill
extends: some-other-skill
applies_to:
  frameworks: ["laravel"]
  languages: []
---
fake body
SKILL_EOF

# Build a minimal Laravel-shaped target on disk: composer.json with
# laravel/framework is what detect_frameworks() looks for.
TARGET_LARAVEL=$(mktemp -d)
cat > "$TARGET_LARAVEL/composer.json" <<'JSON'
{
  "name": "ext-loader/test-target",
  "require": {
    "laravel/framework": "^12.0"
  }
}
JSON

assert "laravel target composer.json present" '[ -f "$TARGET_LARAVEL/composer.json" ]'

# A pure-empty target with no detectable framework — for the negative case.
EMPTY_TARGET=$(mktemp -d)
echo "{}" > "$EMPTY_TARGET/package.json"

echo "=== AC1-match-laravel ==="
# Laravel-shaped target -> loader should emit the laravel extension path.
OUTPUT=$(AI_KIT_AUDIT_SKILLS_DIR="$FAKE_ROOT/workflow/skills" "$LOADER" "$TARGET_LARAVEL" 2>/dev/null || true)
assert "matches audit-architecture-laravel on laravel target" \
  'echo "$OUTPUT" | grep -q "audit-architecture-laravel/SKILL.md$"'
assert "does NOT match audit-architecture-react on laravel target" \
  '! echo "$OUTPUT" | grep -q "audit-architecture-react/SKILL.md$"'
assert "imposter (bad extends) NOT in output" \
  '! echo "$OUTPUT" | grep -q "audit-architecture-imposter"'
assert "orphan (missing extends) NOT in output" \
  '! echo "$OUTPUT" | grep -q "audit-architecture-orphan"'

echo "=== AC1-no-match-empty ==="
# Target with no detectable framework -> loader emits nothing.
OUTPUT_EMPTY=$(AI_KIT_AUDIT_SKILLS_DIR="$FAKE_ROOT/workflow/skills" "$LOADER" "$EMPTY_TARGET" 2>/dev/null || true)
assert "no match on empty project -> empty stdout" \
  '[ -z "$OUTPUT_EMPTY" ]'

echo "=== AC2-opt-out ==="
# AI_KIT_AUDIT_NO_EXTEND=1 must return empty even when a match would otherwise be found.
OUTPUT_OPTOUT=$(AI_KIT_AUDIT_NO_EXTEND=1 AI_KIT_AUDIT_SKILLS_DIR="$FAKE_ROOT/workflow/skills" "$LOADER" "$TARGET_LARAVEL" 2>/dev/null || true)
assert "AI_KIT_AUDIT_NO_EXTEND=1 returns empty" \
  '[ -z "$OUTPUT_OPTOUT" ]'

echo "=== AC3-extends-validation ==="
# Loader must warn on stderr about orphan + imposter but stay exit-0.
STDERR_FILE=$(mktemp)
set +e
AI_KIT_AUDIT_SKILLS_DIR="$FAKE_ROOT/workflow/skills" "$LOADER" "$TARGET_LARAVEL" 2>"$STDERR_FILE" >/dev/null
LOADER_EXIT=$?
set -e
assert "loader exits 0 even with malformed extensions present" '[ "$LOADER_EXIT" -eq 0 ]'
assert "stderr names the imposter extension" 'grep -q "audit-architecture-imposter" "$STDERR_FILE"'
assert "stderr names the orphan extension" 'grep -q "audit-architecture-orphan" "$STDERR_FILE"'
assert "stderr explains the extends-field reason" 'grep -qE "extends:?" "$STDERR_FILE"'
rm -f "$STDERR_FILE"

echo "=== stable-order ==="
# Multiple matches must come back in stable filename-sorted order.
# Add a second laravel-matching extension so we can assert the ordering.
mkdir -p "$FAKE_ROOT/workflow/skills/audit-architecture-aaa-laravel-extra"
cat > "$FAKE_ROOT/workflow/skills/audit-architecture-aaa-laravel-extra/SKILL.md" <<'SKILL_EOF'
---
name: audit-architecture-aaa-laravel-extra
description: sorted first by filename
extends: audit-architecture
applies_to:
  frameworks: ["laravel"]
  languages: []
---
SKILL_EOF
OUTPUT_ORDERED=$(AI_KIT_AUDIT_SKILLS_DIR="$FAKE_ROOT/workflow/skills" "$LOADER" "$TARGET_LARAVEL" 2>/dev/null)
FIRST_LINE=$(echo "$OUTPUT_ORDERED" | head -1)
assert "filename-sorted: aaa-laravel-extra comes first" \
  'echo "$FIRST_LINE" | grep -q "audit-architecture-aaa-laravel-extra/SKILL.md$"'

echo "=== AC1-match-languages ==="
# Language-keyed extension (TypeScript): matches on tsconfig.json presence
# even when no framework is detected.
mkdir -p "$FAKE_ROOT/workflow/skills/audit-architecture-typescript"
cat > "$FAKE_ROOT/workflow/skills/audit-architecture-typescript/SKILL.md" <<'SKILL_EOF'
---
name: audit-architecture-typescript
description: language-keyed
extends: audit-architecture
applies_to:
  frameworks: []
  languages: ["typescript"]
---
SKILL_EOF

# Block-list YAML form (regression guard for the parser supporting it).
mkdir -p "$FAKE_ROOT/workflow/skills/audit-architecture-flutter"
cat > "$FAKE_ROOT/workflow/skills/audit-architecture-flutter/SKILL.md" <<'SKILL_EOF'
---
name: audit-architecture-flutter
description: language-keyed block-list form
extends: audit-architecture
applies_to:
  frameworks:
    - flutter
  languages:
    - dart
---
SKILL_EOF

TS_TARGET=$(mktemp -d)
cat > "$TS_TARGET/tsconfig.json" <<'JSON'
{ "compilerOptions": { "strict": true } }
JSON

OUTPUT_TS=$(AI_KIT_AUDIT_SKILLS_DIR="$FAKE_ROOT/workflow/skills" "$LOADER" "$TS_TARGET" 2>/dev/null || true)
assert "ts-keyed extension matches on tsconfig.json target" \
  'echo "$OUTPUT_TS" | grep -q "audit-architecture-typescript/SKILL.md$"'

DART_TARGET=$(mktemp -d)
cat > "$DART_TARGET/pubspec.yaml" <<'YAML'
name: dart_target
environment:
  sdk: ">=3.6.0 <4.0.0"
YAML

OUTPUT_DART=$(AI_KIT_AUDIT_SKILLS_DIR="$FAKE_ROOT/workflow/skills" "$LOADER" "$DART_TARGET" 2>/dev/null || true)
assert "block-list dart-keyed extension matches on pubspec.yaml target" \
  'echo "$OUTPUT_DART" | grep -q "audit-architecture-flutter/SKILL.md$"'

rm -rf "$TS_TARGET" "$DART_TARGET"

echo "=== default-skills-dir ==="
# When AI_KIT_AUDIT_SKILLS_DIR is unset, loader must default to AIKIT/workflow/skills.
# No bundled extensions exist yet (this PR ships only the loader + contract),
# so on the laravel fixture the default lookup MUST return empty.
OUTPUT_DEFAULT=$("$LOADER" "$TARGET_LARAVEL" 2>/dev/null || true)
assert "default skills-dir empty (no bundled extensions yet)" \
  '[ -z "$OUTPUT_DEFAULT" ]'

rm -rf "$EMPTY_TARGET" "$TARGET_LARAVEL"

print_summary_and_exit
