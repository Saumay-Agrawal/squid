"use client";

import { Fragment, useState } from "react";
import { Activity, ArrowRight, ChevronDown, Droplets, Layers3 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { PoolSummary } from "@/lib/dashboard";
import { cn, formatAmount, formatAmountParts, formatFeeTier, formatTick, shortenHash } from "@/lib/utils";

export function PoolsView({ pools }: { pools: PoolSummary[] }) {
  const [expandedPoolId, setExpandedPoolId] = useState<string | null>(pools[0]?.poolId ?? null);
  const totalLiquidity = pools.reduce((sum, pool) => sum + pool.totalLiquidity, 0n);
  const activePools = pools.filter((pool) => pool.activeLiquidity > 0n).length;
  const totalLps = pools.reduce((sum, pool) => sum + pool.lpCount, 0);
  const totalLiquidityParts = formatAmountParts(totalLiquidity);

  return (
    <div className="space-y-5">
      <section className="grid gap-4 md:grid-cols-3">
        <MetricCard title="Pools to review" value={String(pools.length)} note="Each seeded fee tier contributes one pool snapshot" icon={Layers3} />
        <MetricCard title="Pools in range" value={String(activePools)} note="Pools with active liquidity right now" icon={Activity} />
        <MetricCard title="Tracked liquidity" value={totalLiquidityParts.primary} detail={totalLiquidityParts.secondary} note={`${totalLps} LP presences across pools`} icon={Droplets} />
      </section>

      <Card className="overflow-hidden">
        <CardHeader className="gap-2">
          <CardTitle className="text-xl">Pool board</CardTitle>
          <CardDescription>Compare seeded fee tiers, active liquidity, and LP concentration without opening every row.</CardDescription>
        </CardHeader>
        <CardContent className="px-0 pb-0">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">Pool</TableHead>
                  <TableHead>Fee</TableHead>
                  <TableHead>Spacing</TableHead>
                  <TableHead>Active liquidity</TableHead>
                  <TableHead>Total liquidity</TableHead>
                  <TableHead>LPs</TableHead>
                  <TableHead>Positions</TableHead>
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
                        <TableCell>{formatFeeTier(pool.fee)}</TableCell>
                        <TableCell>{pool.tickSpacing}</TableCell>
                        <TableCell>
                          <MetricStack
                            primary={activeLiquidityParts.primary}
                            secondary={`peak ${peakActiveLiquidityParts.primary}`}
                            emphasize={pool.activeLiquidity > 0n}
                          />
                        </TableCell>
                        <TableCell>{totalLiquidityParts.primary}</TableCell>
                        <TableCell>{pool.lpCount}</TableCell>
                        <TableCell>
                          <MetricStack primary={String(pool.positionCount)} secondary={`${pool.activePositionCount} active`} />
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
                          <TableCell className="border-0 bg-muted/20 p-0" colSpan={8} id={detailId}>
                            <div className="px-6 py-5">
                              <div className="mx-auto max-w-5xl">
                                <div className="flex items-start justify-between gap-4">
                                  <div>
                                    <div className="text-base font-semibold">{pool.tokenPair}</div>
                                    <div className="text-sm text-muted-foreground">{pool.poolLabel}</div>
                                  </div>
                                  <StatusBadge active={pool.activeLiquidity > 0n} />
                                </div>
                                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
                                  <StatLine label="Current tick" value={formatTick(pool.tick)} />
                                  <StatLine label="Fee tier" value={formatFeeTier(pool.fee)} />
                                  <StatLine label="Tick spacing" value={String(pool.tickSpacing)} />
                                  <StatLine label="Active liquidity" value={activeLiquidityParts.primary} detail={activeLiquidityParts.secondary} />
                                  <StatLine label="Peak active liquidity" value={peakActiveLiquidityParts.primary} detail={peakActiveLiquidityParts.secondary} />
                                </div>
                                <div className="mt-4 text-sm text-muted-foreground">
                                  <div className="mb-2 flex items-center gap-2 text-foreground">
                                    <ArrowRight className="h-4 w-4 text-primary" />
                                    Readout
                                  </div>
                                  <p>
                                    {pool.lpCount} LPs supply {totalLiquidityParts.primary}
                                    {totalLiquidityParts.secondary ? ` (${totalLiquidityParts.secondary})` : ""} total liquidity across {pool.positionCount} positions.{" "}
                                    {pool.activePositionCount} positions are live at the current tick.
                                  </p>
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

function StatLine({ label, value, detail, mono = false }: { label: string; value: string; detail?: string | null; mono?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border/60 bg-background/70 px-3 py-3">
      <span className="text-muted-foreground">{label}</span>
      <div className="text-right">
        <div className={mono ? "font-mono text-xs" : "font-medium"}>{value}</div>
        {detail ? <div className="text-xs text-muted-foreground">{detail}</div> : null}
      </div>
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
