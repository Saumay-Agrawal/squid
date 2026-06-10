"use client";

import { useState } from "react";
import { Activity, ArrowRightLeft, ChevronDown, ExternalLink, Droplets, Users } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { HexValue } from "@/components/ui/hex-value";
import { GroupedMetricsCard, MetricLabel, MetricStack, PnlValue } from "@/components/ui/metric-elements";
import { cn, formatAmount, formatAmountParts, formatBlock, formatBps, formatCompactTokenPair, formatFeeTier, formatRatioPercent, formatSignedAmount, formatSignedAmountParts, formatTimestamp, shortenHash, startCase } from "@/lib/utils";
import type { LpSummary, PoolSummary } from "@/lib/dashboard";

const PROFILE_METRICS = {
  positions: "Current active positions shown against the total tracked positions for your selected wallet.",
  liquidityActive: "Share of your wallet's total liquidity that is currently in range.",
  netPnl: "Net outcome across all of your tracked positions.",
} as const;

const PROFILE_GROUP_ROW_METRICS = {
  token0Invested: "Total token 0 principal your wallet committed across positions in this pool.",
  token1Invested: "Total token 1 principal your wallet committed across positions in this pool.",
  pnl: "Net outcome for your positions in this pool.",
  positions: "Total positions you seeded in this pool, with active positions shown underneath.",
} as const;

const PROFILE_GROUP_DETAIL_METRICS = {
  utilization: "Share of total pool liquidity currently active at the final tick, with the peak share shown for comparison.",
  lps: "Active LP wallets over lifetime LP wallets for this pool, with retained share shown underneath.",
  positions: "Active positions over total seeded positions for this pool, with active share shown underneath.",
  tradeFlow: "Total seeded swaps executed against this pool, with direction split shown underneath.",
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
  rangeWidth: "Distance between the lower and upper ticks for this position.",
  status: "Whether the position is in range at the final simulated tick.",
  created: "Timestamp and block when this position was first created.",
  age: "Elapsed time in seconds since the position was created.",
  initialToken0: "Original token 0 amount committed to establish this position.",
  initialToken1: "Original token 1 amount committed to establish this position.",
  currentToken0: "Current token 0 amount represented by the position at the final state.",
  currentToken1: "Current token 1 amount represented by the position at the final state.",
  feesToken0: "Fees accrued by this position in token 0.",
  feesToken1: "Fees accrued by this position in token 1.",
  activeLiquidityShare: "Share of this position's liquidity that is currently in range.",
  activeSwapVolume0Share: "Share of token 0 swap volume that occurred while this position was active in range.",
  activeSwapVolume1Share: "Share of token 1 swap volume that occurred while this position was active in range.",
  netPnl: "Net outcome for this position across both tokens.",
} as const;

export function ProfileView({
  lps,
  pools,
  selectedAddress,
  selectedLabel,
  onOpenPoolDetails,
}: {
  lps: LpSummary[];
  pools: PoolSummary[];
  selectedAddress: string;
  selectedLabel: string | null;
  onOpenPoolDetails: (poolId: string) => void;
}) {
  const profile = lps.find((entry) => entry.address === selectedAddress) ?? null;
  const poolsById = new Map(pools.map((pool) => [pool.poolId, pool] as const));

  if (!profile) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Your Profile</CardTitle>
          <CardDescription>Select a local Anvil address to view its positions.</CardDescription>
        </CardHeader>
      </Card>
    );
  }

  const pnlParts = formatSignedAmountParts(profile.totalPnl);
  const liquidityActivePercent = formatRatioPercent(profile.totalActiveLiquidity, profile.totalLiquidity);

  return (
    <div className="space-y-4">
      <Card className="overflow-hidden border-primary/10 bg-card/88 shadow-lg shadow-primary/5">
        <CardHeader className="gap-5">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div className="space-y-1">
              <div className="flex flex-wrap items-center gap-2">
                <CardTitle className="text-xl">{selectedLabel ?? profile.label}</CardTitle>
                <Badge>You</Badge>
                {profile.tier ? <Badge variant="secondary">{startCase(profile.tier)}</Badge> : null}
                {profile.anchor ? <Badge variant="outline">Anchor</Badge> : null}
              </div>
              <CardDescription>
                <HexValue value={profile.address} textClassName="text-sm text-muted-foreground" />
              </CardDescription>
            </div>
            <div className="flex flex-wrap gap-2">
              <Badge variant="secondary">{profile.poolCount} pools</Badge>
              <Badge variant="secondary">{profile.positionCount} positions</Badge>
            </div>
          </div>
          <div className="grid gap-4 xl:grid-cols-3">
            <SimpleProfileCard
              title="Positions"
              value={`${profile.activePositionCount} / ${profile.positionCount}`}
              note="Active positions out of total tracked positions."
              tooltip={PROFILE_METRICS.positions}
            />
            <SimpleProfileCard
              title="Liquidity active"
              value={liquidityActivePercent}
              note={`${formatAmount(profile.totalActiveLiquidity)} active of ${formatAmount(profile.totalLiquidity)} total liquidity.`}
              tooltip={PROFILE_METRICS.liquidityActive}
            />
            <SimpleProfileCard
              title="Net PnL"
              value={pnlParts.primary}
              detail={pnlParts.secondary}
              note="Aggregate profit and loss across all tracked positions."
              tooltip={PROFILE_METRICS.netPnl}
              positive={profile.totalPnl >= 0n}
            />
          </div>
        </CardHeader>
      </Card>

      <ProfilePoolsBoard profile={profile} poolsById={poolsById} onOpenPoolDetails={onOpenPoolDetails} />
    </div>
  );
}

function SimpleProfileCard({
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
        <CardTitle className={cn(
          "text-3xl tracking-[-0.04em]",
          positive === undefined ? "" : positive ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
        )}>
          {value}
        </CardTitle>
        {detail ? <div className="text-sm text-muted-foreground">{detail}</div> : null}
        <CardDescription>{note}</CardDescription>
      </CardHeader>
    </Card>
  );
}

function ProfilePoolsBoard({
  profile,
  poolsById,
  onOpenPoolDetails,
}: {
  profile: LpSummary;
  poolsById: Map<string, PoolSummary>;
  onOpenPoolDetails: (poolId: string) => void;
}) {
  const [expandedPoolId, setExpandedPoolId] = useState<string | null>(profile.groups[0]?.poolId ?? null);

  return (
    <Card className="overflow-hidden">
      <CardHeader className="gap-2">
        <CardTitle className="text-xl">Your pools</CardTitle>
        <CardDescription>Expand a pool to inspect its positions inline instead of browsing separate cards.</CardDescription>
      </CardHeader>
      <CardContent className="px-0 pb-0">
        <div className="space-y-px">
          {profile.groups.map((group) => {
            const isExpanded = expandedPoolId === group.poolId;
            const detailId = `profile-pool-${group.poolId}`;
            const pnlParts = formatSignedAmountParts(group.totalPnl);
            const token0InvestedParts = formatAmountParts(group.totalPrincipal0);
            const token1InvestedParts = formatAmountParts(group.totalPrincipal1);
            const pool = poolsById.get(group.poolId) ?? null;

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
                    <MetricLabel label="USD invested" tooltip={PROFILE_GROUP_ROW_METRICS.token0Invested} className="text-xs uppercase tracking-[0.16em]" />
                    <div className="mt-1 font-medium">{token0InvestedParts.primary}</div>
                  </div>
                  <div>
                    <MetricLabel label="ETH invested" tooltip={PROFILE_GROUP_ROW_METRICS.token1Invested} className="text-xs uppercase tracking-[0.16em]" />
                    <div className="mt-1 font-medium">{token1InvestedParts.primary}</div>
                  </div>
                  <div>
                    <MetricLabel label="PnL" tooltip={PROFILE_GROUP_ROW_METRICS.pnl} className="text-xs uppercase tracking-[0.16em]" />
                    <PnlValue value={pnlParts.primary} positive={group.totalPnl >= 0n} className="mt-1 font-medium" />
                  </div>
                  <div>
                    <MetricLabel label="Positions" tooltip={PROFILE_GROUP_ROW_METRICS.positions} className="text-xs uppercase tracking-[0.16em]" />
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
                          <div className="text-base font-semibold">{pool?.tokenPair ?? profile.label}</div>
                          <div className="text-sm text-muted-foreground">{group.poolLabel}</div>
                        </div>
                        <Button
                          variant="outline"
                          className="gap-2 self-start"
                          onClick={() => onOpenPoolDetails(group.poolId)}
                        >
                          <ExternalLink className="h-4 w-4" />
                          Pools view
                        </Button>
                      </div>
                      <div className="mt-4 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                        <ProfilePoolMetricCard
                          title="Utilisation"
                          tooltip={PROFILE_GROUP_DETAIL_METRICS.utilization}
                          value={pool ? formatBps(pool.liquidityUtilisationBps) : "N/A"}
                          detail={pool ? `peak ${formatBps(pool.peakLiquidityUtilisationBps)}` : null}
                          note="Current and peak in-range liquidity share for this pool."
                          icon={Droplets}
                          emphasize={Boolean(pool && pool.activeLiquidity > 0n)}
                        />
                        <ProfilePoolMetricCard
                          title="LPs"
                          tooltip={PROFILE_GROUP_DETAIL_METRICS.lps}
                          value={pool ? `${pool.activeLpCount}/${pool.lifetimeLpCount}` : "N/A"}
                          detail={pool ? `${formatBps(pool.lpRetentionBps)} retained` : null}
                          note="Active LP wallets relative to lifetime pool participation."
                          icon={Users}
                        />
                        <ProfilePoolMetricCard
                          title="Positions"
                          tooltip={PROFILE_GROUP_DETAIL_METRICS.positions}
                          value={pool ? `${pool.activePositionCount}/${pool.totalPositionCount}` : "N/A"}
                          detail={pool ? `${formatBps(pool.activePositionPercentageBps)} active` : null}
                          note="Active positions relative to all seeded positions in the pool."
                          icon={Activity}
                        />
                        <ProfilePoolMetricCard
                          title="Trade flow"
                          tooltip={PROFILE_GROUP_DETAIL_METRICS.tradeFlow}
                          value={pool ? String(pool.totalSwapCount) : "N/A"}
                          detail={pool ? `${pool.zeroToOneSwapCount}:${pool.oneToZeroSwapCount} direction` : null}
                          note="Seeded swaps executed against this pool and their direction split."
                          icon={ArrowRightLeft}
                        />
                      </div>
                      <div className="mt-4">
                        <ProfilePositionsBoard
                          positions={group.positions}
                          groupKey={`profile-${profile.address}-${group.poolId}`}
                          token0Symbol={pool?.token0Symbol ?? "Token 0"}
                          token1Symbol={pool?.token1Symbol ?? "Token 1"}
                        />
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

function ProfilePoolMetricCard({
  title,
  tooltip,
  value,
  detail,
  note,
  icon: Icon,
  emphasize = false,
}: {
  title: string;
  tooltip: string;
  value: string;
  detail?: string | null;
  note: string;
  icon: React.ComponentType<{ className?: string }>;
  emphasize?: boolean;
}) {
  return (
    <Card className="border-border/60 bg-background/70 shadow-none">
      <CardHeader className="flex flex-row items-start justify-between space-y-0">
        <div>
          <CardDescription className="uppercase tracking-[0.14em]">
            <MetricLabel label={title} tooltip={tooltip} />
          </CardDescription>
          <CardTitle className={cn("mt-2 text-2xl tracking-[-0.03em]", emphasize ? "text-emerald-600 dark:text-emerald-400" : "")}>
            {value}
          </CardTitle>
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

function ProfilePositionsBoard({
  positions,
  groupKey,
  token0Symbol,
  token1Symbol,
}: {
  positions: LpSummary["groups"][number]["positions"];
  groupKey: string;
  token0Symbol: string;
  token1Symbol: string;
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
        const activeLiquidityShare = formatRatioPercent(position.activeLiquidity, position.liquidity);
        const activeSwapVolume0Share = formatRatioPercent(position.activeSwapVolume0, position.lifetimeSwapVolume0);
        const activeSwapVolume1Share = formatRatioPercent(position.activeSwapVolume1, position.lifetimeSwapVolume1);
        const formattedAge = formatDuration(position.age);
        const shortPositionId = shortenHash(position.positionId);

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
                <MetricLabel label={`${token0Symbol} invested`} tooltip={POSITION_ROW_METRICS.token0Invested} className="text-xs uppercase tracking-[0.16em]" />
                <div className="mt-1 font-medium">{token0InvestedParts.primary}</div>
                {token0InvestedParts.secondary ? <div className="text-xs text-muted-foreground">{token0InvestedParts.secondary}</div> : null}
              </div>
              <div>
                <MetricLabel label={`${token1Symbol} invested`} tooltip={POSITION_ROW_METRICS.token1Invested} className="text-xs uppercase tracking-[0.16em]" />
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
                  aria-label={`${isExpanded ? "Collapse" : "Expand"} position ${shortPositionId}`}
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
                    description="Basic position metadata, range definition, and creation context."
                    metrics={[
                      { label: "Position ID", value: <HexValue value={position.positionId} textClassName="text-xs" />, tooltip: POSITION_DETAIL_METRICS.positionId, mono: true },
                      { label: "Range", value: `[${position.tickLower}, ${position.tickUpper}]`, tooltip: POSITION_DETAIL_METRICS.range, mono: true },
                      { label: "Range width", value: String(position.tickUpper - position.tickLower), tooltip: POSITION_DETAIL_METRICS.rangeWidth },
                      { label: "Status", value: position.active ? "Active" : "Inactive", tooltip: POSITION_DETAIL_METRICS.status },
                      { label: "Created", value: formatTimestamp(position.createdTimestamp), detail: `Block ${formatBlock(position.createdBlock)}`, tooltip: POSITION_DETAIL_METRICS.created },
                      { label: "Position age", value: formattedAge, detail: `${position.age}s`, tooltip: POSITION_DETAIL_METRICS.age },
                    ]}
                  />
                  <GroupedMetricsCard
                    title="Position stats"
                    description="Initial and current balances plus fees accrued for each pool token."
                    metrics={[
                      { label: `${token0Symbol} initial`, value: token0InvestedParts.primary, detail: token0InvestedParts.secondary, tooltip: POSITION_DETAIL_METRICS.initialToken0 },
                      { label: `${token1Symbol} initial`, value: token1InvestedParts.primary, detail: token1InvestedParts.secondary, tooltip: POSITION_DETAIL_METRICS.initialToken1 },
                      { label: `${token0Symbol} current`, value: currentToken0Parts.primary, detail: currentToken0Parts.secondary, tooltip: POSITION_DETAIL_METRICS.currentToken0 },
                      { label: `${token1Symbol} current`, value: currentToken1Parts.primary, detail: currentToken1Parts.secondary, tooltip: POSITION_DETAIL_METRICS.currentToken1 },
                      { label: `${token0Symbol} fees`, value: feesToken0Parts.primary, detail: feesToken0Parts.secondary, tooltip: POSITION_DETAIL_METRICS.feesToken0 },
                      { label: `${token1Symbol} fees`, value: feesToken1Parts.primary, detail: feesToken1Parts.secondary, tooltip: POSITION_DETAIL_METRICS.feesToken1 },
                    ]}
                  />
                  <GroupedMetricsCard
                    title="Position performance"
                    description="How active this position stayed and the resulting aggregate outcome."
                    metrics={[
                      { label: "Active liquidity", value: activeLiquidityShare, detail: `${formatAmount(position.activeLiquidity)} of ${formatAmount(position.liquidity)}`, tooltip: POSITION_DETAIL_METRICS.activeLiquidityShare },
                      { label: `${token0Symbol} active swap volume`, value: activeSwapVolume0Share, detail: `${formatAmount(position.activeSwapVolume0)} of ${formatAmount(position.lifetimeSwapVolume0)}`, tooltip: POSITION_DETAIL_METRICS.activeSwapVolume0Share },
                      { label: `${token1Symbol} active swap volume`, value: activeSwapVolume1Share, detail: `${formatAmount(position.activeSwapVolume1)} of ${formatAmount(position.lifetimeSwapVolume1)}`, tooltip: POSITION_DETAIL_METRICS.activeSwapVolume1Share },
                      { label: "Net PnL", value: formatSignedAmount(position.netPnl), detail: formatCompactTokenPair(token0Symbol, position.netPnl0, token1Symbol, position.netPnl1).primary, tooltip: POSITION_DETAIL_METRICS.netPnl, positive: position.netPnl >= 0n },
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

function formatDuration(seconds: number) {
  if (seconds < 60) {
    return `${seconds}s`;
  }

  if (seconds < 3_600) {
    return `${Math.floor(seconds / 60)}m`;
  }

  if (seconds < 86_400) {
    return `${Math.floor(seconds / 3_600)}h`;
  }

  return `${Math.floor(seconds / 86_400)}d`;
}
