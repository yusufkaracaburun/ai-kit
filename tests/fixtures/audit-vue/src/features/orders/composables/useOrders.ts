// Fixture composable. Trips V1 + V6.

import { ref, watch } from "vue";
// V6: Cross-feature reach-through import — reaches into the customers feature's
// internals instead of its public entry (🔴).
import { formatName } from "@/features/customers/lib/format";

export function useOrders() {
  const orders = ref<{ customer: string }[]>([]);
  const labels = ref<string[]>([]);

  // V1: watch doing derived state where computed belongs (🟡).
  watch(orders, () => {
    labels.value = orders.value.map((o) => formatName(o.customer));
  });

  return { orders, labels };
}
