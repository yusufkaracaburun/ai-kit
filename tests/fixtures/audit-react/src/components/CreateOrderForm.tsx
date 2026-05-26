// Fixture component. Trips R7.

// R7: Missing typing on <form action={...}> server actions in React 19 (🟠).
// The bound function is `Function`-typed (effectively any), losing the
// FormData -> Promise<void> contract React 19 expects.
export function CreateOrderForm({ action }: { action: Function }) {
  return (
    <form action={action as never}>
      <input name="name" />
      <button type="submit">Create</button>
    </form>
  );
}
