import { Activity, ArrowRightLeft, Layers3, TrendingUp } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { DashboardData } from "@/lib/simulation";
import { formatAmount, formatFeeTier, formatTick, shortenHash } from "@/lib/utils";

export function PoolsView({ data }: { data: DashboardData }) {
  const totalActiveLiquidity = data.poolRows.reduce((sum, row) => sum + row.activeLiquidity, 0n);
  const peakLiquidity = data.poolRows.reduce((sum, row) => sum + row.peakActiveLiquidity, 0n);

  return (
    <div className="space-y-4">
      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard title="Scenarios" value={String(data.scenarios.length)} note="Simulation runs loaded" icon={Layers3} />
        <MetricCard title="Pools" value={String(data.poolRows.length)} note="Distinct pool snapshots" icon={Activity} />
        <MetricCard title="Active Liquidity" value={formatAmount(totalActiveLiquidity)} note="Summed final active liquidity" icon={TrendingUp} />
        <MetricCard title="Peak Liquidity" value={formatAmount(peakLiquidity)} note="Summed peak active liquidity" icon={ArrowRightLeft} />
      </section>

      <Card>
        <CardHeader>
          <CardTitle>Pools</CardTitle>
          <CardDescription>Final pool state per simulation scenario.</CardDescription>
        </CardHeader>
        <CardContent className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Scenario</TableHead>
                <TableHead>Pair</TableHead>
                <TableHead>Fee</TableHead>
                <TableHead>Tick</TableHead>
                <TableHead>Total Liquidity</TableHead>
                <TableHead>Active Liquidity</TableHead>
                <TableHead>LP Count</TableHead>
                <TableHead>Pool Id</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.poolRows.map((row) => (
                <TableRow key={row.poolId}>
                  <TableCell className="min-w-48">
                    <div className="font-medium">{row.scenarioName}</div>
                    <div className="text-xs text-muted-foreground">{row.description}</div>
                  </TableCell>
                  <TableCell>
                    <Badge variant="secondary">{row.tokenPair}</Badge>
                  </TableCell>
                  <TableCell>{formatFeeTier(row.fee)}</TableCell>
                  <TableCell>{formatTick(row.tick)}</TableCell>
                  <TableCell>{formatAmount(row.totalLiquidity)}</TableCell>
                  <TableCell>{formatAmount(row.activeLiquidity)}</TableCell>
                  <TableCell>{row.lpCount}</TableCell>
                  <TableCell className="font-mono text-xs">{shortenHash(row.poolId)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <div className="grid gap-4 xl:grid-cols-3">
        {data.poolRows.map((row) => (
          <Card key={`${row.poolId}-detail`} className="bg-card/90">
            <CardHeader>
              <CardTitle className="flex items-center justify-between gap-4 text-base">
                <span>{row.tokenPair}</span>
                <Badge variant={row.activeLiquidity > 0n ? "default" : "secondary"}>{row.activeLiquidity > 0n ? "Active" : "Out of range"}</Badge>
              </CardTitle>
              <CardDescription>{row.scenarioName}</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3 text-sm">
              <InfoLine label="Current tick" value={formatTick(row.tick)} />
              <InfoLine label="Total liquidity" value={formatAmount(row.totalLiquidity)} />
              <InfoLine label="Peak active liquidity" value={formatAmount(row.peakActiveLiquidity)} />
              <InfoLine label="Actions" value={String(row.actionCount)} />
            </CardContent>
          </Card>
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

function InfoLine({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-muted-foreground">{label}</span>
      <span className="font-mono text-xs">{value}</span>
    </div>
  );
}
