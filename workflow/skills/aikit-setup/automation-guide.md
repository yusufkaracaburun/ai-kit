# Setup automation guide (for /aikit-setup skill)

Scripts handle detection and validation; the agent handles Tier A/B decisions and doc refinement.

## Before branch 0

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh "$(pwd)" --json
```

Use JSON as **Finding**. Prefer `agent_stack.recommendation` and other detected defaults.

## detect-tooling.sh

| Mode | Command | Purpose |
| ---- | ------- | ------- |
| Human | `detect-tooling.sh "$(pwd)"` | Readable report |
| JSON | `detect-tooling.sh "$(pwd)" --json` | Machine findings |
| Dev draft | `detect-tooling.sh "$(pwd)" --write` | `dev-environment.md` |
| Stack draft | `detect-tooling.sh "$(pwd)" --write-agent-stack` | `agent-stack.md` (brownfield) |

## write-setup-marker.sh

```bash
$AI_KIT_ROOT/bin/write-setup-marker.sh "$(pwd)" \
  --setup-mode=solo-both|solo-global|project-only|brownfield \
  --tier=minimal|full \
  --docker=skipped|... \
  --tracker=skipped|github|... \
  --workflow=skipped|informal|... \
  --architecture=skipped|... \
  --sandcastle=true|false
```

## verify-setup.sh

```bash
$AI_KIT_ROOT/bin/verify-setup.sh "$(pwd)" --strict --minimal   # Tier A
$AI_KIT_ROOT/bin/verify-setup.sh "$(pwd)" --strict             # Tier B full
```

**Tier A (`--minimal`):** AGENTS, skills (unless solo-global), dev-environment, marker.

**Brownfield:** requires `agent-stack.md` when `aikit-setup_mode=brownfield`.

**Done rule:** verify exits 0 before claiming complete.
