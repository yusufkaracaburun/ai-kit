// Fixture component. Trips R8.

// R8: Mechanism-named component (`*Container`) where a domain name exists (🟡).
// `OrderListContainer` should be `OrderListPage` or `OrderListScreen` — the
// "Container" suffix is a leftover from the HOC era and obscures intent.
import { OrderList } from "./OrderList";

export function OrderListContainer() {
  return <OrderList />;
}
