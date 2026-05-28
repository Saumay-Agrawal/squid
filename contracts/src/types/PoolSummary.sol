// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

struct PoolSummary {
    PoolId poolId;
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    uint256 initializedAtBlock;
    uint256 activeLpCount;
    uint256 activePositionCount;
    uint128 trackedLiquidity;
    uint256 swapCount;
}
