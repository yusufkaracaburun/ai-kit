// Fixture provider. Trips V5.

import { inject, provide } from "vue";

export interface Session {
  userId: string;
}

export function provideSession(session: Session) {
  // V5: provide/inject on a raw string key instead of InjectionKey<T> —
  // ambient global state with no typed contract (🟠).
  provide("session", session);
}

export function useSession() {
  return inject("session");
}
