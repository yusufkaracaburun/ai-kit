## rtk (compacted shell output)

- [rtk](https://github.com/rtk-ai/rtk) compacts shell command output (git, grep,
  tests, docker) through a PreToolUse Bash hook before the agent reads it. It
  does not overlap graphify (code search input) or caveman (output prose).
- Activation is machine-wide: `rtk init -g` patches `~/.claude/settings.json`,
  so it applies in every project on this machine.
- Remove: `rtk init -g --uninstall`, then remove the binary (`brew uninstall rtk` for brew, `rm ~/.local/bin/rtk` for install.sh).
