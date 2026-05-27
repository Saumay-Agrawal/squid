// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolId} from "v4-core/types/PoolId.sol";

struct LpProfile {
    bool exists;
    uint256 firstActionBlock;
    uint256 lastActionBlock;
    uint256 activePoolCount;
    uint256 lifetimePoolCount;
    uint256 activePositionCount;
    uint256 lifetimePositionCount;
    uint256 addLiquidityCount;
    uint256 removeLiquidityCount;
}

struct LpPoolProfile {
    bool exists;
    PoolId poolId;
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    uint256 firstActionBlock;
    uint256 lastActionBlock;
    uint256 activePositionCount;
    uint256 lifetimePositionCount;
    uint256 amount0Deposited;
    uint256 amount1Deposited;
    uint256 amount0Removed;
    uint256 amount1Removed;
    uint256 totalAmount0Deposited;
    uint256 totalAmount1Deposited;
    uint128 trackedLiquidity;
    uint256 addLiquidityCount;
    uint256 removeLiquidityCount;
}

struct LpPositionProfile {
    bool exists;
    address owner;
    PoolId poolId;
    address currency0;
    address currency1;
    int24 tickLower;
    int24 tickUpper;
    bytes32 salt;
    bool active;
    uint128 liquidity;
    uint256 amount0Deposited;
    uint256 amount1Deposited;
    uint256 amount0Removed;
    uint256 amount1Removed;
    uint256 totalAmount0Deposited;
    uint256 totalAmount1Deposited;
    uint256 addLiquidityCount;
    uint256 removeLiquidityCount;
    uint256 openedAtBlock;
    uint256 lastActionBlock;
    uint256 closedAtBlock;
}
