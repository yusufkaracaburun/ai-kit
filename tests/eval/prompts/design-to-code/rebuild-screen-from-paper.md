---
id: rebuild-screen-from-paper
skill: design-to-code
expects:
  - checks for a Paper design plus a reachable Paper MCP before starting; stops without inventing a design when neither exists
  - defers to a project-local design/Paper skill under .claude/skills or .agents/skills when one exists, and says so
  - checks the app tokens in the Paper file from `open_file`'s token list (`get_tokens` only when missing) before building, and hands a missing token setup to the designer
  - reads the frame with Paper MCP reads (get_basic_info, get_screenshot, get_computed_styles), never pastes get_jsx output as app code
  - the lead never calls a Paper write tool itself; token setup and design edits go through the designer subagent
  - uses Paper only for the new screen; an existing screen is compared through a Playwright screenshot of the app, not copied into Paper
  - states the Paper Free budget (100 calls per week, about 5 per new screen) and counts the calls it spends
  - delegates the build to the designer subagent with the frame id, target path and the project's token file, one unit per frame
  - delegates the prove step to the verifier subagent with the claim "<route> matches design frame <id>", passing it the Paper screenshot and the render
  - scores fidelity per component against the frame, not as an average; fixes code rather than loosening the bar
  - reports done only with a CONFIRMED verdict and zero unresolved drift; never claims "1:1" from a glance
---

# Prompt

The relaties list screen got a new design in Paper yesterday (page "Relaties",
artboard "Relaties lijst"). Bouw dit scherm opnieuw uit het design en check
daarna of de code met het design klopt.
