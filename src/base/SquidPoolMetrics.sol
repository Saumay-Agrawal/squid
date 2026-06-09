// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PoolLiquidity, PoolLPs, PoolPositions, PoolSummary, PoolTradeFlow} from "../types/PoolMetrics.sol";
import {TokenSymbolResolver} from "../libraries/TokenSymbolResolver.sol";

abstract contract SquidPoolMetrics {
    using PoolIdLibrary for PoolKey;

    uint32 internal constant BPS_DENOMINATOR = 10_000;

    error PoolAlreadyRegistered(bytes32 poolId);
    error PoolNotRegistered(bytes32 poolId);
    error TwapNotSupported();
    error LiquidityDeltaOverflow();

    mapping(PoolId poolId => PoolSummary) internal poolSummariesById;
    mapping(PoolId poolId => mapping(address owner => uint32 count)) internal activePositionCountByPoolAndOwner;
    mapping(PoolId poolId => mapping(address owner => bool counted)) internal hasCountedOwnerForPool;

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
        _syncPoolLiquidity(summary, poolId);
    }

    function _recordPoolLiquidityAdded(PoolKey calldata key, ModifyLiquidityParams calldata params) internal {
        PoolId poolId = key.toId();
        PoolSummary storage summary = poolSummariesById[poolId];
        _requirePoolRegistered(poolId);

        summary.liquidity.totalLiquidity += _liquidityDeltaToUint128(params.liquidityDelta);
        _syncPoolLiquidity(summary, poolId);
    }

    function _recordPoolLiquidityRemoved(PoolKey calldata key, ModifyLiquidityParams calldata params) internal {
        PoolId poolId = key.toId();
        PoolSummary storage summary = poolSummariesById[poolId];
        _requirePoolRegistered(poolId);

        summary.liquidity.totalLiquidity -= _liquidityDeltaToUint128(-params.liquidityDelta);
        _syncPoolLiquidity(summary, poolId);
    }

    function _recordPoolSwap(PoolKey calldata key, SwapParams calldata params) internal {
        PoolId poolId = key.toId();
        PoolSummary storage summary = poolSummariesById[poolId];
        _requirePoolRegistered(poolId);

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
        if (zeroToOneSwapCount == 0 || oneToZeroSwapCount == 0) return 0;

        uint256 ratioBps = (uint256(zeroToOneSwapCount) * BPS_DENOMINATOR) / uint256(oneToZeroSwapCount);
        return ratioBps >= BPS_DENOMINATOR ? uint32(ratioBps - BPS_DENOMINATOR) : uint32(BPS_DENOMINATOR - ratioBps);
    }

    function _requirePoolRegistered(PoolId poolId) internal view {
        if (!poolSummariesById[poolId].initialized) revert PoolNotRegistered(PoolId.unwrap(poolId));
    }

    function _poolManager() internal view virtual returns (IPoolManager);
}
