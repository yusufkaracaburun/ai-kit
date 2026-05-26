// Fixture module. Trips T4.

type OrderStatus = "pending" | "paid" | "shipped" | "cancelled";

// T4: Missing exhaustive switch — no `never` check on default branch (🟠).
// Adding a new OrderStatus variant won't fail the compile here.
export function statusLabel(s: OrderStatus): string {
  switch (s) {
    case "pending":
      return "Pending";
    case "paid":
      return "Paid";
    case "shipped":
      return "Shipped";
    default:
      return "Unknown";
  }
}
