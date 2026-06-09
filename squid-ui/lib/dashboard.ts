import fs from "node:fs";
import path from "node:path";

type Artifact = {
  format: "seed-v1";
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
};

type ArtifactSeedManifest = {
  description: string;
  poolCount: number;
  lpCount: number;
  positionCount: number;
  swapCount: number;
  lpRoster: ArtifactLpRosterEntry[];
};

type ArtifactLpRosterEntry = {
  account: string;
  label: string;
  tier: string;
  anchor: boolean;
  plannedPositions: number;
  usdBalanceSeeded: string | number;
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
      token0Symbol: string;
      token1Symbol: string;
      fee: number;
      tickSpacing: number;
      liquidity: {
        totalLiquidity: string | number;
        activeLiquidity: string | number;
        peakActiveLiquidity: string | number;
      };
    };
    currentPoolState: {
      tick: number;
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
  summary: {
    active: boolean;
    poolId: string;
  };
  liquidity: {
    totalLiquidity: string | number;
    activeLiquidity: string | number;
  };
  pnl: {
    feeAccumulated0: string | number;
    feeAccumulated1: string | number;
    netPnl0: string | number;
    netPnl1: string | number;
  };
};

export type KnownAddress = {
  address: string;
  label: string;
  tier: string | null;
  anchor: boolean;
  plannedPositions: number | null;
};

export type PositionSnapshot = {
  address: string;
  label: string;
  positionId: string;
  active: boolean;
  tickLower: number;
  tickUpper: number;
  liquidity: bigint;
  activeLiquidity: bigint;
  fees: bigint;
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
  totalFees: bigint;
  totalPnl: bigint;
};

export type PoolSummary = {
  poolId: string;
  poolIndex: number;
  poolLabel: string;
  tokenPair: string;
  fee: number;
  tickSpacing: number;
  tick: number;
  totalLiquidity: bigint;
  activeLiquidity: bigint;
  peakActiveLiquidity: bigint;
  lpCount: number;
  positionCount: number;
  activePositionCount: number;
};

export type LpSummary = {
  address: string;
  label: string;
  tier: string | null;
  anchor: boolean;
  plannedPositions: number | null;
  seededUsdBalance: bigint | null;
  seededEthBalance: bigint | null;
  positionCount: number;
  activePositionCount: number;
  poolCount: number;
  totalLiquidity: bigint;
  totalFees: bigint;
  totalPnl: bigint;
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

  if (artifact.format !== "seed-v1") {
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

  const knownAddresses: KnownAddress[] = artifact.seedManifest.lpRoster.map((entry) => ({
    address: entry.account,
    label: entry.label,
    tier: entry.tier,
    anchor: entry.anchor,
    plannedPositions: entry.plannedPositions,
  }));

  const poolSummaries: PoolSummary[] = artifact.pools.map((pool) => {
    const positions = positionsByPoolId.get(pool.poolId) ?? [];

    return {
      poolId: pool.poolId,
      poolIndex: pool.index,
      poolLabel: pool.label,
      tokenPair: artifact.market.basePair,
      fee: pool.finalState.poolSummary.fee,
      tickSpacing: pool.finalState.poolSummary.tickSpacing,
      tick: pool.finalState.currentPoolState.tick,
      totalLiquidity: toBigInt(pool.finalState.poolSummary.liquidity.totalLiquidity),
      activeLiquidity: toBigInt(pool.finalState.poolSummary.liquidity.activeLiquidity),
      peakActiveLiquidity: toBigInt(pool.finalState.poolSummary.liquidity.peakActiveLiquidity),
      lpCount: pool.lpAddresses.length,
      positionCount: positions.length,
      activePositionCount: positions.filter((position) => position.summary.active).length,
    };
  });

  const lpBuckets = new Map<string, LpSummary>();

  for (const position of artifact.positions) {
    const rosterEntry = rosterByAddress.get(position.lp);
    const address = position.lp;
    const label = rosterEntry?.label ?? shortenAddressLike(address);
    const pool = poolById.get(position.summary.poolId);
    const fees = toBigInt(position.pnl.feeAccumulated0) + toBigInt(position.pnl.feeAccumulated1);
    const netPnl = toBigInt(position.pnl.netPnl0) + toBigInt(position.pnl.netPnl1);
    const liquidity = toBigInt(position.liquidity.totalLiquidity);
    const activeLiquidity = toBigInt(position.liquidity.activeLiquidity);

    let lp = lpBuckets.get(address);

    if (!lp) {
      lp = {
        address,
        label,
        tier: rosterEntry?.tier ?? null,
        anchor: rosterEntry?.anchor ?? false,
        plannedPositions: rosterEntry?.plannedPositions ?? null,
        seededUsdBalance: rosterEntry ? toBigInt(rosterEntry.usdBalanceSeeded) : null,
        seededEthBalance: rosterEntry ? toBigInt(rosterEntry.ethBalanceSeeded) : null,
        positionCount: 0,
        activePositionCount: 0,
        poolCount: 0,
        totalLiquidity: 0n,
        totalFees: 0n,
        totalPnl: 0n,
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
        totalFees: 0n,
        totalPnl: 0n,
      };
      lp.groups.push(group);
    }

    const snapshot: PositionSnapshot = {
      address,
      label,
      positionId: position.positionId,
      active: position.summary.active,
      tickLower: position.tickLower,
      tickUpper: position.tickUpper,
      liquidity,
      activeLiquidity,
      fees,
      netPnl,
    };

    group.positions.push(snapshot);
    group.positionCount += 1;
    group.activePositionCount += position.summary.active ? 1 : 0;
    group.totalLiquidity += liquidity;
    group.totalFees += fees;
    group.totalPnl += netPnl;

    lp.positionCount += 1;
    lp.activePositionCount += position.summary.active ? 1 : 0;
    lp.totalLiquidity += liquidity;
    lp.totalFees += fees;
    lp.totalPnl += netPnl;
  }

  const lpSummaries = knownAddresses
    .map((entry) => lpBuckets.get(entry.address))
    .filter((value): value is LpSummary => Boolean(value))
    .map((lp) => ({
      ...lp,
      poolCount: lp.groups.length,
      groups: lp.groups.sort((left, right) => left.poolIndex - right.poolIndex),
    }));

  return {
    chainId: artifact.chainId,
    market: artifact.market,
    contracts: artifact.contracts,
    seedManifest: {
      description: artifact.seedManifest.description,
      poolCount: artifact.seedManifest.poolCount,
      lpCount: artifact.seedManifest.lpCount,
      positionCount: artifact.seedManifest.positionCount,
      swapCount: artifact.seedManifest.swapCount,
    },
    poolSummaries,
    lpSummaries,
    knownAddresses,
  };
}

function toBigInt(value: string | number) {
  return BigInt(value);
}

function shortenAddressLike(value: string) {
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}
