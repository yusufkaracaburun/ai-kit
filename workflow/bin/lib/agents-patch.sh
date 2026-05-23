#!/usr/bin/env bash
# Idempotent AGENTS.md / CLAUDE.md section patches for ai-kit apply scripts.

agents_file() {
  local target="$1"
  if [ -f "$target/CLAUDE.md" ]; then
    echo "$target/CLAUDE.md"
  elif [ -f "$target/AGENTS.md" ]; then
    echo "$target/AGENTS.md"
  fi
}

# patch_agents_section TARGET "SectionName" "body line(s)"
patch_agents_section() {
  local target="$1"
  local section="$2"
  local body="$3"
  local file
  file="$(agents_file "$target")"
  [ -n "$file" ] || return 0

  # Never patch a Laravel Boost-managed file — Boost regenerates AGENTS.md on
  # every `artisan boost:*` run and would silently wipe ai-kit's section.
  if grep -q '<laravel-boost-guidelines>' "$file" 2>/dev/null; then
    return 0
  fi

  local header="### ${section}"
  local tmp
  tmp="$(mktemp)"

  if grep -q "^${header}$" "$file"; then
    awk -v hdr="$header" -v body="$body" '
      BEGIN { in_section = 0; printed = 0 }
      $0 == hdr {
        print $0
        print body
        in_section = 1
        printed = 1
        next
      }
      in_section && /^### / { in_section = 0 }
      in_section && /^## / { in_section = 0 }
      !in_section { print }
    ' "$file" > "$tmp"
  elif grep -q '^## Agent skills' "$file"; then
    awk -v hdr="$header" -v body="$body" '
      /^## Agent skills/ { print; print ""; print hdr; print body; skip = 1; next }
      skip && /^## / { skip = 0 }
      !skip { print }
    ' "$file" > "$tmp"
  else
    cat >> "$file" << EOF

${header}

${body}
EOF
    return 0
  fi

  mv "$tmp" "$file"
}

patch_agents_docker_section() {
  local target="$1"
  patch_agents_section "$target" "Docker" "See \`docs/agents/docker.md\`."
}

patch_agents_dev_environment_section() {
  local target="$1"
  patch_agents_section "$target" "Dev environment" "Stack-agnostic. See \`docs/agents/dev-environment.md\`. Use official docs for detected tooling."
}
