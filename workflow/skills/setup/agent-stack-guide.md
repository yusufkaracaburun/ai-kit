# Agent stack guide (for /setup branch 0)

**One question** replaces the old agent-stack + global/project/both split.

## Explore

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh "$(pwd)" --json
```

Read `agent_stack.recommendation` and `agent_stack.needs_doc`.

## Setup mode (ask once)

| Mode | When | Bootstrap |
| ---- | ---- | --------- |
| **solo-both** | Greenfield default | `install-global.sh` + `--merge-skills` |
| **solo-global** | Machine-wide only | `install-global.sh` + `--no-skills` |
| **project-only** | No global install | `--merge-skills` only |
| **brownfield** | Custom rules, MCP, commands, or project skills | `install-global.sh` (usually) + `--merge-skills` |

Recommend **solo-both** when `needs_doc` is false. Recommend **brownfield** when `needs_doc` is true.

## agent-stack.md (brownfield only)

Skip on greenfield. When mode is **brownfield**:

```bash
$AI_KIT_ROOT/bin/detect-tooling.sh "$(pwd)" --write-agent-stack
```

Refine the draft with user; list what must not be overwritten.

## Record

```bash
$AI_KIT_ROOT/bin/write-setup-marker.sh "$(pwd)" --setup-mode=solo-both --tier=minimal
```

## Fast path default

Unless the user asks for full setup, use **Tier A** (see SKILL.md): mode + bootstrap + dev-env, then `--tier=minimal`.
