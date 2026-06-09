import { Activity, Droplets, Layers3 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { PoolSummary } from "@/lib/dashboard";
import { formatAmount, formatFeeTier, formatTick, shortenHash } from "@/lib/utils";

export function PoolsView({ pools }: { pools: PoolSummary[] }) {
  const totalLiquidity = pools.reduce((sum, pool) => sum + pool.totalLiquidity, 0n);
  const activePools = pools.filter((pool) => pool.activeLiquidity > 0n).length;
  const totalLps = pools.reduce((sum, pool) => sum + pool.lpCount, 0);

  return (
    <div className="space-y-4">
      <section className="grid gap-4 md:grid-cols-3">
        <MetricCard title="Pools to review" value={String(pools.length)} note="Each scenario contributes one pool snapshot" icon={Layers3} />
        <MetricCard title="Pools in range" value={String(activePools)} note="Pools with active liquidity right now" icon={Activity} />
        <MetricCard title="Tracked liquidity" value={formatAmount(totalLiquidity)} note={`${totalLps} LP presences across pools`} icon={Droplets} />
      </section>

      <div className="space-y-4">
        {pools.map((pool) => (
          <details key={pool.poolId} className="group">
            <Card className="overflow-hidden">
              <summary className="cursor-pointer list-none">
                <CardHeader className="gap-3">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div className="space-y-1">
                      <CardTitle className="text-base">{pool.tokenPair}</CardTitle>
                      <CardDescription>{pool.description}</CardDescription>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <Badge variant="secondary">{pool.scenarioName}</Badge>
                      <Badge variant={pool.activeLiquidity > 0n ? "default" : "outline"}>
                        {pool.activeLiquidity > 0n ? "In range" : "Out of range"}
                      </Badge>
                    </div>
                  </div>
                  <div className="grid gap-3 text-sm text-muted-foreground sm:grid-cols-2 xl:grid-cols-4">
                    <StatLine label="Fee tier" value={formatFeeTier(pool.fee)} />
                    <StatLine label="LP count" value={String(pool.lpCount)} />
                    <StatLine label="Positions" value={String(pool.positionCount)} />
                    <StatLine label="Active liquidity" value={formatAmount(pool.activeLiquidity)} />
                  </div>
                </CardHeader>
              </summary>
              <CardContent className="border-t border-border/70 bg-background/40 pt-4">
                <div className="grid gap-3 text-sm sm:grid-cols-2 xl:grid-cols-3">
                  <StatLine label="Current tick" value={formatTick(pool.tick)} />
                  <StatLine label="Total liquidity" value={formatAmount(pool.totalLiquidity)} />
                  <StatLine label="Peak active liquidity" value={formatAmount(pool.peakActiveLiquidity)} />
                  <StatLine label="Active positions" value={String(pool.activePositionCount)} />
                  <StatLine label="Pool id" value={shortenHash(pool.poolId)} mono />
                </div>
              </CardContent>
            </Card>
          </details>
        ))}
      </div>
    </div>
  );
}

function MetricCard({
  title,
  value,
  note,
  icon: Icon,
}: {
  title: string;
  value: string;
  note: string;
  icon: React.ComponentType<{ className?: string }>;
}) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between space-y-0">
        <div>
          <CardDescription>{title}</CardDescription>
          <CardTitle className="mt-2 text-2xl">{value}</CardTitle>
        </div>
        <div className="rounded-2xl bg-primary/10 p-3 text-primary">
          <Icon className="h-4 w-4" />
        </div>
      </CardHeader>
      <CardContent className="text-sm text-muted-foreground">{note}</CardContent>
    </Card>
  );
}

function StatLine({ label, value, mono = false }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-xl border border-border/60 bg-background/70 px-3 py-2">
      <span className="text-muted-foreground">{label}</span>
      <span className={mono ? "font-mono text-xs" : "font-medium"}>{value}</span>
    </div>
  );
}
