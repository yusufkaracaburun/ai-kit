// Same fetch-state-machine pattern duplicated (counts toward R3).

import { useEffect, useState } from "react";

// R3: third occurrence of the same pattern (across Dashboard + OrderList + this).
export function CustomerList() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [data, setData] = useState<unknown>(null);

  useEffect(() => {
    fetch("/api/customers")
      .then((r) => r.json())
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>loading</p>;
  if (error) return <p>{error.message}</p>;
  return <pre>{JSON.stringify(data)}</pre>;
}
