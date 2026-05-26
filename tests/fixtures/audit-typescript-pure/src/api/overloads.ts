// Fixture module. Trips T3.

// T3: Discriminated union encoded as function overload (🟡) — should be a tagged union.
export function dispatch(event: { kind: "create"; payload: string }): { ok: true };
export function dispatch(event: { kind: "delete"; id: number }): { ok: true; deleted: number };
export function dispatch(event: any): any {
  if (event.kind === "create") {
    return { ok: true };
  }
  return { ok: true, deleted: event.id };
}
