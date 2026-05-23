---
name: react-rsc
description: React Server Components conventions — server-by-default, "use client" boundaries minimal, no client/server confusion
applies_to:
  frameworks: ["nextjs", "remix"]
  languages: []
  architectures: ["frontend"]
universal: false
default_mode: always-on
weight: medium
repo_age_min_years: 0
---

# React Server Components (RSC)

In the App Router era, **server is the default and the client is the
exception**. Most bugs come from accidentally turning a server tree into
a client tree, or vice versa.

## The mental model

- A component is a **Server Component** unless it (transitively) contains
  `"use client"`. Server Components run on the server, ship zero JS to
  the client, and can be `async` / fetch data directly.
- A component becomes a **Client Component** by adding `"use client"` at
  the top. Everything imported by it (children, hooks, helpers) runs on
  the client too — the directive marks the *boundary*, not the file.
- **Push `"use client"` as far down the tree as possible.** A `"use client"`
  on a page bundles the whole page; on a `<LikeButton />`, it bundles only
  the button.

## Data fetching

- Fetch in Server Components with native `async`/`await`. No `useEffect`
  loading patterns for initial data.
- **Co-locate fetching with the component that uses it.** Prop-drilling
  data from a parent is a code smell unless multiple children share it.
- Cache requests with `fetch()`'s built-in deduplication + Next.js
  `revalidate` semantics. Don't reach for `react-query` on the server.
- **`react-query` / `swr` is for client-side mutations + interactive
  refetch flows**, not initial render. RSC handles initial render better.

## Mutations

- Use **Server Actions** for form submissions and state mutations from
  client components. Tag with `"use server"`.
- Server Actions are not exempt from validation — treat their args as
  untrusted input and validate (`zod`, etc.) before touching the DB.
- Don't put Server Actions in the same file as a `"use client"` directive —
  Server Actions inside a client component file must be in a *separate*
  `"use server"` file.

## Boundaries that bite

- **Cannot import Server Components from Client Components directly.**
  Compose them: pass Server children into a Client wrapper via `children`
  prop.
- **Hooks (`useState`, `useEffect`, `useContext`) are client-only.** Using
  one accidentally turns a Server Component into an error.
- **No `window` / `document` access in Server Components.** Guard
  effects-style code behind `"use client"` or `useEffect`.
- **Don't `JSON.stringify` non-serializable values across the
  client/server boundary.** Dates work; class instances, Maps, functions
  don't.

## Streaming + Suspense

- Wrap async Server Components in `<Suspense fallback={...}>` to stream
  HTML as data resolves. The fallback is what the user sees while the
  slow query runs.
- One `<Suspense>` per *independent* slow region — don't wrap everything
  in one Suspense, or one slow query blocks everything else.

## Anti-patterns

- `"use client"` at the root of every page (defeats RSC entirely).
- Importing a server-only library (e.g. DB client) into a file that has
  `"use client"` somewhere up the tree — runtime error at best, secret
  leak at worst.
- Building "isomorphic" components that try to work in both worlds.
  Split them. Server logic in server file; client logic in client file.
- Mixing `getServerSideProps` / Pages Router patterns into App Router
  code. Pick one router per app.

## See also

- [`a11y.mini.md`](./a11y.mini.md) — RSC's HTML output must still be
  accessible.
- React docs on Server Components: https://react.dev/reference/rsc/server-components
- Next.js App Router: https://nextjs.org/docs/app
