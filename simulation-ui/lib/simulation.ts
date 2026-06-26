import fs from "node:fs";
import path from "node:path";

type Numeric = string | number;

type Artifact = {
  format: string;
  runTimestamp: number;
  chainId: number;
  contracts: Record<string, string>;
  market: {
    basePair: string;
    token0Symbol: string;
    token1Symbol: string;
    token0Decimals: number;
    token1Decimals: number;
  };
  seedManifest: {
    description: string;
    poolCount: number;
    lpCount: number;
    traderCount: number;
    positionCount: number;
    swapCount: number;
    scenarioActionCount: number;
    lpRoster: LpRoster[];
    traderRoster: TraderRoster[];
  };
  pools: ArtifactPool[];
  positions: ArtifactPosition[];
  scenarioActions: ArtifactAction[];
  history: ArtifactCheckpoint[];
};

type LpRoster = {
  account: string; label: string; tier: string; strategy: string; anchor: boolean;
  plannedPositions: number; usdcBalanceSeeded: Numeric; ethBalanceSeeded: Numeric;
};
type TraderRoster = {
  account: string; label: string; strategy: string; preferredPoolIndex: number;
  netBuyEth: boolean; plannedSwaps: number; usdcBalanceSeeded: Numeric; ethBalanceSeeded: Numeric;
};
type ArtifactPool = {
  index: number; label: string; poolId: string; lpAddresses: string[];
  config: { fee: number; tickSpacing: number; initialTick: number; hook: string };
  finalState: {
    currentPoolState: { sqrtPriceX96: Numeric; tick: number; protocolFee: number; lpFee: number };
    poolSummary: {
      token0Symbol: string; token1Symbol: string; fee: number; tickSpacing: number;
      amounts: Record<string, Numeric>;
      liquidity: Record<string, Numeric>;
      lps: Record<string, number>;
      positions: Record<string, number>;
      tradeFlow: Record<string, number>;
    };
  };
};
type ArtifactPosition = {
  label: string; lp: string; poolIndex: number; poolLabel: string; positionId: string;
  tickLower: number; tickUpper: number;
  summary: {
    active: boolean; owner: string; poolId: string; age: number;
    createdTimestamp: number; updatedTimestamp: number;
  };
  liquidity: Record<string, Numeric>;
  pnl: Record<string, Numeric>;
};
type ArtifactAction = {
  phase: string; actionType: string; actor: string; poolIndex: number;
  liquidityDelta: Numeric; amountSpecified: Numeric; zeroForOne: boolean; positionId: string;
};
type ArtifactCheckpoint = {
  sequence: number; phase: string; actionType: string; blockNumber: number; timestamp: number;
  poolIndex: number; positionId: string; pool: null | {
    poolId: string; sqrtPriceX96: Numeric; tick: number; totalLiquidity: Numeric;
    activeLiquidity: Numeric; peakActiveLiquidity: Numeric; liquidityUtilisationBps: number;
    activeLpCount: number; lifetimeLpCount: number; activePositionCount: number;
    totalPositionCount: number; totalSwapCount: number; zeroToOneSwapCount: number;
    oneToZeroSwapCount: number; flowSkewnessBps: number;
  };
  position: null | {
    active: boolean; totalLiquidity: Numeric; activeLiquidity: Numeric;
    feeAccumulated0: Numeric; feeAccumulated1: Numeric; netPnl0: Numeric; netPnl1: Numeric;
  };
};

export type PoolRow = {
  index: number; label: string; poolId: string; tokenPair: string; fee: number; tickSpacing: number;
  initialTick: number; tick: number; totalLiquidity: bigint; activeLiquidity: bigint;
  peakActiveLiquidity: bigint; liquidityUtilisationBps: number; peakLiquidityUtilisationBps: number;
  activeLpCount: number; lifetimeLpCount: number; activePositionCount: number; totalPositionCount: number;
  totalSwapCount: number; zeroToOneSwapCount: number; oneToZeroSwapCount: number; flowSkewnessBps: number;
  currentToken0Amount: bigint; currentToken1Amount: bigint; totalFeeAccruedToken0: bigint; totalFeeAccruedToken1: bigint;
};
export type PositionRow = {
  label: string; lp: string; poolIndex: number; poolLabel: string; positionId: string; active: boolean;
  tickLower: number; tickUpper: number; age: number; createdTimestamp: number; updatedTimestamp: number;
  totalLiquidity: bigint; activeLiquidity: bigint; activeSwapVolume0: bigint; activeSwapVolume1: bigint;
  lifetimeSwapVolume0: bigint; lifetimeSwapVolume1: bigint; principalAmount0: bigint; principalAmount1: bigint;
  currentAmount0: bigint; currentAmount1: bigint; feeAccumulated0: bigint; feeAccumulated1: bigint;
  netPnl0: bigint; netPnl1: bigint;
};
export type ParticipantRow = {
  address: string; label: string; role: "LP" | "Trader"; strategy: string; tier: string | null;
  anchor: boolean; preferredPoolIndex: number | null; plannedActivity: number;
  actualActivity: number; seededEth: bigint; seededUsdc: bigint;
};
export type ActionRow = ArtifactAction & { sequence: number };
export type HistoryRow = Omit<ArtifactCheckpoint, "pool" | "position"> & {
  pool: null | Omit<NonNullable<ArtifactCheckpoint["pool"]>, "sqrtPriceX96" | "totalLiquidity" | "activeLiquidity" | "peakActiveLiquidity"> & {
    sqrtPriceX96: bigint; totalLiquidity: bigint; activeLiquidity: bigint; peakActiveLiquidity: bigint;
  };
  position: null | {
    active: boolean; totalLiquidity: bigint; activeLiquidity: bigint; feeAccumulated0: bigint;
    feeAccumulated1: bigint; netPnl0: bigint; netPnl1: bigint;
  };
};
export type DashboardData = {
  format: string; runTimestamp: number; chainId: number; description: string;
  contracts: Record<string, string>; market: Artifact["market"]; counts: Artifact["seedManifest"];
  pools: PoolRow[]; positions: PositionRow[]; participants: ParticipantRow[];
  actions: ActionRow[]; history: HistoryRow[];
};

export function loadSimulationDashboard(): DashboardData {
  const configuredPath = process.env.SQUID_SIMULATION_ARTIFACT;
  const artifactPath = configuredPath
    ? path.resolve(configuredPath)
    : path.resolve(process.cwd(), "..", "script", "output", "anvil-simulation.json");
  let parsed: unknown;
  try {
    parsed = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
  } catch (error) {
    throw new Error(`Unable to read simulation artifact at ${artifactPath}: ${error instanceof Error ? error.message : String(error)}`);
  }
  const artifact = validateArtifact(parsed);

  const pools = artifact.pools.map((pool): PoolRow => {
    const summary = pool.finalState.poolSummary;
    return {
      index: pool.index, label: pool.label, poolId: pool.poolId,
      tokenPair: `${summary.token0Symbol}/${summary.token1Symbol}`, fee: summary.fee,
      tickSpacing: summary.tickSpacing, initialTick: pool.config.initialTick,
      tick: pool.finalState.currentPoolState.tick,
      totalLiquidity: bi(summary.liquidity.totalLiquidity), activeLiquidity: bi(summary.liquidity.activeLiquidity),
      peakActiveLiquidity: bi(summary.liquidity.peakActiveLiquidity),
      liquidityUtilisationBps: Number(summary.liquidity.liquidityUtilisationBps),
      peakLiquidityUtilisationBps: Number(summary.liquidity.peakLiquidityUtilisationBps),
      activeLpCount: summary.lps.activeLpCount, lifetimeLpCount: summary.lps.lifetimeLpCount,
      activePositionCount: summary.positions.activePositionCount, totalPositionCount: summary.positions.totalPositionCount,
      totalSwapCount: summary.tradeFlow.totalSwapCount, zeroToOneSwapCount: summary.tradeFlow.zeroToOneSwapCount,
      oneToZeroSwapCount: summary.tradeFlow.oneToZeroSwapCount, flowSkewnessBps: summary.tradeFlow.flowSkewnessBps,
      currentToken0Amount: bi(summary.amounts.currentToken0Amount), currentToken1Amount: bi(summary.amounts.currentToken1Amount),
      totalFeeAccruedToken0: bi(summary.amounts.totalFeeAccruedToken0), totalFeeAccruedToken1: bi(summary.amounts.totalFeeAccruedToken1),
    };
  });
  const positions = artifact.positions.map((p): PositionRow => ({
    label: p.label, lp: p.lp, poolIndex: p.poolIndex, poolLabel: p.poolLabel, positionId: p.positionId,
    active: p.summary.active, tickLower: p.tickLower, tickUpper: p.tickUpper, age: p.summary.age,
    createdTimestamp: p.summary.createdTimestamp, updatedTimestamp: p.summary.updatedTimestamp,
    totalLiquidity: bi(p.liquidity.totalLiquidity), activeLiquidity: bi(p.liquidity.activeLiquidity),
    activeSwapVolume0: bi(p.liquidity.activeSwapVolume0), activeSwapVolume1: bi(p.liquidity.activeSwapVolume1),
    lifetimeSwapVolume0: bi(p.liquidity.lifetimeSwapVolume0), lifetimeSwapVolume1: bi(p.liquidity.lifetimeSwapVolume1),
    principalAmount0: bi(p.pnl.principalAmount0), principalAmount1: bi(p.pnl.principalAmount1),
    currentAmount0: bi(p.pnl.currentAmount0), currentAmount1: bi(p.pnl.currentAmount1),
    feeAccumulated0: bi(p.pnl.feeAccumulated0), feeAccumulated1: bi(p.pnl.feeAccumulated1),
    netPnl0: bi(p.pnl.netPnl0), netPnl1: bi(p.pnl.netPnl1),
  }));
  const participants: ParticipantRow[] = [
    ...artifact.seedManifest.lpRoster.map((p) => ({
      address: p.account, label: p.label, role: "LP" as const, strategy: p.strategy, tier: p.tier,
      anchor: p.anchor, preferredPoolIndex: null, plannedActivity: p.plannedPositions,
      actualActivity: positions.filter((position) => position.lp.toLowerCase() === p.account.toLowerCase()).length,
      seededEth: bi(p.ethBalanceSeeded), seededUsdc: bi(p.usdcBalanceSeeded),
    })),
    ...artifact.seedManifest.traderRoster.map((p) => ({
      address: p.account, label: p.label, role: "Trader" as const, strategy: p.strategy, tier: null,
      anchor: false, preferredPoolIndex: p.preferredPoolIndex, plannedActivity: p.plannedSwaps,
      actualActivity: artifact.scenarioActions.filter((a) => a.actor === p.label && a.actionType === "swap").length,
      seededEth: bi(p.ethBalanceSeeded), seededUsdc: bi(p.usdcBalanceSeeded),
    })),
  ];
  const history: HistoryRow[] = artifact.history.map((h) => ({
    ...h,
    pool: h.pool ? { ...h.pool, sqrtPriceX96: bi(h.pool.sqrtPriceX96), totalLiquidity: bi(h.pool.totalLiquidity),
      activeLiquidity: bi(h.pool.activeLiquidity), peakActiveLiquidity: bi(h.pool.peakActiveLiquidity) } : null,
    position: h.position ? { ...h.position, totalLiquidity: bi(h.position.totalLiquidity),
      activeLiquidity: bi(h.position.activeLiquidity), feeAccumulated0: bi(h.position.feeAccumulated0),
      feeAccumulated1: bi(h.position.feeAccumulated1), netPnl0: bi(h.position.netPnl0), netPnl1: bi(h.position.netPnl1) } : null,
  }));

  return {
    format: artifact.format, runTimestamp: artifact.runTimestamp, chainId: artifact.chainId,
    description: artifact.seedManifest.description, contracts: artifact.contracts, market: artifact.market,
    counts: artifact.seedManifest, pools, positions, participants,
    actions: artifact.scenarioActions.map((action, sequence) => ({ ...action, sequence })), history,
  };
}

function validateArtifact(value: unknown): Artifact {
  if (!value || typeof value !== "object") throw new Error("Simulation artifact must be a JSON object.");
  const candidate = value as Partial<Artifact>;
  if (candidate.format !== "seed-v3") throw new Error(`Unsupported simulation artifact format: ${String(candidate.format)}`);
  for (const key of ["pools", "positions", "scenarioActions", "history"] as const) {
    if (!Array.isArray(candidate[key])) throw new Error(`Simulation artifact is missing ${key}.`);
  }
  if (!candidate.seedManifest || !candidate.market || !candidate.contracts) throw new Error("Simulation artifact metadata is incomplete.");
  if (candidate.pools!.length !== candidate.seedManifest.poolCount) throw new Error("Pool count does not match the seed manifest.");
  if (candidate.positions!.length !== candidate.seedManifest.positionCount) throw new Error("Position count does not match the seed manifest.");
  if (candidate.scenarioActions!.length !== candidate.seedManifest.scenarioActionCount) throw new Error("Action count does not match the seed manifest.");
  if (candidate.history!.length !== candidate.scenarioActions!.length) throw new Error("Every action must have one history checkpoint.");
  candidate.history!.forEach((point, index) => {
    if (point.sequence !== index) throw new Error(`History sequence is invalid at index ${index}.`);
  });
  return candidate as Artifact;
}

function bi(value: Numeric | undefined): bigint {
  return BigInt(value ?? 0);
}
