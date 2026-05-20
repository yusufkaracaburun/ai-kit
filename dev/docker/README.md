# Docker in ai-kit

Two separate uses of Docker:

| Use | What | When |
| --- | ---- | ---- |
| **App dev** | `compose.yaml` in your project | Optional — configure via `/setup` |
| **Sandcastle** | Agent sandboxes | Optional AFK agents; needs Docker Desktop |

Configure app Docker during **`/setup`**, not bootstrap.

Templates: `compose.yml.template` — minimal starter; customize per project. Test commands in docs should come from repo scripts or official documentation.
