---
name: secrets-hygiene
description: Never commit, log, or hard-code secrets — single source for credentials, rotation playbook
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: true
default_mode: always-on
weight: high
repo_age_min_years: 0
---

# Secrets hygiene

A leaked secret is a paged-at-3am incident. Cheap to prevent, expensive to
recover from.

## What counts as a secret

API keys, OAuth client secrets, DB passwords, JWT signing keys, encryption
keys, webhook signing secrets, private TLS keys, SSH keys, session tokens,
cloud-provider credentials, third-party service tokens (Slack, Stripe,
Sentry, GitHub PATs).

## Hard rules

- **Never commit secrets to the repo.** Not in `.env.production`, not in
  fixtures, not in test snapshots, not in a `# TODO remove later` comment.
- **Never log secrets.** Redact at the logger layer — don't rely on
  developers remembering per call-site.
- **Never put secrets in URLs.** They show up in proxy logs, CDN logs,
  and browser history. Use headers.
- **`.env.example` only**, with empty or placeholder values; the real
  `.env` is gitignored.
- **One secret store per environment.** AWS Secrets Manager / Vault / 1Password
  / Doppler — pick one and use it everywhere. No "this one is special".
- **Rotate on suspicion.** If a secret may have leaked (laptop lost,
  ex-employee, accidental log), rotate immediately. Don't audit first.

## Detection + response

- Pre-commit hook with `gitleaks` (or equivalent) — blocks commits with
  high-entropy strings matching known token patterns.
- CI scan for the same on every PR — pre-commit is bypassable.
- If a secret reaches `origin/main`: **rotate it first**, then rewrite
  history with `git filter-repo`, then force-push (coordinate with team).
  Rewriting alone is not enough — assume the secret is already compromised.

## What "rotation" means

- Generate a new credential at the source (AWS, Stripe, GitHub, etc.).
- Update the secret store.
- Verify the new credential works in a deploy.
- Revoke the old credential.
- Audit logs for the leaked window — what was accessed with the old
  credential between leak and revocation?

## See also

- [`twelve-factor.mini.md`](./twelve-factor.mini.md) — config-in-env.
- [`git-hygiene.mini.md`](./git-hygiene.mini.md) — branch + commit conventions.
- gitleaks: https://github.com/gitleaks/gitleaks
