"use client";

import { Fragment, useEffect, useState } from "react";
import { Activity, ArrowRightLeft, ChevronDown, CircleHelp, Droplets, Users } from "lucide-react";
import { useBalance, useReadContract, useWaitForTransactionReceipt } from "wagmi";
import { erc20Abi, parseUnits, type Address } from "viem";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { HexValue } from "@/components/ui/hex-value";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Tooltip } from "@/components/ui/tooltip";
import type { PoolSummary, SquidDashboardData } from "@/lib/dashboard";
import {
  alignTickToSpacing,
  buildDefaultTicks,
  buildPoolKey,
  getApprovalAmount,
  makeSalt,
  modifyLiquidityRouterAbi,
} from "@/lib/liquidity";
import { anvil, anvilPublicClient, createAnvilWalletClient, hasLocalAnvilSigner } from "@/lib/wallet";
import { cn, formatBps, formatFeeTier, formatTick, formatTokenPairWithDecimals, type TokenDisplayConfig } from "@/lib/utils";

const SUMMARY_METRICS = {
  utilization: "Share of total liquidity currently active at the pool's final tick, with the peak share shown for comparison.",
  lps: "Active LP wallets over lifetime LP wallets for this pool, with the retained share shown below.",
  positions: "Active positions over total seeded positions for this pool, with the active share shown below.",
  tradeFlow: "Total seeded swaps executed against the pool, with direction split and skewness percentage shown below.",
} as const;

const TOP_CARD_METRICS = {
  pools: "Active pools have at least one active position at the final tick. Total pools counts every seeded pool snapshot.",
  liquidityUtilisation: "Average share of liquidity currently in range across all pools, with the average peak in-range share shown below.",
  lpRetention: "Average share of lifetime LP wallets that still have an active position across all pools.",
  tradeFlow: "Average swap-direction skewness across all pools, derived from the ratio between the dominant and minority seeded swap counts.",
} as const;

const DETAIL_METRICS = {
  currentTick: "The pool's final tick after all seeded actions finished.",
  feeTier: "The configured pool fee tier applied to swaps in this pool.",
  tickSpacing: "Minimum spacing allowed between initialized ticks in this pool.",
  lpFee: "The LP-facing fee currently applied by the pool state.",
  protocolFee: "The protocol-owned fee currently configured on the pool state.",
  initialAmounts: "Token0 and token1 amounts first recorded when this pool became funded in the seeded scenario.",
  currentAmounts: "Token0 and token1 amounts tracked at the pool's final seeded state.",
  totalFeesAccrued: "Lifetime token0 and token1 fees accrued by the pool metrics during seeded liquidity updates.",
  totalSwapCount: "Total number of seeded swaps executed against this pool.",
  zeroToOneSwaps: "Number of seeded swaps that moved from token0 into token1.",
  oneToZeroSwaps: "Number of seeded swaps that moved from token1 into token0.",
  flowSkewness: "Skewness percentage derived from the ratio between the dominant and minority swap directions.",
  activeLps: "Number of LP wallets with at least one active position at the final tick.",
  lpRetention: "Share of lifetime LP wallets that still have an active position in range.",
  activePositions: "Number of positions currently in range, with total seeded positions shown below.",
  positionActivity: "Share of seeded positions that remain active at the final tick.",
} as const;

export function PoolsView({
  pools,
  token0,
  token1,
  market,
  contracts,
  selectedAddress,
  expandedPoolId: controlledExpandedPoolId,
  onExpandedPoolChange,
}: {
  pools: PoolSummary[];
  token0: TokenDisplayConfig;
  token1: TokenDisplayConfig;
  market: SquidDashboardData["market"];
  contracts: SquidDashboardData["contracts"];
  selectedAddress: string;
  expandedPoolId?: string | null;
  onExpandedPoolChange?: (poolId: string | null) => void;
}) {
  const [uncontrolledExpandedPoolId, setUncontrolledExpandedPoolId] = useState<string | null>(pools[0]?.poolId ?? null);
  const expandedPoolId = controlledExpandedPoolId === undefined ? uncontrolledExpandedPoolId : controlledExpandedPoolId;
  const setExpandedPoolId = onExpandedPoolChange ?? setUncontrolledExpandedPoolId;
  const activePools = pools.filter((pool) => pool.activePositionCount > 0).length;
  const averageLiquidityUtilisationBps = averageBps(pools.map((pool) => pool.liquidityUtilisationBps));
  const averagePeakLiquidityUtilisationBps = averageBps(pools.map((pool) => pool.peakLiquidityUtilisationBps));
  const averageLpRetentionBps = averageBps(pools.map((pool) => pool.lpRetentionBps));
  const averageFlowSkewnessBps = averageBps(pools.map((pool) => pool.flowSkewnessBps));

  return (
    <div className="space-y-5">
      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          title="Pools"
          tooltip={TOP_CARD_METRICS.pools}
          value={String(activePools)}
          detail={`${pools.length} total`}
          note="Pools currently in range versus total seeded pool snapshots."
          icon={Activity}
        />
        <MetricCard
          title="Liquidity utilisation"
          tooltip={TOP_CARD_METRICS.liquidityUtilisation}
          value={formatBps(averageLiquidityUtilisationBps)}
          detail={`peak ${formatBps(averagePeakLiquidityUtilisationBps)}`}
          note="Average current and peak in-range liquidity share across all pools."
          icon={Droplets}
        />
        <MetricCard
          title="LP retention"
          tooltip={TOP_CARD_METRICS.lpRetention}
          value={formatBps(averageLpRetentionBps)}
          note="Average share of lifetime LPs that remain active across all pools."
          icon={Users}
        />
        <MetricCard
          title="Trade flow"
          tooltip={TOP_CARD_METRICS.tradeFlow}
          value={formatBps(averageFlowSkewnessBps)}
          note="Average ratio-based skewness of seeded trade flow across all pools."
          icon={ArrowRightLeft}
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
                  const initialAmounts = formatTokenPairWithDecimals(
                    token0,
                    pool.initialToken0Amount,
                    token1,
                    pool.initialToken1Amount,
                  );
                  const currentAmounts = formatTokenPairWithDecimals(
                    token0,
                    pool.currentToken0Amount,
                    token1,
                    pool.currentToken1Amount,
                  );
                  const totalFeesAccrued = formatTokenPairWithDecimals(
                    token0,
                    pool.totalFeeAccruedToken0,
                    token1,
                    pool.totalFeeAccruedToken1,
                  );

                  return (
                    <Fragment key={pool.poolId}>
                      <TableRow key={`${pool.poolId}-summary`} className="bg-transparent">
                        <TableCell className="pl-6">
                          <div className="min-w-52">
                            <div className="font-semibold">{pool.tokenPair}</div>
                            <div className="mt-1 text-xs text-muted-foreground">{pool.poolLabel}</div>
                            <HexValue value={pool.poolId} className="mt-2" textClassName="text-[11px] text-muted-foreground" />
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
                          <MetricStack
                            primary={formatBps(pool.flowSkewnessBps)}
                            secondary={`${pool.zeroToOneSwapCount}:${pool.oneToZeroSwapCount} direction`}
                          />
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
                                    title="Liquidity & order flow"
                                    description="Tracked pool amounts, accrued fees, and directional swap activity for this pool."
                                    metrics={[
                                      {
                                        label: "Initial amounts",
                                        value: initialAmounts.primary,
                                        detail: initialAmounts.secondary,
                                        tooltip: DETAIL_METRICS.initialAmounts,
                                      },
                                      {
                                        label: "Current amounts",
                                        value: currentAmounts.primary,
                                        detail: currentAmounts.secondary,
                                        tooltip: DETAIL_METRICS.currentAmounts,
                                      },
                                      {
                                        label: "Total fees accrued",
                                        value: totalFeesAccrued.primary,
                                        detail: totalFeesAccrued.secondary,
                                        tooltip: DETAIL_METRICS.totalFeesAccrued,
                                      },
                                      {
                                        label: "Total swap count",
                                        value: String(pool.totalSwapCount),
                                        tooltip: DETAIL_METRICS.totalSwapCount,
                                      },
                                      {
                                        label: "Zero to one swaps",
                                        value: String(pool.zeroToOneSwapCount),
                                        tooltip: DETAIL_METRICS.zeroToOneSwaps,
                                      },
                                      {
                                        label: "One to zero swaps",
                                        value: String(pool.oneToZeroSwapCount),
                                        tooltip: DETAIL_METRICS.oneToZeroSwaps,
                                      },
                                      {
                                        label: "Flow skewness",
                                        value: formatBps(pool.flowSkewnessBps),
                                        detail: `${pool.zeroToOneSwapCount}:${pool.oneToZeroSwapCount} direction`,
                                        tooltip: DETAIL_METRICS.flowSkewness,
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
                                <CreatePositionCard
                                  pool={pool}
                                  token0={token0}
                                  token1={token1}
                                  market={market}
                                  contracts={contracts}
                                  selectedAddress={selectedAddress}
                                />
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
  tooltip,
  value,
  detail,
  note,
  icon: Icon,
}: {
  title: string;
  tooltip: string;
  value: string;
  detail?: string | null;
  note: string;
  icon: React.ComponentType<{ className?: string }>;
}) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between space-y-0">
        <div>
          <CardDescription className="uppercase tracking-[0.14em]">
            <MetricLabel label={title} tooltip={tooltip} />
          </CardDescription>
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
    value: React.ReactNode;
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
  value: React.ReactNode;
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

function averageBps(values: number[]) {
  if (values.length === 0) return 0;
  return Math.round(values.reduce((sum, value) => sum + value, 0) / values.length);
}

function CreatePositionCard({
  pool,
  token0,
  token1,
  market,
  contracts,
  selectedAddress,
}: {
  pool: PoolSummary;
  token0: TokenDisplayConfig;
  token1: TokenDisplayConfig;
  market: SquidDashboardData["market"];
  contracts: SquidDashboardData["contracts"];
  selectedAddress: string;
}) {
  const [open, setOpen] = useState(false);
  const defaults = buildDefaultTicks(pool);
  const [tickLower, setTickLower] = useState(String(defaults.lower));
  const [tickUpper, setTickUpper] = useState(String(defaults.upper));
  const [liquidityInput, setLiquidityInput] = useState("1");
  const [maxToken0Input, setMaxToken0Input] = useState(market.token0Native ? "0.25" : "0");
  const [maxToken1Input, setMaxToken1Input] = useState(market.token1Native ? "0.25" : "1000");
  const [salt, setSalt] = useState<string>(() => makeSalt(selectedAddress, pool.poolId));
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [approvalHash, setApprovalHash] = useState<`0x${string}` | undefined>(undefined);
  const [createHash, setCreateHash] = useState<`0x${string}` | undefined>(undefined);
  const [approvalPending, setApprovalPending] = useState(false);
  const [createPending, setCreatePending] = useState(false);
  const [approvalError, setApprovalError] = useState<string | null>(null);
  const [createError, setCreateError] = useState<string | null>(null);

  const hasSelectedSigner = hasLocalAnvilSigner(selectedAddress);
  const approvalToken = market.token0Native ? (market.token1 as Address) : market.token1Native ? (market.token0 as Address) : null;
  const nativeBalanceQuery = useBalance({
    address: selectedAddress as Address,
    chainId: anvil.id,
    query: {
      enabled: Boolean(selectedAddress && hasSelectedSigner && (market.token0Native || market.token1Native)),
      refetchInterval: 10_000,
    },
  });

  const approvalAmount =
    approvalToken === null
      ? 0n
      : parseUnits(
          market.token0Native ? (maxToken1Input || "0") : market.token1Native ? (maxToken0Input || "0") : "0",
          market.token0Native ? token1.decimals : token0.decimals,
        );

  const allowanceQuery = useReadContract({
    address: approvalToken ?? undefined,
    abi: erc20Abi,
    functionName: "allowance",
    args: hasSelectedSigner ? [selectedAddress as Address, contracts.modifyLiquidityRouter as Address] : undefined,
    chainId: anvil.id,
    query: {
      enabled: Boolean(approvalToken && hasSelectedSigner),
      refetchInterval: 10_000,
    },
  });

  const approvalReceipt = useWaitForTransactionReceipt({ hash: approvalHash, chainId: anvil.id });
  const createReceipt = useWaitForTransactionReceipt({ hash: createHash, chainId: anvil.id });

  useEffect(() => {
    const nextDefaults = buildDefaultTicks(pool);
    setTickLower(String(nextDefaults.lower));
    setTickUpper(String(nextDefaults.upper));
    setSalt(makeSalt(selectedAddress, pool.poolId));
    setStatusMessage(null);
    setApprovalError(null);
    setCreateError(null);
  }, [pool.poolId, pool.tick, pool.tickSpacing, selectedAddress]);

  useEffect(() => {
    if (approvalReceipt.isSuccess) {
      setStatusMessage(`Approval confirmed for ${market.token0Native ? token1.symbol : token0.symbol}.`);
      setApprovalPending(false);
    }
    if (approvalReceipt.isError) {
      setApprovalPending(false);
    }
  }, [approvalReceipt.isError, approvalReceipt.isSuccess, market.token0Native, token0.symbol, token1.symbol]);

  useEffect(() => {
    if (createReceipt.isSuccess) {
      setStatusMessage("Liquidity position created on Anvil. Refreshing balances and pool reads may take a few seconds.");
      setSalt(makeSalt(selectedAddress, pool.poolId));
      setCreatePending(false);
    }
    if (createReceipt.isError) {
      setCreatePending(false);
    }
  }, [createReceipt.isError, createReceipt.isSuccess, selectedAddress, pool.poolId]);

  const tickLowerValue = Number(tickLower);
  const tickUpperValue = Number(tickUpper);
  const liquidityDelta = safeParseLiquidity(liquidityInput);
  const nativeFundingValue = market.token0Native
    ? parseTokenAmount(maxToken0Input, token0.decimals)
    : market.token1Native
      ? parseTokenAmount(maxToken1Input, token1.decimals)
      : 0n;
  const allowanceValue = allowanceQuery.data ?? 0n;
  const hasSufficientApproval = approvalToken === null || allowanceValue >= approvalAmount;
  const hasSufficientNativeBalance = !market.token0Native && !market.token1Native
    ? true
    : (nativeBalanceQuery.data?.value ?? 0n) >= nativeFundingValue;

  const validationError =
    !Number.isInteger(tickLowerValue) || !Number.isInteger(tickUpperValue)
      ? "Ticks must be whole numbers."
      : tickLowerValue >= tickUpperValue
        ? "Tick lower must be less than tick upper."
        : tickLowerValue % pool.tickSpacing !== 0 || tickUpperValue % pool.tickSpacing !== 0
          ? `Ticks must align to the pool's spacing of ${pool.tickSpacing}.`
          : liquidityDelta <= 0n
            ? "Liquidity delta must be greater than zero."
            : nativeFundingValue <= 0n && (market.token0Native || market.token1Native)
              ? `Enter a max ${market.token0Native ? token0.symbol : token1.symbol} funding amount.`
              : approvalAmount <= 0n && approvalToken
                ? `Enter a max ${market.token0Native ? token1.symbol : token0.symbol} funding amount.`
                : null;

  async function handleApprove() {
    setStatusMessage(null);
    setApprovalError(null);

    if (!approvalToken) return;

    try {
      setApprovalPending(true);
      const walletClient = createAnvilWalletClient(selectedAddress as Address);
      const hash = await walletClient.writeContract({
        address: approvalToken,
        abi: erc20Abi,
        functionName: "approve",
        args: [contracts.modifyLiquidityRouter as Address, getApprovalAmount()],
        chain: anvil,
      });
      setApprovalHash(hash);
    } catch (error) {
      setApprovalPending(false);
      setApprovalError(formatWriteError(error));
    }
  }

  async function handleCreatePosition() {
    setStatusMessage(null);
    setCreateError(null);

    try {
      setCreatePending(true);
      const walletClient = createAnvilWalletClient(selectedAddress as Address);
      const hash = await walletClient.writeContract({
        address: contracts.modifyLiquidityRouter as Address,
        abi: modifyLiquidityRouterAbi,
        functionName: "modifyLiquidity",
        args: [
          buildPoolKey(pool),
          {
            tickLower: tickLowerValue,
            tickUpper: tickUpperValue,
            liquidityDelta,
            salt: salt as `0x${string}`,
          },
          "0x",
        ],
        value: nativeFundingValue,
        chain: anvil,
      });
      setCreateHash(hash);
    } catch (error) {
      setCreatePending(false);
      setCreateError(formatWriteError(error));
    }
  }

  return (
    <>
      <Card className="mt-4 border-primary/10 bg-background/80 shadow-none">
        <CardContent className="flex flex-col gap-4 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="text-sm font-medium text-foreground">Create liquidity position</div>
            <div className="mt-1 text-sm text-muted-foreground">
              Launch the local Anvil flow for this pool using the selected seeded LP address.
            </div>
          </div>
          <Button onClick={() => setOpen(true)}>Open position modal</Button>
        </CardContent>
      </Card>

      {open ? (
        <ModalShell
          title={`Create ${pool.tokenPair} position`}
          description="Submit a live modifyLiquidity call for this pool on local Anvil."
          onClose={() => setOpen(false)}
        >
          <div className="space-y-4">
            <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
              <Field
                label={`Tick lower (${pool.tickSpacing} spacing)`}
                value={tickLower}
                onChange={setTickLower}
                onAlign={() => setTickLower(String(alignTickToSpacing(Number(tickLower) || pool.tick, pool.tickSpacing, "down")))}
              />
              <Field
                label={`Tick upper (${pool.tickSpacing} spacing)`}
                value={tickUpper}
                onChange={setTickUpper}
                onAlign={() => setTickUpper(String(alignTickToSpacing(Number(tickUpper) || pool.tick, pool.tickSpacing, "up")))}
              />
              <Field label="Liquidity delta" value={liquidityInput} onChange={setLiquidityInput} help="Interpreted as a decimal and scaled to 18 decimals." />
              <Field label="Position salt" value={salt} onChange={setSalt} mono help="Use a unique salt to avoid merging with an existing range." />
            </div>

            <div className="grid gap-3 md:grid-cols-2">
              <Field
                label={`Max ${token0.symbol} funding`}
                value={maxToken0Input}
                onChange={setMaxToken0Input}
                disabled={!market.token0Native}
                help={market.token0Native ? "Sent as msg.value. Unused ETH is refunded by the router." : `${token0.symbol} is not the native leg in this market.`}
              />
              <Field
                label={`Max ${token1.symbol} funding`}
                value={maxToken1Input}
                onChange={setMaxToken1Input}
                disabled={market.token1Native}
                help={!market.token1Native ? `Used to size ${token1.symbol} approval for the router.` : `${token1.symbol} is the native leg in this market.`}
              />
            </div>

            <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
              <StatusPill
                label="Selected LP"
                value={selectedAddress}
                tone={hasSelectedSigner ? "positive" : "warning"}
              />
              <StatusPill
                label="Execution signer"
                value={hasSelectedSigner ? "Local Anvil signer ready" : "Unavailable"}
                tone={hasSelectedSigner ? "positive" : "warning"}
              />
              <StatusPill
                label="Approval"
                value={approvalToken ? (hasSufficientApproval ? "Ready" : "Needs approval") : "No ERC-20 leg"}
                tone={hasSufficientApproval ? "positive" : "warning"}
              />
              <StatusPill
                label="Native balance"
                value={
                  market.token0Native || market.token1Native
                    ? hasSufficientNativeBalance
                      ? "Sufficient"
                      : "Too low"
                    : "Not required"
                }
                tone={hasSufficientNativeBalance ? "positive" : "warning"}
              />
            </div>

            {validationError ? <InlineNotice tone="warning">{validationError}</InlineNotice> : null}
            {!hasSelectedSigner ? <InlineNotice tone="warning">The selected address is not one of the deterministic local Anvil accounts available to this app.</InlineNotice> : null}
            {approvalError ? <InlineNotice tone="danger">{approvalError}</InlineNotice> : null}
            {createError ? <InlineNotice tone="danger">{createError}</InlineNotice> : null}
            {statusMessage ? <InlineNotice tone="positive">{statusMessage}</InlineNotice> : null}

            <div className="flex flex-wrap items-center gap-3">
              {approvalToken && !hasSufficientApproval ? (
                <Button
                  variant="secondary"
                  onClick={handleApprove}
                  disabled={!hasSelectedSigner || approvalAmount <= 0n || approvalPending || approvalReceipt.isLoading}
                >
                  {approvalPending || approvalReceipt.isLoading ? `Approving ${market.token0Native ? token1.symbol : token0.symbol}...` : `Approve ${market.token0Native ? token1.symbol : token0.symbol}`}
                </Button>
              ) : null}
              <Button
                onClick={handleCreatePosition}
                disabled={
                  !hasSelectedSigner ||
                  Boolean(validationError) ||
                  !hasSufficientApproval ||
                  !hasSufficientNativeBalance ||
                  createPending ||
                  createReceipt.isLoading
                }
              >
                {createPending || createReceipt.isLoading ? "Creating..." : "Create position"}
              </Button>
              <Button variant="outline" onClick={() => setOpen(false)}>
                Close
              </Button>
            </div>

            <div className="text-xs text-muted-foreground">
              Native settlement uses the max {market.token0Native ? token0.symbol : token1.symbol} amount you provide. ERC-20 settlement uses the approved router allowance and only consumes what the pool manager requires.
            </div>
          </div>
        </ModalShell>
      ) : null}
    </>
  );
}

function ModalShell({
  title,
  description,
  children,
  onClose,
}: {
  title: string;
  description: string;
  children: React.ReactNode;
  onClose: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-background/70 p-4 backdrop-blur-sm">
      <div className="absolute inset-0" onClick={onClose} />
      <Card className="relative z-10 max-h-[90vh] w-full max-w-5xl overflow-hidden border-border/80 bg-background shadow-2xl">
        <CardHeader className="border-b border-border/60">
          <div className="flex items-start justify-between gap-4">
            <div>
              <CardTitle className="text-lg">{title}</CardTitle>
              <CardDescription className="mt-1">{description}</CardDescription>
            </div>
            <Button variant="ghost" size="icon" onClick={onClose} aria-label="Close modal">
              <ChevronDown className="h-4 w-4 -rotate-90" />
            </Button>
          </div>
        </CardHeader>
        <CardContent className="max-h-[calc(90vh-7rem)] overflow-y-auto p-6">
          {children}
        </CardContent>
      </Card>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  help,
  mono = false,
  disabled = false,
  onAlign,
}: {
  label: string;
  value: string;
  onChange: (next: string) => void;
  help?: string;
  mono?: boolean;
  disabled?: boolean;
  onAlign?: () => void;
}) {
  return (
    <label className="space-y-2">
      <div className="flex items-center justify-between gap-3">
        <span className="text-sm font-medium text-foreground">{label}</span>
        {onAlign ? (
          <button type="button" className="text-xs text-primary" onClick={onAlign}>
            Align
          </button>
        ) : null}
      </div>
      <input
        value={value}
        onChange={(event) => onChange(event.target.value)}
        disabled={disabled}
        className={cn(
          "w-full rounded-xl border border-border/70 bg-background px-3 py-2.5 text-sm outline-none transition focus:border-primary/50 focus:ring-2 focus:ring-primary/20 disabled:cursor-not-allowed disabled:opacity-50",
          mono ? "font-mono text-xs" : "",
        )}
      />
      {help ? <div className="text-xs text-muted-foreground">{help}</div> : null}
    </label>
  );
}

function StatusPill({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: "neutral" | "positive" | "warning";
}) {
  return (
    <div
      className={cn(
        "rounded-2xl border px-3 py-3",
        tone === "positive"
          ? "border-emerald-500/30 bg-emerald-500/10"
          : tone === "warning"
            ? "border-amber-500/30 bg-amber-500/10"
            : "border-border/60 bg-background/70",
      )}
    >
      <div className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">{label}</div>
      <div className="mt-1 truncate text-sm font-medium">{value}</div>
    </div>
  );
}

function InlineNotice({
  children,
  tone,
}: {
  children: React.ReactNode;
  tone: "warning" | "danger" | "positive";
}) {
  return (
    <div
      className={cn(
        "rounded-2xl border px-3 py-3 text-sm",
        tone === "warning"
          ? "border-amber-500/30 bg-amber-500/10 text-amber-700 dark:text-amber-300"
          : tone === "danger"
            ? "border-rose-500/30 bg-rose-500/10 text-rose-700 dark:text-rose-300"
            : "border-emerald-500/30 bg-emerald-500/10 text-emerald-700 dark:text-emerald-300",
      )}
    >
      {children}
    </div>
  );
}

function safeParseLiquidity(value: string) {
  try {
    return parseUnits(value || "0", 18);
  } catch {
    return 0n;
  }
}

function parseTokenAmount(value: string, decimals: number) {
  try {
    return parseUnits(value || "0", decimals);
  } catch {
    return 0n;
  }
}

function formatWriteError(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  if (typeof error === "object" && error !== null && "message" in error) {
    const message = (error as { message?: unknown }).message;
    if (typeof message === "string") return message;
  }

  return "Transaction failed.";
}
