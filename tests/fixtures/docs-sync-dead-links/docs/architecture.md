# Architecture

See [setup guide](./setup.md) for the install flow.

External: [GitHub](https://github.com/example/repo) — should be ignored.

Anchor-only link: [back to top](#architecture) — should be ignored.

Image (not validated): ![diagram](./does-not-exist.png)

This link is broken on purpose: [legacy install](./legacy-install.md).

Repo-absolute link: [readme](/docs/setup.md).

Repo-absolute that does not exist: [missing-root](/missing-root.md).

Bare URL ignored: https://example.com/raw

HTML anchor ignored: <a href="./html-broken.md">html link</a>

Link inside fenced code block — must NOT be reported:

```
[ignored in code fence](./this-does-not-exist.md)
```

Inline code span — must NOT be reported: `[ignored in backticks](./inline-code-nope.md)`.
