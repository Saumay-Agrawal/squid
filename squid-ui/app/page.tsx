import { DashboardShell } from "@/components/dashboard-shell";
import { loadSquidDashboard } from "@/lib/dashboard";

export default function HomePage() {
  const data = loadSquidDashboard();

  return <DashboardShell data={data} />;
}
