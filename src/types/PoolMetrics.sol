// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct PoolLiquidity {
    uint128 totalLiquidity;
    uint128 activeLiquidity;
    uint128 peakActiveLiquidity;
    uint128 totalLiquidityAtPeakActive;
    uint32 liquidityUtilisationBps;
    uint32 peakLiquidityUtilisationBps;
}

struct PoolLPs {
    uint32 activeLpCount;
    uint32 lifetimeLpCount;
    uint32 lpRetentionBps;
}

struct PoolPositions {
    uint32 activePositionCount;
    uint32 totalPositionCount;
    uint32 activePositionPercentageBps;
}

struct PoolTradeFlow {
    uint32 totalSwapCount;
    uint32 zeroToOneSwapCount;
    uint32 oneToZeroSwapCount;
    uint32 flowSkewnessBps;
}

struct PoolSummary {
    bytes32 poolId;
    bool initialized;
    uint64 initializedBlock;
    uint64 initializedTimestamp;
    address token0;
    address token1;
    string token0Symbol;
    string token1Symbol;
    uint24 fee;
    int24 tickSpacing;
    uint160 initialSqrtPriceX96;
    PoolLiquidity liquidity;
    PoolLPs lps;
    PoolPositions positions;
    PoolTradeFlow tradeFlow;
}
