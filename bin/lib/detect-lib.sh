#!/usr/bin/env bash
# Shared detection helpers for ai-kit bin scripts.
# Source this file, then call detect_* functions with a project directory.

# Official docs suggestions (agent verifies live)
docs_url_for() {
  case "$1" in
    laravel) echo "https://laravel.com/docs" ;;
    react) echo "https://react.dev" ;;
    nextjs) echo "https://nextjs.org/docs" ;;
    vue) echo "https://vuejs.org/guide" ;;
    astro) echo "https://docs.astro.build" ;;
    inertia) echo "https://inertiajs.com" ;;
    nx) echo "https://nx.dev" ;;
    pnpm) echo "https://pnpm.io" ;;
    npm) echo "https://docs.npmjs.com" ;;
    composer) echo "https://getcomposer.org/doc" ;;
    *) echo "" ;;
  esac
}

detect_package_manager() {
  local target="$1"
  PM_NAME=""
  INSTALL_CMD=""
  AUDIT_CMD=""
  HAS_JS=false
  HAS_PHP=false
  COPY_NODE_MODULES=false

  if [ -f "$target/pnpm-lock.yaml" ]; then
    PM_NAME="pnpm"
    INSTALL_CMD="pnpm install"
    AUDIT_CMD="pnpm audit"
    HAS_JS=true
    COPY_NODE_MODULES=true
  elif [ -f "$target/yarn.lock" ]; then
    PM_NAME="yarn"
    INSTALL_CMD="yarn install"
    AUDIT_CMD="yarn npm audit"
    HAS_JS=true
    COPY_NODE_MODULES=true
  elif [ -f "$target/package-lock.json" ]; then
    PM_NAME="npm"
    INSTALL_CMD="npm ci"
    AUDIT_CMD="npm audit"
    HAS_JS=true
    COPY_NODE_MODULES=true
  elif [ -f "$target/package.json" ]; then
    PM_NAME="npm"
    INSTALL_CMD="npm install"
    AUDIT_CMD="npm audit"
    HAS_JS=true
    COPY_NODE_MODULES=true
  fi

  if [ -f "$target/composer.lock" ] || [ -f "$target/composer.json" ]; then
    HAS_PHP=true
    if [ -z "$INSTALL_CMD" ]; then
      PM_NAME="composer"
      INSTALL_CMD="composer install"
      AUDIT_CMD="composer audit"
    else
      AUDIT_CMD="${AUDIT_CMD}; composer audit"
    fi
  fi
}

detect_dependencies() {
  local target="$1"
  DEPENDENCIES_JSON="[]"

  DEPENDENCIES_JSON="$(python3 -c "
import json

names = set()

def collect(path, keys):
    try:
        data = json.load(open(path))
    except Exception:
        return
    for key in keys:
        section = data.get(key) or {}
        if isinstance(section, dict):
            names.update(str(n) for n in section)

collect('$target/package.json', ('dependencies', 'devDependencies'))
collect('$target/composer.json', ('require', 'require-dev'))
names.discard('php')
print(json.dumps(sorted(names)))
" 2>/dev/null || true)"

  if [ -z "$DEPENDENCIES_JSON" ]; then
    DEPENDENCIES_JSON="[]"
  fi
}

detect_frameworks() {
  local target="$1"
  FRAMEWORKS=()

  if [ -f "$target/package.json" ]; then
    if grep -qE '"next"' "$target/package.json" 2>/dev/null; then
      FRAMEWORKS+=("nextjs")
    fi
    if grep -qE '"astro"' "$target/package.json" 2>/dev/null; then
      FRAMEWORKS+=("astro")
    fi
    if grep -qE '"react"' "$target/package.json" 2>/dev/null; then
      FRAMEWORKS+=("react")
    fi
    if grep -qE '"vue"' "$target/package.json" 2>/dev/null; then
      FRAMEWORKS+=("vue")
    fi
    if grep -qE '"@inertiajs/' "$target/package.json" 2>/dev/null; then
      FRAMEWORKS+=("inertia")
    fi
  fi

  if [ -f "$target/composer.json" ]; then
    if grep -qE 'laravel/framework' "$target/composer.json" 2>/dev/null; then
      FRAMEWORKS+=("laravel")
    fi
  fi

  if [ -f "$target/nx.json" ]; then
    FRAMEWORKS+=("nx")
  fi

  # shadcn/ui: copy-paste components, no package.json dep. Signal is the
  # `components.json` CLI config at repo root (created by `shadcn init`).
  if [ -f "$target/components.json" ] && grep -qE '"\$schema"\s*:\s*"https://ui\.shadcn\.com/schema\.json"' "$target/components.json" 2>/dev/null; then
    FRAMEWORKS+=("shadcn")
  fi
}

detect_docker() {
  local target="$1"
  DOCKER_REC="none"
  DOCKER_FILES=()

  for f in compose.yaml docker-compose.yml docker-compose.yaml Dockerfile Dockerfile.dev; do
    if [ -f "$target/$f" ]; then
      DOCKER_FILES+=("$f")
    fi
  done

  if [ -d "$target/.devcontainer" ]; then
    DOCKER_FILES+=(".devcontainer/")
  fi

  if [ "${#DOCKER_FILES[@]}" -gt 0 ]; then
    DOCKER_REC="existing"
  fi
}

detect_deploy_shape() {
  local target="$1"
  DEPLOY_SHAPE="unknown"
  DEPLOY_SERVERLESS_MARKERS=()
  DEPLOY_SELF_HOST_MARKERS=()
  DEPLOY_COOLIFY=false

  for f in vercel.json netlify.toml wrangler.toml wrangler.jsonc wrangler.json serverless.yml serverless.yaml template.yaml sam-template.yaml; do
    if [ -f "$target/$f" ]; then
      DEPLOY_SERVERLESS_MARKERS+=("$f")
    fi
  done

  local has_dockerfile=false
  local has_compose=false
  [ -f "$target/Dockerfile" ] && has_dockerfile=true
  for f in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
    if [ -f "$target/$f" ]; then
      has_compose=true
      DEPLOY_SELF_HOST_MARKERS+=("$f")
    fi
  done
  if [ "$has_dockerfile" = true ]; then
    DEPLOY_SELF_HOST_MARKERS+=("Dockerfile")
  fi

  for f in .coolify coolify.json coolify.yml coolify.yaml; do
    if [ -e "$target/$f" ]; then
      DEPLOY_COOLIFY=true
      DEPLOY_SELF_HOST_MARKERS+=("$f")
    fi
  done

  local has_serverless=false
  local has_self_host=false
  [ "${#DEPLOY_SERVERLESS_MARKERS[@]}" -gt 0 ] && has_serverless=true
  if [ "$has_dockerfile" = true ] && [ "$has_compose" = true ]; then
    has_self_host=true
  fi
  [ "$DEPLOY_COOLIFY" = true ] && has_self_host=true

  if [ "$has_serverless" = true ] && [ "$has_self_host" = true ]; then
    DEPLOY_SHAPE="mixed"
  elif [ "$has_serverless" = true ]; then
    DEPLOY_SHAPE="serverless"
  elif [ "$has_self_host" = true ]; then
    DEPLOY_SHAPE="self-host"
  fi
}

detect_issue_tracker() {
  local target="$1"
  TRACKER_REC="unknown"
  TRACKER_REMOTE=""

  if [ -d "$target/.scratch" ]; then
    TRACKER_REC="local"
    return
  fi

  if [ -d "$target/.git" ]; then
    TRACKER_REMOTE="$(git -C "$target" remote get-url origin 2>/dev/null || true)"
    case "$TRACKER_REMOTE" in
      *github.com*) TRACKER_REC="github" ;;
      *gitlab*) TRACKER_REC="gitlab" ;;
      *) TRACKER_REC="unknown" ;;
    esac
  fi
}

detect_domain_layout() {
  local target="$1"
  DOMAIN_LAYOUT="missing"
  HAS_CONTEXT=false
  HAS_ADR=false

  if [ -f "$target/CONTEXT-MAP.md" ]; then
    DOMAIN_LAYOUT="multi"
    HAS_CONTEXT=true
  elif [ -f "$target/CONTEXT.md" ]; then
    DOMAIN_LAYOUT="single"
    HAS_CONTEXT=true
  fi

  if [ -d "$target/docs/adr" ] && [ -n "$(find "$target/docs/adr" -maxdepth 1 -name '*.md' 2>/dev/null | head -1)" ]; then
    HAS_ADR=true
  fi
}

_has_skills_layout() {
  # Accept both layouts: --link-all (symlink to ai-kit's skills) and
  # --merge-skills (regular dir whose entries are symlinks per skill). Either
  # way the path must dereference to a non-empty directory.
  local p="$1"
  [ -e "$p" ] && [ -d "$p" ] && [ -n "$(ls -A "$p" 2>/dev/null)" ]
}

# Return the ai-kit primitives root (where skills/, agents/, commands/ live).
# Dev clone: $root/workflow ; plugin install: $root.
_aikit_primitives_root() {
  local root="$1"
  if [ -d "$root/workflow/skills" ]; then
    echo "$root/workflow"
  else
    echo "$root"
  fi
}

detect_bootstrap_state() {
  local target="$1"
  BOOTSTRAP_STATE="missing"
  BOOTSTRAP_MISSING=()

  local has_agents=false
  local has_cursor=false

  if [ -f "$target/AGENTS.md" ] || [ -f "$target/CLAUDE.md" ]; then
    has_agents=true
  else
    BOOTSTRAP_MISSING+=("AGENTS.md")
  fi

  if ! _has_skills_layout "$target/.claude/skills"; then
    BOOTSTRAP_MISSING+=(".claude/skills")
  fi

  if ! _has_skills_layout "$target/.agents/skills"; then
    BOOTSTRAP_MISSING+=(".agents/skills")
  fi

  if _has_skills_layout "$target/.cursor/skills"; then
    has_cursor=true
  else
    BOOTSTRAP_MISSING+=(".cursor/skills")
  fi

  if [ "$has_agents" = true ] && [ "${#BOOTSTRAP_MISSING[@]}" -eq 0 ]; then
    BOOTSTRAP_STATE="complete"
  elif [ "$has_agents" = true ] || [ "${#BOOTSTRAP_MISSING[@]}" -lt 3 ]; then
    BOOTSTRAP_STATE="partial"
  else
    BOOTSTRAP_STATE="missing"
  fi
}

detect_npm_scripts() {
  local target="$1"
  SCRIPT_TEST=""
  SCRIPT_BUILD=""
  SCRIPT_LINT=""

  if [ ! -f "$target/package.json" ]; then
    return
  fi

  SCRIPT_TEST="$(python3 -c "
import json, sys
try:
    s = json.load(open('$target/package.json')).get('scripts', {})
    for k in ('test', 'test:unit', 'test:ci'):
        if k in s:
            print(s[k]); break
except Exception:
    pass
" 2>/dev/null || true)"

  SCRIPT_BUILD="$(python3 -c "
import json
try:
    s = json.load(open('$target/package.json')).get('scripts', {})
    for k in ('build', 'compile'):
        if k in s:
            print(s[k]); break
except Exception:
    pass
" 2>/dev/null || true)"

  SCRIPT_LINT="$(python3 -c "
import json
try:
    s = json.load(open('$target/package.json')).get('scripts', {})
    for k in ('lint', 'eslint'):
        if k in s:
            print(s[k]); break
except Exception:
    pass
" 2>/dev/null || true)"
}

detect_architecture() {
  local target="$1"
  ARCH_FE=""
  ARCH_BE=""
  ARCH_FE_PATHS=()
  ARCH_BE_PATHS=()
  ARCH_MONOREPO=false
  ARCH_RECOMMENDATION="skip-or-ask"

  if [ -f "$target/nx.json" ]; then
    ARCH_MONOREPO=true
    if compgen -G "$target/apps/*/src" >/dev/null 2>&1; then
      ARCH_FE="nx-monorepo"
      for d in "$target"/apps/*/src; do
        [ -d "$d" ] && ARCH_FE_PATHS+=("${d#$target/}")
      done
    fi
    if [ -d "$target/libs" ]; then
      ARCH_BE="modular-monolith"
      ARCH_BE_PATHS+=("libs/")
    fi
  fi

  if [ -z "$ARCH_FE" ]; then
    if [ -d "$target/resources/js/Pages" ] || [ -d "$target/resources/js/pages" ]; then
      ARCH_FE="laravel-inertia"
      ARCH_FE_PATHS+=("resources/js/Pages")
    elif [ -d "$target/src/features" ]; then
      ARCH_FE="feature-folders"
      ARCH_FE_PATHS+=("src/features/")
    elif [ -d "$target/features" ]; then
      ARCH_FE="feature-folders"
      ARCH_FE_PATHS+=("features/")
    elif [ -d "$target/app/pages" ]; then
      ARCH_FE="pages-components"
      ARCH_FE_PATHS+=("app/pages/")
      [ -d "$target/components" ] && ARCH_FE_PATHS+=("components/")
      [ -d "$target/app/components" ] && ARCH_FE_PATHS+=("app/components/")
    fi
  fi

  if [ -z "$ARCH_BE" ]; then
    if [ -d "$target/internal" ] && { [ -d "$target/ports" ] || [ -d "$target/internal/ports" ]; }; then
      ARCH_BE="ports-adapters"
      ARCH_BE_PATHS+=("internal/")
      [ -d "$target/ports" ] && ARCH_BE_PATHS+=("ports/")
    elif [ -d "$target/src/Domain" ]; then
      ARCH_BE="domain-centric"
      ARCH_BE_PATHS+=("src/Domain/")
    elif [ -d "$target/Domain" ]; then
      ARCH_BE="domain-centric"
      ARCH_BE_PATHS+=("Domain/")
    elif [ -d "$target/app/Actions" ] || [ -d "$target/app/Services" ]; then
      ARCH_BE="action-service"
      [ -d "$target/app/Actions" ] && ARCH_BE_PATHS+=("app/Actions/")
      [ -d "$target/app/Services" ] && ARCH_BE_PATHS+=("app/Services/")
    elif [ -d "$target/app/Http/Controllers" ]; then
      ARCH_BE="laravel-default"
      ARCH_BE_PATHS+=("app/Http/Controllers/")
    fi
  fi

  if [ -n "$ARCH_FE" ] || [ -n "$ARCH_BE" ]; then
    ARCH_RECOMMENDATION="document-existing"
  fi
}

# Detect a generic (non-Nx) monorepo: depth-1 child directories that each carry
# a package manifest. Two or more such app dirs = monorepo. detect_architecture
# only flags Nx workspaces (nx.json); this catches everything else — a Laravel
# backend beside React/Next frontends, Go services, etc. Sets MONOREPO_DETECTED
# and MONOREPO_APPS (relative dir names).
detect_monorepo() {
  local target="$1"
  MONOREPO_DETECTED=false
  MONOREPO_APPS=()

  local d name
  for d in "$target"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    case "$name" in
      node_modules | vendor | dist | build | tmp | coverage) continue ;;
    esac
    if [ -f "${d}composer.json" ] || [ -f "${d}package.json" ] \
      || [ -f "${d}go.mod" ] || [ -f "${d}pyproject.toml" ] \
      || [ -f "${d}Cargo.toml" ]; then
      MONOREPO_APPS+=("$name")
    fi
  done

  if [ "${#MONOREPO_APPS[@]}" -ge 2 ]; then
    MONOREPO_DETECTED=true
  fi
}

# Detect Laravel Boost. Boost ships as the laravel/boost composer package and
# regenerates an AGENTS.md carrying a <laravel-boost-guidelines> block. Scans
# the target root and depth-1 child dirs (monorepos keep the Laravel app in a
# subdir). Sets BOOST_DETECTED and BOOST_MANAGED_FILES — relative paths of
# AGENTS.md files ai-kit must never patch, since Boost overwrites them.
detect_boost() {
  local target="$1"
  BOOST_DETECTED=false
  BOOST_MANAGED_FILES=()

  local dirs d name rel
  dirs=("$target")
  for d in "$target"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    case "$name" in
      node_modules | vendor | dist | build | tmp | coverage) continue ;;
    esac
    dirs+=("${d%/}")
  done

  for d in "${dirs[@]}"; do
    if [ -f "$d/composer.json" ] \
      && grep -q '"laravel/boost"' "$d/composer.json" 2>/dev/null; then
      BOOST_DETECTED=true
    fi
    if [ -f "$d/AGENTS.md" ] \
      && grep -q '<laravel-boost-guidelines>' "$d/AGENTS.md" 2>/dev/null; then
      BOOST_DETECTED=true
      rel="$d/AGENTS.md"
      rel="${rel#"$target"/}"
      BOOST_MANAGED_FILES+=("$rel")
    fi
  done
}

# Historical ai-kit Cursor rule basenames (without .mdc). ai-kit no longer
# generates these — list kept so legacy installs are classified correctly and
# users can identify leftover files to delete.
_aikit_rule_names() {
  echo "ai-kit legacy-code ddd-distilled refactoring aposd release-it pragmatic-baseline git-hygiene context-discipline"
}

# Detect which AI agents are configured in a target project.
# Sets DETECTED_AGENTS array (e.g. "cursor" "claude-code"). ai-kit supports
# Cursor and Claude Code; an agent counts as "present" when its config
# dir/file exists. Empty array = no agents.
detect_agents() {
  local target="$1"
  DETECTED_AGENTS=()

  [ -d "$target/.cursor" ] && DETECTED_AGENTS+=("cursor")
  { [ -d "$target/.claude" ] || [ -f "$target/CLAUDE.md" ]; } \
    && DETECTED_AGENTS+=("claude-code")
  return 0
}

# Classify entries in a skills directory; sets _CLASS_AIKIT and _CLASS_CUSTOM arrays
_classify_skills_at() {
  local skills_path="$1"
  local aikit_root="$2"
  _CLASS_AIKIT=()
  _CLASS_CUSTOM=()

  [ -e "$skills_path" ] || return 0

  local resolved
  resolved="$(cd "$skills_path" 2>/dev/null && pwd -P)" || resolved=""

  local aikit_primitives
  aikit_primitives="$(_aikit_primitives_root "$aikit_root")"

  local aikit_skills_resolved
  aikit_skills_resolved="$(cd "$aikit_primitives/skills" 2>/dev/null && pwd -P)" || aikit_skills_resolved=""

  if [ -n "$resolved" ] && [ "$resolved" = "$aikit_skills_resolved" ]; then
    for skill in "$aikit_primitives/skills"/*/; do
      [ -d "$skill" ] && _CLASS_AIKIT+=("$(basename "$skill")")
    done
    return 0
  fi

  local known="" name
  for skill in "$aikit_primitives/skills"/*/; do
    known+=" $(basename "$skill") "
  done

  if [ -d "$skills_path" ]; then
    for entry in "$skills_path"/*; do
      [ -e "$entry" ] || continue
      name="$(basename "$entry")"
      if [[ "$known" == *" $name "* ]]; then
        _CLASS_AIKIT+=("$name")
      else
        _CLASS_CUSTOM+=("$name")
      fi
    done
  fi
}

detect_agent_stack() {
  local target="$1"
  local aikit_root="$2"

  AGENT_STACK_CURSOR_SKILLS_AIKIT=()
  AGENT_STACK_CURSOR_SKILLS_CUSTOM=()
  AGENT_STACK_AGENTS_SKILLS_AIKIT=()
  AGENT_STACK_AGENTS_SKILLS_CUSTOM=()
  AGENT_STACK_RULES_AIKIT=()
  AGENT_STACK_RULES_CUSTOM=()
  AGENT_STACK_COMMANDS=()
  AGENT_STACK_MCP=()
  AGENT_STACK_GLOBAL_CURSOR=()
  AGENT_STACK_GLOBAL_AGENTS=()
  AGENT_STACK_HAS_AGENTS_MD=false
  AGENT_STACK_HAS_CLAUDE_MD=false
  AGENT_STACK_RECOMMENDATION="solo-both"
  AGENT_STACK_NEEDS_DOC=false

  [ -f "$target/AGENTS.md" ] && AGENT_STACK_HAS_AGENTS_MD=true
  [ -f "$target/CLAUDE.md" ] && AGENT_STACK_HAS_CLAUDE_MD=true

  _classify_skills_at "$target/.cursor/skills" "$aikit_root"
  AGENT_STACK_CURSOR_SKILLS_AIKIT=(${_CLASS_AIKIT[@]+"${_CLASS_AIKIT[@]}"})
  AGENT_STACK_CURSOR_SKILLS_CUSTOM=(${_CLASS_CUSTOM[@]+"${_CLASS_CUSTOM[@]}"})
  _classify_skills_at "$target/.agents/skills" "$aikit_root"
  AGENT_STACK_AGENTS_SKILLS_AIKIT=(${_CLASS_AIKIT[@]+"${_CLASS_AIKIT[@]}"})
  AGENT_STACK_AGENTS_SKILLS_CUSTOM=(${_CLASS_CUSTOM[@]+"${_CLASS_CUSTOM[@]}"})

  local known_rules rule base f seen=""
  known_rules="$(_aikit_rule_names)"
  if [ -d "$target/.cursor" ]; then
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      base="$(basename "$f" .mdc)"
      rel="${f#$target/}"
      case " $seen " in
        *" $rel "*) continue ;;
      esac
      seen="$seen $rel "
      if [[ " $known_rules " == *" $base "* ]]; then
        AGENT_STACK_RULES_AIKIT+=("$rel")
      else
        AGENT_STACK_RULES_CUSTOM+=("$rel")
      fi
    done < <(find "$target/.cursor" -name '*.mdc' 2>/dev/null)
  fi

  if [ -d "$target/.cursor/commands" ]; then
    for f in "$target/.cursor/commands"/*; do
      [ -e "$f" ] || continue
      AGENT_STACK_COMMANDS+=("$(basename "$f")")
    done
  fi

  if [ -d "$target/.cursor/agents" ]; then
    for f in "$target/.cursor/agents"/*; do
      [ -e "$f" ] || continue
      AGENT_STACK_COMMANDS+=(".cursor/agents/$(basename "$f")")
    done
  fi

  for mcp in "$target/.mcp.json" "$target/.cursor/mcp.json" "$target/.vscode/mcp.json"; do
    [ -f "$mcp" ] && AGENT_STACK_MCP+=("${mcp#$target/}")
  done

  if [ -d "${HOME}/.cursor/skills" ]; then
    for entry in "${HOME}/.cursor/skills"/*; do
      [ -d "$entry" ] || continue
      AGENT_STACK_GLOBAL_CURSOR+=("$(basename "$entry")")
    done
  fi

  if [ -d "${HOME}/.agents/skills" ]; then
    for entry in "${HOME}/.agents/skills"/*; do
      [ -d "$entry" ] || continue
      AGENT_STACK_GLOBAL_AGENTS+=("$(basename "$entry")")
    done
  fi

  local custom_skills="${#AGENT_STACK_CURSOR_SKILLS_CUSTOM[@]}"
  custom_skills=$((custom_skills + ${#AGENT_STACK_AGENTS_SKILLS_CUSTOM[@]}))
  local custom_rules="${#AGENT_STACK_RULES_CUSTOM[@]}"
  local has_commands="${#AGENT_STACK_COMMANDS[@]}"
  local has_mcp="${#AGENT_STACK_MCP[@]}"

  AGENT_STACK_NEEDS_DOC=false
  if [ "$custom_skills" -gt 0 ] || [ "$custom_rules" -gt 0 ] \
    || [ "$has_commands" -gt 0 ] || [ "$has_mcp" -gt 0 ]; then
    AGENT_STACK_NEEDS_DOC=true
  fi

  if [ "$AGENT_STACK_NEEDS_DOC" = true ]; then
    AGENT_STACK_RECOMMENDATION="brownfield"
  else
    AGENT_STACK_RECOMMENDATION="solo-both"
  fi
}

# JSON array helper: join bash array elements as JSON strings
_json_array() {
  local first=true
  local out="["
  for item in "$@"; do
    if [ "$first" = true ]; then
      first=false
    else
      out+=","
    fi
    item="${item//\\/\\\\}"
    item="${item//\"/\\\"}"
    out+="\"$item\""
  done
  out+="]"
  printf '%s' "$out"
}
