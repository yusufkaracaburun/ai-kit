---
name: api-design
description: REST API conventions — resource modelling, status codes, versioning, OpenAPI source-of-truth
applies_to:
  frameworks: ["express", "fastify", "nestjs", "fastapi", "django", "rails", "laravel", "spring"]
  languages: []
  architectures: ["backend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# API design (REST)

REST without conventions is RPC over HTTP. These rules keep an HTTP API
self-describing and predictable for both humans and code generators.

## Resource modelling

- **Nouns, not verbs** in paths — `/orders/123/items`, not `/getOrderItems`.
- **Plural collections** — `/users`, not `/user`.
- **Nested resources only when ownership is real** — `/users/{id}/orders`
  is fine; `/users/{id}/posts/{post_id}/comments/{comment_id}/likes` is a
  smell. Flatten with query params instead.
- **Identifiers are opaque.** Don't leak DB ids when a UUID/slug fits;
  don't leak slugs when a UUID is more stable.

## Methods + status codes

- `GET` safe + idempotent; never mutates.
- `POST` create or non-idempotent action.
- `PUT` full replace, idempotent.
- `PATCH` partial update, idempotent (use JSON Merge Patch or JSON Patch).
- `DELETE` idempotent — second delete returns 404 or 204, not 500.

Status code discipline:

- `200` success with body. `201` created (include `Location` header).
- `204` success no body. `202` accepted (async).
- `400` malformed request. `401` unauthenticated. `403` authenticated but forbidden.
- `404` resource not found. `409` conflict (concurrent update, duplicate).
- `422` validation failed (semantically wrong but well-formed).
- `429` rate-limited. `5xx` server bugs — always logged at ERROR.

## Versioning

- Choose **one** strategy and stick to it: URL prefix (`/v1/...`) **or**
  `Accept` header media type. Don't mix.
- Breaking changes ⇒ new major version. Deprecated endpoints return
  `Deprecation` + `Sunset` headers.

## Errors

- Single envelope shape across the API (RFC 7807 Problem Details is the
  default). Include `type`, `title`, `status`, `detail`, optionally
  `errors[]` for field-level validation failures.
- Never return stack traces or framework internals in 5xx bodies.

## Documentation

- **OpenAPI is source of truth.** Generate clients + server stubs from the
  spec; do not hand-maintain both.
- Every endpoint has request/response examples in the spec.
- Spec lives in the repo (`openapi.yaml`) and CI fails if implementation
  drifts from spec.

## See also

- [`error-handling.mini.md`](./error-handling.mini.md)
- [`semver.mini.md`](./semver.mini.md)
