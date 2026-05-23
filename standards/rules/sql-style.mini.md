---
name: sql-style
description: SQL style — readable formatting, explicit joins, no SELECT *, parameterised queries always
applies_to:
  frameworks: []
  languages: []
  architectures: ["backend"]
universal: false
default_mode: always-on
weight: low
repo_age_min_years: 0
---

# SQL style

SQL gets read more than it gets written. Optimise for the reader; the
database doesn't care about your formatting, but the next debugger does.

## Formatting

- **Keywords UPPERCASE** (`SELECT`, `JOIN`, `WHERE`), identifiers lowercase.
- One clause per line, lined up at the left margin:

  ```sql
  SELECT u.id,
         u.email,
         COUNT(o.id) AS order_count
    FROM users u
    LEFT JOIN orders o ON o.user_id = u.id
   WHERE u.created_at >= $1
   GROUP BY u.id, u.email
   ORDER BY order_count DESC
   LIMIT 50;
  ```

- Trailing commas on lists are fine if your dialect supports them; if not,
  align them at the front so adding a column = one-line diff.

## Selects

- **Never `SELECT *`** in application code. Name every column. Breaks the
  moment a column is added; ships rows you don't need.
- Alias tables with one or two letters (`users u`, `orders o`). Long
  aliases obscure the join.
- Compute derived values inline if used once; promote to a CTE or view if
  used twice.

## Joins

- **`JOIN` is `INNER JOIN`.** Spell it for `LEFT`, `RIGHT`, `FULL` —
  never rely on implicit join type.
- **Always explicit `ON`** — no `USING(...)` (column names lie eventually)
  and never `,`-style cross joins by accident.
- Multi-table joins read top-down: the leftmost table is the anchor;
  joined tables flow downward.

## Predicates

- One condition per `AND` / `OR` line; align operators.
- `IN (...)` for static lists; subquery `IN (SELECT ...)` is fine; **avoid
  correlated subqueries** in hot paths — rewrite as a join + aggregate.
- Date ranges: `>= start AND < end` (half-open), never `BETWEEN` for
  timestamps (off-by-one ambiguity on the upper bound).
- `NULL` is not equal to anything, including `NULL`. Use `IS NULL` /
  `IS DISTINCT FROM`.

## Mutations

- `INSERT INTO t (cols) VALUES (...)` — explicit column list, never
  positional `INSERT INTO t VALUES (...)`.
- `UPDATE` / `DELETE` always have a `WHERE`. CI / pre-commit can reject
  unbounded mutation statements.
- `RETURNING ...` (Postgres) or equivalent — read the new state in the
  same round trip.

## Safety

- **Parameterised queries always.** `WHERE id = $1`, never
  `WHERE id = '${id}'`. SQL injection is one of the most preventable
  classes of bug.
- Migrations are forward-only in prod; rollback = a new migration.
- Long-running migrations (large `UPDATE`, index creation) use
  `CREATE INDEX CONCURRENTLY` / batched updates — never block writes.

## Don't

- Don't ship multi-statement SQL in one query string from app code; the
  driver behaviour differs across libraries.
- Don't use `ORDER BY <integer>` for column position — fragile to schema
  changes. Order by the named column.
- Don't return whole BLOB / TEXT columns when a `LENGTH(...)` would do.

## See also

- [`prisma.mini.md`](./prisma.mini.md) — same principles via ORM.
- [`api-design.mini.md`](./api-design.mini.md) — pagination patterns.
