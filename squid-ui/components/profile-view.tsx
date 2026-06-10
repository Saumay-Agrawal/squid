"use client";

import { useState } from "react";
import { ChevronDown } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { GroupedMetricsCard, MetricLabel, MetricStack, PnlValue } from "@/components/ui/metric-elements";
import { cn, formatAmount, formatAmountParts, formatBlock, formatCompactTokenPair, formatFeeTier, formatSignedAmount, formatSignedAmountParts, formatTimestamp, shortenAddress, shortenHash, startCase } from "@/lib/utils";
import type { LpSummary } from "@/lib/dashboard";

const PROFILE_METRICS = {
  positions: "Total tracked positions for your selected wallet.",
  active: "Positions currently in range at the final simulated tick.",
  liquidity: "Total liquidity assigned to your wallet across all positions.",
  activeLiquidity: "Liquidity currently in range across your active positions.",
  netPnl: "Net outcome across all of your tracked positions.",
  usdBalance: "Initial USD balance assigned to your wallet in the seed manifest.",
  ethBalance: "Initial ETH balance assigned to your wallet in the seed manifest.",
  lifetimeFlow: "Total swap volume your positions experienced across the full scenario.",
  feeCapture: "Total fees accrued across all grouped positions.",
  activeFlow: "Swap volume seen while your positions were in range.",
  plannedPositions: "Original seeded target for your wallet in the scenario manifest.",
  exposure: "How many pools your wallet is currently exposed to in the final snapshot.",
} as const;

const PROFILE_GROUP_ROW_METRICS = {
  liquidity: "Total liquidity your wallet has assigned to this pool.",
  fees: "Fees accrued by your positions in this pool.",
  pnl: "Net outcome for your positions in this pool.",
  positions: "Total positions you seeded in this pool, with active positions shown underneath.",
} as const;

const PROFILE_GROUP_DETAIL_METRICS = {
  liquidity: "Total liquidity your wallet has assigned to this pool.",
  activeLiquidity: "Liquidity from your wallet that is still in range in this pool.",
  fees: "Fees accrued by your wallet from this pool.",
  pnl: "Net result from your positions in this pool.",
  lifetimeFlow: "Total swap volume experienced by your positions in this pool.",
  feeTier: "Configured swap fee tier for this pool.",
  tickSpacing: "Minimum spacing between initialized ticks for this pool.",
} as const;

const POSITION_ROW_METRICS = {
  status: "Whether the position is in range at the final simulated tick.",
  liquidity: "Total liquidity assigned to this position.",
  pnl: "Net outcome for this position across both tokens.",
} as const;

const POSITION_DETAIL_METRICS = {
  positionId: "Unique identifier for the position NFT or tracked position record.",
  rangeWidth: "Distance between the lower and upper ticks for this position.",
  activeLiquidity: "Liquidity currently in range at the final simulated tick.",
  totalLiquidity: "Total liquidity assigned to the position.",
  feesAccrued: "Aggregate fees accrued by the position.",
  principal: "Original token amounts committed to establish this position.",
  currentAmounts: "Current token amounts represented by the position at the final state.",
  activeSwapFlow: "Swap volume seen only while the position was active in range.",
  lifetimeSwapFlow: "Total swap volume seen across the whole scenario, whether active or not.",
  tokenFees: "Fees accrued by token denomination rather than as a combined total.",
  tokenPnl: "Net token-by-token profit and loss for the position.",
  owner: "Wallet recorded as the position owner in the simulation artifact.",
  coreOwner: "Core ownership address tracked by the underlying protocol state.",
  created: "Block and timestamp when this position was first created.",
  updated: "Most recent block and timestamp captured for this position.",
} as const;

export function ProfileView({
  lps,
  selectedAddress,
  selectedLabel,
}: {
  lps: LpSummary[];
  selectedAddress: string;
  selectedLabel: string | null;
}) {
  const profile = lps.find((entry) => entry.address === selectedAddress) ?? null;

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

  const liquidityParts = formatAmountParts(profile.totalLiquidity);
  const activeLiquidityParts = formatAmountParts(profile.totalActiveLiquidity);
  const pnlParts = formatSignedAmountParts(profile.totalPnl);
  const seededUsdParts = profile.seededUsdBalance === null ? null : formatAmountParts(profile.seededUsdBalance);
  const seededEthParts = profile.seededEthBalance === null ? null : formatAmountParts(profile.seededEthBalance);
  const feeCaptureParts = formatAmountParts(profile.totalFees);
  const lifetimeFlowParts = formatCompactTokenPair("USD", profile.totalLifetimeSwapVolume0, "ETH", profile.totalLifetimeSwapVolume1);
  const activeFlowParts = formatCompactTokenPair("USD", profile.totalActiveSwapVolume0, "ETH", profile.totalActiveSwapVolume1);

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
              <CardDescription>{shortenAddress(profile.address)}</CardDescription>
            </div>
            <Badge variant="secondary">{profile.poolCount} pools</Badge>
          </div>
          <div className="grid gap-4 xl:grid-cols-3">
            <GroupedMetricsCard
              title="Exposure"
              description="Position footprint and live market exposure for your wallet."
              metrics={[
                { label: "Positions", value: String(profile.positionCount), tooltip: PROFILE_METRICS.positions },
                { label: "Active", value: String(profile.activePositionCount), tooltip: PROFILE_METRICS.active },
                { label: "Liquidity", value: liquidityParts.primary, detail: liquidityParts.secondary, tooltip: PROFILE_METRICS.liquidity },
                { label: "Active liquidity", value: activeLiquidityParts.primary, detail: activeLiquidityParts.secondary, tooltip: PROFILE_METRICS.activeLiquidity },
              ]}
            />
            <GroupedMetricsCard
              title="Balances & outcome"
              description="Wallet balances, fees, and aggregate result."
              metrics={[
                { label: "Net PnL", value: pnlParts.primary, detail: pnlParts.secondary, tooltip: PROFILE_METRICS.netPnl, positive: profile.totalPnl >= 0n },
                { label: "USD balance", value: seededUsdParts?.primary ?? "N/A", detail: seededUsdParts?.secondary ?? null, tooltip: PROFILE_METRICS.usdBalance },
                { label: "ETH balance", value: seededEthParts?.primary ?? "N/A", detail: seededEthParts?.secondary ?? null, tooltip: PROFILE_METRICS.ethBalance },
                { label: "Fee capture", value: feeCaptureParts.primary, detail: feeCaptureParts.secondary, tooltip: PROFILE_METRICS.feeCapture },
              ]}
            />
            <GroupedMetricsCard
              title="Trading activity"
              description="How much flow your positions absorbed during the scenario."
              metrics={[
                { label: "Lifetime flow", value: lifetimeFlowParts.primary, detail: lifetimeFlowParts.secondary, tooltip: PROFILE_METRICS.lifetimeFlow },
                { label: "Active flow", value: activeFlowParts.primary, detail: activeFlowParts.secondary, tooltip: PROFILE_METRICS.activeFlow },
                { label: "Planned positions", value: profile.plannedPositions === null ? "N/A" : String(profile.plannedPositions), tooltip: PROFILE_METRICS.plannedPositions },
                { label: "Exposure", value: `${profile.poolCount} pools`, tooltip: PROFILE_METRICS.exposure },
              ]}
            />
          </div>
        </CardHeader>
      </Card>

      <ProfilePoolsBoard profile={profile} />
    </div>
  );
}

function ProfilePoolsBoard({ profile }: { profile: LpSummary }) {
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
            const liquidityParts = formatAmountParts(group.totalLiquidity);
            const feeParts = formatAmountParts(group.totalFees);
            const pnlParts = formatSignedAmountParts(group.totalPnl);
            const activeLiquidityParts = formatAmountParts(group.totalActiveLiquidity);
            const lifetimeFlowParts = formatCompactTokenPair("USD", group.totalLifetimeSwapVolume0, "ETH", group.totalLifetimeSwapVolume1);

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
                    <MetricLabel label="Liquidity" tooltip={PROFILE_GROUP_ROW_METRICS.liquidity} className="text-xs uppercase tracking-[0.16em]" />
                    <div className="mt-1 font-medium">{liquidityParts.primary}</div>
                  </div>
                  <div>
                    <MetricLabel label="Fees" tooltip={PROFILE_GROUP_ROW_METRICS.fees} className="text-xs uppercase tracking-[0.16em]" />
                    <div className="mt-1 font-medium">{feeParts.primary}</div>
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
                      <div className="grid gap-4 xl:grid-cols-3">
                        <GroupedMetricsCard
                          title="Pool config"
                          description="Pool settings for this slice of your profile."
                          metrics={[
                            { label: "Fee tier", value: formatFeeTier(group.fee), tooltip: PROFILE_GROUP_DETAIL_METRICS.feeTier },
                            { label: "Tick spacing", value: String(group.tickSpacing), tooltip: PROFILE_GROUP_DETAIL_METRICS.tickSpacing },
                          ]}
                        />
                        <GroupedMetricsCard
                          title="Liquidity & outcome"
                          description="Liquidity, fees, and result for your positions in this pool."
                          metrics={[
                            { label: "Liquidity", value: liquidityParts.primary, detail: liquidityParts.secondary, tooltip: PROFILE_GROUP_DETAIL_METRICS.liquidity },
                            { label: "Active liquidity", value: activeLiquidityParts.primary, detail: activeLiquidityParts.secondary, tooltip: PROFILE_GROUP_DETAIL_METRICS.activeLiquidity },
                            { label: "Fees", value: feeParts.primary, detail: feeParts.secondary, tooltip: PROFILE_GROUP_DETAIL_METRICS.fees },
                            { label: "PnL", value: pnlParts.primary, detail: pnlParts.secondary, tooltip: PROFILE_GROUP_DETAIL_METRICS.pnl, positive: group.totalPnl >= 0n },
                          ]}
                        />
                        <GroupedMetricsCard
                          title="Trading activity"
                          description="Lifetime swap flow experienced by your positions in this pool."
                          metrics={[
                            { label: "Lifetime flow", value: lifetimeFlowParts.primary, detail: lifetimeFlowParts.secondary, tooltip: PROFILE_GROUP_DETAIL_METRICS.lifetimeFlow },
                          ]}
                        />
                      </div>
                      <div className="mt-4">
                        <ProfilePositionsBoard positions={group.positions} groupKey={`profile-${profile.address}-${group.poolId}`} />
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

function ProfilePositionsBoard({
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
        const activeLiquidityParts = formatAmountParts(position.activeLiquidity);
        const totalLiquidityParts = formatAmountParts(position.liquidity);
        const feeParts = formatAmountParts(position.fees);
        const lifetimeFlowParts = formatCompactTokenPair("USD", position.lifetimeSwapVolume0, "ETH", position.lifetimeSwapVolume1);
        const activeFlowParts = formatCompactTokenPair("USD", position.activeSwapVolume0, "ETH", position.activeSwapVolume1);
        const principalParts = formatCompactTokenPair("USD", position.principalAmount0, "ETH", position.principalAmount1);
        const currentParts = formatCompactTokenPair("USD", position.currentAmount0, "ETH", position.currentAmount1);
        const pnlParts = formatCompactTokenPair("USD", position.netPnl0, "ETH", position.netPnl1);
        const feeTokenParts = formatCompactTokenPair("USD", position.feeAccumulated0, "ETH", position.feeAccumulated1);

        return (
          <div key={position.positionId} className="overflow-hidden rounded-2xl border border-border/60 bg-card/75">
            <div className="grid items-center gap-3 px-4 py-4 text-sm lg:grid-cols-[minmax(0,1.4fr)_minmax(140px,0.7fr)_minmax(120px,0.5fr)_minmax(120px,0.5fr)_40px]">
              <div>
                <div className="font-medium">
                  Range [{position.tickLower}, {position.tickUpper}]
                </div>
                <div className="mt-1 font-mono text-xs text-muted-foreground">{shortenHash(position.positionId)}</div>
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
                <MetricLabel label="Liquidity" tooltip={POSITION_ROW_METRICS.liquidity} className="text-xs uppercase tracking-[0.16em]" />
                <div className="mt-1 font-medium">{formatAmount(position.liquidity)}</div>
              </div>
              <div>
                <MetricLabel label="PnL" tooltip={POSITION_ROW_METRICS.pnl} className="text-xs uppercase tracking-[0.16em]" />
                <PnlValue value={formatSignedAmount(position.netPnl)} positive={position.netPnl >= 0n} className="mt-1 font-medium" />
              </div>
              <div className="text-right">
                <button
                  type="button"
                  aria-expanded={isExpanded}
                  aria-controls={detailId}
                  aria-label={`${isExpanded ? "Collapse" : "Expand"} position ${shortenHash(position.positionId)}`}
                  className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-border/70 bg-background/70 text-muted-foreground transition hover:bg-accent hover:text-foreground"
                  onClick={() => setExpandedPositionId(isExpanded ? null : position.positionId)}
                >
                  <ChevronDown className={cn("h-4 w-4 transition-transform", isExpanded ? "rotate-180" : "")} />
                </button>
              </div>
            </div>
            {isExpanded ? (
              <div id={detailId} className="border-t border-border/60 bg-background/55 px-4 py-4">
                <div className="grid gap-4 lg:grid-cols-2 xl:grid-cols-4">
                  <GroupedMetricsCard
                    title="Range & liquidity"
                    description="How this position is configured and how much of it is active."
                    metrics={[
                      { label: "Position ID", value: shortenHash(position.positionId), tooltip: POSITION_DETAIL_METRICS.positionId, mono: true },
                      { label: "Range width", value: String(position.tickUpper - position.tickLower), tooltip: POSITION_DETAIL_METRICS.rangeWidth },
                      { label: "Active liquidity", value: activeLiquidityParts.primary, detail: activeLiquidityParts.secondary, tooltip: POSITION_DETAIL_METRICS.activeLiquidity },
                      { label: "Total liquidity", value: totalLiquidityParts.primary, detail: totalLiquidityParts.secondary, tooltip: POSITION_DETAIL_METRICS.totalLiquidity },
                    ]}
                  />
                  <GroupedMetricsCard
                    title="Holdings & outcome"
                    description="Principal, current amounts, and position-level result."
                    metrics={[
                      { label: "Fees accrued", value: feeParts.primary, detail: feeParts.secondary, tooltip: POSITION_DETAIL_METRICS.feesAccrued },
                      { label: "Principal", value: principalParts.primary, detail: principalParts.secondary, tooltip: POSITION_DETAIL_METRICS.principal },
                      { label: "Current amounts", value: currentParts.primary, detail: currentParts.secondary, tooltip: POSITION_DETAIL_METRICS.currentAmounts },
                      { label: "Token PnL", value: pnlParts.primary, detail: pnlParts.secondary, tooltip: POSITION_DETAIL_METRICS.tokenPnl, positive: position.netPnl >= 0n },
                    ]}
                  />
                  <GroupedMetricsCard
                    title="Flow & fees"
                    description="Swap volume and fee accrual experienced by this position."
                    metrics={[
                      { label: "Active swap flow", value: activeFlowParts.primary, detail: activeFlowParts.secondary, tooltip: POSITION_DETAIL_METRICS.activeSwapFlow },
                      { label: "Lifetime swap flow", value: lifetimeFlowParts.primary, detail: lifetimeFlowParts.secondary, tooltip: POSITION_DETAIL_METRICS.lifetimeSwapFlow },
                      { label: "Token fees", value: feeTokenParts.primary, detail: feeTokenParts.secondary, tooltip: POSITION_DETAIL_METRICS.tokenFees },
                    ]}
                  />
                  <GroupedMetricsCard
                    title="Ownership & timing"
                    description="Who owns the position and when it changed."
                    metrics={[
                      { label: "Owner", value: shortenAddress(position.owner), tooltip: POSITION_DETAIL_METRICS.owner },
                      { label: "Core owner", value: shortenAddress(position.coreOwner), tooltip: POSITION_DETAIL_METRICS.coreOwner },
                      { label: "Created", value: `Block ${formatBlock(position.createdBlock)}`, detail: formatTimestamp(position.createdTimestamp), tooltip: POSITION_DETAIL_METRICS.created },
                      { label: "Updated", value: `Block ${formatBlock(position.updatedBlock)}`, detail: formatTimestamp(position.updatedTimestamp), tooltip: POSITION_DETAIL_METRICS.updated },
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
