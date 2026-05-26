// Fixture module. Trips T6.

function Injectable(_target: unknown): void {
  // pretend decorator from a DI library
}

// T6: Decorator + runtime mismatch (🟠) — @Injectable applied to a non-class
// declaration, and tsconfig has emitDecoratorMetadata: false, so the runtime
// DI lookup will fail at resolve-time.
@Injectable
export const orderRegistry = {
  resolve(name: string): unknown {
    return null;
  },
};
