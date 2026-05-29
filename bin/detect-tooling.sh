#!/usr/bin/env bash
# Report detected tooling for /ai:setup. Human report by default; --json or --write.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
# shellcheck source=lib/detect-lib.sh
source "$AIKIT/bin/lib/detect-lib.sh"

usage() {
  echo "Usage: $0 /path/to/project [--json|--write|--write-agent-stack]"
  exit 1
}

if [ $# -lt 1 ]; then usage; fi

TARGET="$(cd "$1" && pwd)"
shift
JSON=false
WRITE=false
WRITE_AGENT_STACK=false

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=true; shift ;;
    --write) WRITE=true; shift ;;
    --write-agent-stack) WRITE_AGENT_STACK=true; shift ;;
    -h | --help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

detect_package_manager "$TARGET"
detect_frameworks "$TARGET"
detect_docker "$TARGET"
detect_deploy_shape "$TARGET"
detect_issue_tracker "$TARGET"
detect_domain_layout "$TARGET"
detect_bootstrap_state "$TARGET"
detect_npm_scripts "$TARGET"
detect_architecture "$TARGET"
detect_agent_stack "$TARGET" "$AIKIT"
detect_monorepo "$TARGET"
detect_boost "$TARGET"

needs_doc_json="false"
[ "$AGENT_STACK_NEEDS_DOC" = true ] && needs_doc_json="true"

# Laravel version hint for docs
LARAVEL_VERSION=""
if [ -f "$TARGET/composer.lock" ]; then
  LARAVEL_VERSION="$(python3 -c "
import json, re
try:
    data = json.load(open('$TARGET/composer.lock'))
    for pkg in data.get('packages', []) + data.get('packages-dev', []):
        if pkg.get('name') == 'laravel/framework':
            v = pkg.get('version', '')
            m = re.match(r'v?(\d+)', v)
            if m:
                print(m.group(1))
            break
except Exception:
    pass
" 2>/dev/null || true)"
fi

if [ "$WRITE_AGENT_STACK" = true ]; then
  mkdir -p "$TARGET/docs/agents"
  OUT="$TARGET/docs/agents/agent-stack.md"
  cp "$AIKIT/context/templates/docs/agents/agent-stack.md" "$OUT"
  python3 - "$OUT" "${AGENT_STACK_RECOMMENDATION}" \
    "${AGENT_STACK_CURSOR_SKILLS_AIKIT[*]-}" "${AGENT_STACK_CURSOR_SKILLS_CUSTOM[*]-}" \
    "${AGENT_STACK_RULES_AIKIT[*]-}" "${AGENT_STACK_RULES_CUSTOM[*]-}" \
    "${AGENT_STACK_COMMANDS[*]-}" "${AGENT_STACK_MCP[*]-}" <<'PY'
import pathlib, sys

out = pathlib.Path(sys.argv[1])
mode = sys.argv[2]
cursor_aikit = [x for x in sys.argv[3].split() if x]
cursor_custom = [x for x in sys.argv[4].split() if x]
rules_aikit = [x for x in sys.argv[5].split() if x]
rules_custom = [x for x in sys.argv[6].split() if x]
commands = [x for x in sys.argv[7].split() if x]
mcp = [x for x in sys.argv[8].split() if x]

text = out.read_text()
text = text.replace("[solo-global | solo-both | project-only | brownfield]", mode)
text = text.replace("[list or \"via merge\"]", ", ".join(cursor_aikit) or "via merge")
text = text.replace("[list]", ", ".join(cursor_custom) or "n/a", 1)
text = text.replace("[e.g. coding-standards.mdc]", ", ".join(rules_custom) or "n/a")
text = text.replace("[`.cursor/commands/` entries or n/a]", ", ".join(commands) or "n/a")
text = text.replace("[config paths or n/a]", ", ".join(mcp) or "n/a")
text = text.replace(
    "[custom skills, plugins, project rules — from user answers]",
    ", ".join(cursor_custom + rules_custom) or "none detected",
)
text = text.replace("[list items user chose to preserve]", ", ".join(rules_custom + commands + mcp) or "n/a")
out.write_text(text)
PY
  echo "Wrote draft: $OUT"
  exit 0
fi

if [ "$WRITE" = true ]; then
  mkdir -p "$TARGET/docs/agents"
  OUT="$TARGET/docs/agents/dev-environment.md"
  cp "$AIKIT/context/templates/docs/agents/dev-environment.md" "$OUT"

  FW_LIST="$(IFS=,; echo "${FRAMEWORKS[*]-}")"
  python3 - "$OUT" "$PM_NAME" "$INSTALL_CMD" "$FW_LIST" "$SCRIPT_TEST" "$SCRIPT_BUILD" \
    "$LARAVEL_VERSION" <<'PY'
import json, pathlib, re, sys

out = pathlib.Path(sys.argv[1])
pm, install, fw_list, test, build, laravel_ver = sys.argv[2:8]
frameworks = [f.strip() for f in fw_list.split(",") if f.strip()]

docs_urls = {
    "laravel": "https://laravel.com/docs",
    "react": "https://react.dev",
    "nextjs": "https://nextjs.org/docs",
    "vue": "https://vuejs.org/guide",
    "inertia": "https://inertiajs.com",
    "nx": "https://nx.dev",
    "pnpm": "https://pnpm.io",
    "npm": "https://docs.npmjs.com",
    "composer": "https://getcomposer.org/doc",
}

text = out.read_text()
detected = ["## Detected in this repo", ""]
if pm:
    detected.append(f"- Package manager: {pm} (`{install}`)")
if frameworks:
    detected.append(f"- Frameworks: {', '.join(frameworks)}")
if test:
    detected.append(f"- Test script: `{test}`")
if build:
    detected.append(f"- Build script: `{build}`")
detected.append("")
block = "\n".join(detected)
text = re.sub(
    r"## Detected in this repo\n\n<!-- Filled by /ai:setup[^>]*-->",
    block,
    text,
    count=1,
)

rows = []
for fw in frameworks:
    url = docs_urls.get(fw, "")
    if fw == "laravel" and laravel_ver and url:
        url = f"{url}/{laravel_ver}.x"
    if url:
        rows.append(f"| {fw} | {url} |")
if pm and pm in docs_urls:
    rows.append(f"| {pm} | {docs_urls[pm]} |")
if rows:
    table = "\n".join(["| Tool | Documentation |", "| ---- | ------------- |"] + rows)
    text = re.sub(
        r"## Official documentation\n\n<!-- Filled by /ai:setup[^>]*-->\n\n\| Tool \| Documentation \|\n\| ---- \| ------------- \|\n\| \| \|",
        "## Official documentation\n\n" + table,
        text,
        count=1,
    )
text = re.sub(r"<!-- Filled by /ai:setup[^>]*-->\n?", "", text)
out.write_text(text)
PY

  echo "Wrote draft: $OUT"
  exit 0
fi

if [ "$JSON" = true ]; then
  # Use ${ARR[@]+...} so empty arrays don't trip set -u on bash 3.2 (macOS).
  fw_json="$(_json_array ${FRAMEWORKS[@]+"${FRAMEWORKS[@]}"})"
  docker_files="$(_json_array ${DOCKER_FILES[@]+"${DOCKER_FILES[@]}"})"
  deploy_serverless_markers="$(_json_array ${DEPLOY_SERVERLESS_MARKERS[@]+"${DEPLOY_SERVERLESS_MARKERS[@]}"})"
  deploy_self_host_markers="$(_json_array ${DEPLOY_SELF_HOST_MARKERS[@]+"${DEPLOY_SELF_HOST_MARKERS[@]}"})"
  deploy_coolify_json="false"
  [ "$DEPLOY_COOLIFY" = true ] && deploy_coolify_json="true"
  bootstrap_missing="$(_json_array ${BOOTSTRAP_MISSING[@]+"${BOOTSTRAP_MISSING[@]}"})"
  fe_paths="$(_json_array ${ARCH_FE_PATHS[@]+"${ARCH_FE_PATHS[@]}"})"
  be_paths="$(_json_array ${ARCH_BE_PATHS[@]+"${ARCH_BE_PATHS[@]}"})"
  ast_cursor_aikit="$(_json_array ${AGENT_STACK_CURSOR_SKILLS_AIKIT[@]+"${AGENT_STACK_CURSOR_SKILLS_AIKIT[@]}"})"
  ast_cursor_custom="$(_json_array ${AGENT_STACK_CURSOR_SKILLS_CUSTOM[@]+"${AGENT_STACK_CURSOR_SKILLS_CUSTOM[@]}"})"
  ast_agents_aikit="$(_json_array ${AGENT_STACK_AGENTS_SKILLS_AIKIT[@]+"${AGENT_STACK_AGENTS_SKILLS_AIKIT[@]}"})"
  ast_agents_custom="$(_json_array ${AGENT_STACK_AGENTS_SKILLS_CUSTOM[@]+"${AGENT_STACK_AGENTS_SKILLS_CUSTOM[@]}"})"
  ast_rules_aikit="$(_json_array ${AGENT_STACK_RULES_AIKIT[@]+"${AGENT_STACK_RULES_AIKIT[@]}"})"
  ast_rules_custom="$(_json_array ${AGENT_STACK_RULES_CUSTOM[@]+"${AGENT_STACK_RULES_CUSTOM[@]}"})"
  ast_commands="$(_json_array ${AGENT_STACK_COMMANDS[@]+"${AGENT_STACK_COMMANDS[@]}"})"
  ast_mcp="$(_json_array ${AGENT_STACK_MCP[@]+"${AGENT_STACK_MCP[@]}"})"
  ast_global_cursor="$(_json_array ${AGENT_STACK_GLOBAL_CURSOR[@]+"${AGENT_STACK_GLOBAL_CURSOR[@]}"})"
  ast_global_agents="$(_json_array ${AGENT_STACK_GLOBAL_AGENTS[@]+"${AGENT_STACK_GLOBAL_AGENTS[@]}"})"

  has_agents_md="false"
  has_claude_md="false"
  [ "$AGENT_STACK_HAS_AGENTS_MD" = true ] && has_agents_md="true"
  [ "$AGENT_STACK_HAS_CLAUDE_MD" = true ] && has_claude_md="true"

  monorepo_json="false"
  [ "$ARCH_MONOREPO" = true ] && monorepo_json="true"

  mono_detected_json="false"
  [ "$MONOREPO_DETECTED" = true ] && mono_detected_json="true"
  mono_apps_json="$(_json_array ${MONOREPO_APPS[@]+"${MONOREPO_APPS[@]}"})"
  boost_detected_json="false"
  [ "$BOOST_DETECTED" = true ] && boost_detected_json="true"
  boost_files_json="$(_json_array ${BOOST_MANAGED_FILES[@]+"${BOOST_MANAGED_FILES[@]}"})"

  docs_json="["
  first_doc=true
  for fw in ${FRAMEWORKS[@]+"${FRAMEWORKS[@]}"}; do
    url="$(docs_url_for "$fw")"
    if [ "$fw" = "laravel" ] && [ -n "$LARAVEL_VERSION" ] && [ -n "$url" ]; then
      url="${url}/${LARAVEL_VERSION}.x"
    fi
    [ -z "$url" ] && continue
    if [ "$first_doc" = true ]; then first_doc=false; else docs_json+=","; fi
    docs_json+="{\"tool\":\"${fw}\",\"url\":\"${url}\"}"
  done
  docs_json+="]"

  cat <<EOF
{
  "package_manager": {
    "name": "${PM_NAME:-}",
    "install": "${INSTALL_CMD:-}",
    "audit": "${AUDIT_CMD:-}",
    "has_js": ${HAS_JS:-false},
    "has_php": ${HAS_PHP:-false}
  },
  "frameworks": ${fw_json},
  "docker": {
    "recommendation": "${DOCKER_REC}",
    "files": ${docker_files}
  },
  "deploy": {
    "shape": "${DEPLOY_SHAPE}",
    "serverless_markers": ${deploy_serverless_markers},
    "self_host_markers": ${deploy_self_host_markers},
    "coolify_detected": ${deploy_coolify_json}
  },
  "issue_tracker": {
    "recommendation": "${TRACKER_REC}",
    "remote": "${TRACKER_REMOTE}"
  },
  "domain": {
    "layout": "${DOMAIN_LAYOUT}",
    "has_context": ${HAS_CONTEXT},
    "has_adr": ${HAS_ADR}
  },
  "bootstrap": {
    "state": "${BOOTSTRAP_STATE}",
    "missing": ${bootstrap_missing}
  },
  "scripts": {
    "test": "${SCRIPT_TEST}",
    "build": "${SCRIPT_BUILD}",
    "lint": "${SCRIPT_LINT}"
  },
  "architecture": {
    "frontend": {
      "detected": "${ARCH_FE}",
      "paths": ${fe_paths}
    },
    "backend": {
      "detected": "${ARCH_BE}",
      "paths": ${be_paths}
    },
    "monorepo": ${monorepo_json},
    "recommendation": "${ARCH_RECOMMENDATION}"
  },
  "monorepo": {
    "detected": ${mono_detected_json},
    "apps": ${mono_apps_json}
  },
  "boost": {
    "detected": ${boost_detected_json},
    "managed_files": ${boost_files_json}
  },
  "agent_stack": {
    "project_skills": {
      "cursor": { "ai_kit": ${ast_cursor_aikit}, "custom": ${ast_cursor_custom} },
      "agents": { "ai_kit": ${ast_agents_aikit}, "custom": ${ast_agents_custom} }
    },
    "project_rules": { "ai_kit": ${ast_rules_aikit}, "custom": ${ast_rules_custom} },
    "commands": ${ast_commands},
    "mcp": ${ast_mcp},
    "global_skills": {
      "cursor": ${ast_global_cursor},
      "agents": ${ast_global_agents}
    },
    "has_agents_md": ${has_agents_md},
    "has_claude_md": ${has_claude_md},
    "needs_doc": ${needs_doc_json},
    "recommendation": "${AGENT_STACK_RECOMMENDATION}"
  },
  "docs_suggestions": ${docs_json}
}
EOF
  exit 0
fi

# Human-readable report
echo "## Detected tooling"
echo ""
[ -n "$PM_NAME" ] && echo "- **Package manager:** ${PM_NAME} (\`${INSTALL_CMD}\`)"
if [ "${#FRAMEWORKS[@]}" -gt 0 ]; then
  echo "- **Frameworks:** $(IFS=', '; echo "${FRAMEWORKS[*]}")"
fi
echo "- **Docker:** ${DOCKER_REC}"
[ "${#DOCKER_FILES[@]}" -gt 0 ] && echo "  - files: $(IFS=', '; echo "${DOCKER_FILES[*]}")"
echo "- **Deploy shape:** ${DEPLOY_SHAPE}"
[ "$DEPLOY_COOLIFY" = true ] && echo "  - Coolify marker detected"
echo "- **Issue tracker:** ${TRACKER_REC}"
[ -n "$TRACKER_REMOTE" ] && echo "  - remote: ${TRACKER_REMOTE}"
echo "- **Domain:** ${DOMAIN_LAYOUT} (context=${HAS_CONTEXT}, adr=${HAS_ADR})"
echo "- **Bootstrap:** ${BOOTSTRAP_STATE}"
[ "${#BOOTSTRAP_MISSING[@]}" -gt 0 ] && echo "  - missing: $(IFS=', '; echo "${BOOTSTRAP_MISSING[*]}")"
if [ -n "$ARCH_FE" ] || [ -n "$ARCH_BE" ]; then
  echo "- **Architecture:** FE=${ARCH_FE:-none} BE=${ARCH_BE:-none} → recommend ${ARCH_RECOMMENDATION}"
  [ "${#ARCH_FE_PATHS[@]}" -gt 0 ] && echo "  - FE paths: $(IFS=', '; echo "${ARCH_FE_PATHS[*]}")"
  [ "${#ARCH_BE_PATHS[@]}" -gt 0 ] && echo "  - BE paths: $(IFS=', '; echo "${ARCH_BE_PATHS[*]}")"
fi
if [ "$MONOREPO_DETECTED" = true ]; then
  echo "- **Monorepo:** $(IFS=', '; echo "${MONOREPO_APPS[*]}")"
fi
if [ "$BOOST_DETECTED" = true ]; then
  echo "- **Laravel Boost:** detected"
  [ "${#BOOST_MANAGED_FILES[@]}" -gt 0 ] && \
    echo "  - manages (ai-kit will not patch): $(IFS=', '; echo "${BOOST_MANAGED_FILES[*]}")"
fi
echo "- **Setup mode:** ${AGENT_STACK_RECOMMENDATION} (needs agent-stack doc: ${AGENT_STACK_NEEDS_DOC})"
[ "${#AGENT_STACK_CURSOR_SKILLS_CUSTOM[@]}" -gt 0 ] && \
  echo "  - custom cursor skills: $(IFS=', '; echo "${AGENT_STACK_CURSOR_SKILLS_CUSTOM[*]}")"
[ "${#AGENT_STACK_RULES_CUSTOM[@]}" -gt 0 ] && \
  echo "  - custom rules: $(IFS=', '; echo "${AGENT_STACK_RULES_CUSTOM[*]}")"
[ "${#AGENT_STACK_COMMANDS[@]}" -gt 0 ] && \
  echo "  - commands: $(IFS=', '; echo "${AGENT_STACK_COMMANDS[*]}")"
[ "${#AGENT_STACK_MCP[@]}" -gt 0 ] && \
  echo "  - mcp: $(IFS=', '; echo "${AGENT_STACK_MCP[*]}")"
if [ -n "$SCRIPT_TEST" ] || [ -n "$SCRIPT_BUILD" ]; then
  echo "- **Scripts:** test=${SCRIPT_TEST:-n/a} build=${SCRIPT_BUILD:-n/a}"
fi
echo ""
echo "**Suggested docs:** (verify URLs live)"
for fw in ${FRAMEWORKS[@]+"${FRAMEWORKS[@]}"}; do
  url="$(docs_url_for "$fw")"
  if [ "$fw" = "laravel" ] && [ -n "$LARAVEL_VERSION" ] && [ -n "$url" ]; then
    url="${url}/${LARAVEL_VERSION}.x"
  fi
  [ -n "$url" ] && echo "- ${fw}: ${url}"
done
