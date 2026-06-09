import fs from "node:fs";
import path from "node:path";

type Artifact = {
  chainId: number;
  scenarios: ArtifactScenario[];
};

type ArtifactScenario = {
  name: string;
  description: string;
  lpAddresses: string[];
  finalState: {
    poolSummary: {
      poolId: string;
      token0Symbol: string;
      token1Symbol: string;
      fee: number;
      liquidity: {
        totalLiquidity: number | string;
        activeLiquidity: number | string;
        peakActiveLiquidity: number | string;
      };
    };
    currentPoolState: {
      tick: number;
    };
    positions: ArtifactPosition[];
  };
};

type ArtifactPosition = {
  lp: string;
  positionId: string;
  tickLower: number;
  tickUpper: number;
  summary: {
    active: boolean;
    poolId: string;
  };
  liquidity: {
    totalLiquidity: number | string;
  };
  pnl: {
    feeAccumulated0: number | string;
    feeAccumulated1: number | string;
    netPnl0: number | string;
    netPnl1: number | string;
  };
};

export type PositionSnapshot = {
  address: string;
  label: string;
  positionId: string;
  active: boolean;
  tickLower: number;
  tickUpper: number;
  liquidity: bigint;
  fees: bigint;
  netPnl: bigint;
};

export type PositionGroup = {
  poolId: string;
  poolLabel: string;
  scenarioName: string;
  positions: PositionSnapshot[];
  positionCount: number;
  activePositionCount: number;
  totalLiquidity: bigint;
  totalFees: bigint;
  totalPnl: bigint;
};

export type PoolSummary = {
  poolId: string;
  scenarioName: string;
  description: string;
  tokenPair: string;
  fee: number;
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
  poolSummaries: PoolSummary[];
  lpSummaries: LpSummary[];
  knownAddresses: Array<{ address: string; label: string }>;
};

export function loadSquidDashboard(): SquidDashboardData {
  const artifactPath = path.resolve(process.cwd(), "..", "script", "output", "anvil-simulation.json");
  const raw = fs.readFileSync(artifactPath, "utf8");
  const artifact = JSON.parse(raw) as Artifact;

  const addressLabels = new Map<string, string>();
  const orderedAddresses: string[] = [];

  for (const scenario of artifact.scenarios) {
    for (const address of scenario.lpAddresses) {
      if (!addressLabels.has(address)) {
        orderedAddresses.push(address);
        addressLabels.set(address, `LP ${orderedAddresses.length}`);
      }
    }
    for (const position of scenario.finalState.positions) {
      if (!addressLabels.has(position.lp)) {
        orderedAddresses.push(position.lp);
        addressLabels.set(position.lp, `LP ${orderedAddresses.length}`);
      }
    }
  }

  const poolSummaries: PoolSummary[] = artifact.scenarios.map((scenario) => {
    const positions = scenario.finalState.positions;

    return {
      poolId: scenario.finalState.poolSummary.poolId,
      scenarioName: scenario.name,
      description: scenario.description,
      tokenPair: `${scenario.finalState.poolSummary.token0Symbol}/${scenario.finalState.poolSummary.token1Symbol}`,
      fee: scenario.finalState.poolSummary.fee,
      tick: scenario.finalState.currentPoolState.tick,
      totalLiquidity: toBigInt(scenario.finalState.poolSummary.liquidity.totalLiquidity),
      activeLiquidity: toBigInt(scenario.finalState.poolSummary.liquidity.activeLiquidity),
      peakActiveLiquidity: toBigInt(scenario.finalState.poolSummary.liquidity.peakActiveLiquidity),
      lpCount: new Set(positions.map((position) => position.lp)).size,
      positionCount: positions.length,
      activePositionCount: positions.filter((position) => position.summary.active).length,
    };
  });

  const lpBuckets = new Map<string, LpSummary>();

  for (const scenario of artifact.scenarios) {
    for (const position of scenario.finalState.positions) {
      const address = position.lp;
      const label = addressLabels.get(address) ?? address;
      const poolLabel = `${scenario.finalState.poolSummary.token0Symbol}/${scenario.finalState.poolSummary.token1Symbol}`;
      const fees = toBigInt(position.pnl.feeAccumulated0) + toBigInt(position.pnl.feeAccumulated1);
      const netPnl = toBigInt(position.pnl.netPnl0) + toBigInt(position.pnl.netPnl1);
      const liquidity = toBigInt(position.liquidity.totalLiquidity);

      let lp = lpBuckets.get(address);

      if (!lp) {
        lp = {
          address,
          label,
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
          poolLabel,
          scenarioName: scenario.name,
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
  }

  const lpSummaries = orderedAddresses
    .map((address) => lpBuckets.get(address))
    .filter((value): value is LpSummary => Boolean(value))
    .map((lp) => ({
      ...lp,
      poolCount: lp.groups.length,
      groups: lp.groups.sort((left, right) => left.poolLabel.localeCompare(right.poolLabel)),
    }));

  return {
    chainId: artifact.chainId,
    poolSummaries,
    lpSummaries,
    knownAddresses: orderedAddresses.map((address) => ({
      address,
      label: addressLabels.get(address) ?? address,
    })),
  };
}

function toBigInt(value: string | number) {
  return BigInt(value);
}
