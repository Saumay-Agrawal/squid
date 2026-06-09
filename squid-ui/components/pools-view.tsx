import { Activity, ArrowRight, Droplets, Layers3 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { PoolSummary } from "@/lib/dashboard";
import { cn, formatAmount, formatFeeTier, formatTick, shortenHash } from "@/lib/utils";

export function PoolsView({ pools }: { pools: PoolSummary[] }) {
  const totalLiquidity = pools.reduce((sum, pool) => sum + pool.totalLiquidity, 0n);
  const activePools = pools.filter((pool) => pool.activeLiquidity > 0n).length;
  const totalLps = pools.reduce((sum, pool) => sum + pool.lpCount, 0);

  return (
    <div className="space-y-5">
      <section className="grid gap-4 md:grid-cols-3">
        <MetricCard title="Pools to review" value={String(pools.length)} note="Each scenario contributes one pool snapshot" icon={Layers3} />
        <MetricCard title="Pools in range" value={String(activePools)} note="Pools with active liquidity right now" icon={Activity} />
        <MetricCard title="Tracked liquidity" value={formatAmount(totalLiquidity)} note={`${totalLps} LP presences across pools`} icon={Droplets} />
      </section>

      <Card className="overflow-hidden">
        <CardHeader className="gap-2">
          <CardTitle className="text-xl">Pool board</CardTitle>
          <CardDescription>Compare fee tiers, active liquidity, and LP concentration without opening every row.</CardDescription>
        </CardHeader>
        <CardContent className="px-0 pb-0">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">Pool</TableHead>
                  <TableHead>Scenario</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Fee</TableHead>
                  <TableHead>Current tick</TableHead>
                  <TableHead>Active liquidity</TableHead>
                  <TableHead>Total liquidity</TableHead>
                  <TableHead>LPs</TableHead>
                  <TableHead className="pr-6">Positions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {pools.map((pool) => (
                  <TableRow key={pool.poolId} className="bg-transparent">
                    <TableCell className="pl-6">
                      <div className="min-w-52">
                        <div className="font-semibold">{pool.tokenPair}</div>
                        <div className="mt-1 text-xs text-muted-foreground">{pool.description}</div>
                        <div className="mt-2 font-mono text-[11px] text-muted-foreground">{shortenHash(pool.poolId)}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant="secondary">{pool.scenarioName}</Badge>
                    </TableCell>
                    <TableCell>
                      <StatusBadge active={pool.activeLiquidity > 0n} />
                    </TableCell>
                    <TableCell>{formatFeeTier(pool.fee)}</TableCell>
                    <TableCell>{formatTick(pool.tick)}</TableCell>
                    <TableCell>
                      <MetricStack
                        primary={formatAmount(pool.activeLiquidity)}
                        secondary={`peak ${formatAmount(pool.peakActiveLiquidity)}`}
                        emphasize={pool.activeLiquidity > 0n}
                      />
                    </TableCell>
                    <TableCell>{formatAmount(pool.totalLiquidity)}</TableCell>
                    <TableCell>{pool.lpCount}</TableCell>
                    <TableCell className="pr-6">
                      <MetricStack primary={String(pool.positionCount)} secondary={`${pool.activePositionCount} active`} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>

      <section className="grid gap-4 xl:grid-cols-2">
        {pools.map((pool) => (
          <Card key={`${pool.poolId}-detail`} className="border-border/70 bg-card/82">
            <CardHeader className="gap-3">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <CardTitle className="text-base">{pool.tokenPair}</CardTitle>
                  <CardDescription>{pool.scenarioName}</CardDescription>
                </div>
                <StatusBadge active={pool.activeLiquidity > 0n} />
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                <StatLine label="Current tick" value={formatTick(pool.tick)} />
                <StatLine label="Fee tier" value={formatFeeTier(pool.fee)} />
                <StatLine label="Active liquidity" value={formatAmount(pool.activeLiquidity)} />
                <StatLine label="Peak active liquidity" value={formatAmount(pool.peakActiveLiquidity)} />
              </div>
            </CardHeader>
            <CardContent className="pt-0">
              <div className="rounded-2xl border border-border/70 bg-background/60 p-4 text-sm text-muted-foreground">
                <div className="mb-2 flex items-center gap-2 text-foreground">
                  <ArrowRight className="h-4 w-4 text-primary" />
                  Readout
                </div>
                <p>
                  {pool.lpCount} LPs supply {formatAmount(pool.totalLiquidity)} total liquidity across {pool.positionCount} positions.
                  {" "}
                  {pool.activePositionCount} positions are live at the current tick.
                </p>
              </div>
            </CardContent>
          </Card>
        ))}
      </section>
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
          <CardDescription className="uppercase tracking-[0.14em]">{title}</CardDescription>
          <CardTitle className="mt-2 text-2xl tracking-[-0.03em]">{value}</CardTitle>
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
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border/60 bg-background/70 px-3 py-3">
      <span className="text-muted-foreground">{label}</span>
      <span className={mono ? "font-mono text-xs" : "font-medium"}>{value}</span>
    </div>
  );
}

function MetricStack({
  primary,
  secondary,
  emphasize = false,
}: {
  primary: string;
  secondary: string;
  emphasize?: boolean;
}) {
  return (
    <div>
      <div className={cn("font-medium", emphasize ? "text-emerald-600 dark:text-emerald-400" : "")}>{primary}</div>
      <div className="text-xs text-muted-foreground">{secondary}</div>
    </div>
  );
}

function StatusBadge({ active }: { active: boolean }) {
  return <Badge className={cn(active ? "bg-emerald-600 text-white" : "bg-transparent text-foreground", active ? "" : "border-border")} variant={active ? "default" : "outline"}>{active ? "In range" : "Out of range"}</Badge>;
}
