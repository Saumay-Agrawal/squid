import { DashboardShell } from "@/components/dashboard-shell";
import { loadSimulationDashboard } from "@/lib/simulation";

export default function HomePage() {
  try {
    const data = loadSimulationDashboard();
    return <DashboardShell data={data} />;
  } catch (error) {
    return (
      <main className="mx-auto flex min-h-screen max-w-3xl items-center px-6">
        <section className="w-full rounded-3xl border bg-card p-8 shadow-sm">
          <p className="text-sm font-medium text-destructive">Artifact unavailable</p>
          <h1 className="mt-2 text-2xl font-semibold">The simulation dashboard could not load.</h1>
          <p className="mt-4 font-mono text-sm text-muted-foreground">
            {error instanceof Error ? error.message : "Unknown artifact error"}
          </p>
          <p className="mt-4 text-sm text-muted-foreground">
            Regenerate the artifact with the Foundry simulation script, then rebuild or refresh this page.
          </p>
        </section>
      </main>
    );
  }
}
