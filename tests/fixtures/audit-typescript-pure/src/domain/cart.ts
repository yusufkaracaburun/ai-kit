// Fixture module. Trips T5.

// T5: Mutable shared state typed `readonly` (🟡) — annotation lies about behaviour.
export class Cart {
  // Typed readonly but mutated via push() below.
  public readonly items: string[] = [];

  public add(item: string): void {
    (this.items as string[]).push(item);
  }
}
