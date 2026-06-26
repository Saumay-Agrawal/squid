import { Activity, BarChart3, Droplets, Users } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { MetricCard } from "@/components/ui/metric-card";
import type { DashboardData } from "@/lib/simulation";
import { formatAmount, formatDate, shortenAddress } from "@/lib/utils";

export function OverviewView({ data }: { data: DashboardData }) {
  const active = data.pools.reduce((sum, pool) => sum + pool.activeLiquidity, 0n);
  return <div className="space-y-4">
    <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <MetricCard title="Pools" value={String(data.pools.length)} note={`${data.positions.length} positions`} icon={Droplets} />
      <MetricCard title="Participants" value={String(data.participants.length)} note={`${data.counts.lpCount} LPs · ${data.counts.traderCount} traders`} icon={Users} />
      <MetricCard title="Actions" value={String(data.actions.length)} note={`${data.counts.swapCount} planned swaps`} icon={Activity} />
      <MetricCard title="Active liquidity" value={formatAmount(active)} note="Across all final pool states" icon={BarChart3} />
    </section>
    <div className="grid gap-4 lg:grid-cols-2">
      <Card><CardHeader><CardTitle>Simulation run</CardTitle><CardDescription>{data.description}</CardDescription></CardHeader>
        <CardContent className="grid gap-3 text-sm sm:grid-cols-2">
          <Info label="Format" value={data.format} /><Info label="Chain" value={String(data.chainId)} />
          <Info label="Generated" value={formatDate(data.runTimestamp)} /><Info label="Market" value={data.market.basePair} />
        </CardContent></Card>
      <Card><CardHeader><CardTitle>Contracts</CardTitle><CardDescription>Addresses generated for this run.</CardDescription></CardHeader>
        <CardContent className="space-y-3 text-sm">{Object.entries(data.contracts).map(([name, address]) =>
          <Info key={name} label={name} value={shortenAddress(address)} />)}</CardContent></Card>
    </div>
  </div>;
}

function Info({ label, value }: { label: string; value: string }) {
  return <div className="flex justify-between gap-4"><span className="capitalize text-muted-foreground">{label}</span><span className="font-mono text-xs">{value}</span></div>;
}
