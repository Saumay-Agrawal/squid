import { DashboardShell } from "@/components/dashboard-shell";
import { loadSimulationDashboard } from "@/lib/simulation";

export default function HomePage() {
  const data = loadSimulationDashboard();

  return <DashboardShell data={data} />;
}

