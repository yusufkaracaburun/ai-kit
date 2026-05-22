---
id: null-pointer-react
skill: aikit-diagnose
expects:
  - asks for a failing test or concrete repro before guessing at causes
  - names the Phase 1 feedback-loop step explicitly
  - does NOT propose a fix before reproducing the bug
  - asks at least one question about when the bug started (recent change, version, environment)
---

# Prompt

My React app throws "Cannot read property 'map' of undefined" intermittently in
production. It started two days ago. I can't reproduce locally. The error
points to `src/components/Dashboard.tsx:127` but the code there has worked for
months. What should I do?
