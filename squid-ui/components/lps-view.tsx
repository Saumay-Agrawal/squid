"use client";

import { Fragment, useState } from "react";
import { ChevronDown } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { HexValue } from "@/components/ui/hex-value";
import { GroupedMetricsCard, MetricHeader, MetricLabel, MetricStack, PnlValue } from "@/components/ui/metric-elements";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { LpSummary } from "@/lib/dashboard";
import { cn, formatAmount, formatAmountParts, formatFeeTier, formatRatioPercent, formatSignedAmount, formatSignedAmountParts, startCase } from "@/lib/utils";

const LP_BOARD_METRICS = {
  positions: "Total positions seeded by this LP, with currently active positions shown underneath.",
  pools: "Distinct pools this LP has taken positions in.",
  invested: "Placeholder dollar value derived from seeded USD principal already tracked in the simulation artifact.",
  liquidityActive: "Share of this LP's total liquidity that is currently active across all tracked positions.",
  pnl: "Net outcome across all tracked positions for this LP.",
} as const;

const LP_PROFILE_METRICS = {
  positions: "Current active positions shown against the total tracked positions for this LP.",
  liquidityActive: "Share of this LP's total liquidity that is currently in range.",
  invested: "Placeholder dollar value sourced from the LP's seeded USD principal.",
  netPnl: "Net outcome across all tracked positions for this LP.",
} as const;

const POOL_ROW_METRICS = {
  token0Invested: "Total token 0 principal this LP committed across positions in this pool.",
  token1Invested: "Total token 1 principal this LP committed across positions in this pool.",
  pnl: "Net outcome for this LP's positions in this pool.",
  positions: "Total positions this LP seeded in this pool, with active positions shown underneath.",
} as const;

const POOL_DETAIL_METRICS = {
  liquidityActive: "Share of this LP's liquidity in the pool that is currently in range.",
  fees: "Total fees accrued by this LP from positions in this pool.",
  positions: "Active positions over total seeded positions for this LP in this pool.",
  pnl: "Net pooled outcome for this LP in this market.",
} as const;

const POSITION_ROW_METRICS = {
  identifier: "Compact position identifier derived from the tracked position ID.",
  status: "Whether the position is in range at the final simulated tick.",
  token0Invested: "Original token 0 amount committed to establish this position.",
  token1Invested: "Original token 1 amount committed to establish this position.",
  pnl: "Net outcome for this position across both tokens.",
} as const;

const POSITION_DETAIL_METRICS = {
  positionId: "Unique identifier for the position NFT or tracked position record.",
  range: "Lower and upper ticks that define where this position is active.",
  status: "Whether the position is in range at the final simulated tick.",
  liquidityActive: "Share of this position's liquidity that is currently in range.",
  initialToken0: "Original token 0 amount committed to establish this position.",
  initialToken1: "Original token 1 amount committed to establish this position.",
  currentToken0: "Current token 0 amount represented by the position at the final state.",
  currentToken1: "Current token 1 amount represented by the position at the final state.",
  feesToken0: "Fees accrued by this position in token 0.",
  feesToken1: "Fees accrued by this position in token 1.",
  netPnl: "Net outcome for this position across both tokens.",
} as const;

export function LpsView({ lps, selectedAddress }: { lps: LpSummary[]; selectedAddress: string }) {
  const [expandedAddress, setExpandedAddress] = useState<string | null>(selectedAddress || (lps[0]?.address ?? null));
  const participatingLps = lps.filter((lp) => lp.positionCount > 0);
  const totalInvested = participatingLps.reduce((sum, lp) => sum + lp.totalPrincipal0, 0n);
  const totalPnl = participatingLps.reduce((sum, lp) => sum + lp.totalPnl, 0n);
  const totalInvestedParts = formatAmountParts(totalInvested);
  const totalPnlParts = formatSignedAmountParts(totalPnl);

  return (
    <div className="space-y-4">
      <section className="grid gap-4 md:grid-cols-3">
        <SummaryCard
          title="LPs"
          value={String(participatingLps.length)}
          note="Number of LPs who have taken positions."
          tooltip={LP_PROFILE_METRICS.positions}
        />
        <SummaryCard
          title="Total amount invested"
          value={`$${totalInvestedParts.primary}`}
          detail={totalInvestedParts.secondary ? `$${totalInvestedParts.secondary}` : null}
          note="Placeholder total dollar value across all LPs, based on tracked seeded USD principal."
          tooltip={LP_PROFILE_METRICS.invested}
        />
        <SummaryCard
          title="Net PnL"
          value={totalPnlParts.primary}
          detail={totalPnlParts.secondary}
          note="Aggregate net PnL across all tracked LP positions."
          tooltip={LP_PROFILE_METRICS.netPnl}
          positive={totalPnl >= 0n}
        />
      </section>

      <Card className="overflow-hidden">
        <CardHeader className="gap-2">
          <CardTitle className="text-xl">LP board</CardTitle>
          <CardDescription>Compare participating LPs by footprint, invested capital placeholder, active liquidity share, and aggregate outcome.</CardDescription>
        </CardHeader>
        <CardContent className="px-0 pb-0">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">LP</TableHead>
                  <TableHead><MetricHeader label="Positions" tooltip={LP_BOARD_METRICS.positions} /></TableHead>
                  <TableHead><MetricHeader label="Pools" tooltip={LP_BOARD_METRICS.pools} /></TableHead>
                  <TableHead><MetricHeader label="Total amount invested" tooltip={LP_BOARD_METRICS.invested} /></TableHead>
                  <TableHead><MetricHeader label="Avg % liquidity active" tooltip={LP_BOARD_METRICS.liquidityActive} /></TableHead>
                  <TableHead><MetricHeader label="Net PnL" tooltip={LP_BOARD_METRICS.pnl} /></TableHead>
                  <TableHead className="w-12 pr-6" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {participatingLps.map((lp) => {
                  const isExpanded = expandedAddress === lp.address;
                  const isSelected = lp.address === selectedAddress;
                  const detailId = `lp-detail-${lp.address}`;

                  return (
                    <Fragment key={lp.address}>
                      <TableRow className={cn("bg-transparent", isSelected ? "bg-primary/5" : "")}>
                        <TableCell className="pl-6">
                          <div className="min-w-52">
                            <div className="flex flex-wrap items-center gap-2">
                              <span className="font-semibold">{lp.label}</span>
                              {isSelected ? <Badge>You</Badge> : null}
                              {lp.tier ? <Badge variant="secondary">{startCase(lp.tier)}</Badge> : null}
                              {lp.anchor ? <Badge variant="outline">Anchor</Badge> : null}
                            </div>
                            <HexValue value={lp.address} className="mt-1" textClassName="text-xs text-muted-foreground" />
                          </div>
                        </TableCell>
                        <TableCell>
                          <MetricStack primary={String(lp.positionCount)} secondary={`${lp.activePositionCount} active`} />
                        </TableCell>
                        <TableCell>{lp.poolCount}</TableCell>
                        <TableCell>{formatUsdPlaceholder(lp.totalPrincipal0)}</TableCell>
                        <TableCell>{formatRatioPercent(lp.totalActiveLiquidity, lp.totalLiquidity)}</TableCell>
                        <TableCell>
                          <PnlValue value={formatSignedAmount(lp.totalPnl)} positive={lp.totalPnl >= 0n} />
                        </TableCell>
                        <TableCell className="pr-6 text-right">
                          <button
                            type="button"
                            aria-expanded={isExpanded}
                            aria-controls={detailId}
                            aria-label={`${isExpanded ? "Collapse" : "Expand"} ${lp.label}`}
                            className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-border/70 bg-background/70 text-muted-foreground transition hover:bg-accent hover:text-foreground"
                            onClick={() => setExpandedAddress(isExpanded ? null : lp.address)}
                          >
                            <ChevronDown className={cn("h-4 w-4 transition-transform", isExpanded ? "rotate-180" : "")} />
                          </button>
                        </TableCell>
                      </TableRow>
                      {isExpanded ? (
                        <TableRow className="bg-transparent hover:bg-transparent">
                          <TableCell className="border-0 bg-muted/20 p-0" colSpan={7} id={detailId}>
                            <div className="px-6 py-5">
                              <LpProfileView lp={lp} selected={lp.address === selectedAddress} />
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

function SummaryCard({
  title,
  value,
  note,
  tooltip,
  detail,
  positive,
}: {
  title: string;
  value: string;
  note: string;
  tooltip: string;
  detail?: string | null;
  positive?: boolean;
}) {
  return (
    <Card className="border-border/60 bg-background/70 shadow-none">
      <CardHeader className="gap-3 pb-4">
        <MetricLabel label={title} tooltip={tooltip} className="text-xs uppercase tracking-[0.18em]" />
        <CardTitle
          className={cn(
            "text-3xl tracking-[-0.04em]",
            positive === undefined ? "" : positive ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
          )}
        >
          {value}
        </CardTitle>
        {detail ? <div className="text-sm text-muted-foreground">{detail}</div> : null}
        <CardDescription>{note}</CardDescription>
      </CardHeader>
    </Card>
  );
}

function LpProfileView({ lp, selected }: { lp: LpSummary; selected: boolean }) {
  const investedParts = formatAmountParts(lp.totalPrincipal0);
  const pnlParts = formatSignedAmountParts(lp.totalPnl);
  const liquidityActivePercent = formatRatioPercent(lp.totalActiveLiquidity, lp.totalLiquidity);

  return (
    <div className="space-y-4">
      <Card className="overflow-hidden border-primary/10 bg-card/88 shadow-lg shadow-primary/5">
        <CardHeader className="gap-5">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div className="space-y-1">
              <div className="flex flex-wrap items-center gap-2">
                <CardTitle className="text-xl">{lp.label}</CardTitle>
                {selected ? <Badge>You</Badge> : null}
                {lp.tier ? <Badge variant="secondary">{startCase(lp.tier)}</Badge> : null}
                {lp.anchor ? <Badge variant="outline">Anchor</Badge> : null}
              </div>
              <CardDescription>
                <HexValue value={lp.address} textClassName="text-sm text-muted-foreground" />
              </CardDescription>
            </div>
            <div className="flex flex-wrap gap-2">
              <Badge variant="secondary">{lp.poolCount} pools</Badge>
              <Badge variant="secondary">{lp.positionCount} positions</Badge>
            </div>
          </div>
          <div className="grid gap-4 xl:grid-cols-3">
            <SummaryCard
              title="Positions"
              value={`${lp.activePositionCount} / ${lp.positionCount}`}
              note="Active positions out of total tracked positions."
              tooltip={LP_PROFILE_METRICS.positions}
            />
            <SummaryCard
              title="Liquidity active"
              value={liquidityActivePercent}
              note={`${formatAmount(lp.totalActiveLiquidity)} active of ${formatAmount(lp.totalLiquidity)} total liquidity.`}
              tooltip={LP_PROFILE_METRICS.liquidityActive}
            />
            <SummaryCard
              title="Net PnL"
              value={pnlParts.primary}
              detail={pnlParts.secondary}
              note={`Total amount invested ${formatUsdPlaceholder(lp.totalPrincipal0)}.`}
              tooltip={LP_PROFILE_METRICS.netPnl}
              positive={lp.totalPnl >= 0n}
            />
          </div>
          <div className="rounded-2xl border border-border/60 bg-background/60 px-4 py-3 text-sm text-muted-foreground">
            Total amount invested {formatUsdPlaceholder(lp.totalPrincipal0)}
            {investedParts.secondary ? ` • ${investedParts.secondary}` : ""}
          </div>
        </CardHeader>
      </Card>

      <LpPoolsBoard groups={lp.groups} lpAddress={lp.address} />
    </div>
  );
}

function LpPoolsBoard({
  groups,
  lpAddress,
}: {
  groups: LpSummary["groups"];
  lpAddress: string;
}) {
  const [expandedPoolId, setExpandedPoolId] = useState<string | null>(groups[0]?.poolId ?? null);

  return (
    <Card className="overflow-hidden">
      <CardHeader className="gap-2">
        <CardTitle className="text-xl">LP pools</CardTitle>
        <CardDescription>Expand a pool to inspect its positions inline in the same structure as Your Profile.</CardDescription>
      </CardHeader>
      <CardContent className="px-0 pb-0">
        <div className="space-y-px">
          {groups.map((group) => {
            const isExpanded = expandedPoolId === group.poolId;
            const detailId = `${lpAddress}-${group.poolId}`;
            const pnlParts = formatSignedAmountParts(group.totalPnl);
            const token0InvestedParts = formatAmountParts(group.totalPrincipal0);
            const token1InvestedParts = formatAmountParts(group.totalPrincipal1);
            const liquidityActivePercent = formatRatioPercent(group.totalActiveLiquidity, group.totalLiquidity);

            return (
              <div key={group.poolId} className="border-t border-border/60 first:border-t-0">
                <div className="grid items-center gap-3 px-6 py-4 text-sm lg:grid-cols-[minmax(0,1.6fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_40px]">
                  <div>
                    <div className="font-semibold">{group.poolLabel}</div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      Pool {group.poolIndex + 1} · {formatFeeTier(group.fee)} fee · spacing {group.tickSpacing}
                    </div>
                  </div>
                  <div>
                    <MetricLabel label="USD invested" tooltip={POOL_ROW_METRICS.token0Invested} className="text-xs uppercase tracking-[0.16em]" />
                    <div className="mt-1 font-medium">{token0InvestedParts.primary}</div>
                  </div>
                  <div>
                    <MetricLabel label="ETH invested" tooltip={POOL_ROW_METRICS.token1Invested} className="text-xs uppercase tracking-[0.16em]" />
                    <div className="mt-1 font-medium">{token1InvestedParts.primary}</div>
                  </div>
                  <div>
                    <MetricLabel label="PnL" tooltip={POOL_ROW_METRICS.pnl} className="text-xs uppercase tracking-[0.16em]" />
                    <PnlValue value={pnlParts.primary} positive={group.totalPnl >= 0n} className="mt-1 font-medium" />
                  </div>
                  <div>
                    <MetricLabel label="Positions" tooltip={POOL_ROW_METRICS.positions} className="text-xs uppercase tracking-[0.16em]" />
                    <div className="mt-1">
                      <MetricStack primary={String(group.positionCount)} secondary={`${group.activePositionCount} active`} />
                    </div>
                  </div>
                  <div className="text-right">
                    <button
                      type="button"
                      aria-expanded={isExpanded}
                      aria-controls={detailId}
                      aria-label={`${isExpanded ? "Collapse" : "Expand"} ${group.poolLabel}`}
                      className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-border/70 bg-background/70 text-muted-foreground transition hover:bg-accent hover:text-foreground"
                      onClick={() => setExpandedPoolId(isExpanded ? null : group.poolId)}
                    >
                      <ChevronDown className={cn("h-4 w-4 transition-transform", isExpanded ? "rotate-180" : "")} />
                    </button>
                  </div>
                </div>
                {isExpanded ? (
                  <div id={detailId} className="border-t border-border/60 bg-muted/20 px-6 py-5">
                    <div className="mx-auto max-w-5xl">
                      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                        <div>
                          <div className="text-base font-semibold">{group.poolLabel}</div>
                          <div className="text-sm text-muted-foreground">
                            Pool {group.poolIndex + 1} · {formatFeeTier(group.fee)} fee · spacing {group.tickSpacing}
                          </div>
                        </div>
                        <div className="flex flex-wrap gap-2">
                          <Badge variant="secondary">{group.positionCount} positions</Badge>
                          <Badge variant="outline">{group.activePositionCount} active</Badge>
                        </div>
                      </div>
                      <div className="mt-4 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                        <PoolMetricCard
                          title="Liquidity active"
                          tooltip={POOL_DETAIL_METRICS.liquidityActive}
                          value={liquidityActivePercent}
                          detail={`${formatAmount(group.totalActiveLiquidity)} active`}
                          note="Current in-range share of this LP's pool liquidity."
                        />
                        <PoolMetricCard
                          title="Fees"
                          tooltip={POOL_DETAIL_METRICS.fees}
                          value={formatAmount(group.totalFees)}
                          detail={formatAmountParts(group.totalFees).secondary}
                          note="Aggregate fees accrued by this LP in the pool."
                        />
                        <PoolMetricCard
                          title="Positions"
                          tooltip={POOL_DETAIL_METRICS.positions}
                          value={`${group.activePositionCount}/${group.positionCount}`}
                          note="Active positions out of this LP's total seeded positions in the pool."
                        />
                        <PoolMetricCard
                          title="Net PnL"
                          tooltip={POOL_DETAIL_METRICS.pnl}
                          value={pnlParts.primary}
                          detail={pnlParts.secondary}
                          note="Aggregate net outcome for this LP in the pool."
                          positive={group.totalPnl >= 0n}
                        />
                      </div>
                      <div className="mt-4">
                        <ProfileLikePositionsBoard positions={group.positions} groupKey={`${lpAddress}-${group.poolId}`} />
                      </div>
                    </div>
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}

function PoolMetricCard({
  title,
  tooltip,
  value,
  detail,
  note,
  positive,
}: {
  title: string;
  tooltip: string;
  value: string;
  detail?: string | null;
  note: string;
  positive?: boolean;
}) {
  return (
    <Card className="border-border/60 bg-background/70 shadow-none">
      <CardHeader className="gap-3 pb-4">
        <MetricLabel label={title} tooltip={tooltip} className="text-xs uppercase tracking-[0.18em]" />
        <CardTitle
          className={cn(
            "text-2xl tracking-[-0.04em]",
            positive === undefined ? "" : positive ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
          )}
        >
          {value}
        </CardTitle>
        {detail ? <div className="text-sm text-muted-foreground">{detail}</div> : null}
        <CardDescription>{note}</CardDescription>
      </CardHeader>
    </Card>
  );
}

function ProfileLikePositionsBoard({
  positions,
  groupKey,
}: {
  positions: LpSummary["groups"][number]["positions"];
  groupKey: string;
}) {
  const [expandedPositionId, setExpandedPositionId] = useState<string | null>(positions[0]?.positionId ?? null);

  return (
    <div className="space-y-2">
      {positions.map((position) => {
        const isExpanded = expandedPositionId === position.positionId;
        const detailId = `${groupKey}-${position.positionId}`;
        const token0InvestedParts = formatAmountParts(position.principalAmount0);
        const token1InvestedParts = formatAmountParts(position.principalAmount1);
        const currentToken0Parts = formatAmountParts(position.currentAmount0);
        const currentToken1Parts = formatAmountParts(position.currentAmount1);
        const feesToken0Parts = formatAmountParts(position.feeAccumulated0);
        const feesToken1Parts = formatAmountParts(position.feeAccumulated1);
        const liquidityActive = formatRatioPercent(position.activeLiquidity, position.liquidity);

        return (
          <div key={position.positionId} className="overflow-hidden rounded-2xl border border-border/60 bg-card/75">
            <div className="grid items-center gap-3 px-4 py-4 text-sm lg:grid-cols-[minmax(140px,0.95fr)_minmax(120px,0.7fr)_minmax(140px,0.8fr)_minmax(140px,0.8fr)_minmax(140px,0.8fr)_40px]">
              <div>
                <MetricLabel label="Position" tooltip={POSITION_ROW_METRICS.identifier} className="text-xs uppercase tracking-[0.16em]" />
                <div className="mt-1">
                  <HexValue value={position.positionId} prefix="Pos" textClassName="text-sm font-medium" />
                </div>
              </div>
              <div>
                <MetricLabel label="Status" tooltip={POSITION_ROW_METRICS.status} className="text-xs uppercase tracking-[0.16em]" />
                <div className="mt-1">
                  <Badge variant={position.active ? "default" : "outline"} className={position.active ? "bg-emerald-600 text-white" : ""}>
                    {position.active ? "Active" : "Inactive"}
                  </Badge>
                </div>
              </div>
              <div>
                <MetricLabel label="USD invested" tooltip={POSITION_ROW_METRICS.token0Invested} className="text-xs uppercase tracking-[0.16em]" />
                <div className="mt-1 font-medium">{token0InvestedParts.primary}</div>
                {token0InvestedParts.secondary ? <div className="text-xs text-muted-foreground">{token0InvestedParts.secondary}</div> : null}
              </div>
              <div>
                <MetricLabel label="ETH invested" tooltip={POSITION_ROW_METRICS.token1Invested} className="text-xs uppercase tracking-[0.16em]" />
                <div className="mt-1 font-medium">{token1InvestedParts.primary}</div>
                {token1InvestedParts.secondary ? <div className="text-xs text-muted-foreground">{token1InvestedParts.secondary}</div> : null}
              </div>
              <div>
                <MetricLabel label="Current PnL" tooltip={POSITION_ROW_METRICS.pnl} className="text-xs uppercase tracking-[0.16em]" />
                <PnlValue value={formatSignedAmount(position.netPnl)} positive={position.netPnl >= 0n} className="mt-1 font-medium" />
              </div>
              <div className="text-right">
                <button
                  type="button"
                  aria-expanded={isExpanded}
                  aria-controls={detailId}
                  aria-label={`${isExpanded ? "Collapse" : "Expand"} position ${position.positionId}`}
                  className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-border/70 bg-background/70 text-muted-foreground transition hover:bg-accent hover:text-foreground"
                  onClick={() => setExpandedPositionId(isExpanded ? null : position.positionId)}
                >
                  <ChevronDown className={cn("h-4 w-4 transition-transform", isExpanded ? "rotate-180" : "")} />
                </button>
              </div>
            </div>
            {isExpanded ? (
              <div id={detailId} className="border-t border-border/60 bg-background/55 px-4 py-4">
                <div className="grid gap-4 xl:grid-cols-3">
                  <GroupedMetricsCard
                    title="Position config"
                    description="Basic position metadata, range definition, and status."
                    metrics={[
                      { label: "Position ID", value: <HexValue value={position.positionId} textClassName="text-xs" />, tooltip: POSITION_DETAIL_METRICS.positionId, mono: true },
                      { label: "Range", value: `[${position.tickLower}, ${position.tickUpper}]`, tooltip: POSITION_DETAIL_METRICS.range, mono: true },
                      { label: "Status", value: position.active ? "Active" : "Inactive", tooltip: POSITION_DETAIL_METRICS.status },
                      { label: "Liquidity active", value: liquidityActive, detail: `${formatAmount(position.activeLiquidity)} of ${formatAmount(position.liquidity)}`, tooltip: POSITION_DETAIL_METRICS.liquidityActive },
                    ]}
                  />
                  <GroupedMetricsCard
                    title="Position stats"
                    description="Initial and current balances plus fees accrued for each pool token."
                    metrics={[
                      { label: "USD initial", value: token0InvestedParts.primary, detail: token0InvestedParts.secondary, tooltip: POSITION_DETAIL_METRICS.initialToken0 },
                      { label: "ETH initial", value: token1InvestedParts.primary, detail: token1InvestedParts.secondary, tooltip: POSITION_DETAIL_METRICS.initialToken1 },
                      { label: "USD current", value: currentToken0Parts.primary, detail: currentToken0Parts.secondary, tooltip: POSITION_DETAIL_METRICS.currentToken0 },
                      { label: "ETH current", value: currentToken1Parts.primary, detail: currentToken1Parts.secondary, tooltip: POSITION_DETAIL_METRICS.currentToken1 },
                      { label: "USD fees", value: feesToken0Parts.primary, detail: feesToken0Parts.secondary, tooltip: POSITION_DETAIL_METRICS.feesToken0 },
                      { label: "ETH fees", value: feesToken1Parts.primary, detail: feesToken1Parts.secondary, tooltip: POSITION_DETAIL_METRICS.feesToken1 },
                    ]}
                  />
                  <GroupedMetricsCard
                    title="Position performance"
                    description="How active this position stayed and the resulting aggregate outcome."
                    metrics={[
                      { label: "Liquidity active", value: liquidityActive, detail: `${formatAmount(position.activeLiquidity)} of ${formatAmount(position.liquidity)}`, tooltip: POSITION_DETAIL_METRICS.liquidityActive },
                      { label: "Net PnL", value: formatSignedAmount(position.netPnl), detail: `USD ${formatSignedAmount(position.netPnl0)} / ETH ${formatSignedAmount(position.netPnl1)}`, tooltip: POSITION_DETAIL_METRICS.netPnl, positive: position.netPnl >= 0n },
                    ]}
                  />
                </div>
              </div>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}

function formatUsdPlaceholder(value: bigint) {
  return `$${formatAmount(value)}`;
}
