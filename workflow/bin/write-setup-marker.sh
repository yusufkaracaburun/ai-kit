#!/usr/bin/env bash
# Idempotent .ai-kit-setup writer for /ai:setup Done step.
set -euo pipefail

SCRIPT_BIN="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/ai-kit-root.sh
source "$SCRIPT_BIN/lib/ai-kit-root.sh"
AIKIT="$(resolve_ai_kit_root "$SCRIPT_BIN")"
VERSION="$(resolve_ai_kit_version "$AIKIT")"

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
  echo "  --tool-recommendation=completed|deferred|skipped"
  echo "  --repo-templates=all|picked|skipped"
  echo "  --lifecycle=development|production"
  echo "  --universal-mcps-prompted=name1,name2  (CSV; appended to existing list — names not re-prompted on next /ai:setup)"
  echo "  --universal-companions-prompted=name1,name2  (CSV; same accumulating semantics)"
  echo "  --search-delegation-hook=wired|skipped"
  echo "  --phase-check-hook=wired|skipped"
  echo "  --skip-skill-merge=true|false  (plugin already serves ai-kit skills; don't merge them into this project's skills dirs)"
  echo "  --secrets-scan=clean|findings-acknowledged|findings-issue-filed|skipped-no-binary|skipped-not-git|error"
  echo "  --project-skills-merged=true|false  (ADR-0012: does this project also want ai-kit skills merged into its own skills dirs)"
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
TOOL_RECOMMENDATION=""
REPO_TEMPLATES=""
LIFECYCLE=""
UNIVERSAL_MCPS_PROMPTED=""
UNIVERSAL_COMPANIONS_PROMPTED=""
SEARCH_DELEGATION_HOOK=""
PHASE_CHECK_HOOK=""
SKIP_SKILL_MERGE=""
SECRETS_SCAN=""
PROJECT_SKILLS_MERGED=""

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
    --tool-recommendation=*) TOOL_RECOMMENDATION="${1#*=}"; shift ;;
    --repo-templates=*) REPO_TEMPLATES="${1#*=}"; shift ;;
    --lifecycle=*) LIFECYCLE="${1#*=}"; shift ;;
    --universal-mcps-prompted=*) UNIVERSAL_MCPS_PROMPTED="${1#*=}"; shift ;;
    --universal-companions-prompted=*) UNIVERSAL_COMPANIONS_PROMPTED="${1#*=}"; shift ;;
    --search-delegation-hook=*) SEARCH_DELEGATION_HOOK="${1#*=}"; shift ;;
    --phase-check-hook=*) PHASE_CHECK_HOOK="${1#*=}"; shift ;;
    --skip-skill-merge=*) SKIP_SKILL_MERGE="${1#*=}"; shift ;;
    --secrets-scan=*) SECRETS_SCAN="${1#*=}"; shift ;;
    --project-skills-merged=*) PROJECT_SKILLS_MERGED="${1#*=}"; shift ;;
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

# ADR-0012: a machine fact, not a per-project choice — always computed,
# never a flag. Whether it's *used* for anything is a later phase; this
# just starts the dual-write.
GLOBAL_CHANNEL_AVAILABLE="false"
global_channel_available && GLOBAL_CHANNEL_AVAILABLE="true"

python3 - "$SETUP_FILE" "$VERSION" "$COMPLETED_AT" \
  "$SETUP_MODE" "$SETUP_TIER" "$DOCKER" "$TRACKER" "$WORKFLOW" "$DOMAIN_DOCS" "$ARCHITECTURE" "$SANDCASTLE" \
  "$AUTOMATION_RECOMMENDER" "$CONTEXT_DRIFT_HOOK" "$RULE_RECOMMENDATION" "$TOOL_RECOMMENDATION" "$REPO_TEMPLATES" \
  "$LIFECYCLE" "$UNIVERSAL_MCPS_PROMPTED" "$UNIVERSAL_COMPANIONS_PROMPTED" "$SEARCH_DELEGATION_HOOK" "$PHASE_CHECK_HOOK" \
  "$SKIP_SKILL_MERGE" "$SECRETS_SCAN" "$PROJECT_SKILLS_MERGED" "$GLOBAL_CHANNEL_AVAILABLE" <<'PY'
import json, sys, os

path, version, completed = sys.argv[1:4]
setup_mode, tier, docker, tracker, workflow, domain_docs, architecture, sandcastle, automation_recommender, context_drift_hook, rule_recommendation, tool_recommendation, repo_templates, lifecycle, universal_mcps_prompted, universal_companions_prompted, search_delegation_hook, phase_check_hook, skip_skill_merge, secrets_scan, project_skills_merged, global_channel_available = sys.argv[4:26]

VALID_LIFECYCLE = {"development", "production"}
if lifecycle and lifecycle not in VALID_LIFECYCLE:
    print(f"error: invalid --lifecycle={lifecycle!r} (expected one of {sorted(VALID_LIFECYCLE)})", file=sys.stderr)
    sys.exit(2)

VALID_SECRETS_SCAN = {"clean", "findings-acknowledged", "findings-issue-filed", "skipped-no-binary", "skipped-not-git", "error"}
if secrets_scan and secrets_scan not in VALID_SECRETS_SCAN:
    print(f"error: invalid --secrets-scan={secrets_scan!r} (expected one of {sorted(VALID_SECRETS_SCAN)})", file=sys.stderr)
    sys.exit(2)

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
if tool_recommendation:
    branches["tool_recommendation"] = tool_recommendation
if repo_templates:
    branches["repo_templates"] = repo_templates
if lifecycle:
    branches["lifecycle"] = lifecycle
if search_delegation_hook:
    branches["search_delegation_hook"] = search_delegation_hook
if phase_check_hook:
    branches["phase_check_hook"] = phase_check_hook
if skip_skill_merge:
    branches["skip_skill_merge"] = skip_skill_merge.lower() == "true"
if secrets_scan:
    branches["secrets_scan"] = secrets_scan
if project_skills_merged:
    branches["project_skills_merged"] = project_skills_merged.lower() == "true"
branches["global_channel_available"] = global_channel_available.lower() == "true"


def accumulate(key, csv):
    """Union-merge a CSV into an existing list field — re-runs accumulate, never clobber."""
    if not csv:
        return
    existing = branches.get(key, []) or []
    incoming = [n.strip() for n in csv.split(",") if n.strip()]
    branches[key] = list(dict.fromkeys(existing + incoming))


accumulate("universal_mcps_prompted", universal_mcps_prompted)
accumulate("universal_companions_prompted", universal_companions_prompted)

data["branches"] = branches

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"Wrote {path}")
PY
