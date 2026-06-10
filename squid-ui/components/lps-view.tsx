"use client";

import { Fragment, useState } from "react";
import { ChevronDown } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { GroupedMetricsCard, MetricHeader, MetricLabel, MetricStack, PnlValue } from "@/components/ui/metric-elements";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { LpSummary } from "@/lib/dashboard";
import { cn, formatAmount, formatAmountParts, formatBlock, formatCompactTokenPair, formatFeeTier, formatSignedAmount, formatSignedAmountParts, formatTimestamp, shortenAddress, shortenHash, startCase } from "@/lib/utils";

const LP_BOARD_METRICS = {
  liquidity: "Total liquidity this wallet has seeded across all tracked pools.",
  fees: "Fees accrued across every position owned by this wallet.",
  pnl: "Net outcome across the wallet's tracked positions after fees and price movement.",
  pools: "Distinct pools where this wallet currently has or had seeded positions.",
  positions: "Total seeded positions for this wallet, with active positions shown underneath.",
  planned: "Original number of positions this wallet was expected to seed in the scenario manifest.",
} as const;

const WALLET_METRICS = {
  positions: "Total tracked positions for this wallet across all pools.",
  planned: "Original seeded target for this wallet in the simulation manifest.",
  liquidity: "Total liquidity assigned to this wallet across all positions.",
  activeLiquidity: "Liquidity currently in range across this wallet's active positions.",
  fees: "Total fees accrued across all tracked positions for this wallet.",
  netPnl: "Net wallet outcome after aggregating all tracked position PnL.",
  seededUsd: "Initial USD balance assigned to this wallet by the seed manifest.",
  seededEth: "Initial ETH balance assigned to this wallet by the seed manifest.",
  lifetimeFlow: "Total swap volume this wallet's positions experienced across the full scenario.",
} as const;

const GROUP_ROW_METRICS = {
  liquidity: "Total liquidity this wallet has assigned to this pool.",
  fees: "Fees accrued by this wallet from positions in this pool.",
  pnl: "Net outcome for this wallet's positions in this pool.",
  positions: "Total positions this wallet seeded in this pool, with active positions shown underneath.",
} as const;

const GROUP_DETAIL_METRICS = {
  liquidity: "Total liquidity this wallet has assigned to this pool.",
  activeLiquidity: "Liquidity from this wallet that is currently in range in this pool.",
  fees: "Total fees accrued by this wallet from positions in this pool.",
  pnl: "Net pooled outcome for this wallet in this market.",
  lifetimeFlow: "Total swap volume this wallet's positions in this pool saw over the full scenario.",
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

export function LpsView({ lps, selectedAddress }: { lps: LpSummary[]; selectedAddress: string }) {
  const [expandedAddress, setExpandedAddress] = useState<string | null>(selectedAddress || (lps[0]?.address ?? null));
  const activeWallets = lps.filter((lp) => lp.activePositionCount > 0).length;
  const totalLiquidity = lps.reduce((sum, lp) => sum + lp.totalLiquidity, 0n);
  const totalActiveLiquidity = lps.reduce((sum, lp) => sum + lp.totalActiveLiquidity, 0n);
  const totalPnl = lps.reduce((sum, lp) => sum + lp.totalPnl, 0n);
  const totalLiquidityParts = formatAmountParts(totalLiquidity);
  const totalActiveLiquidityParts = formatAmountParts(totalActiveLiquidity);
  const totalPnlParts = formatSignedAmountParts(totalPnl);

  return (
    <div className="space-y-4">
      <section className="grid gap-4 md:grid-cols-3">
        <MetricCard title="Tracked wallets" value={String(lps.length)} note={`${activeWallets} wallets currently have active positions`} />
        <MetricCard title="Aggregate liquidity" value={totalLiquidityParts.primary} detail={totalLiquidityParts.secondary} note={`Combined liquidity across every tracked LP snapshot, ${totalActiveLiquidityParts.primary} active`} />
        <MetricCard title="Aggregate PnL" value={totalPnlParts.primary} detail={totalPnlParts.secondary} note="Net outcome across all tracked LPs" positive={totalPnl >= 0n} />
      </section>

      <Card className="overflow-hidden">
        <CardHeader className="gap-2">
          <CardTitle className="text-xl">LP board</CardTitle>
          <CardDescription>Compare wallets by exposure, activity, and outcome, then expand one wallet for grouped pool and position details.</CardDescription>
        </CardHeader>
        <CardContent className="px-0 pb-0">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">Wallet</TableHead>
                  <TableHead><MetricHeader label="Liquidity" tooltip={LP_BOARD_METRICS.liquidity} /></TableHead>
                  <TableHead><MetricHeader label="Fees" tooltip={LP_BOARD_METRICS.fees} /></TableHead>
                  <TableHead><MetricHeader label="PnL" tooltip={LP_BOARD_METRICS.pnl} /></TableHead>
                  <TableHead><MetricHeader label="Pools" tooltip={LP_BOARD_METRICS.pools} /></TableHead>
                  <TableHead><MetricHeader label="Positions" tooltip={LP_BOARD_METRICS.positions} /></TableHead>
                  <TableHead><MetricHeader label="Planned" tooltip={LP_BOARD_METRICS.planned} /></TableHead>
                  <TableHead className="w-12 pr-6"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {lps.map((lp) => {
                  const isExpanded = expandedAddress === lp.address;
                  const isSelected = lp.address === selectedAddress;
                  const detailId = `lp-detail-${lp.address}`;
                  const liquidityParts = formatAmountParts(lp.totalLiquidity);
                  const feeParts = formatAmountParts(lp.totalFees);
                  const pnlParts = formatSignedAmountParts(lp.totalPnl);
                  const activeLiquidityParts = formatAmountParts(lp.totalActiveLiquidity);
                  const seededUsdParts = lp.seededUsdBalance === null ? null : formatAmountParts(lp.seededUsdBalance);
                  const seededEthParts = lp.seededEthBalance === null ? null : formatAmountParts(lp.seededEthBalance);
                  const lifetimeFlowParts = formatCompactTokenPair("USD", lp.totalLifetimeSwapVolume0, "ETH", lp.totalLifetimeSwapVolume1);

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
                            <div className="mt-1 text-xs text-muted-foreground">{shortenAddress(lp.address)}</div>
                          </div>
                        </TableCell>
                        <TableCell>{formatAmount(lp.totalLiquidity)}</TableCell>
                        <TableCell>{formatAmount(lp.totalFees)}</TableCell>
                        <TableCell>
                          <PnlValue value={formatSignedAmount(lp.totalPnl)} positive={lp.totalPnl >= 0n} />
                        </TableCell>
                        <TableCell>{lp.poolCount}</TableCell>
                        <TableCell>
                          <MetricStack primary={String(lp.positionCount)} secondary={`${lp.activePositionCount} active`} />
                        </TableCell>
                        <TableCell>{lp.plannedPositions === null ? "N/A" : String(lp.plannedPositions)}</TableCell>
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
                          <TableCell className="border-0 bg-muted/20 p-0" colSpan={8} id={detailId}>
                            <div className="px-6 py-5">
                              <div className="mx-auto max-w-5xl">
                                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                                  <div className="space-y-1">
                                    <div className="flex flex-wrap items-center gap-2">
                                      <div className="text-base font-semibold">{lp.label}</div>
                                      {isSelected ? <Badge>You</Badge> : null}
                                      {lp.tier ? <Badge variant="secondary">{startCase(lp.tier)}</Badge> : null}
                                      {lp.anchor ? <Badge variant="outline">Anchor</Badge> : null}
                                    </div>
                                    <div className="text-sm text-muted-foreground">{shortenAddress(lp.address)}</div>
                                  </div>
                                  <div className="flex flex-wrap gap-2">
                                    <Badge variant="secondary">{lp.poolCount} pools</Badge>
                                    <Badge variant="outline">{lp.activePositionCount} active</Badge>
                                  </div>
                                </div>

                                <div className="mt-4 grid gap-4 xl:grid-cols-3">
                                  <GroupedMetricsCard
                                    title="Exposure"
                                    description="Position footprint and committed liquidity for this wallet."
                                    metrics={[
                                      { label: "Positions", value: String(lp.positionCount), tooltip: WALLET_METRICS.positions },
                                      { label: "Planned", value: lp.plannedPositions === null ? "N/A" : String(lp.plannedPositions), tooltip: WALLET_METRICS.planned },
                                      { label: "Liquidity", value: liquidityParts.primary, detail: liquidityParts.secondary, tooltip: WALLET_METRICS.liquidity },
                                      { label: "Active liquidity", value: activeLiquidityParts.primary, detail: activeLiquidityParts.secondary, tooltip: WALLET_METRICS.activeLiquidity },
                                    ]}
                                  />
                                  <GroupedMetricsCard
                                    title="Balances & outcome"
                                    description="Wallet balances, fee capture, and aggregate result."
                                    metrics={[
                                      { label: "Fees", value: feeParts.primary, detail: feeParts.secondary, tooltip: WALLET_METRICS.fees },
                                      { label: "Net PnL", value: pnlParts.primary, detail: pnlParts.secondary, tooltip: WALLET_METRICS.netPnl, positive: lp.totalPnl >= 0n },
                                      { label: "Seeded USD", value: seededUsdParts?.primary ?? "N/A", detail: seededUsdParts?.secondary ?? null, tooltip: WALLET_METRICS.seededUsd },
                                      { label: "Seeded ETH", value: seededEthParts?.primary ?? "N/A", detail: seededEthParts?.secondary ?? null, tooltip: WALLET_METRICS.seededEth },
                                    ]}
                                  />
                                  <GroupedMetricsCard
                                    title="Trading activity"
                                    description="How much swap flow this wallet's positions absorbed."
                                    metrics={[
                                      { label: "Lifetime flow", value: lifetimeFlowParts.primary, detail: lifetimeFlowParts.secondary, tooltip: WALLET_METRICS.lifetimeFlow },
                                    ]}
                                  />
                                </div>

                                <div className="mt-5">
                                  <LpGroupsView groups={lp.groups} lpAddress={lp.address} />
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
  positive,
}: {
  title: string;
  value: string;
  detail?: string | null;
  note: string;
  positive?: boolean;
}) {
  return (
    <Card>
      <CardHeader className="space-y-2">
        <CardDescription className="uppercase tracking-[0.14em]">{title}</CardDescription>
        <CardTitle
          className={cn(
            "text-2xl tracking-[-0.03em]",
            positive === undefined ? "" : positive ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
          )}
        >
          {value}
        </CardTitle>
        {detail ? <div className="text-sm text-muted-foreground">{detail}</div> : null}
      </CardHeader>
      <CardContent className="text-sm text-muted-foreground">{note}</CardContent>
    </Card>
  );
}

function GroupPositionsView({
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

function LpGroupsView({
  groups,
  lpAddress,
}: {
  groups: LpSummary["groups"];
  lpAddress: string;
}) {
  const [expandedPoolId, setExpandedPoolId] = useState<string | null>(groups[0]?.poolId ?? null);

  return (
    <div className="space-y-3">
      {groups.map((group) => {
        const isExpanded = expandedPoolId === group.poolId;
        const detailId = `${lpAddress}-${group.poolId}`;
        const liquidityParts = formatAmountParts(group.totalLiquidity);
        const feeParts = formatAmountParts(group.totalFees);
        const pnlParts = formatSignedAmountParts(group.totalPnl);
        const activeLiquidityParts = formatAmountParts(group.totalActiveLiquidity);
        const lifetimeFlowParts = formatCompactTokenPair("USD", group.totalLifetimeSwapVolume0, "ETH", group.totalLifetimeSwapVolume1);

        return (
          <div key={group.poolId} className="overflow-hidden rounded-3xl border border-border/70 bg-background/65">
            <div className="grid items-center gap-3 px-4 py-4 text-sm lg:grid-cols-[minmax(0,1.5fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_40px]">
              <div>
                <div className="font-semibold">{group.poolLabel}</div>
                <div className="text-sm text-muted-foreground">
                  Pool {group.poolIndex + 1} · {formatFeeTier(group.fee)} fee · spacing {group.tickSpacing}
                </div>
              </div>
              <div>
                <MetricLabel label="Liquidity" tooltip={GROUP_ROW_METRICS.liquidity} className="text-xs uppercase tracking-[0.16em]" />
                <div className="mt-1 font-medium">{liquidityParts.primary}</div>
              </div>
              <div>
                <MetricLabel label="Fees" tooltip={GROUP_ROW_METRICS.fees} className="text-xs uppercase tracking-[0.16em]" />
                <div className="mt-1 font-medium">{feeParts.primary}</div>
              </div>
              <div>
                <MetricLabel label="PnL" tooltip={GROUP_ROW_METRICS.pnl} className="text-xs uppercase tracking-[0.16em]" />
                <PnlValue value={pnlParts.primary} positive={group.totalPnl >= 0n} className="mt-1 font-medium" />
              </div>
              <div>
                <MetricLabel label="Positions" tooltip={GROUP_ROW_METRICS.positions} className="text-xs uppercase tracking-[0.16em]" />
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
              <div id={detailId} className="border-t border-border/60 bg-background/55 px-4 py-4">
                <div className="grid gap-4 xl:grid-cols-3">
                  <GroupedMetricsCard
                    title="Pool config"
                    description="Pool-level settings for this wallet's market exposure."
                    metrics={[
                      { label: "Fee tier", value: formatFeeTier(group.fee), tooltip: GROUP_DETAIL_METRICS.feeTier },
                      { label: "Tick spacing", value: String(group.tickSpacing), tooltip: GROUP_DETAIL_METRICS.tickSpacing },
                    ]}
                  />
                  <GroupedMetricsCard
                    title="Liquidity & outcome"
                    description="Liquidity footprint and result for this wallet in this pool."
                    metrics={[
                      { label: "Liquidity", value: liquidityParts.primary, detail: liquidityParts.secondary, tooltip: GROUP_DETAIL_METRICS.liquidity },
                      { label: "Active liquidity", value: activeLiquidityParts.primary, detail: activeLiquidityParts.secondary, tooltip: GROUP_DETAIL_METRICS.activeLiquidity },
                      { label: "Fees", value: feeParts.primary, detail: feeParts.secondary, tooltip: GROUP_DETAIL_METRICS.fees },
                      { label: "PnL", value: pnlParts.primary, detail: pnlParts.secondary, tooltip: GROUP_DETAIL_METRICS.pnl, positive: group.totalPnl >= 0n },
                    ]}
                  />
                  <GroupedMetricsCard
                    title="Trading activity"
                    description="How much lifetime flow this pool generated for the wallet."
                    metrics={[
                      { label: "Lifetime flow", value: lifetimeFlowParts.primary, detail: lifetimeFlowParts.secondary, tooltip: GROUP_DETAIL_METRICS.lifetimeFlow },
                    ]}
                  />
                </div>
                <div className="mt-4">
                  <GroupPositionsView positions={group.positions} groupKey={`${lpAddress}-${group.poolId}`} />
                </div>
              </div>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}
