// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

import {PoolSummary} from "../types/PoolMetrics.sol";
import {TokenSymbolResolver} from "../libraries/TokenSymbolResolver.sol";

abstract contract SquidPoolMetrics {
    using PoolIdLibrary for PoolKey;

    error PoolAlreadyRegistered(bytes32 poolId);
    error PoolNotRegistered(bytes32 poolId);
    error TwapNotSupported();

    mapping(PoolId poolId => PoolSummary) internal poolSummariesById;

    function getPoolSummary(PoolId poolId) external view returns (PoolSummary memory summary) {
        summary = poolSummariesById[poolId];
        if (!summary.initialized) revert PoolNotRegistered(PoolId.unwrap(poolId));
    }

    function getCurrentPoolState(PoolId poolId)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
    {
        _requirePoolRegistered(poolId);
        return StateLibrary.getSlot0(_poolManager(), poolId);
    }

    function getCurrentSqrtPriceX96(PoolId poolId) external view returns (uint160 sqrtPriceX96) {
        _requirePoolRegistered(poolId);
        (sqrtPriceX96,,,) = StateLibrary.getSlot0(_poolManager(), poolId);
    }

    function getTwapSqrtPriceX96(PoolId, uint32) external pure returns (uint160) {
        revert TwapNotSupported();
    }

    function _registerPoolSummary(PoolKey calldata key, uint160 sqrtPriceX96) internal {
        PoolId poolId = key.toId();
        PoolSummary storage summary = poolSummariesById[poolId];
        if (summary.initialized) revert PoolAlreadyRegistered(PoolId.unwrap(poolId));

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        summary.poolId = PoolId.unwrap(poolId);
        summary.initialized = true;
        summary.initializedBlock = uint64(block.number);
        summary.initializedTimestamp = uint64(block.timestamp);
        summary.token0 = token0;
        summary.token1 = token1;
        summary.token0Symbol = TokenSymbolResolver.resolve(token0);
        summary.token1Symbol = TokenSymbolResolver.resolve(token1);
        summary.fee = key.fee;
        summary.tickSpacing = key.tickSpacing;
        summary.initialSqrtPriceX96 = sqrtPriceX96;
    }

    function _requirePoolRegistered(PoolId poolId) internal view {
        if (!poolSummariesById[poolId].initialized) revert PoolNotRegistered(PoolId.unwrap(poolId));
    }

    function _poolManager() internal view virtual returns (IPoolManager);
}
