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
    
    uint256 amount0Deposited;
    uint256 amount1Deposited;

    uint256 amount0DepositedUSD;
    uint256 amount1DepositedUSD;

}
