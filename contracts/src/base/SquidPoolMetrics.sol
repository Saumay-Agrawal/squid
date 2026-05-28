// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {PoolMetrics} from "../types/PoolMetrics.sol";

abstract contract SquidPoolMetrics {
    using PoolIdLibrary for PoolKey;

    error InvalidMetricLiquidityDelta();

    struct MetricPosition {
        bool active;
        bool seen;
        uint128 liquidity;
        uint256 amount0Deposited;
        uint256 amount1Deposited;
    }

    mapping(PoolId poolId => PoolMetrics) internal poolMetrics;
    mapping(PoolId poolId => mapping(address owner => bool seen)) internal poolLpSeen;
    mapping(PoolId poolId => mapping(address owner => uint256 activePositionCount)) internal poolLpActivePositions;
    mapping(PoolId poolId => mapping(bytes32 positionId => MetricPosition)) internal metricPositions;

    function getPoolMetrics(PoolKey calldata key) external view returns (PoolMetrics memory) {
        PoolKey memory keyMemory = key;
        return poolMetrics[keyMemory.toId()];
    }

    function getPoolMetricsById(PoolId poolId) external view returns (PoolMetrics memory) {
        return poolMetrics[poolId];
    }

    function _trackPoolInitialized(PoolKey calldata key, uint160 sqrtPriceX96, int24 tick) internal {
        PoolKey memory keyMemory = key;
        PoolId poolId = keyMemory.toId();
        PoolMetrics storage metrics = poolMetrics[poolId];

        if (!metrics.initialized) {
            metrics.initialized = true;
            metrics.currency0 = Currency.unwrap(key.currency0);
            metrics.currency1 = Currency.unwrap(key.currency1);
            metrics.fee = key.fee;
            metrics.tickSpacing = key.tickSpacing;
            metrics.initialSqrtPriceX96 = sqrtPriceX96;
            metrics.initialTick = tick;
            metrics.initializedAtBlock = block.number;
        }
    }

    function _trackPoolLiquidityChange(
        address owner,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta
    ) internal {
        if (params.liquidityDelta == 0) return;

        PoolKey memory keyMemory = key;
        PoolId poolId = keyMemory.toId();
        bytes32 positionId = _metricPositionId(owner, poolId, params.tickLower, params.tickUpper, params.salt);
        PoolMetrics storage metrics = poolMetrics[poolId];
        MetricPosition storage position = metricPositions[poolId][positionId];

        (uint128 liveLiquidity,,) =
            StateLibrary.getPositionInfo(_poolManager(), poolId, owner, params.tickLower, params.tickUpper, params.salt);
        uint128 oldLiquidity = position.liquidity;

        if (!position.seen) {
            position.seen = true;
            metrics.lifetimePositionCount++;
        }

        if (params.liquidityDelta > 0) {
            _trackPoolLiquidityIncrease(metrics, position, delta);
            metrics.addLiquidityCount++;
        } else {
            _trackPoolLiquidityDecrease(metrics, position, params.liquidityDelta, oldLiquidity, liveLiquidity);
            metrics.removeLiquidityCount++;
        }

        if (!position.active && liveLiquidity > 0) {
            position.active = true;
            metrics.activePositionCount++;
            if (poolLpActivePositions[poolId][owner] == 0) {
                metrics.activeLpCount++;
            }
            poolLpActivePositions[poolId][owner]++;

            if (!poolLpSeen[poolId][owner]) {
                poolLpSeen[poolId][owner] = true;
                metrics.lifetimeLpCount++;
            }
        } else if (position.active && liveLiquidity == 0) {
            position.active = false;
            metrics.activePositionCount--;
            poolLpActivePositions[poolId][owner]--;
            if (poolLpActivePositions[poolId][owner] == 0) {
                metrics.activeLpCount--;
            }
        }

        if (liveLiquidity >= oldLiquidity) {
            metrics.trackedLiquidity += liveLiquidity - oldLiquidity;
        } else {
            metrics.trackedLiquidity -= oldLiquidity - liveLiquidity;
        }
        position.liquidity = liveLiquidity;
    }

    function _trackPoolSwap(PoolKey calldata key, SwapParams calldata, BalanceDelta delta) internal {
        PoolKey memory keyMemory = key;
        PoolMetrics storage metrics = poolMetrics[keyMemory.toId()];

        metrics.swapCount++;
        metrics.volume0 += _absMetricInt128(delta.amount0());
        metrics.volume1 += _absMetricInt128(delta.amount1());
    }

    function _trackPoolDonate(PoolKey calldata key, uint256 amount0, uint256 amount1) internal {
        PoolKey memory keyMemory = key;
        PoolMetrics storage metrics = poolMetrics[keyMemory.toId()];

        metrics.donateCount++;
        metrics.amount0Donated += amount0;
        metrics.amount1Donated += amount1;
    }

    function _poolManager() internal view virtual returns (IPoolManager);

    function _trackPoolLiquidityIncrease(
        PoolMetrics storage metrics,
        MetricPosition storage position,
        BalanceDelta delta
    ) private {
        uint256 amount0 = _absMetricInt128(delta.amount0());
        uint256 amount1 = _absMetricInt128(delta.amount1());

        position.amount0Deposited += amount0;
        position.amount1Deposited += amount1;
        metrics.amount0Deposited += amount0;
        metrics.amount1Deposited += amount1;
    }

    function _trackPoolLiquidityDecrease(
        PoolMetrics storage metrics,
        MetricPosition storage position,
        int256 liquidityDelta,
        uint128 oldLiquidity,
        uint128 liveLiquidity
    ) private {
        uint128 removedLiquidity = _absMetricInt256ToUint128(liquidityDelta);
        if (removedLiquidity > oldLiquidity) revert InvalidMetricLiquidityDelta();

        if (oldLiquidity > 0) {
            uint256 amount0Removed = (position.amount0Deposited * removedLiquidity) / oldLiquidity;
            uint256 amount1Removed = (position.amount1Deposited * removedLiquidity) / oldLiquidity;

            position.amount0Deposited -= amount0Removed;
            position.amount1Deposited -= amount1Removed;
            metrics.amount0Deposited -= amount0Removed;
            metrics.amount1Deposited -= amount1Removed;
        }

        if (liveLiquidity == 0) {
            metrics.amount0Deposited -= position.amount0Deposited;
            metrics.amount1Deposited -= position.amount1Deposited;
            position.amount0Deposited = 0;
            position.amount1Deposited = 0;
        }
    }

    function _absMetricInt128(int128 x) private pure returns (uint256) {
        return x < 0 ? uint256(uint128(-x)) : uint256(uint128(x));
    }

    function _absMetricInt256ToUint128(int256 x) private pure returns (uint128) {
        if (x == type(int256).min) revert InvalidMetricLiquidityDelta();
        uint256 absValue = x < 0 ? uint256(-x) : uint256(x);
        if (absValue > type(uint128).max) revert InvalidMetricLiquidityDelta();
        return uint128(absValue);
    }

    function _metricPositionId(address owner, PoolId poolId, int24 tickLower, int24 tickUpper, bytes32 salt)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(owner, poolId, tickLower, tickUpper, salt));
    }
}
