#!/usr/bin/env bash
# audit-architecture-laravel helper-script.
#
# Sub-commands:
#   detect_mode <project-path>   -> "api-only" | "full-stack"
#   run_tools   <project-path>   -> one-line "Tools ingested: ..." header; caches raw output
#   phpstan_level_check <project-path>  -> finding row(s) under dimension 9; empty if no phpstan.neon
#
# Env:
#   AI_KIT_AUDIT_LARAVEL_MODE=api-only|full-stack  -> overrides detect_mode
#
# Tool-gate protocol: every external tool is wrapped with `command -v` and a
# degrade-to-✗ fallback. Tool absence is never fatal. See
# standards/contracts/audit-architecture-extension.contract.md.

set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 <subcommand> <project-path>

Subcommands:
  detect_mode <project-path>
  run_tools <project-path>
  phpstan_level_check <project-path>
EOF
  exit 2
}

if [ $# -lt 2 ]; then usage; fi

SUB="$1"
TARGET="$(cd "$2" && pwd)"

# ------------------------- detect_mode -------------------------
detect_mode() {
  local target="$1"
  local override="${AI_KIT_AUDIT_LARAVEL_MODE:-}"

  if [ -n "$override" ]; then
    case "$override" in
      api-only|full-stack)
        echo "$override"
        return 0
        ;;
      *)
        echo "audit-laravel-helpers: invalid AI_KIT_AUDIT_LARAVEL_MODE='$override' (expected api-only|full-stack)" >&2
        exit 2
        ;;
    esac
  fi

  local has_api_routes=false
  local has_views=false
  local has_inertia=false
  local has_livewire=false

  if [ -s "$target/routes/api.php" ]; then
    # Non-empty + contains at least one Route:: call (not just a stub).
    if grep -qE 'Route::|->' "$target/routes/api.php" 2>/dev/null; then
      has_api_routes=true
    fi
  fi

  if [ -d "$target/resources/views" ]; then
    if find "$target/resources/views" -type f -name '*.blade.php' 2>/dev/null | grep -q .; then
      has_views=true
    fi
  fi

  if [ -f "$target/composer.json" ]; then
    if grep -qE '"inertiajs/inertia-laravel"' "$target/composer.json" 2>/dev/null; then
      has_inertia=true
    fi
    if grep -qE '"livewire/livewire"' "$target/composer.json" 2>/dev/null; then
      has_livewire=true
    fi
  fi

  # full-stack wins when both signals are present (safer default).
  if [ "$has_views" = true ] || [ "$has_inertia" = true ] || [ "$has_livewire" = true ]; then
    echo "full-stack"
    return 0
  fi

  if [ "$has_api_routes" = true ]; then
    echo "api-only"
    return 0
  fi

  # Bare Laravel with neither routes/api.php nor views — treat as full-stack
  # (safer default; nothing to skip).
  echo "full-stack"
}

# ------------------------- run_tools -------------------------
run_tools() {
  local target="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local cache="${TMPDIR:-/tmp}/ai-kit-audit-laravel-$ts"
  mkdir -p "$cache"

  local larastan="✗"
  local composer_outdated="✗"
  local artisan_about="✗"

  if command -v phpstan >/dev/null 2>&1 || \
     [ -x "$target/vendor/bin/phpstan" ]; then
    local phpstan_bin
    if [ -x "$target/vendor/bin/phpstan" ]; then
      phpstan_bin="$target/vendor/bin/phpstan"
    else
      phpstan_bin="$(command -v phpstan)"
    fi
    if "$phpstan_bin" analyze --error-format=json --no-progress 2>/dev/null \
        > "$cache/larastan.json" \
        || [ -s "$cache/larastan.json" ]; then
      larastan="✓"
    fi
  fi

  if command -v composer >/dev/null 2>&1; then
    if (cd "$target" && composer outdated --direct --strict --format=json 2>/dev/null) \
        > "$cache/composer-outdated.json"; then
      composer_outdated="✓"
    fi
  fi

  if command -v php >/dev/null 2>&1 && [ -f "$target/artisan" ]; then
    if (cd "$target" && php artisan about --json 2>/dev/null) \
        > "$cache/artisan-about.json"; then
      artisan_about="✓"
    fi
  fi

  echo "**Tools ingested:** Larastan $larastan · composer outdated $composer_outdated · php artisan about $artisan_about"
  echo "Cache: $cache"
}

# ------------------------- phpstan_level_check -------------------------
phpstan_level_check() {
  local target="$1"
  local cfg=""
  for candidate in phpstan.neon phpstan.neon.dist; do
    if [ -f "$target/$candidate" ]; then
      cfg="$target/$candidate"
      break
    fi
  done
  if [ -z "$cfg" ]; then
    return 0
  fi
  local level
  level="$(grep -E '^\s*level:' "$cfg" | head -1 | awk '{print $2}')"
  if [ -z "$level" ]; then
    return 0
  fi
  if [ "$level" -lt 9 ] 2>/dev/null; then
    echo "$cfg:1 · 🟡 · L-phpstan PHPStan/Larastan level=$level below 9 · $cfg pins below max strictness · raise to level 9 (or document opt-out)"
  fi
}

case "$SUB" in
  detect_mode) detect_mode "$TARGET" ;;
  run_tools) run_tools "$TARGET" ;;
  phpstan_level_check) phpstan_level_check "$TARGET" ;;
  *) usage ;;
esac
