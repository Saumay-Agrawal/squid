// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
}
