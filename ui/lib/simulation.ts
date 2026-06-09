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
  actions: Array<{ type: string; actor: string; details: string }>;
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
    positions: Array<{
      lp: string;
      positionId: string;
      tickLower: number;
      tickUpper: number;
      summary: {
        active: boolean;
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
    }>;
  };
};

export type PoolRow = {
  scenarioName: string;
  description: string;
  poolId: string;
  tokenPair: string;
  fee: number;
  tick: number;
  totalLiquidity: bigint;
  activeLiquidity: bigint;
  peakActiveLiquidity: bigint;
  lpCount: number;
  actionCount: number;
};

export type PositionRow = {
  scenarioName: string;
  lp: string;
  positionId: string;
  active: boolean;
  tickLower: number;
  tickUpper: number;
  totalLiquidity: bigint;
  feeAccumulated0: bigint;
  feeAccumulated1: bigint;
  netPnl0: bigint;
  netPnl1: bigint;
};

export type DashboardData = {
  chainId: number;
  scenarios: Array<{ name: string; description: string }>;
  poolRows: PoolRow[];
  positionRows: PositionRow[];
};

export function loadSimulationDashboard(): DashboardData {
  const artifactPath = path.resolve(process.cwd(), "..", "script", "output", "anvil-simulation.json");
  const raw = fs.readFileSync(artifactPath, "utf8");
  const artifact = JSON.parse(raw) as Artifact;

  const poolRows: PoolRow[] = artifact.scenarios.map((scenario) => ({
    scenarioName: scenario.name,
    description: scenario.description,
    poolId: scenario.finalState.poolSummary.poolId,
    tokenPair: `${scenario.finalState.poolSummary.token0Symbol}/${scenario.finalState.poolSummary.token1Symbol}`,
    fee: scenario.finalState.poolSummary.fee,
    tick: scenario.finalState.currentPoolState.tick,
    totalLiquidity: toBigInt(scenario.finalState.poolSummary.liquidity.totalLiquidity),
    activeLiquidity: toBigInt(scenario.finalState.poolSummary.liquidity.activeLiquidity),
    peakActiveLiquidity: toBigInt(scenario.finalState.poolSummary.liquidity.peakActiveLiquidity),
    lpCount: scenario.lpAddresses.length,
    actionCount: scenario.actions.length,
  }));

  const positionRows: PositionRow[] = artifact.scenarios.flatMap((scenario) =>
    scenario.finalState.positions.map((position) => ({
      scenarioName: scenario.name,
      lp: position.lp,
      positionId: position.positionId,
      active: position.summary.active,
      tickLower: position.tickLower,
      tickUpper: position.tickUpper,
      totalLiquidity: toBigInt(position.liquidity.totalLiquidity),
      feeAccumulated0: toBigInt(position.pnl.feeAccumulated0),
      feeAccumulated1: toBigInt(position.pnl.feeAccumulated1),
      netPnl0: toBigInt(position.pnl.netPnl0),
      netPnl1: toBigInt(position.pnl.netPnl1),
    }))
  );

  return {
    chainId: artifact.chainId,
    scenarios: artifact.scenarios.map((scenario) => ({
      name: scenario.name,
      description: scenario.description,
    })),
    poolRows,
    positionRows,
  };
}

function toBigInt(value: string | number) {
  return BigInt(value);
}
