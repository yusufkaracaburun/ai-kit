---
name: aikit-zoom-out
description: Tell the agent to zoom out and give broader context or a higher-level perspective. Use when you're unfamiliar with a section of code or need to understand how it fits into the bigger picture.
disable-model-invocation: true
---

I don't know this area of code well. Go up a layer of abstraction. Give me a map of all the relevant modules and callers, using the project's domain glossary vocabulary.

## Usage logging (opt-in)

When `AI_KIT_USAGE=1` is set, log the invocation so `aikit-retro` can spot patterns:

```bash
bash "$AI_KIT_ROOT/bin/log-skill.sh" aikit-zoom-out start  # at the start
bash "$AI_KIT_ROOT/bin/log-skill.sh" aikit-zoom-out done   # at the end (or `abort` if you bail)
```

Silent no-op when the env var is unset. See [SECURITY.md](../../../SECURITY.md) for what is logged and where.

