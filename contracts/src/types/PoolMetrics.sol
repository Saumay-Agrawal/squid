// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct PoolMetrics {
    bool initialized;
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    uint160 initialSqrtPriceX96;
    int24 initialTick;
    uint256 initializedAtBlock;
    uint256 activeLpCount;
    uint256 lifetimeLpCount;
    uint256 activePositionCount;
    uint256 lifetimePositionCount;
    uint256 amount0Deposited;
    uint256 amount1Deposited;
    uint128 trackedLiquidity;
    uint256 addLiquidityCount;
    uint256 removeLiquidityCount;
    uint256 swapCount;
    uint256 donateCount;
    uint256 volume0;
    uint256 volume1;
    uint256 amount0Donated;
    uint256 amount1Donated;
    uint256 spotPriceX18;
    uint256 twapPriceX18;
    uint256 volatilityBps;
    uint256 priceCumulativeX18;
    uint256 lastPriceTimestamp;
    uint256 averageLpAge;
}
