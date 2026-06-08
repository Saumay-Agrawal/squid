// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct PositionSummary {
    bytes32 positionId;
    bool initialized;
    bool active;
    uint64 age;
    uint64 createdBlock;
    uint64 createdTimestamp;
    uint64 updatedBlock;
    uint64 updatedTimestamp;
    address owner;
    address coreOwner;
    bytes32 poolId;
    int24 tickLower;
    int24 tickUpper;
    bytes32 salt;
}

struct PositionLiquidity {
    uint128 totalLiquidity;
    uint128 activeLiquidity;
    uint256 activeSwapVolume0;
    uint256 activeSwapVolume1;
    uint256 lifetimeSwapVolume0;
    uint256 lifetimeSwapVolume1;
}

struct PositionPnLState {
    uint256 principalAmount0;
    uint256 principalAmount1;
    uint256 realizedFeeAmount0;
    uint256 realizedFeeAmount1;
}

struct PositionPnL {
    uint256 principalAmount0;
    uint256 principalAmount1;
    uint256 currentAmount0;
    uint256 currentAmount1;
    uint256 feeAccumulated0;
    uint256 feeAccumulated1;
    int256 netPnl0;
    int256 netPnl1;
}
