// React-shaped smell: props-bloat (>8 props on a component). Owned by
// audit-architecture-react (heuristic R2 under dimension #6 coupling).
import { ReactNode } from "react";

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
