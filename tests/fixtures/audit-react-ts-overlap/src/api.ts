// TS-shaped smell: `any` past module boundary on an exported function
// signature. Owned by audit-architecture-typescript (heuristic T1 under
// dimension #9 type safety). NOT a React concern — pure TS surface.
export function parseApiResponse(raw: any): { id: string; payload: unknown } {
  return { id: String(raw.id), payload: raw.payload };
}

// TS-shaped smell: `as` cast past system edge (raw JSON -> domain).
// Owned by audit-architecture-typescript (heuristic T2 under #9).
interface User {
  id: string;
  email: string;
}

export function userFromJson(json: string): User {
  return JSON.parse(json) as User;
}
