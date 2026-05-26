// Fixture module. Trips T1, T2.

// T1: `any` past module boundary (🟠) — exported function signature uses `any`.
export function parseApiResponse(raw: any): { id: string; payload: unknown } {
  return { id: String(raw.id), payload: raw.payload };
}

interface User {
  id: string;
  email: string;
}

// T2: `as` cast past system edge (🟠) — JSON -> domain entity with no runtime check.
export function userFromJson(json: string): User {
  return JSON.parse(json) as User;
}
