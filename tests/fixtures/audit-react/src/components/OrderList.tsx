// Fixture component. Trips R3 + R4.

import { useEffect, useState } from "react";

export function OrderList() {
  // R3: Same fetch + state-machine quartet duplicated > 2x across components (🟡).
  // R4: useEffect-empty-deps async-on-mount where data-router loader should own (🟡).
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [data, setData] = useState<unknown>(null);

  useEffect(() => {
    fetch("/api/orders")
      .then((r) => r.json())
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>loading</p>;
  if (error) return <p>{error.message}</p>;
  return <pre>{JSON.stringify(data)}</pre>;
}
