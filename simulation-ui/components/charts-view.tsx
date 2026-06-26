"use client";
import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { DashboardData, HistoryRow } from "@/lib/simulation";
import { formatAmount, formatBps, formatTick } from "@/lib/utils";

type Metric = "liquidity" | "utilization" | "tick" | "positions" | "swaps";

export function ChartsView({ data }: { data: DashboardData }) {
  const [poolIndex, setPoolIndex] = useState(data.pools[0]?.index ?? 0);
  const [metric, setMetric] = useState<Metric>("liquidity");
  const points = useMemo(() => data.history.filter((point) => point.poolIndex === poolIndex && point.pool), [data.history, poolIndex]);
  const pool = data.pools.find((candidate) => candidate.index === poolIndex);
  const series = getSeries(points, metric);

  return <div className="space-y-4">
    <Card><CardHeader><CardTitle>Historical charts</CardTitle><CardDescription>Post-action state captured during deterministic simulation execution.</CardDescription></CardHeader>
      <CardContent className="space-y-3">
        <div className="flex flex-wrap gap-2">{data.pools.map((item) => <Button key={item.index} size="sm" variant={poolIndex === item.index ? "default" : "outline"} onClick={() => setPoolIndex(item.index)}>{item.label}</Button>)}</div>
        <div className="flex flex-wrap gap-2">{(["liquidity", "utilization", "tick", "positions", "swaps"] as Metric[]).map((item) => <Button key={item} size="sm" variant={metric === item ? "secondary" : "ghost"} onClick={() => setMetric(item)} className="capitalize">{item}</Button>)}</div>
      </CardContent></Card>
    <Card><CardHeader><CardTitle>{pool?.label} · {metric}</CardTitle><CardDescription>{series.length} checkpoints with activity in this pool.</CardDescription></CardHeader>
      <CardContent><LineChart series={series} /><div className="mt-4 flex flex-wrap gap-x-6 gap-y-2 text-xs text-muted-foreground">
        {series.slice(-6).map((point) => <span key={point.sequence}>#{point.sequence} {point.phase}: <strong className="text-foreground">{point.label}</strong></span>)}
      </div></CardContent></Card>
  </div>;
}

type ChartPoint = { sequence: number; phase: string; value: number; label: string };

function getSeries(points: HistoryRow[], metric: Metric): ChartPoint[] {
  return points.flatMap((point) => {
    const pool = point.pool;
    if (!pool) return [];
    if (metric === "liquidity") return [{ sequence: point.sequence, phase: point.phase, value: scaled(pool.activeLiquidity), label: formatAmount(pool.activeLiquidity) }];
    if (metric === "utilization") return [{ sequence: point.sequence, phase: point.phase, value: pool.liquidityUtilisationBps, label: formatBps(pool.liquidityUtilisationBps) }];
    if (metric === "tick") return [{ sequence: point.sequence, phase: point.phase, value: pool.tick, label: formatTick(pool.tick) }];
    if (metric === "positions") return [{ sequence: point.sequence, phase: point.phase, value: pool.activePositionCount, label: `${pool.activePositionCount}/${pool.totalPositionCount}` }];
    return [{ sequence: point.sequence, phase: point.phase, value: pool.totalSwapCount, label: String(pool.totalSwapCount) }];
  });
}

function scaled(value: bigint) {
  const text = value.toString();
  const divisor = Math.max(0, text.length - 12);
  return Number(value / (10n ** BigInt(divisor)));
}

function LineChart({ series }: { series: ChartPoint[] }) {
  if (series.length < 2) return <div className="flex h-72 items-center justify-center text-muted-foreground">Not enough checkpoints to chart.</div>;
  const width = 1000, height = 320, pad = 28;
  const values = series.map((p) => p.value);
  const min = Math.min(...values), max = Math.max(...values), span = max - min || 1;
  const coords = series.map((point, index) => ({
    ...point, x: pad + (index / (series.length - 1)) * (width - pad * 2),
    y: height - pad - ((point.value - min) / span) * (height - pad * 2),
  }));
  return <div className="overflow-x-auto"><svg viewBox={`0 0 ${width} ${height}`} className="min-w-[700px]">
    {[0, .25, .5, .75, 1].map((ratio) => <line key={ratio} x1={pad} x2={width-pad} y1={pad + ratio*(height-pad*2)} y2={pad + ratio*(height-pad*2)} stroke="currentColor" className="text-border" />)}
    <polyline points={coords.map((p) => `${p.x},${p.y}`).join(" ")} fill="none" stroke="var(--color-primary)" strokeWidth="3" strokeLinejoin="round" />
    {coords.map((p) => <g key={p.sequence}><circle cx={p.x} cy={p.y} r="5" fill="var(--color-primary)"><title>#{p.sequence} {p.phase}: {p.label}</title></circle></g>)}
  </svg></div>;
}
