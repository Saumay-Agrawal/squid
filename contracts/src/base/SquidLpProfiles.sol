// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {LpProfile, LpPoolProfile, LpPositionProfile} from "../types/LpProfile.sol";

abstract contract SquidLpProfiles {
    using PoolIdLibrary for PoolKey;

    error InvalidLpProfileLiquidityDelta();

    address[] internal allLps;
    mapping(address lp => LpProfile) internal lpProfiles;
    mapping(address lp => PoolId[] poolIds) internal lpPools;
    mapping(address lp => bytes32[] positionIds) internal lpPositions;
    mapping(address lp => mapping(PoolId poolId => bytes32[] positionIds)) internal lpPoolPositions;
    mapping(address lp => mapping(PoolId poolId => LpPoolProfile)) internal lpPoolProfiles;
    mapping(bytes32 positionId => LpPositionProfile) internal lpPositionProfiles;
    mapping(PoolId poolId => bytes32[] positionIds) internal poolPositionIds;
    mapping(PoolId poolId => int24 tick) internal poolPreSwapTicks;
    mapping(PoolId poolId => bool set) internal poolPreSwapTickSet;

    function getLpProfile(address lp) external view returns (LpProfile memory) {
        return lpProfiles[lp];
    }

    function getLpPoolProfile(address lp, PoolId poolId) external view returns (LpPoolProfile memory) {
        return lpPoolProfiles[lp][poolId];
    }

    function getLpPositionProfile(bytes32 positionId) external view returns (LpPositionProfile memory) {
        return lpPositionProfiles[positionId];
    }

    function getLpCount() external view returns (uint256) {
        return allLps.length;
    }

    function getLpAt(uint256 index) external view returns (address) {
        return allLps[index];
    }

    function getLpPoolCount(address lp) external view returns (uint256) {
        return lpPools[lp].length;
    }

    function getLpPoolAt(address lp, uint256 index) external view returns (PoolId) {
        return lpPools[lp][index];
    }

    function getLpPositionCount(address lp) external view returns (uint256) {
        return lpPositions[lp].length;
    }

    function getLpPositionAt(address lp, uint256 index) external view returns (bytes32) {
        return lpPositions[lp][index];
    }

    function getLpPoolPositionCount(address lp, PoolId poolId) external view returns (uint256) {
        return lpPoolPositions[lp][poolId].length;
    }

    function getLpPoolPositionAt(address lp, PoolId poolId, uint256 index) external view returns (bytes32) {
        return lpPoolPositions[lp][poolId][index];
    }

    function _trackLpProfileLiquidityChange(
        address owner,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta
    ) internal {
        if (params.liquidityDelta == 0) return;

        PoolKey memory keyMemory = key;
        PoolId poolId = keyMemory.toId();
        bytes32 positionId = _lpProfilePositionId(owner, poolId, params.tickLower, params.tickUpper, params.salt);
        _initializeLpProfile(owner);
        _initializeLpPoolProfile(owner, poolId, key);
        _initializeLpPositionProfile(owner, poolId, positionId, key, params);

        LpProfile storage profile = lpProfiles[owner];
        LpPoolProfile storage poolProfile = lpPoolProfiles[owner][poolId];
        LpPositionProfile storage positionProfile = lpPositionProfiles[positionId];
        uint128 oldLiquidity = positionProfile.liquidity;
        (uint128 liveLiquidity,,) =
            StateLibrary.getPositionInfo(_poolManager(), poolId, owner, params.tickLower, params.tickUpper, params.salt);

        if (params.liquidityDelta > 0) {
            _trackLpProfileLiquidityIncrease(profile, poolProfile, positionProfile, delta);
        } else {
            _trackLpProfileLiquidityDecrease(
                profile, poolProfile, positionProfile, params.liquidityDelta, oldLiquidity, liveLiquidity
            );
        }

        _trackLpProfileActiveTransitions(profile, poolProfile, positionProfile, oldLiquidity, liveLiquidity);
        _updateLpProfileLiquidity(poolProfile, positionProfile, oldLiquidity, liveLiquidity);
    }

    function _poolManager() internal view virtual returns (IPoolManager);

    function _initializeLpProfile(address owner) private {
        LpProfile storage profile = lpProfiles[owner];
        if (profile.exists) return;

        profile.exists = true;
        profile.firstActionBlock = block.number;
        allLps.push(owner);
    }

    function _initializeLpPoolProfile(address owner, PoolId poolId, PoolKey calldata key) private {
        LpPoolProfile storage poolProfile = lpPoolProfiles[owner][poolId];
        if (poolProfile.exists) return;

        LpProfile storage profile = lpProfiles[owner];
        poolProfile.exists = true;
        poolProfile.poolId = poolId;
        poolProfile.currency0 = Currency.unwrap(key.currency0);
        poolProfile.currency1 = Currency.unwrap(key.currency1);
        poolProfile.fee = key.fee;
        poolProfile.tickSpacing = key.tickSpacing;
        poolProfile.firstActionBlock = block.number;
        lpPools[owner].push(poolId);
        profile.lifetimePoolCount++;
    }

    function _initializeLpPositionProfile(
        address owner,
        PoolId poolId,
        bytes32 positionId,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params
    ) private {
        LpPositionProfile storage positionProfile = lpPositionProfiles[positionId];
        if (positionProfile.exists) return;

        LpProfile storage profile = lpProfiles[owner];
        LpPoolProfile storage poolProfile = lpPoolProfiles[owner][poolId];
        positionProfile.exists = true;
        positionProfile.owner = owner;
        positionProfile.poolId = poolId;
        positionProfile.currency0 = Currency.unwrap(key.currency0);
        positionProfile.currency1 = Currency.unwrap(key.currency1);
        positionProfile.tickLower = params.tickLower;
        positionProfile.tickUpper = params.tickUpper;
        positionProfile.salt = params.salt;
        positionProfile.openedAtBlock = block.number;
        lpPositions[owner].push(positionId);
        lpPoolPositions[owner][poolId].push(positionId);
        poolPositionIds[poolId].push(positionId);
        profile.lifetimePositionCount++;
        poolProfile.lifetimePositionCount++;
    }

    function _trackLpPositionSwapVolume(PoolKey calldata key, SwapParams calldata, BalanceDelta delta) internal {
        PoolKey memory keyMemory = key;
        PoolId poolId = keyMemory.toId();
        bytes32[] storage positionIdsForPool = poolPositionIds[poolId];
        if (positionIdsForPool.length == 0) return;

        (, int24 currentTick,,) = StateLibrary.getSlot0(_poolManager(), poolId);
        int24 referenceTick = poolPreSwapTickSet[poolId] ? poolPreSwapTicks[poolId] : currentTick;
        uint256 volume0 = _absLpProfileInt128(delta.amount0());
        uint256 volume1 = _absLpProfileInt128(delta.amount1());

        for (uint256 i = 0; i < positionIdsForPool.length; i++) {
            LpPositionProfile storage positionProfile = lpPositionProfiles[positionIdsForPool[i]];
            if (!positionProfile.active) continue;

            positionProfile.totalPoolVolume0 += volume0;
            positionProfile.totalPoolVolume1 += volume1;

            if (_isPositionInRange(positionProfile, referenceTick)) {
                positionProfile.activePositionVolume0 += volume0;
                positionProfile.activePositionVolume1 += volume1;
            }

            positionProfile.activeVolumePercentage0Bps = positionProfile.totalPoolVolume0 == 0
                ? 0
                : (positionProfile.activePositionVolume0 * 10_000) / positionProfile.totalPoolVolume0;
            positionProfile.activeVolumePercentage1Bps = positionProfile.totalPoolVolume1 == 0
                ? 0
                : (positionProfile.activePositionVolume1 * 10_000) / positionProfile.totalPoolVolume1;
        }

        poolPreSwapTickSet[poolId] = false;
    }

    function _snapshotPoolTickBeforeSwap(PoolKey calldata key) internal {
        PoolKey memory keyMemory = key;
        PoolId poolId = keyMemory.toId();
        (, int24 tick,,) = StateLibrary.getSlot0(_poolManager(), poolId);
        poolPreSwapTicks[poolId] = tick;
        poolPreSwapTickSet[poolId] = true;
    }

    function _trackLpProfileLiquidityIncrease(
        LpProfile storage profile,
        LpPoolProfile storage poolProfile,
        LpPositionProfile storage positionProfile,
        BalanceDelta delta
    ) private {
        uint256 amount0 = _absLpProfileInt128(delta.amount0());
        uint256 amount1 = _absLpProfileInt128(delta.amount1());

        positionProfile.amount0Deposited += amount0;
        positionProfile.amount1Deposited += amount1;
        positionProfile.totalAmount0Deposited += amount0;
        positionProfile.totalAmount1Deposited += amount1;
        positionProfile.addLiquidityCount++;

        poolProfile.amount0Deposited += amount0;
        poolProfile.amount1Deposited += amount1;
        poolProfile.totalAmount0Deposited += amount0;
        poolProfile.totalAmount1Deposited += amount1;
        poolProfile.addLiquidityCount++;

        profile.addLiquidityCount++;
    }

    function _trackLpProfileLiquidityDecrease(
        LpProfile storage profile,
        LpPoolProfile storage poolProfile,
        LpPositionProfile storage positionProfile,
        int256 liquidityDelta,
        uint128 oldLiquidity,
        uint128 liveLiquidity
    ) private {
        uint128 removedLiquidity = _absLpProfileInt256ToUint128(liquidityDelta);
        if (removedLiquidity > oldLiquidity) revert InvalidLpProfileLiquidityDelta();

        if (oldLiquidity > 0) {
            uint256 amount0Removed = (positionProfile.amount0Deposited * removedLiquidity) / oldLiquidity;
            uint256 amount1Removed = (positionProfile.amount1Deposited * removedLiquidity) / oldLiquidity;

            positionProfile.amount0Deposited -= amount0Removed;
            positionProfile.amount1Deposited -= amount1Removed;
            positionProfile.amount0Removed += amount0Removed;
            positionProfile.amount1Removed += amount1Removed;

            poolProfile.amount0Deposited -= amount0Removed;
            poolProfile.amount1Deposited -= amount1Removed;
            poolProfile.amount0Removed += amount0Removed;
            poolProfile.amount1Removed += amount1Removed;
        }

        if (liveLiquidity == 0) {
            poolProfile.amount0Deposited -= positionProfile.amount0Deposited;
            poolProfile.amount1Deposited -= positionProfile.amount1Deposited;
            poolProfile.amount0Removed += positionProfile.amount0Deposited;
            poolProfile.amount1Removed += positionProfile.amount1Deposited;
            positionProfile.amount0Removed += positionProfile.amount0Deposited;
            positionProfile.amount1Removed += positionProfile.amount1Deposited;
            positionProfile.amount0Deposited = 0;
            positionProfile.amount1Deposited = 0;
        }

        positionProfile.removeLiquidityCount++;
        poolProfile.removeLiquidityCount++;
        profile.removeLiquidityCount++;
    }

    function _trackLpProfileActiveTransitions(
        LpProfile storage profile,
        LpPoolProfile storage poolProfile,
        LpPositionProfile storage positionProfile,
        uint128 oldLiquidity,
        uint128 liveLiquidity
    ) private {
        if (!positionProfile.active && liveLiquidity > 0) {
            positionProfile.active = true;
            positionProfile.closedAtBlock = 0;
            poolProfile.activePositionCount++;
            profile.activePositionCount++;
            if (poolProfile.activePositionCount == 1) {
                profile.activePoolCount++;
            }
        } else if (positionProfile.active && oldLiquidity > 0 && liveLiquidity == 0) {
            positionProfile.active = false;
            positionProfile.closedAtBlock = block.number;
            poolProfile.activePositionCount--;
            profile.activePositionCount--;
            if (poolProfile.activePositionCount == 0) {
                profile.activePoolCount--;
            }
        }

        profile.lastActionBlock = block.number;
        poolProfile.lastActionBlock = block.number;
        positionProfile.lastActionBlock = block.number;
    }

    function _updateLpProfileLiquidity(
        LpPoolProfile storage poolProfile,
        LpPositionProfile storage positionProfile,
        uint128 oldLiquidity,
        uint128 liveLiquidity
    ) private {
        if (liveLiquidity >= oldLiquidity) {
            poolProfile.trackedLiquidity += liveLiquidity - oldLiquidity;
        } else {
            poolProfile.trackedLiquidity -= oldLiquidity - liveLiquidity;
        }
        positionProfile.liquidity = liveLiquidity;
    }

    function _absLpProfileInt128(int128 x) private pure returns (uint256) {
        return x < 0 ? uint256(uint128(-x)) : uint256(uint128(x));
    }

    function _isPositionInRange(LpPositionProfile storage positionProfile, int24 tick) private view returns (bool) {
        return positionProfile.tickLower <= tick && tick < positionProfile.tickUpper;
    }

    function _absLpProfileInt256ToUint128(int256 x) private pure returns (uint128) {
        if (x == type(int256).min) revert InvalidLpProfileLiquidityDelta();
        uint256 absValue = x < 0 ? uint256(-x) : uint256(x);
        if (absValue > type(uint128).max) revert InvalidLpProfileLiquidityDelta();
        return uint128(absValue);
    }

    function _lpProfilePositionId(address owner, PoolId poolId, int24 tickLower, int24 tickUpper, bytes32 salt)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(owner, poolId, tickLower, tickUpper, salt));
    }
}
