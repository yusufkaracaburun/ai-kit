---
id: rebuild-screen-from-pen
skill: design-to-code
expects:
  - checks for a .pen file plus a reachable Pencil MCP before starting; stops without inventing a design when neither exists
  - defers to a project-local design/pencil skill under .claude/skills or .agents/skills when one exists, and says so
  - never Reads or Greps the .pen file; calls get_app_state before any other Pencil tool
  - delegates the build to the designer subagent with the frame id, target path and the project's token file, one unit per frame
  - delegates the prove step to the verifier subagent with the claim "<route> matches design frame <id>" and a concrete observation method
  - scores fidelity per component against the frame, not as an average; fixes code rather than loosening the bar
  - reports done only with a CONFIRMED verdict and zero unresolved drift; never claims "1:1" from a glance
---

# Prompt

The relaties list screen in `.pencil/relaties.pen` changed yesterday. Bouw dit
scherm opnieuw uit het design en check daarna of de code met het design klopt.
