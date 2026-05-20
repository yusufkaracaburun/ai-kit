# Setup prompt (global, once per machine)

Gebruik dit als je **alleen** machine-wide skills wilt — zonder een specifieke repo te configureren.

Voor een project (met keuze global / project / both): gebruik [setup-project.md](./setup-project.md).

---

## Copy-paste

```
Install ai-kit skills globally on this machine (global scope only).

Resolve ai-kit root first:
  export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"
  # If still empty: ask me for the install path.

Run:
  $AI_KIT_ROOT/bin/install-global.sh

This saves the path to ~/.config/ai-kit/root for future runs.

Verify both exist:
  ~/.agents/skills/setup   (Claude Code)
  ~/.cursor/skills/setup   (Cursor)

Skills will be available in any project via /setup without project-local symlinks.
When I open a repo, I will use the project setup prompt or run /setup directly.
```

---

## Handmatig (zonder agent)

```bash
export AI_KIT_ROOT="${AI_KIT_ROOT:-$(cat "${HOME}/.config/ai-kit/root" 2>/dev/null)}"
$AI_KIT_ROOT/bin/install-global.sh
```

Of vanuit de ai-kit clone (schrijft ook config):

```bash
/path/to/ai-kit/bin/install-global.sh
```
