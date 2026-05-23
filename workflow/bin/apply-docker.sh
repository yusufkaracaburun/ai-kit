#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
source "$AIKIT/bin/lib/agents-patch.sh"

usage() {
  echo "Usage: $0 /path/to/project none|minimal|existing"
  exit 1
}

if [ $# -lt 2 ]; then usage; fi

TARGET="$(cd "$1" && pwd)"
MODE="$2"
mkdir -p "$TARGET/docs/agents"

case "$MODE" in
  none)
    cp "$AIKIT/context/templates/docs/agents/docker-none.md" "$TARGET/docs/agents/docker.md"
    echo "none" > "$TARGET/.ai-kit-docker"
    echo "Docker: none"
    ;;
  minimal)
    if [ ! -f "$TARGET/compose.yaml" ] && [ ! -f "$TARGET/docker-compose.yml" ] && [ ! -f "$TARGET/docker-compose.yaml" ]; then
      cp "$AIKIT/dev/docker/compose.yml.template" "$TARGET/compose.yaml"
      echo "Created compose.yaml (customize before use)"
    else
      echo "Compose file already exists — skipped scaffold"
    fi
    cp "$AIKIT/context/templates/docs/agents/docker-minimal.md" "$TARGET/docs/agents/docker.md"
    echo "minimal" > "$TARGET/.ai-kit-docker"
    echo "Docker: minimal compose"
    ;;
  existing)
    echo "existing" > "$TARGET/.ai-kit-docker"
    echo "Docker: existing — write docs/agents/docker.md from compose/Dockerfile/Sail in /ai:setup"
    ;;
  *) usage ;;
esac

patch_agents_docker_section "$TARGET"
