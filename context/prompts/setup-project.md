# Setup prompt (project)

Plak in **Cursor** of **Claude Code**. De agent doet Tier A (fast) tenzij je Full setup vraagt.

---

## Copy-paste

```
Set up ai-kit on this repository.

Resolve ai-kit root:
  export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"

Run detect-tooling --json first.

Ask once: Fast setup (Tier A, default) or Full setup (Tier B)?

Tier A (default, ~5 min):
1. Setup mode — ONE question (recommend from agent_stack.recommendation):
   solo-both | solo-global | project-only | brownfield
   - solo-both: install-global + bootstrap --merge-skills (greenfield default)
   - solo-global: install-global + bootstrap --no-skills
   - project-only: bootstrap --merge-skills only
   - brownfield: merge-skills + detect-tooling --write-agent-stack (only if needs_doc)
2. Bootstrap per mode above
3. detect-tooling --write + refine dev-environment.md URLs

Done Tier A:
  write-setup-marker --setup-mode=... --tier=minimal \
    --docker=skipped --tracker=skipped --workflow=skipped \
    --architecture=skipped --sandcastle=false
  verify-setup --strict --minimal

Tier B only if I ask: docker, tracker, labels, domain, architecture, sandcastle, workflow.
Then --tier=full and verify-setup --strict (no --minimal).

Do not claim done until verify exits 0.
```

Zie [setup SKILL](../../workflow/skills/setup/SKILL.md).
