// Fixture page that trips R6 (RSC boundary leak).

'use client';

// R6: RSC boundary leak — 'use client' file imports server-only module (🔴).
// `next/headers` is server-only; importing it from a client component breaks
// the build (or — worse — silently bundles a server symbol into client output).
import { cookies } from "next/headers";

export default function ProfilePage() {
  const c = cookies();
  return <p>{String(c)}</p>;
}
