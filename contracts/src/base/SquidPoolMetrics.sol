// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {PoolPriceMath} from "../libraries/PoolPriceMath.sol";
import {PoolMetrics} from "../types/PoolMetrics.sol";
import {PoolSummary} from "../types/PoolSummary.sol";

abstract contract SquidPoolMetrics {
    using PoolIdLibrary for PoolKey;

    error InvalidMetricLiquidityDelta();

    uint256 internal constant TWAP_WINDOW = 30 minutes;

    struct MetricPosition {
        bool active;
        bool seen;
        uint128 liquidity;
        uint256 amount0Deposited;
        uint256 amount1Deposited;
        uint256 openedAtTimestamp;
    }

    struct PriceObservation {
        uint256 timestamp;
        uint256 priceCumulativeX18;
        uint256 spotPriceX18;
    }

    struct PoolAgeState {
        uint256 activePositionAgeSum;
        uint256 lastAgeUpdateTimestamp;
    }

    mapping(PoolId poolId => PoolMetrics) internal poolMetrics;
    PoolId[] internal poolIds;
    mapping(PoolId poolId => bool seen) internal poolRegistrySeen;
    mapping(PoolId poolId => mapping(address owner => bool seen)) internal poolLpSeen;
    mapping(PoolId poolId => mapping(address owner => uint256 activePositionCount)) internal poolLpActivePositions;
    mapping(PoolId poolId => mapping(bytes32 positionId => MetricPosition)) internal metricPositions;
    mapping(PoolId poolId => PriceObservation[]) internal poolPriceObservations;
    mapping(PoolId poolId => uint256 observationStartIndex) internal poolPriceObservationStartIndex;
    mapping(PoolId poolId => PoolAgeState) internal poolAgeStates;

    function getPoolMetrics(PoolKey calldata key) external view returns (PoolMetrics memory) {
        PoolKey memory keyMemory = key;
        return poolMetrics[keyMemory.toId()];
    }

    function getPoolMetricsById(PoolId poolId) external view returns (PoolMetrics memory) {
        return poolMetrics[poolId];
    }

    function getPoolCount() external view returns (uint256) {
        return poolIds.length;
    }

    function getPoolIdAt(uint256 index) external view returns (PoolId) {
        return poolIds[index];
    }

    function getPoolIds(uint256 offset, uint256 limit) external view returns (PoolId[] memory ids) {
        uint256 count = poolIds.length;
        if (offset >= count || limit == 0) {
            return new PoolId[](0);
        }

        uint256 end = offset + limit;
        if (end > count) {
            end = count;
        }

        ids = new PoolId[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            ids[i - offset] = poolIds[i];
        }
    }

    function getPoolSummaryById(PoolId poolId) external view returns (PoolSummary memory) {
        return _poolSummary(poolId, poolMetrics[poolId]);
    }

    function getPoolSummaries(uint256 offset, uint256 limit) external view returns (PoolSummary[] memory summaries) {
        uint256 count = poolIds.length;
        if (offset >= count || limit == 0) {
            return new PoolSummary[](0);
        }

        uint256 end = offset + limit;
        if (end > count) {
            end = count;
        }

        summaries = new PoolSummary[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            PoolId poolId = poolIds[i];
            summaries[i - offset] = _poolSummary(poolId, poolMetrics[poolId]);
        }
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
            _initializePoolPriceMetrics(poolId, metrics, sqrtPriceX96);
            poolAgeStates[poolId].lastAgeUpdateTimestamp = block.timestamp;
        }

        if (!poolRegistrySeen[poolId]) {
            poolRegistrySeen[poolId] = true;
            poolIds.push(poolId);
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
            position.openedAtTimestamp = block.timestamp;
            metrics.lifetimePositionCount++;
        }

        _accruePoolAge(poolId, metrics);

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
            poolAgeStates[poolId].activePositionAgeSum += block.timestamp - position.openedAtTimestamp;
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
            poolAgeStates[poolId].activePositionAgeSum -= block.timestamp - position.openedAtTimestamp;
            metrics.activePositionCount--;
            poolLpActivePositions[poolId][owner]--;
            if (poolLpActivePositions[poolId][owner] == 0) {
                metrics.activeLpCount--;
            }
        }

        metrics.averageLpAge = metrics.activePositionCount == 0
            ? 0
            : poolAgeStates[poolId].activePositionAgeSum / metrics.activePositionCount;

        if (liveLiquidity >= oldLiquidity) {
            metrics.trackedLiquidity += liveLiquidity - oldLiquidity;
        } else {
            metrics.trackedLiquidity -= oldLiquidity - liveLiquidity;
        }
        position.liquidity = liveLiquidity;

        _updatePoolPriceMetrics(poolId);
    }

    function _trackPoolSwap(PoolKey calldata key, SwapParams calldata, BalanceDelta delta) internal {
        PoolKey memory keyMemory = key;
        PoolMetrics storage metrics = poolMetrics[keyMemory.toId()];

        metrics.swapCount++;
        metrics.volume0 += _absMetricInt128(delta.amount0());
        metrics.volume1 += _absMetricInt128(delta.amount1());
        _updatePoolPriceMetrics(keyMemory.toId());
    }

    function _trackPoolDonate(PoolKey calldata key, uint256 amount0, uint256 amount1) internal {
        PoolKey memory keyMemory = key;
        PoolMetrics storage metrics = poolMetrics[keyMemory.toId()];

        metrics.donateCount++;
        metrics.amount0Donated += amount0;
        metrics.amount1Donated += amount1;
        _updatePoolPriceMetrics(keyMemory.toId());
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

    function _poolSummary(PoolId poolId, PoolMetrics storage metrics) private view returns (PoolSummary memory) {
        return PoolSummary({
            poolId: poolId,
            currency0: metrics.currency0,
            currency1: metrics.currency1,
            fee: metrics.fee,
            tickSpacing: metrics.tickSpacing,
            initializedAtBlock: metrics.initializedAtBlock,
            activeLpCount: metrics.activeLpCount,
            activePositionCount: metrics.activePositionCount,
            trackedLiquidity: metrics.trackedLiquidity,
            swapCount: metrics.swapCount,
            spotPriceX18: metrics.spotPriceX18,
            twapPriceX18: metrics.twapPriceX18,
            volatilityBps: metrics.volatilityBps,
            averageLpAge: metrics.averageLpAge
        });
    }

    function _accruePoolAge(PoolId poolId, PoolMetrics storage metrics) private {
        PoolAgeState storage ageState = poolAgeStates[poolId];
        uint256 currentTimestamp = block.timestamp;
        uint256 elapsed = currentTimestamp - ageState.lastAgeUpdateTimestamp;

        if (elapsed > 0 && metrics.activePositionCount > 0) {
            ageState.activePositionAgeSum += elapsed * metrics.activePositionCount;
        }

        ageState.lastAgeUpdateTimestamp = currentTimestamp;
    }

    function _initializePoolPriceMetrics(PoolId poolId, PoolMetrics storage metrics, uint160 sqrtPriceX96) private {
        uint256 spotPriceX18 = PoolPriceMath.spotPriceX18(sqrtPriceX96);
        uint256 currentTimestamp = block.timestamp;

        metrics.spotPriceX18 = spotPriceX18;
        metrics.twapPriceX18 = spotPriceX18;
        metrics.lastPriceTimestamp = currentTimestamp;

        poolPriceObservations[poolId].push(
            PriceObservation({timestamp: currentTimestamp, priceCumulativeX18: 0, spotPriceX18: spotPriceX18})
        );
    }

    function _updatePoolPriceMetrics(PoolId poolId) private {
        PoolMetrics storage metrics = poolMetrics[poolId];
        if (!metrics.initialized) return;

        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(_poolManager(), poolId);

        uint256 currentTimestamp = block.timestamp;
        uint256 elapsed = currentTimestamp - metrics.lastPriceTimestamp;
        if (elapsed > 0) {
            metrics.priceCumulativeX18 += metrics.spotPriceX18 * elapsed;
        }

        uint256 spotPriceX18 = PoolPriceMath.spotPriceX18(sqrtPriceX96);
        metrics.lastPriceTimestamp = currentTimestamp;

        _upsertPriceObservation(poolId, currentTimestamp, metrics.priceCumulativeX18, spotPriceX18);

        uint256 twapPriceX18 = _twapPriceX18(poolId, currentTimestamp, metrics.priceCumulativeX18, spotPriceX18);

        metrics.spotPriceX18 = spotPriceX18;
        metrics.twapPriceX18 = twapPriceX18;
        metrics.volatilityBps = PoolPriceMath.volatilityBps(spotPriceX18, twapPriceX18);

        _prunePriceObservations(poolId, currentTimestamp);
    }

    function _upsertPriceObservation(
        PoolId poolId,
        uint256 currentTimestamp,
        uint256 priceCumulativeX18,
        uint256 spotPriceX18
    ) private {
        PriceObservation[] storage observations = poolPriceObservations[poolId];
        uint256 observationCount = observations.length;

        if (observationCount > 0 && observations[observationCount - 1].timestamp == currentTimestamp) {
            PriceObservation storage observation = observations[observationCount - 1];
            observation.priceCumulativeX18 = priceCumulativeX18;
            observation.spotPriceX18 = spotPriceX18;
            return;
        }

        observations.push(
            PriceObservation({
                timestamp: currentTimestamp,
                priceCumulativeX18: priceCumulativeX18,
                spotPriceX18: spotPriceX18
            })
        );
    }

    function _twapPriceX18(PoolId poolId, uint256 currentTimestamp, uint256 currentCumulativeX18, uint256 spotPriceX18)
        private
        view
        returns (uint256)
    {
        PriceObservation[] storage observations = poolPriceObservations[poolId];
        uint256 startIndex = poolPriceObservationStartIndex[poolId];
        if (observations.length == 0 || startIndex >= observations.length) {
            return spotPriceX18;
        }

        uint256 windowStart = currentTimestamp > TWAP_WINDOW ? currentTimestamp - TWAP_WINDOW : 0;
        uint256 twapStartTimestamp = observations[startIndex].timestamp;
        uint256 startCumulativeX18 = observations[startIndex].priceCumulativeX18;

        if (windowStart > twapStartTimestamp) {
            (twapStartTimestamp, startCumulativeX18) = _cumulativePriceAt(poolId, windowStart);
        }

        uint256 twapDuration = currentTimestamp - twapStartTimestamp;
        if (twapDuration == 0) {
            return spotPriceX18;
        }

        return (currentCumulativeX18 - startCumulativeX18) / twapDuration;
    }

    function _cumulativePriceAt(PoolId poolId, uint256 targetTimestamp) private view returns (uint256, uint256) {
        PriceObservation[] storage observations = poolPriceObservations[poolId];
        uint256 startIndex = poolPriceObservationStartIndex[poolId];
        uint256 observationCount = observations.length;

        if (observationCount == 0 || startIndex >= observationCount) {
            return (targetTimestamp, 0);
        }

        PriceObservation storage observation = observations[startIndex];
        if (targetTimestamp <= observation.timestamp) {
            return (observation.timestamp, observation.priceCumulativeX18);
        }

        for (uint256 i = startIndex; i < observationCount - 1; i++) {
            PriceObservation storage currentObservation = observations[i];
            PriceObservation storage nextObservation = observations[i + 1];

            if (targetTimestamp < nextObservation.timestamp) {
                return (
                    targetTimestamp,
                    currentObservation.priceCumulativeX18
                        + currentObservation.spotPriceX18 * (targetTimestamp - currentObservation.timestamp)
                );
            }
        }

        PriceObservation storage lastObservation = observations[observationCount - 1];
        return (
            targetTimestamp,
            lastObservation.priceCumulativeX18 + lastObservation.spotPriceX18 * (targetTimestamp - lastObservation.timestamp)
        );
    }

    function _prunePriceObservations(PoolId poolId, uint256 currentTimestamp) private {
        uint256 windowStart = currentTimestamp > TWAP_WINDOW ? currentTimestamp - TWAP_WINDOW : 0;
        PriceObservation[] storage observations = poolPriceObservations[poolId];
        uint256 observationCount = observations.length;

        if (observationCount < 2) return;

        uint256 startIndex = poolPriceObservationStartIndex[poolId];
        while (startIndex + 1 < observationCount && observations[startIndex + 1].timestamp <= windowStart) {
            startIndex++;
        }

        poolPriceObservationStartIndex[poolId] = startIndex;
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
