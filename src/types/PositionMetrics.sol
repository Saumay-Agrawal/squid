// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct PositionSummary {
    bytes32 positionId;
    bool initialized;
    bool active;
    uint64 createdBlock;
    uint64 createdTimestamp;
    uint64 updatedBlock;
    uint64 updatedTimestamp;
    address owner;
    bytes32 poolId;
    int24 tickLower;
    int24 tickUpper;
    bytes32 salt;
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
