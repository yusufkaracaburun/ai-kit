// Fixture module. Trips T7.

// T7: Duplicated type alias > 2x across files (🟡).
// The same shape appears in src/api/parser.ts, src/domain/order-status.ts, and here.
export type Payload = {
  id: string;
  createdAt: string;
  updatedAt: string;
  meta: Record<string, unknown>;
};
