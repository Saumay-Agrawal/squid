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
