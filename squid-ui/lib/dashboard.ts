import fs from "node:fs";
import path from "node:path";

type Artifact = {
  format: "seed-v3";
  chainId: number;
  contracts: ArtifactContracts;
  market: ArtifactMarket;
  seedManifest: ArtifactSeedManifest;
  pools: ArtifactPool[];
  positions: ArtifactPosition[];
};

type ArtifactContracts = {
  poolManager: string;
  squid: string;
  modifyLiquidityRouter: string;
  swapRouter: string;
  swapRouterNoChecks: string;
  actionsRouter: string;
};

type ArtifactMarket = {
  basePair: string;
  token0: string;
  token1: string;
  token0Symbol: string;
  token1Symbol: string;
  token0Decimals: number;
  token1Decimals: number;
  token0Native: boolean;
  token1Native: boolean;
};

type ArtifactSeedManifest = {
  description: string;
  poolCount: number;
  lpCount: number;
  traderCount: number;
  positionCount: number;
  swapCount: number;
  lpRoster: ArtifactLpRosterEntry[];
  traderRoster: ArtifactTraderRosterEntry[];
};

type ArtifactLpRosterEntry = {
  account: string;
  label: string;
  role: "lp";
  tier: string;
  strategy: string;
  anchor: boolean;
  plannedPositions: number;
  usdcBalanceSeeded: string | number;
  ethBalanceSeeded: string | number;
};

type ArtifactTraderRosterEntry = {
  account: string;
  label: string;
  role: "trader";
  strategy: string;
  preferredPoolIndex: number;
  netBuyEth: boolean;
  plannedSwaps: number;
  usdcBalanceSeeded: string | number;
  ethBalanceSeeded: string | number;
};

type ArtifactPool = {
  index: number;
  label: string;
  poolId: string;
  config: {
    fee: number;
    tickSpacing: number;
    initialTick: number;
    hook: string;
  };
  lpAddresses: string[];
  finalState: {
    poolSummary: {
      poolId: string;
      initialized: boolean;
      initializedBlock: number;
      initializedTimestamp: number;
      token0: string;
      token1: string;
      token0Symbol: string;
      token1Symbol: string;
      fee: number;
      tickSpacing: number;
      initialSqrtPriceX96: string | number;
      amounts: {
        initialToken0Amount: string | number;
        initialToken1Amount: string | number;
        currentToken0Amount: string | number;
        currentToken1Amount: string | number;
        totalFeeAccruedToken0: string | number;
        totalFeeAccruedToken1: string | number;
      };
      liquidity: {
        totalLiquidity: string | number;
        activeLiquidity: string | number;
        peakActiveLiquidity: string | number;
        totalLiquidityAtPeakActive: string | number;
        liquidityUtilisationBps: number;
        peakLiquidityUtilisationBps: number;
      };
      lps: {
        activeLpCount: number;
        lifetimeLpCount: number;
        lpRetentionBps: number;
      };
      positions: {
        activePositionCount: number;
        totalPositionCount: number;
        activePositionPercentageBps: number;
      };
      tradeFlow: {
        totalSwapCount: number;
        zeroToOneSwapCount: number;
        oneToZeroSwapCount: number;
        flowSkewnessBps: number;
      };
    };
    currentPoolState: {
      sqrtPriceX96: string | number;
      tick: number;
      protocolFee: number;
      lpFee: number;
    };
  };
};

type ArtifactPosition = {
  label: string;
  lp: string;
  poolIndex: number;
  poolLabel: string;
  positionId: string;
  tickLower: number;
  tickUpper: number;
  salt: string;
  seedLiquidityDelta: string | number;
  summary: {
    positionId: string;
    initialized: boolean;
    active: boolean;
    age: number;
    createdBlock: number;
    createdTimestamp: number;
    updatedBlock: number;
    updatedTimestamp: number;
    owner: string;
    coreOwner: string;
    poolId: string;
    tickLower: number;
    tickUpper: number;
    salt: string;
  };
  liquidity: {
    totalLiquidity: string | number;
    activeLiquidity: string | number;
    activeSwapVolume0: string | number;
    activeSwapVolume1: string | number;
    lifetimeSwapVolume0: string | number;
    lifetimeSwapVolume1: string | number;
  };
  pnl: {
    principalAmount0: string | number;
    principalAmount1: string | number;
    currentAmount0: string | number;
    currentAmount1: string | number;
    feeAccumulated0: string | number;
    feeAccumulated1: string | number;
    netPnl0: string | number;
    netPnl1: string | number;
  };
};

export type KnownAddress = {
  address: string;
  label: string;
  role: "lp" | "trader";
  tier: string | null;
  anchor: boolean;
  strategy: string | null;
  plannedPositions: number | null;
  preferredPoolIndex: number | null;
  plannedSwaps: number | null;
  netBuyEth: boolean | null;
  seededUsdcBalance: bigint | null;
  seededEthBalance: bigint | null;
};

export type PositionSnapshot = {
  address: string;
  label: string;
  positionId: string;
  active: boolean;
  poolId: string;
  poolLabel: string;
  owner: string;
  coreOwner: string;
  tickLower: number;
  tickUpper: number;
  salt: string;
  age: number;
  createdBlock: number;
  createdTimestamp: number;
  updatedBlock: number;
  updatedTimestamp: number;
  liquidity: bigint;
  activeLiquidity: bigint;
  activeSwapVolume0: bigint;
  activeSwapVolume1: bigint;
  lifetimeSwapVolume0: bigint;
  lifetimeSwapVolume1: bigint;
  principalAmount0: bigint;
  principalAmount1: bigint;
  currentAmount0: bigint;
  currentAmount1: bigint;
  feeAccumulated0: bigint;
  feeAccumulated1: bigint;
  fees: bigint;
  netPnl0: bigint;
  netPnl1: bigint;
  netPnl: bigint;
};

export type PositionGroup = {
  poolId: string;
  poolIndex: number;
  poolLabel: string;
  fee: number;
  tickSpacing: number;
  positions: PositionSnapshot[];
  positionCount: number;
  activePositionCount: number;
  totalLiquidity: bigint;
  totalActiveLiquidity: bigint;
  totalFees: bigint;
  totalFeeAccumulated0: bigint;
  totalFeeAccumulated1: bigint;
  totalPnl: bigint;
  totalNetPnl0: bigint;
  totalNetPnl1: bigint;
  totalPrincipal0: bigint;
  totalPrincipal1: bigint;
  totalCurrent0: bigint;
  totalCurrent1: bigint;
  totalActiveSwapVolume0: bigint;
  totalActiveSwapVolume1: bigint;
  totalLifetimeSwapVolume0: bigint;
  totalLifetimeSwapVolume1: bigint;
};

export type PoolSummary = {
  poolId: string;
  poolIndex: number;
  poolLabel: string;
  tokenPair: string;
  token0: string;
  token1: string;
  token0Symbol: string;
  token1Symbol: string;
  hook: string;
  fee: number;
  tickSpacing: number;
  tick: number;
  initialSqrtPriceX96: bigint;
  currentSqrtPriceX96: bigint;
  protocolFee: number;
  lpFee: number;
  totalLiquidity: bigint;
  activeLiquidity: bigint;
  peakActiveLiquidity: bigint;
  totalLiquidityAtPeakActive: bigint;
  liquidityUtilisationBps: number;
  peakLiquidityUtilisationBps: number;
  activeLpCount: number;
  lifetimeLpCount: number;
  lpRetentionBps: number;
  lpCount: number;
  activePositionCount: number;
  totalPositionCount: number;
  activePositionPercentageBps: number;
  positionCount: number;
  totalSwapCount: number;
  zeroToOneSwapCount: number;
  oneToZeroSwapCount: number;
  flowSkewnessBps: number;
  initialToken0Amount: bigint;
  initialToken1Amount: bigint;
  currentToken0Amount: bigint;
  currentToken1Amount: bigint;
  totalFeeAccruedToken0: bigint;
  totalFeeAccruedToken1: bigint;
};

export type LpSummary = {
  address: string;
  label: string;
  tier: string | null;
  anchor: boolean;
  strategy: string | null;
  plannedPositions: number | null;
  seededUsdcBalance: bigint | null;
  seededEthBalance: bigint | null;
  positionCount: number;
  activePositionCount: number;
  poolCount: number;
  totalLiquidity: bigint;
  totalActiveLiquidity: bigint;
  totalFees: bigint;
  totalFeeAccumulated0: bigint;
  totalFeeAccumulated1: bigint;
  totalPnl: bigint;
  totalNetPnl0: bigint;
  totalNetPnl1: bigint;
  totalPrincipal0: bigint;
  totalPrincipal1: bigint;
  totalCurrent0: bigint;
  totalCurrent1: bigint;
  totalActiveSwapVolume0: bigint;
  totalActiveSwapVolume1: bigint;
  totalLifetimeSwapVolume0: bigint;
  totalLifetimeSwapVolume1: bigint;
  groups: PositionGroup[];
};

export type SquidDashboardData = {
  chainId: number;
  market: ArtifactMarket;
  contracts: ArtifactContracts;
  seedManifest: {
    description: string;
    poolCount: number;
    lpCount: number;
    traderCount: number;
    positionCount: number;
    swapCount: number;
  };
  poolSummaries: PoolSummary[];
  lpSummaries: LpSummary[];
  knownAddresses: KnownAddress[];
};

export function loadSquidDashboard(): SquidDashboardData {
  const artifactPath = path.resolve(process.cwd(), "..", "script", "output", "anvil-simulation.json");
  const raw = fs.readFileSync(artifactPath, "utf8");
  const artifact = JSON.parse(raw) as Artifact;

  if (artifact.format !== "seed-v3") {
    throw new Error(`Unsupported simulation artifact format: ${artifact.format}`);
  }

  const rosterByAddress = new Map(artifact.seedManifest.lpRoster.map((entry) => [entry.account, entry] as const));
  const poolById = new Map(artifact.pools.map((pool) => [pool.poolId, pool] as const));
  const positionsByPoolId = new Map<string, ArtifactPosition[]>();

  for (const position of artifact.positions) {
    const bucket = positionsByPoolId.get(position.summary.poolId) ?? [];
    bucket.push(position);
    positionsByPoolId.set(position.summary.poolId, bucket);
  }

  const knownAddresses: KnownAddress[] = [
    ...artifact.seedManifest.lpRoster.map((entry) => ({
      address: entry.account,
      label: entry.label,
      role: entry.role,
      tier: entry.tier,
      anchor: entry.anchor,
      strategy: entry.strategy,
      plannedPositions: entry.plannedPositions,
      preferredPoolIndex: null,
      plannedSwaps: null,
      netBuyEth: null,
      seededUsdcBalance: toBigInt(entry.usdcBalanceSeeded),
      seededEthBalance: toBigInt(entry.ethBalanceSeeded),
    })),
    ...artifact.seedManifest.traderRoster.map((entry) => ({
      address: entry.account,
      label: entry.label,
      role: entry.role,
      tier: null,
      anchor: false,
      strategy: entry.strategy,
      plannedPositions: null,
      preferredPoolIndex: entry.preferredPoolIndex,
      plannedSwaps: entry.plannedSwaps,
      netBuyEth: entry.netBuyEth,
      seededUsdcBalance: toBigInt(entry.usdcBalanceSeeded),
      seededEthBalance: toBigInt(entry.ethBalanceSeeded),
    })),
  ];

  const poolSummaries: PoolSummary[] = artifact.pools.map((pool) => {
    const poolSummary = pool.finalState.poolSummary;
    const poolAmounts = poolSummary.amounts;

    return {
      poolId: pool.poolId,
      poolIndex: pool.index,
      poolLabel: pool.label,
      tokenPair: artifact.market.basePair,
      token0: poolSummary.token0,
      token1: poolSummary.token1,
      token0Symbol: poolSummary.token0Symbol,
      token1Symbol: poolSummary.token1Symbol,
      hook: pool.config.hook,
      fee: poolSummary.fee,
      tickSpacing: poolSummary.tickSpacing,
      tick: pool.finalState.currentPoolState.tick,
      initialSqrtPriceX96: toBigInt(poolSummary.initialSqrtPriceX96),
      currentSqrtPriceX96: toBigInt(pool.finalState.currentPoolState.sqrtPriceX96),
      protocolFee: pool.finalState.currentPoolState.protocolFee,
      lpFee: pool.finalState.currentPoolState.lpFee,
      totalLiquidity: toBigInt(poolSummary.liquidity.totalLiquidity),
      activeLiquidity: toBigInt(poolSummary.liquidity.activeLiquidity),
      peakActiveLiquidity: toBigInt(poolSummary.liquidity.peakActiveLiquidity),
      totalLiquidityAtPeakActive: toBigInt(
        poolSummary.liquidity.totalLiquidityAtPeakActive,
        poolSummary.liquidity.totalLiquidity,
      ),
      liquidityUtilisationBps: poolSummary.liquidity.liquidityUtilisationBps,
      peakLiquidityUtilisationBps: poolSummary.liquidity.peakLiquidityUtilisationBps,
      activeLpCount: poolSummary.lps.activeLpCount,
      lifetimeLpCount: poolSummary.lps.lifetimeLpCount,
      lpRetentionBps: poolSummary.lps.lpRetentionBps,
      lpCount: poolSummary.lps.lifetimeLpCount || pool.lpAddresses.length,
      activePositionCount: poolSummary.positions.activePositionCount,
      totalPositionCount: poolSummary.positions.totalPositionCount,
      activePositionPercentageBps: poolSummary.positions.activePositionPercentageBps,
      positionCount: poolSummary.positions.totalPositionCount,
      totalSwapCount: poolSummary.tradeFlow.totalSwapCount,
      zeroToOneSwapCount: poolSummary.tradeFlow.zeroToOneSwapCount,
      oneToZeroSwapCount: poolSummary.tradeFlow.oneToZeroSwapCount,
      flowSkewnessBps: poolSummary.tradeFlow.flowSkewnessBps,
      initialToken0Amount: toBigInt(poolAmounts?.initialToken0Amount),
      initialToken1Amount: toBigInt(poolAmounts?.initialToken1Amount),
      currentToken0Amount: toBigInt(poolAmounts?.currentToken0Amount),
      currentToken1Amount: toBigInt(poolAmounts?.currentToken1Amount),
      totalFeeAccruedToken0: toBigInt(poolAmounts?.totalFeeAccruedToken0),
      totalFeeAccruedToken1: toBigInt(poolAmounts?.totalFeeAccruedToken1),
    };
  });

  const lpBuckets = new Map<string, LpSummary>();

  for (const position of artifact.positions) {
    const rosterEntry = rosterByAddress.get(position.lp);
    const address = position.lp;
    const label = rosterEntry?.label ?? shortenAddressLike(address);
    const pool = poolById.get(position.summary.poolId);
    const liquidity = toBigInt(position.liquidity.totalLiquidity);
    const activeLiquidity = toBigInt(position.liquidity.activeLiquidity);
    const feeAccumulated0 = toBigInt(position.pnl.feeAccumulated0);
    const feeAccumulated1 = toBigInt(position.pnl.feeAccumulated1);
    const netPnl0 = toBigInt(position.pnl.netPnl0);
    const netPnl1 = toBigInt(position.pnl.netPnl1);
    const fees = feeAccumulated0 + feeAccumulated1;
    const netPnl = netPnl0 + netPnl1;

    let lp = lpBuckets.get(address);

    if (!lp) {
      lp = {
        address,
        label,
        tier: rosterEntry?.tier ?? null,
        anchor: rosterEntry?.anchor ?? false,
        strategy: rosterEntry?.strategy ?? null,
        plannedPositions: rosterEntry?.plannedPositions ?? null,
        seededUsdcBalance: rosterEntry ? toBigInt(rosterEntry.usdcBalanceSeeded) : null,
        seededEthBalance: rosterEntry ? toBigInt(rosterEntry.ethBalanceSeeded) : null,
        positionCount: 0,
        activePositionCount: 0,
        poolCount: 0,
        totalLiquidity: 0n,
        totalActiveLiquidity: 0n,
        totalFees: 0n,
        totalFeeAccumulated0: 0n,
        totalFeeAccumulated1: 0n,
        totalPnl: 0n,
        totalNetPnl0: 0n,
        totalNetPnl1: 0n,
        totalPrincipal0: 0n,
        totalPrincipal1: 0n,
        totalCurrent0: 0n,
        totalCurrent1: 0n,
        totalActiveSwapVolume0: 0n,
        totalActiveSwapVolume1: 0n,
        totalLifetimeSwapVolume0: 0n,
        totalLifetimeSwapVolume1: 0n,
        groups: [],
      };
      lpBuckets.set(address, lp);
    }

    let group = lp.groups.find((candidate) => candidate.poolId === position.summary.poolId);

    if (!group) {
      group = {
        poolId: position.summary.poolId,
        poolIndex: position.poolIndex,
        poolLabel: position.poolLabel,
        fee: pool?.config.fee ?? 0,
        tickSpacing: pool?.config.tickSpacing ?? 0,
        positions: [],
        positionCount: 0,
        activePositionCount: 0,
        totalLiquidity: 0n,
        totalActiveLiquidity: 0n,
        totalFees: 0n,
        totalFeeAccumulated0: 0n,
        totalFeeAccumulated1: 0n,
        totalPnl: 0n,
        totalNetPnl0: 0n,
        totalNetPnl1: 0n,
        totalPrincipal0: 0n,
        totalPrincipal1: 0n,
        totalCurrent0: 0n,
        totalCurrent1: 0n,
        totalActiveSwapVolume0: 0n,
        totalActiveSwapVolume1: 0n,
        totalLifetimeSwapVolume0: 0n,
        totalLifetimeSwapVolume1: 0n,
      };
      lp.groups.push(group);
    }

    const snapshot: PositionSnapshot = {
      address,
      label,
      positionId: position.positionId,
      active: position.summary.active,
      poolId: position.summary.poolId,
      poolLabel: position.poolLabel,
      owner: position.summary.owner,
      coreOwner: position.summary.coreOwner,
      tickLower: position.tickLower,
      tickUpper: position.tickUpper,
      salt: position.summary.salt,
      age: position.summary.age,
      createdBlock: position.summary.createdBlock,
      createdTimestamp: position.summary.createdTimestamp,
      updatedBlock: position.summary.updatedBlock,
      updatedTimestamp: position.summary.updatedTimestamp,
      liquidity,
      activeLiquidity,
      activeSwapVolume0: toBigInt(position.liquidity.activeSwapVolume0),
      activeSwapVolume1: toBigInt(position.liquidity.activeSwapVolume1),
      lifetimeSwapVolume0: toBigInt(position.liquidity.lifetimeSwapVolume0),
      lifetimeSwapVolume1: toBigInt(position.liquidity.lifetimeSwapVolume1),
      principalAmount0: toBigInt(position.pnl.principalAmount0),
      principalAmount1: toBigInt(position.pnl.principalAmount1),
      currentAmount0: toBigInt(position.pnl.currentAmount0),
      currentAmount1: toBigInt(position.pnl.currentAmount1),
      feeAccumulated0,
      feeAccumulated1,
      fees,
      netPnl0,
      netPnl1,
      netPnl,
    };

    group.positions.push(snapshot);
    group.positionCount += 1;
    group.activePositionCount += position.summary.active ? 1 : 0;
    group.totalLiquidity += liquidity;
    group.totalActiveLiquidity += activeLiquidity;
    group.totalFees += fees;
    group.totalFeeAccumulated0 += feeAccumulated0;
    group.totalFeeAccumulated1 += feeAccumulated1;
    group.totalPnl += netPnl;
    group.totalNetPnl0 += netPnl0;
    group.totalNetPnl1 += netPnl1;
    group.totalPrincipal0 += snapshot.principalAmount0;
    group.totalPrincipal1 += snapshot.principalAmount1;
    group.totalCurrent0 += snapshot.currentAmount0;
    group.totalCurrent1 += snapshot.currentAmount1;
    group.totalActiveSwapVolume0 += snapshot.activeSwapVolume0;
    group.totalActiveSwapVolume1 += snapshot.activeSwapVolume1;
    group.totalLifetimeSwapVolume0 += snapshot.lifetimeSwapVolume0;
    group.totalLifetimeSwapVolume1 += snapshot.lifetimeSwapVolume1;

    lp.positionCount += 1;
    lp.activePositionCount += position.summary.active ? 1 : 0;
    lp.totalLiquidity += liquidity;
    lp.totalActiveLiquidity += activeLiquidity;
    lp.totalFees += fees;
    lp.totalFeeAccumulated0 += feeAccumulated0;
    lp.totalFeeAccumulated1 += feeAccumulated1;
    lp.totalPnl += netPnl;
    lp.totalNetPnl0 += netPnl0;
    lp.totalNetPnl1 += netPnl1;
    lp.totalPrincipal0 += snapshot.principalAmount0;
    lp.totalPrincipal1 += snapshot.principalAmount1;
    lp.totalCurrent0 += snapshot.currentAmount0;
    lp.totalCurrent1 += snapshot.currentAmount1;
    lp.totalActiveSwapVolume0 += snapshot.activeSwapVolume0;
    lp.totalActiveSwapVolume1 += snapshot.activeSwapVolume1;
    lp.totalLifetimeSwapVolume0 += snapshot.lifetimeSwapVolume0;
    lp.totalLifetimeSwapVolume1 += snapshot.lifetimeSwapVolume1;
  }

  const lpSummaries = knownAddresses
    .map((entry) => lpBuckets.get(entry.address))
    .filter((value): value is LpSummary => Boolean(value))
    .map((lp) => ({
      ...lp,
      poolCount: lp.groups.length,
      groups: lp.groups
        .map((group) => ({
          ...group,
          positions: group.positions.sort((left, right) => left.tickLower - right.tickLower || left.tickUpper - right.tickUpper),
        }))
        .sort((left, right) => left.poolIndex - right.poolIndex),
    }));

  return {
    chainId: artifact.chainId,
    market: artifact.market,
    contracts: artifact.contracts,
    seedManifest: {
      description: artifact.seedManifest.description,
      poolCount: artifact.seedManifest.poolCount,
      lpCount: artifact.seedManifest.lpCount,
      traderCount: artifact.seedManifest.traderCount,
      positionCount: artifact.seedManifest.positionCount,
      swapCount: artifact.seedManifest.swapCount,
    },
    poolSummaries,
    lpSummaries,
    knownAddresses,
  };
}

function toBigInt(value: string | number | null | undefined, fallback: string | number = 0) {
  return BigInt(value ?? fallback);
}

function shortenAddressLike(value: string) {
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}
