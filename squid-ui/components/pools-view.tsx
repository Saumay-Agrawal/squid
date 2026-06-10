"use client";

import { Fragment, useState } from "react";
import { Activity, ChevronDown, CircleHelp, Droplets, Layers3 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Tooltip } from "@/components/ui/tooltip";
import type { PoolSummary } from "@/lib/dashboard";
import { cn, formatAmountParts, formatBps, formatFeeTier, formatTick, shortenHash } from "@/lib/utils";

const SUMMARY_METRICS = {
  utilization: "Share of total liquidity currently active at the pool's final tick, with the peak share shown for comparison.",
  lps: "Active LP wallets over lifetime LP wallets for this pool, with the retained share shown below.",
  positions: "Active positions over total seeded positions for this pool, with the active share shown below.",
  tradeFlow: "Total seeded swaps executed against the pool, with the direction split shown below.",
} as const;

const DETAIL_METRICS = {
  currentTick: "The pool's final tick after all seeded actions finished.",
  feeTier: "The configured pool fee tier applied to swaps in this pool.",
  tickSpacing: "Minimum spacing allowed between initialized ticks in this pool.",
  lpFee: "The LP-facing fee currently applied by the pool state.",
  protocolFee: "The protocol-owned fee currently configured on the pool state.",
  activeLiquidity: "Liquidity currently in range at the final tick and therefore available to trade.",
  peakActiveLiquidity: "Highest in-range liquidity observed across the seeded scenario.",
  totalLiquidity: "Total seeded liquidity assigned to the pool across all positions.",
  utilization: "Share of total liquidity that is active at the final tick, with the peak share shown below.",
  flowSkew: "Directional balance of seeded swap flow, with the raw 0->1 and 1->0 counts shown below.",
  activeLps: "Number of LP wallets with at least one active position at the final tick.",
  lpRetention: "Share of lifetime LP wallets that still have an active position in range.",
  activePositions: "Number of positions currently in range, with total seeded positions shown below.",
  positionActivity: "Share of seeded positions that remain active at the final tick.",
} as const;

export function PoolsView({ pools }: { pools: PoolSummary[] }) {
  const [expandedPoolId, setExpandedPoolId] = useState<string | null>(pools[0]?.poolId ?? null);
  const totalLiquidity = pools.reduce((sum, pool) => sum + pool.totalLiquidity, 0n);
  const activePools = pools.filter((pool) => pool.activePositionCount > 0).length;
  const totalActiveLps = pools.reduce((sum, pool) => sum + pool.activeLpCount, 0);
  const totalSwaps = pools.reduce((sum, pool) => sum + pool.totalSwapCount, 0);
  const totalLiquidityParts = formatAmountParts(totalLiquidity);

  return (
    <div className="space-y-5">
      <section className="grid gap-4 md:grid-cols-3">
        <MetricCard title="Pools to review" value={String(pools.length)} note="Each seeded fee tier contributes one pool snapshot" icon={Layers3} />
        <MetricCard title="Pools in range" value={String(activePools)} note="Pools with at least one active position at the final tick" icon={Activity} />
        <MetricCard
          title="Tracked liquidity"
          value={totalLiquidityParts.primary}
          detail={totalLiquidityParts.secondary}
          note={`${totalActiveLps} active LPs and ${totalSwaps} seeded swaps across the board`}
          icon={Droplets}
        />
      </section>

      <Card className="overflow-hidden">
        <CardHeader className="gap-2">
          <CardTitle className="text-xl">Pool board</CardTitle>
          <CardDescription>Compare active liquidity, LP participation, and trade flow at a glance, then expand a pool for grouped detail.</CardDescription>
        </CardHeader>
        <CardContent className="px-0 pb-0">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">Pool</TableHead>
                  <TableHead>
                    <MetricHeader label="Utilization" tooltip={SUMMARY_METRICS.utilization} />
                  </TableHead>
                  <TableHead>
                    <MetricHeader label="LPs" tooltip={SUMMARY_METRICS.lps} />
                  </TableHead>
                  <TableHead>
                    <MetricHeader label="Positions" tooltip={SUMMARY_METRICS.positions} />
                  </TableHead>
                  <TableHead>
                    <MetricHeader label="Trade flow" tooltip={SUMMARY_METRICS.tradeFlow} />
                  </TableHead>
                  <TableHead className="w-12 pr-6"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {pools.map((pool) => {
                  const isExpanded = expandedPoolId === pool.poolId;
                  const detailId = `pool-detail-${pool.poolId}`;
                  const activeLiquidityParts = formatAmountParts(pool.activeLiquidity);
                  const peakActiveLiquidityParts = formatAmountParts(pool.peakActiveLiquidity);
                  const totalLiquidityParts = formatAmountParts(pool.totalLiquidity);

                  return (
                    <Fragment key={pool.poolId}>
                      <TableRow key={`${pool.poolId}-summary`} className="bg-transparent">
                        <TableCell className="pl-6">
                          <div className="min-w-52">
                            <div className="font-semibold">{pool.tokenPair}</div>
                            <div className="mt-1 text-xs text-muted-foreground">{pool.poolLabel}</div>
                            <div className="mt-2 font-mono text-[11px] text-muted-foreground">{shortenHash(pool.poolId)}</div>
                          </div>
                        </TableCell>
                        <TableCell>
                          <MetricStack
                            primary={formatBps(pool.liquidityUtilisationBps)}
                            secondary={`peak ${formatBps(pool.peakLiquidityUtilisationBps)}`}
                            emphasize={pool.activeLiquidity > 0n}
                          />
                        </TableCell>
                        <TableCell>
                          <MetricStack primary={`${pool.activeLpCount}/${pool.lifetimeLpCount}`} secondary={`${formatBps(pool.lpRetentionBps)} retained`} />
                        </TableCell>
                        <TableCell>
                          <MetricStack primary={`${pool.activePositionCount}/${pool.totalPositionCount}`} secondary={`${formatBps(pool.activePositionPercentageBps)} active`} />
                        </TableCell>
                        <TableCell>
                          <MetricStack primary={String(pool.totalSwapCount)} secondary={`${pool.zeroToOneSwapCount}:${pool.oneToZeroSwapCount} direction`} />
                        </TableCell>
                        <TableCell className="pr-6 text-right">
                          <button
                            type="button"
                            aria-expanded={isExpanded}
                            aria-controls={detailId}
                            aria-label={`${isExpanded ? "Collapse" : "Expand"} ${pool.poolLabel}`}
                            className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-border/70 bg-background/70 text-muted-foreground transition hover:bg-accent hover:text-foreground"
                            onClick={() => setExpandedPoolId(isExpanded ? null : pool.poolId)}
                          >
                            <ChevronDown className={cn("h-4 w-4 transition-transform", isExpanded ? "rotate-180" : "")} />
                          </button>
                        </TableCell>
                      </TableRow>
                      {isExpanded ? (
                        <TableRow className="bg-transparent hover:bg-transparent">
                          <TableCell className="border-0 bg-muted/20 p-0" colSpan={6} id={detailId}>
                            <div className="px-6 py-5">
                              <div className="mx-auto max-w-5xl">
                                <div className="flex items-start justify-between gap-4">
                                  <div>
                                    <div className="text-base font-semibold">{pool.tokenPair}</div>
                                    <div className="text-sm text-muted-foreground">{pool.poolLabel}</div>
                                  </div>
                                  <StatusBadge active={pool.activeLiquidity > 0n} />
                                </div>
                                <div className="mt-4 grid gap-4 xl:grid-cols-3">
                                  <GroupedMetricsCard
                                    title="Pool config"
                                    description="Static and current-state settings for the pool."
                                    metrics={[
                                      { label: "Current tick", value: formatTick(pool.tick), tooltip: DETAIL_METRICS.currentTick },
                                      { label: "Fee tier", value: formatFeeTier(pool.fee), tooltip: DETAIL_METRICS.feeTier },
                                      { label: "Tick spacing", value: String(pool.tickSpacing), tooltip: DETAIL_METRICS.tickSpacing },
                                      { label: "LP fee", value: formatFeeTier(pool.lpFee), tooltip: DETAIL_METRICS.lpFee },
                                      { label: "Protocol fee", value: formatFeeTier(pool.protocolFee), tooltip: DETAIL_METRICS.protocolFee },
                                    ]}
                                  />
                                  <GroupedMetricsCard
                                    title="Liquidity & flow"
                                    description="How much liquidity is usable and how swaps were distributed."
                                    metrics={[
                                      {
                                        label: "Active liquidity",
                                        value: activeLiquidityParts.primary,
                                        detail: activeLiquidityParts.secondary,
                                        tooltip: DETAIL_METRICS.activeLiquidity,
                                      },
                                      {
                                        label: "Peak active liquidity",
                                        value: peakActiveLiquidityParts.primary,
                                        detail: peakActiveLiquidityParts.secondary,
                                        tooltip: DETAIL_METRICS.peakActiveLiquidity,
                                      },
                                      {
                                        label: "Total liquidity",
                                        value: totalLiquidityParts.primary,
                                        detail: totalLiquidityParts.secondary,
                                        tooltip: DETAIL_METRICS.totalLiquidity,
                                      },
                                      {
                                        label: "Utilization",
                                        value: formatBps(pool.liquidityUtilisationBps),
                                        detail: `peak ${formatBps(pool.peakLiquidityUtilisationBps)}`,
                                        tooltip: DETAIL_METRICS.utilization,
                                      },
                                      {
                                        label: "Flow skew",
                                        value: formatBps(pool.flowSkewnessBps),
                                        detail: `${pool.zeroToOneSwapCount} 0->1 / ${pool.oneToZeroSwapCount} 1->0`,
                                        tooltip: DETAIL_METRICS.flowSkew,
                                      },
                                    ]}
                                  />
                                  <GroupedMetricsCard
                                    title="Participation"
                                    description="How many wallets and positions still remain active in range."
                                    metrics={[
                                      {
                                        label: "Active LPs",
                                        value: String(pool.activeLpCount),
                                        detail: `${pool.lifetimeLpCount} lifetime`,
                                        tooltip: DETAIL_METRICS.activeLps,
                                      },
                                      {
                                        label: "LP retention",
                                        value: formatBps(pool.lpRetentionBps),
                                        tooltip: DETAIL_METRICS.lpRetention,
                                      },
                                      {
                                        label: "Active positions",
                                        value: String(pool.activePositionCount),
                                        detail: `${pool.totalPositionCount} total`,
                                        tooltip: DETAIL_METRICS.activePositions,
                                      },
                                      {
                                        label: "Position activity",
                                        value: formatBps(pool.activePositionPercentageBps),
                                        tooltip: DETAIL_METRICS.positionActivity,
                                      },
                                    ]}
                                  />
                                </div>
                              </div>
                            </div>
                          </TableCell>
                        </TableRow>
                      ) : null}
                    </Fragment>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

function MetricHeader({ label, tooltip }: { label: string; tooltip: string }) {
  return (
    <MetricLabel label={label} tooltip={tooltip} tooltipSide="bottom" className="font-medium text-foreground/90" />
  );
}

function MetricCard({
  title,
  value,
  detail,
  note,
  icon: Icon,
}: {
  title: string;
  value: string;
  detail?: string | null;
  note: string;
  icon: React.ComponentType<{ className?: string }>;
}) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between space-y-0">
        <div>
          <CardDescription className="uppercase tracking-[0.14em]">{title}</CardDescription>
          <CardTitle className="mt-2 text-2xl tracking-[-0.03em]">{value}</CardTitle>
          {detail ? <div className="mt-1 text-sm text-muted-foreground">{detail}</div> : null}
        </div>
        <div className="rounded-2xl bg-primary/10 p-3 text-primary">
          <Icon className="h-4 w-4" />
        </div>
      </CardHeader>
      <CardContent className="text-sm text-muted-foreground">{note}</CardContent>
    </Card>
  );
}

function GroupedMetricsCard({
  title,
  description,
  metrics,
}: {
  title: string;
  description: string;
  metrics: Array<{
    label: string;
    value: string;
    detail?: string | null;
    tooltip: string;
    mono?: boolean;
  }>;
}) {
  return (
    <Card className="border-border/60 bg-background/70 shadow-none">
      <CardHeader className="pb-4">
        <CardTitle className="text-base">{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-3 sm:grid-cols-2 xl:grid-cols-1">
        {metrics.map((metric) => (
          <StatLine key={metric.label} {...metric} />
        ))}
      </CardContent>
    </Card>
  );
}

function StatLine({
  label,
  value,
  detail,
  tooltip,
  mono = false,
}: {
  label: string;
  value: string;
  detail?: string | null;
  tooltip: string;
  mono?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border/60 bg-background/80 px-3 py-3">
      <MetricLabel label={label} tooltip={tooltip} />
      <div className="text-right">
        <div className={mono ? "font-mono text-xs" : "font-medium"}>{value}</div>
        {detail ? <div className="text-xs text-muted-foreground">{detail}</div> : null}
      </div>
    </div>
  );
}

function MetricLabel({
  label,
  tooltip,
  className,
  tooltipSide = "top",
}: {
  label: string;
  tooltip: string;
  className?: string;
  tooltipSide?: "top" | "bottom";
}) {
  return (
    <span className={cn("inline-flex items-center gap-1.5 text-sm text-muted-foreground", className)}>
      <span>{label}</span>
      <Tooltip content={tooltip} side={tooltipSide}>
        <button
          type="button"
          aria-label={`What ${label.toLowerCase()} means`}
          className="inline-flex h-4 w-4 items-center justify-center rounded-full text-muted-foreground transition hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <CircleHelp className="h-3.5 w-3.5" />
        </button>
      </Tooltip>
    </span>
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
