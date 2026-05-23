#!/usr/bin/env bash
# Idempotent .ai-kit-setup writer for /ai:setup Done step.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
VERSION="$(cat "$AIKIT/VERSION" | tr -d '[:space:]')"

usage() {
  echo "Usage: $0 /path/to/project [options]"
  echo ""
  echo "Options:"
  echo "  --setup-mode=solo-global|solo-both|project-only|brownfield"
  echo "  --tier=minimal|full"
  echo "  --docker=none|minimal|existing|skipped"
  echo "  --tracker=github|gitlab|local|other|skipped"
  echo "  --workflow=scrum|kanban|informal|skipped"
  echo "  --domain-docs=scaffolded|filled|skipped"
  echo "  --architecture=documented|follow-existing|skipped"
  echo "  --sandcastle=true|false"
  echo "  --automation-recommender=skipped|deferred|completed"
  echo "  --context-drift-hook=wired|skipped"
  echo "  --rule-recommendation=completed|deferred|skipped"
  echo "  --repo-templates=all|picked|skipped"
  exit 1
}

if [ $# -lt 1 ]; then usage; fi

TARGET="$(cd "$1" && pwd)"
shift

SETUP_MODE=""
SETUP_TIER=""
DOCKER=""
TRACKER=""
WORKFLOW=""
DOMAIN_DOCS=""
ARCHITECTURE=""
SANDCASTLE=""
AUTOMATION_RECOMMENDER=""
CONTEXT_DRIFT_HOOK=""
RULE_RECOMMENDATION=""
REPO_TEMPLATES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --setup-mode=*) SETUP_MODE="${1#*=}"; shift ;;
    --agent-stack=*) SETUP_MODE="${1#*=}"; shift ;; # deprecated alias
    --tier=*) SETUP_TIER="${1#*=}"; shift ;;
    --docker=*) DOCKER="${1#*=}"; shift ;;
    --tracker=*) TRACKER="${1#*=}"; shift ;;
    --workflow=*) WORKFLOW="${1#*=}"; shift ;;
    --domain-docs=*) DOMAIN_DOCS="${1#*=}"; shift ;;
    --architecture=*) ARCHITECTURE="${1#*=}"; shift ;;
    --sandcastle=*) SANDCASTLE="${1#*=}"; shift ;;
    --automation-recommender=*) AUTOMATION_RECOMMENDER="${1#*=}"; shift ;;
    --context-drift-hook=*) CONTEXT_DRIFT_HOOK="${1#*=}"; shift ;;
    --rule-recommendation=*) RULE_RECOMMENDATION="${1#*=}"; shift ;;
    --repo-templates=*) REPO_TEMPLATES="${1#*=}"; shift ;;
    -h | --help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# Map legacy agent-stack values to setup-mode
case "$SETUP_MODE" in
  global-only) SETUP_MODE="solo-global" ;;
  merge-skills | link-all) SETUP_MODE="solo-both" ;;
  parallel) SETUP_MODE="brownfield" ;;
esac

SETUP_FILE="$TARGET/.ai-kit-setup"
COMPLETED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

python3 - "$SETUP_FILE" "$VERSION" "$COMPLETED_AT" \
  "$SETUP_MODE" "$SETUP_TIER" "$DOCKER" "$TRACKER" "$WORKFLOW" "$DOMAIN_DOCS" "$ARCHITECTURE" "$SANDCASTLE" \
  "$AUTOMATION_RECOMMENDER" "$CONTEXT_DRIFT_HOOK" "$RULE_RECOMMENDATION" "$REPO_TEMPLATES" <<'PY'
import json, sys, os

path, version, completed = sys.argv[1:4]
setup_mode, tier, docker, tracker, workflow, domain_docs, architecture, sandcastle, automation_recommender, context_drift_hook, rule_recommendation, repo_templates = sys.argv[4:16]

data = {}
if os.path.isfile(path):
    with open(path) as f:
        data = json.load(f)

data["ai_kit_version"] = version
data["completed_at"] = completed

branches = data.get("branches", {})
branches.setdefault("bootstrap", True)
branches.setdefault("dev_environment", True)

if setup_mode:
    branches["setup_mode"] = setup_mode
    branches["agent_stack"] = setup_mode  # legacy field
if tier:
    branches["setup_tier"] = tier
if docker:
    branches["docker"] = docker
if tracker:
    branches["issue_tracker"] = tracker
    branches["triage_labels"] = tracker != "skipped"
if workflow:
    branches["workflow"] = workflow
if domain_docs:
    branches["domain_docs"] = domain_docs
if architecture:
    branches["architecture"] = architecture
if sandcastle:
    branches["sandcastle"] = sandcastle.lower() == "true"
if automation_recommender:
    branches["automation_recommender"] = automation_recommender
if context_drift_hook:
    branches["context_drift_hook"] = context_drift_hook
if rule_recommendation:
    branches["rule_recommendation"] = rule_recommendation
if repo_templates:
    branches["repo_templates"] = repo_templates

data["branches"] = branches

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"Wrote {path}")
PY
