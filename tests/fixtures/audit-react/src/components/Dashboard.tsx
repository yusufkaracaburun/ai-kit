// Fixture component. Trips R1, R2.

import { ReactNode } from "react";

// R1: God-component > 300 LOC (🟠) — pretend this body is 412 LOC of mixed jobs.
// R2: Props-bloat > 8 props (🟠).
interface DashboardProps {
  title: string;
  subtitle: string;
  user: string;
  role: string;
  permissions: string[];
  onSave: () => void;
  onCancel: () => void;
  onDelete: () => void;
  showHeader: boolean;
  showFooter: boolean;
  theme: "light" | "dark";
  children: ReactNode;
}

export function Dashboard(props: DashboardProps) {
  return (
    <div>
      <h1>{props.title}</h1>
      <p>{props.subtitle}</p>
      {props.children}
    </div>
  );
}
