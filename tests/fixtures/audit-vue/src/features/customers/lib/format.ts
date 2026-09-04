// Internal helper of the customers feature. Not exported from its public entry —
// this is the module V6 reaches through to.

export function formatName(raw: string): string {
  return raw.trim();
}
