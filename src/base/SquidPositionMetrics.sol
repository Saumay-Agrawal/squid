// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {IMsgSender} from "@uniswap/v4-periphery/src/interfaces/IMsgSender.sol";

import {PositionLiquidityAmounts} from "../libraries/PositionLiquidityAmounts.sol";
import {PositionSummary, PositionLiquidity, PositionPnL, PositionPnLState} from "../types/PositionMetrics.sol";

abstract contract SquidPositionMetrics {
    using PoolIdLibrary for PoolKey;

    error PositionNotTracked(bytes32 positionId);

    mapping(bytes32 positionId => PositionSummary) internal positionSummariesById;
    mapping(bytes32 positionId => PositionLiquidity) internal positionLiquiditiesById;
    mapping(bytes32 positionId => PositionPnLState) internal positionPnLStatesById;
    mapping(PoolId poolId => bytes32[] positionIds) internal trackedPositionIdsByPool;

    function getPositionSummary(bytes32 positionId) external view returns (PositionSummary memory summary) {
        summary = positionSummariesById[positionId];
        if (!summary.initialized) revert PositionNotTracked(positionId);
        summary.age = uint64(block.timestamp - summary.createdTimestamp);
    }

    function getPositionLiquidity(bytes32 positionId) external view returns (PositionLiquidity memory liquidity) {
        PositionSummary storage summary = positionSummariesById[positionId];
        if (!summary.initialized) revert PositionNotTracked(positionId);

        liquidity = positionLiquiditiesById[positionId];
    }

    function getPositionPnL(bytes32 positionId) external view returns (PositionPnL memory pnl) {
        PositionSummary storage summary = positionSummariesById[positionId];
        if (!summary.initialized) revert PositionNotTracked(positionId);

        pnl = _buildPositionPnL(summary, positionPnLStatesById[positionId]);
    }

    function getPositionId(address owner, PoolId poolId, int24 tickLower, int24 tickUpper, bytes32 salt)
        public
        pure
        returns (bytes32 positionId)
    {
        positionId = keccak256(abi.encode(owner, PoolId.unwrap(poolId), tickLower, tickUpper, salt));
    }

    function _recordPositionOpenOrIncrease(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued
    ) internal {
        bytes32 positionId = _syncPositionSummary(sender, key, params);
        PositionSummary storage summary = positionSummariesById[positionId];
        uint128 liquidityBefore = positionLiquiditiesById[positionId].totalLiquidity;
        uint128 activeLiquidityBefore = positionLiquiditiesById[positionId].activeLiquidity;

        _syncPositionLiquidity(summary);
        _recordPoolLpPositionLiquidityChange(
            PoolId.wrap(summary.poolId),
            summary.owner,
            liquidityBefore,
            positionLiquiditiesById[positionId].totalLiquidity
        );
        _recordPoolPositionActivityChange(
            PoolId.wrap(summary.poolId),
            activeLiquidityBefore > 0,
            positionLiquiditiesById[positionId].activeLiquidity > 0
        );
        PositionPnLState storage pnlState = positionPnLStatesById[positionId];

        _recordRealizedFees(pnlState, feesAccrued);
        _recordPrincipalIncrease(pnlState, delta - feesAccrued);
    }

    function _recordPositionDecreaseOrClose(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta feesAccrued
    ) internal {
        PoolId poolId = key.toId();
        address owner = _resolvePositionOwner(sender);
        bytes32 positionId = getPositionId(owner, poolId, params.tickLower, params.tickUpper, params.salt);
        uint128 liquidityBeforePosition = positionLiquiditiesById[positionId].totalLiquidity;
        uint128 activeLiquidityBefore = positionLiquiditiesById[positionId].activeLiquidity;
        PositionPnLState storage pnlState = positionPnLStatesById[positionId];

        uint128 liquidityAfter =
            StateLibrary.getPositionLiquidity(_poolManager(), poolId, _corePositionId(sender, params));
        uint128 liquidityRemoved = _absoluteLiquidityDelta(params.liquidityDelta);
        uint128 liquidityBefore = liquidityAfter + liquidityRemoved;

        _recordPrincipalDecrease(pnlState, liquidityBefore, liquidityRemoved);
        _recordRealizedFees(pnlState, feesAccrued);
        PositionSummary storage summary = positionSummariesById[positionId];
        _syncPositionLiquidity(summary);
        _recordPoolLpPositionLiquidityChange(
            poolId, owner, liquidityBeforePosition, positionLiquiditiesById[positionId].totalLiquidity
        );
        _recordPoolPositionActivityChange(
            poolId, activeLiquidityBefore > 0, positionLiquiditiesById[positionId].activeLiquidity > 0
        );
        _syncPositionSummary(sender, key, params);
    }

    function _recordPositionSwap(PoolKey calldata key, SwapParams calldata, BalanceDelta delta) internal {
        PoolId poolId = key.toId();
        bytes32[] storage positionIds = trackedPositionIdsByPool[poolId];
        uint256 volume0 = _unsignedAmount0(delta);
        uint256 volume1 = _unsignedAmount1(delta);

        for (uint256 i; i < positionIds.length; ++i) {
            bytes32 positionId = positionIds[i];
            PositionSummary storage summary = positionSummariesById[positionId];
            PositionLiquidity storage liquidity = positionLiquiditiesById[positionId];
            uint128 activeLiquidityBefore = liquidity.activeLiquidity;

            _syncPositionLiquidity(summary);
            _recordPoolPositionActivityChange(poolId, activeLiquidityBefore > 0, liquidity.activeLiquidity > 0);

            if (liquidity.totalLiquidity == 0) continue;

            liquidity.lifetimeSwapVolume0 += volume0;
            liquidity.lifetimeSwapVolume1 += volume1;

            if (liquidity.activeLiquidity > 0) {
                liquidity.activeSwapVolume0 += volume0;
                liquidity.activeSwapVolume1 += volume1;
            }
        }
    }

    function _syncPositionSummary(address sender, PoolKey calldata key, ModifyLiquidityParams calldata params)
        private
        returns (bytes32 positionId)
    {
        PoolId poolId = key.toId();
        address owner = _resolvePositionOwner(sender);
        positionId = getPositionId(owner, poolId, params.tickLower, params.tickUpper, params.salt);
        PositionSummary storage summary = positionSummariesById[positionId];

        if (!summary.initialized) {
            summary.positionId = positionId;
            summary.initialized = true;
            summary.createdBlock = uint64(block.number);
            summary.createdTimestamp = uint64(block.timestamp);
            summary.owner = owner;
            summary.coreOwner = sender;
            summary.poolId = PoolId.unwrap(poolId);
            summary.tickLower = params.tickLower;
            summary.tickUpper = params.tickUpper;
            summary.salt = params.salt;
            trackedPositionIdsByPool[poolId].push(positionId);
            _recordPoolPositionCreated(poolId);
        }

        summary.updatedBlock = uint64(block.number);
        summary.updatedTimestamp = uint64(block.timestamp);
        summary.coreOwner = sender;
        summary.active = _getPositionLiquidity(poolId, summary) > 0;
    }

    function _buildPositionPnL(PositionSummary storage summary, PositionPnLState storage pnlState)
        internal
        view
        returns (PositionPnL memory pnl)
    {
        (uint256 liveAmount0, uint256 liveAmount1) = _getLiveLiquidityAmounts(summary);
        (uint256 pendingFee0, uint256 pendingFee1) = _getUncollectedFees(summary);

        pnl.principalAmount0 = pnlState.principalAmount0;
        pnl.principalAmount1 = pnlState.principalAmount1;
        pnl.currentAmount0 = liveAmount0 + pendingFee0;
        pnl.currentAmount1 = liveAmount1 + pendingFee1;
        pnl.feeAccumulated0 = pnlState.realizedFeeAmount0 + pendingFee0;
        pnl.feeAccumulated1 = pnlState.realizedFeeAmount1 + pendingFee1;
        pnl.netPnl0 = _signedDiff(pnl.currentAmount0, pnl.principalAmount0);
        pnl.netPnl1 = _signedDiff(pnl.currentAmount1, pnl.principalAmount1);
    }

    function _getLiveLiquidityAmounts(PositionSummary storage summary)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        PoolId poolId = PoolId.wrap(summary.poolId);
        (uint128 liquidity,,) = _getPositionInfo(poolId, summary);
        if (liquidity == 0) return (0, 0);

        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(_poolManager(), poolId);
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtPriceAtTick(summary.tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtPriceAtTick(summary.tickUpper);

        return
            PositionLiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96, sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity
            );
    }

    function _getUncollectedFees(PositionSummary storage summary) internal view returns (uint256 fee0, uint256 fee1) {
        PoolId poolId = PoolId.wrap(summary.poolId);
        (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) =
            _getPositionInfo(poolId, summary);
        if (liquidity == 0) return (0, 0);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            StateLibrary.getFeeGrowthInside(_poolManager(), poolId, summary.tickLower, summary.tickUpper);

        fee0 = FullMath.mulDiv(feeGrowthInside0X128 - feeGrowthInside0LastX128, liquidity, 1 << 128);
        fee1 = FullMath.mulDiv(feeGrowthInside1X128 - feeGrowthInside1LastX128, liquidity, 1 << 128);
    }

    function _recordRealizedFees(PositionPnLState storage pnlState, BalanceDelta feesAccrued) internal {
        pnlState.realizedFeeAmount0 += _positiveAmount0(feesAccrued);
        pnlState.realizedFeeAmount1 += _positiveAmount1(feesAccrued);
    }

    function _recordPrincipalIncrease(PositionPnLState storage pnlState, BalanceDelta principalDelta) internal {
        pnlState.principalAmount0 += _negativeAmount0(principalDelta);
        pnlState.principalAmount1 += _negativeAmount1(principalDelta);
    }

    function _recordPrincipalDecrease(
        PositionPnLState storage pnlState,
        uint128 liquidityBefore,
        uint128 liquidityRemoved
    ) internal {
        if (liquidityRemoved == 0 || liquidityBefore == 0) return;

        if (liquidityRemoved >= liquidityBefore) {
            pnlState.principalAmount0 = 0;
            pnlState.principalAmount1 = 0;
            return;
        }

        pnlState.principalAmount0 -= FullMath.mulDiv(pnlState.principalAmount0, liquidityRemoved, liquidityBefore);
        pnlState.principalAmount1 -= FullMath.mulDiv(pnlState.principalAmount1, liquidityRemoved, liquidityBefore);
    }

    function _syncPositionLiquidity(PositionSummary storage summary) internal {
        PoolId poolId = PoolId.wrap(summary.poolId);
        uint128 totalLiquidity = _getPositionLiquidity(poolId, summary);
        PositionLiquidity storage liquidity = positionLiquiditiesById[summary.positionId];

        liquidity.totalLiquidity = totalLiquidity;
        liquidity.activeLiquidity = _isPositionInRange(summary, poolId) ? totalLiquidity : 0;
        summary.active = totalLiquidity > 0;
    }

    function _getPositionInfo(PoolId poolId, PositionSummary storage summary)
        internal
        view
        returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128)
    {
        return StateLibrary.getPositionInfo(_poolManager(), poolId, _corePositionId(summary));
    }

    function _getPositionLiquidity(PoolId poolId, PositionSummary storage summary)
        internal
        view
        returns (uint128 liquidity)
    {
        liquidity = StateLibrary.getPositionLiquidity(_poolManager(), poolId, _corePositionId(summary));
    }

    function _isPositionInRange(PositionSummary storage summary, PoolId poolId) internal view returns (bool) {
        if (_getPositionLiquidity(poolId, summary) == 0) return false;

        (, int24 tick,,) = StateLibrary.getSlot0(_poolManager(), poolId);
        return tick >= summary.tickLower && tick < summary.tickUpper;
    }

    function _corePositionId(address owner, ModifyLiquidityParams calldata params) internal pure returns (bytes32) {
        return Position.calculatePositionKey(owner, params.tickLower, params.tickUpper, params.salt);
    }

    function _corePositionId(PositionSummary storage summary) internal view returns (bytes32) {
        return Position.calculatePositionKey(summary.coreOwner, summary.tickLower, summary.tickUpper, summary.salt);
    }

    function _resolvePositionOwner(address sender) internal view returns (address owner) {
        owner = sender;

        try IMsgSender(sender).msgSender() returns (address originalSender) {
            if (originalSender != address(0)) {
                owner = originalSender;
            }
        } catch {}
    }

    function _absoluteLiquidityDelta(int256 liquidityDelta) internal pure returns (uint128 liquidity) {
        uint256 absoluteDelta = liquidityDelta < 0 ? uint256(-liquidityDelta) : uint256(liquidityDelta);
        liquidity = uint128(absoluteDelta);
    }

    function _unsignedAmount0(BalanceDelta delta) internal pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount0(delta);
        amount = value < 0 ? uint256(uint128(-value)) : uint256(uint128(value));
    }

    function _unsignedAmount1(BalanceDelta delta) internal pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount1(delta);
        amount = value < 0 ? uint256(uint128(-value)) : uint256(uint128(value));
    }

    function _positiveAmount0(BalanceDelta delta) internal pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount0(delta);
        if (value > 0) amount = uint128(value);
    }

    function _positiveAmount1(BalanceDelta delta) internal pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount1(delta);
        if (value > 0) amount = uint128(value);
    }

    function _negativeAmount0(BalanceDelta delta) internal pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount0(delta);
        if (value < 0) amount = uint256(uint128(-value));
    }

    function _negativeAmount1(BalanceDelta delta) internal pure returns (uint256 amount) {
        int128 value = BalanceDeltaLibrary.amount1(delta);
        if (value < 0) amount = uint256(uint128(-value));
    }

    function _signedDiff(uint256 lhs, uint256 rhs) internal pure returns (int256) {
        return lhs >= rhs ? int256(lhs - rhs) : -int256(rhs - lhs);
    }

    function _recordPoolLpPositionLiquidityChange(
        PoolId poolId,
        address owner,
        uint128 liquidityBefore,
        uint128 liquidityAfter
    ) internal virtual;

    function _recordPoolPositionCreated(PoolId poolId) internal virtual;

    function _recordPoolPositionActivityChange(PoolId poolId, bool wasActive, bool isActive) internal virtual;

    function _poolManager() internal view virtual returns (IPoolManager);
}
