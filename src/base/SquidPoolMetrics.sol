// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PoolAmounts, PoolLiquidity, PoolLPs, PoolPositions, PoolSummary, PoolTradeFlow} from "../types/PoolMetrics.sol";
import {TokenSymbolResolver} from "../libraries/TokenSymbolResolver.sol";

abstract contract SquidPoolMetrics {
    using PoolIdLibrary for PoolKey;

    uint32 internal constant BPS_DENOMINATOR = 10_000;
    uint32 internal constant ACTIVE_POSITION_BREACH_THRESHOLD_BPS = 8_000;
    uint32 internal constant ACTIVE_POSITION_RECOVERY_THRESHOLD_BPS = 8_500;

    error PoolAlreadyRegistered(bytes32 poolId);
    error PoolNotRegistered(bytes32 poolId);
    error TwapNotSupported();
    error LiquidityDeltaOverflow();

    mapping(PoolId poolId => PoolSummary) internal poolSummariesById;
    mapping(PoolId poolId => bool initialized) internal poolAmountsInitializedById;
    mapping(PoolId poolId => mapping(address owner => uint32 count)) internal activePositionCountByPoolAndOwner;
    mapping(PoolId poolId => mapping(address owner => bool counted)) internal hasCountedOwnerForPool;
    mapping(PoolId poolId => bool halted) internal addLiquidityHaltedByPool;
    mapping(PoolId poolId => bool breached) internal activePositionThresholdBreachedByPool;

    event PoolActivePositionThresholdBreached(
        bytes32 poolId, uint32 activePositionCount, uint32 totalPositionCount, uint32 activePositionPercentageBps
    );
    event PoolActivePositionThresholdRecovered(
        bytes32 poolId, uint32 activePositionCount, uint32 totalPositionCount, uint32 activePositionPercentageBps
    );
    event PoolLiquidityAddsHalted(bytes32 poolId);
    event PoolLiquidityAddsResumed(bytes32 poolId);

    function getPoolSummary(PoolId poolId) external view returns (PoolSummary memory summary) {
        summary = poolSummariesById[poolId];
        if (!summary.initialized) revert PoolNotRegistered(PoolId.unwrap(poolId));
    }

    function isPoolAddLiquidityHalted(PoolId poolId) external view returns (bool halted) {
        _requirePoolRegistered(poolId);
        halted = addLiquidityHaltedByPool[poolId];
    }

    function isPoolActivePositionThresholdBreached(PoolId poolId) external view returns (bool breached) {
        _requirePoolRegistered(poolId);
        breached = activePositionThresholdBreachedByPool[poolId];
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
        _syncPoolLiquidity(summary, poolId);
    }

    function _recordPoolLiquidityAdded(
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued
    ) internal {
        PoolId poolId = key.toId();
        PoolSummary storage summary = poolSummariesById[poolId];
        _requirePoolRegistered(poolId);

        _applyPoolDelta(summary.amounts, poolId, delta);
        _recordPoolFeesAccrued(summary.amounts, feesAccrued);
        summary.liquidity.totalLiquidity += _liquidityDeltaToUint128(params.liquidityDelta);
        _syncPoolLiquidity(summary, poolId);
    }

    function _recordPoolLiquidityRemoved(
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued
    ) internal {
        PoolId poolId = key.toId();
        PoolSummary storage summary = poolSummariesById[poolId];
        _requirePoolRegistered(poolId);

        _applyPoolDelta(summary.amounts, poolId, delta);
        _recordPoolFeesAccrued(summary.amounts, feesAccrued);
        summary.liquidity.totalLiquidity -= _liquidityDeltaToUint128(-params.liquidityDelta);
        _syncPoolLiquidity(summary, poolId);
    }

    function _recordPoolSwap(PoolKey calldata key, SwapParams calldata params, BalanceDelta delta) internal {
        PoolId poolId = key.toId();
        PoolSummary storage summary = poolSummariesById[poolId];
        _requirePoolRegistered(poolId);

        _applyPoolDelta(summary.amounts, poolId, delta);
        PoolTradeFlow storage tradeFlow = summary.tradeFlow;
        tradeFlow.totalSwapCount += 1;

        if (params.zeroForOne) {
            tradeFlow.zeroToOneSwapCount += 1;
        } else {
            tradeFlow.oneToZeroSwapCount += 1;
        }

        tradeFlow.flowSkewnessBps =
            _calculateFlowSkewnessBps(tradeFlow.zeroToOneSwapCount, tradeFlow.oneToZeroSwapCount);

        _syncPoolLiquidity(summary, poolId);
    }

    function _syncPoolLiquidity(PoolSummary storage summary, PoolId poolId) private {
        PoolLiquidity storage liquidity = summary.liquidity;
        liquidity.activeLiquidity = StateLibrary.getLiquidity(_poolManager(), poolId);
        liquidity.liquidityUtilisationBps =
            _calculateUtilisationBps(liquidity.activeLiquidity, liquidity.totalLiquidity);

        if (liquidity.activeLiquidity > liquidity.peakActiveLiquidity) {
            liquidity.peakActiveLiquidity = liquidity.activeLiquidity;
            liquidity.totalLiquidityAtPeakActive = liquidity.totalLiquidity;
        }

        liquidity.peakLiquidityUtilisationBps =
            _calculateUtilisationBps(liquidity.peakActiveLiquidity, liquidity.totalLiquidityAtPeakActive);
    }

    function _applyPoolDelta(PoolAmounts storage amounts, PoolId poolId, BalanceDelta delta) private {
        amounts.currentToken0Amount += _poolNegativeAmount0(delta);
        amounts.currentToken1Amount += _poolNegativeAmount1(delta);
        amounts.currentToken0Amount -= _poolPositiveAmount0(delta);
        amounts.currentToken1Amount -= _poolPositiveAmount1(delta);

        if (!poolAmountsInitializedById[poolId] && (amounts.currentToken0Amount > 0 || amounts.currentToken1Amount > 0)) {
            poolAmountsInitializedById[poolId] = true;
            amounts.initialToken0Amount = amounts.currentToken0Amount;
            amounts.initialToken1Amount = amounts.currentToken1Amount;
        }
    }

    function _recordPoolFeesAccrued(PoolAmounts storage amounts, BalanceDelta feesAccrued) private {
        amounts.totalFeeAccruedToken0 += _poolPositiveAmount0(feesAccrued);
        amounts.totalFeeAccruedToken1 += _poolPositiveAmount1(feesAccrued);
    }

    function _recordPoolLpPositionLiquidityChange(
        PoolId poolId,
        address owner,
        uint128 liquidityBefore,
        uint128 liquidityAfter
    ) internal virtual {
        if (liquidityBefore == liquidityAfter) return;

        bool wasActive = liquidityBefore > 0;
        bool isActive = liquidityAfter > 0;

        if (wasActive == isActive) return;

        PoolLPs storage lps = poolSummariesById[poolId].lps;

        if (isActive) {
            uint32 activePositionCount = activePositionCountByPoolAndOwner[poolId][owner];
            if (activePositionCount == 0) {
                lps.activeLpCount += 1;

                if (!hasCountedOwnerForPool[poolId][owner]) {
                    hasCountedOwnerForPool[poolId][owner] = true;
                    lps.lifetimeLpCount += 1;
                }
            }

            activePositionCountByPoolAndOwner[poolId][owner] = activePositionCount + 1;
        } else {
            uint32 activePositionCount = activePositionCountByPoolAndOwner[poolId][owner];
            activePositionCount -= 1;
            activePositionCountByPoolAndOwner[poolId][owner] = activePositionCount;

            if (activePositionCount == 0) {
                lps.activeLpCount -= 1;
            }
        }

        lps.lpRetentionBps = _calculateCountBps(lps.activeLpCount, lps.lifetimeLpCount);
    }

    function _recordPoolPositionCreated(PoolId poolId) internal virtual {
        PoolPositions storage positions = poolSummariesById[poolId].positions;
        positions.totalPositionCount += 1;
        positions.activePositionPercentageBps =
            _calculateCountBps(positions.activePositionCount, positions.totalPositionCount);
        _syncActivePositionThresholdState(poolId, positions);
    }

    function _recordPoolPositionActivityChange(PoolId poolId, bool wasActive, bool isActive) internal virtual {
        if (wasActive == isActive) return;

        PoolPositions storage positions = poolSummariesById[poolId].positions;

        if (isActive) {
            positions.activePositionCount += 1;
        } else {
            positions.activePositionCount -= 1;
        }

        positions.activePositionPercentageBps =
            _calculateCountBps(positions.activePositionCount, positions.totalPositionCount);
        _syncActivePositionThresholdState(poolId, positions);
    }

    function _isPoolAddLiquidityHalted(PoolId poolId) internal view returns (bool halted) {
        halted = addLiquidityHaltedByPool[poolId];
    }

    function _setPoolAddLiquidityHalted(PoolId poolId, bool halted) internal {
        if (addLiquidityHaltedByPool[poolId] == halted) return;

        addLiquidityHaltedByPool[poolId] = halted;

        if (halted) {
            emit PoolLiquidityAddsHalted(PoolId.unwrap(poolId));
        } else {
            emit PoolLiquidityAddsResumed(PoolId.unwrap(poolId));
        }
    }

    function _liquidityDeltaToUint128(int256 liquidityDelta) private pure returns (uint128 liquidity) {
        if (liquidityDelta < 0 || uint256(liquidityDelta) > type(uint128).max) revert LiquidityDeltaOverflow();
        liquidity = uint128(uint256(liquidityDelta));
    }

    function _calculateUtilisationBps(uint128 numerator, uint128 denominator) private pure returns (uint32) {
        if (denominator == 0 || numerator == 0) return 0;
        return uint32((uint256(numerator) * BPS_DENOMINATOR) / uint256(denominator));
    }

    function _calculateCountBps(uint32 numerator, uint32 denominator) private pure returns (uint32) {
        if (denominator == 0 || numerator == 0) return 0;
        return uint32((uint256(numerator) * BPS_DENOMINATOR) / uint256(denominator));
    }

    function _calculateFlowSkewnessBps(uint32 zeroToOneSwapCount, uint32 oneToZeroSwapCount)
        private
        pure
        returns (uint32)
    {
        if (zeroToOneSwapCount == 0 && oneToZeroSwapCount == 0) return 0;
        if (zeroToOneSwapCount == 0 || oneToZeroSwapCount == 0) return BPS_DENOMINATOR;

        uint32 maxSwapCount = zeroToOneSwapCount >= oneToZeroSwapCount ? zeroToOneSwapCount : oneToZeroSwapCount;
        uint32 minSwapCount = zeroToOneSwapCount < oneToZeroSwapCount ? zeroToOneSwapCount : oneToZeroSwapCount;
        uint256 ratioBps = (uint256(maxSwapCount) * BPS_DENOMINATOR) / uint256(minSwapCount);

        return uint32(ratioBps - BPS_DENOMINATOR);
    }

    function _requirePoolRegistered(PoolId poolId) internal view {
        if (!poolSummariesById[poolId].initialized) revert PoolNotRegistered(PoolId.unwrap(poolId));
    }

    function _poolPositiveAmount0(BalanceDelta delta) private pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount0(delta);
        if (value > 0) amount = uint128(value);
    }

    function _poolPositiveAmount1(BalanceDelta delta) private pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount1(delta);
        if (value > 0) amount = uint128(value);
    }

    function _poolNegativeAmount0(BalanceDelta delta) private pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount0(delta);
        if (value < 0) amount = uint256(uint128(-value));
    }

    function _poolNegativeAmount1(BalanceDelta delta) private pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount1(delta);
        if (value < 0) amount = uint256(uint128(-value));
    }

    function _syncActivePositionThresholdState(PoolId poolId, PoolPositions storage positions) private {
        bool breached = activePositionThresholdBreachedByPool[poolId];
        uint32 activePositionPercentageBps = positions.activePositionPercentageBps;

        if (!breached && activePositionPercentageBps < ACTIVE_POSITION_BREACH_THRESHOLD_BPS) {
            activePositionThresholdBreachedByPool[poolId] = true;
            emit PoolActivePositionThresholdBreached(
                PoolId.unwrap(poolId),
                positions.activePositionCount,
                positions.totalPositionCount,
                activePositionPercentageBps
            );
        } else if (breached && activePositionPercentageBps >= ACTIVE_POSITION_RECOVERY_THRESHOLD_BPS) {
            activePositionThresholdBreachedByPool[poolId] = false;
            emit PoolActivePositionThresholdRecovered(
                PoolId.unwrap(poolId),
                positions.activePositionCount,
                positions.totalPositionCount,
                activePositionPercentageBps
            );
        }
    }

    function _poolManager() internal view virtual returns (IPoolManager);
}
