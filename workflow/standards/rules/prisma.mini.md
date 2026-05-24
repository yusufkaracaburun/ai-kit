---
name: prisma
description: Prisma ORM conventions — schema-first, migrations versioned, transactions explicit, no N+1
applies_to:
  frameworks: []
  languages: []
  architectures: ["backend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# Prisma conventions

Prisma is schema-first. The `schema.prisma` is the source of truth — code,
types, migrations, and the DB all derive from it. Deviating from that
inverts the value of the ORM.

## Schema

- One `schema.prisma` per database. Multi-schema = multi-database, period.
- Models named in **PascalCase singular** (`User`, not `users` or
  `UserRecord`). Field names in **camelCase**.
- `@@map("table_name")` only when the DB convention differs from Prisma —
  e.g. legacy snake_case tables. Don't fight either tool.
- Every relation has an inverse (`User` has `posts Post[]` ⇔ `Post` has
  `author User @relation(...)`). Missing inverses break querying.
- Use `enum`s for closed value sets; strings only when the set is open.

## Migrations

- **`prisma migrate dev`** in dev (generates + applies + types).
- **`prisma migrate deploy`** in prod (applies only, no shadow DB).
- Never edit a migration after it ships. New change = new migration.
- Commit the entire `migrations/` directory. Don't `.gitignore` any of it.
- Data migrations live in **separate** migration files using raw SQL or
  a one-off script, not mixed into a schema migration.

## Querying

- **`include` for full relations** with column lists narrowed via `select`
  on the relation. `include: { posts: { select: { id: true, title: true } } }`.
- **`select` for projections** when you don't need the whole model — keeps
  payload small + type narrow.
- **`findUnique` over `findFirst({ where: { id } })`** — guaranteed
  index usage + clearer intent.
- **Pagination is cursor-based** for large lists (`cursor` + `take`).
  Skip/take page-counting is a footgun on growing tables.

## Transactions

- Multi-write workflows wrap in `prisma.$transaction([...])` (sequential)
  or `prisma.$transaction(async (tx) => { ... })` (interactive).
- Transactions are explicit — Prisma does not auto-batch your service.
- Don't hold a transaction open across an external API call. Compose:
  read → external → write-tx, not one giant lock.

## Performance

- N+1 is the default failure mode. If you map an array and call Prisma
  inside the map, you have N+1. Fix with `include` / `select` / a single
  `findMany({ where: { id: { in: ids } } })`.
- Indexes go in `schema.prisma` (`@@index([fields])`), not as raw SQL
  migrations.
- For analytical queries, `prisma.$queryRaw` is fine — but type the
  return shape explicitly via `Prisma.sql` + a tuple.

## Don't

- Don't pass user input into `$queryRawUnsafe`. Use `$queryRaw` (tagged
  template) which parameterises automatically.
- Don't auto-generate the Prisma Client at runtime in prod. CI generates;
  deploys ship the artifact.
- Don't expose `prisma` directly to controllers. Wrap in a repository or
  service layer so the data layer is mockable + the model isn't a
  cross-cutting concern.

## See also

- [`api-design.mini.md`](./api-design.mini.md)
- Prisma docs: https://www.prisma.io/docs
