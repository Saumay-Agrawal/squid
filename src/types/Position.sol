// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

struct Position {
    address owner;
    PoolId poolId;
    PoolKey poolKey;
    address token0;
    address token1;
    int24 tickLower;
    int24 tickUpper;
    bytes32 salt;
    uint128 liquidity;
    uint256 amount0Deposited;
    uint256 amount1Deposited;
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
    uint256 fee0Accrued;
    uint256 fee1Accrued;
    bool active;
}
