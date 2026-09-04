// Fixture hook. Trips R9.

// R9: Cross-feature reach-through import — orders reaches into the customers
// feature's internals instead of its public entry (🔴).
import { formatName } from "@/features/customers/lib/format";

export function useOrderLabels(names: string[]): string[] {
  return names.map(formatName);
}
