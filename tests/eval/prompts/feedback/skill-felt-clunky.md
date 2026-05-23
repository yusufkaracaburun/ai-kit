---
id: skill-felt-clunky
skill: feedback
expects:
  - detects feedback kind (friction in this case) without asking if it's plain
  - rejects vague "felt slow" framing and asks for the concrete moment
  - offers to attach an anonymized context block and redacts before showing it
  - shows the full issue body for user approval before publishing
  - opens the issue with the feedback template (`feedback:` title prefix)
  - prints the resulting issue URL
---

# Prompt

/ai:feedback the to-issues skill felt really clunky just now — it took like
8 turns and re-read the same file three times. I had to keep redirecting it.
file this against ai-kit.
