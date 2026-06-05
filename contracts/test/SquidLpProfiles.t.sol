// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";

import {LpProfile, LpPoolProfile, LpPositionProfile} from "../src/types/LpProfile.sol";
import {SquidTestBase} from "./base/SquidTestBase.sol";

contract SquidLpProfilesTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_TracksEnumerableLpProfileForFirstPosition() public {
        PoolKey memory key = _initializeWhitelistedPool();
        PoolId poolId = key.toId();
        address lp = address(modifyLiquidityRouter);

        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        bytes32 positionId =
            hook.getPositionId(lp, key, LIQUIDITY_PARAMS.tickLower, LIQUIDITY_PARAMS.tickUpper, LIQUIDITY_PARAMS.salt);
        LpProfile memory profile = hook.getLpProfile(lp);
        LpPoolProfile memory poolProfile = hook.getLpPoolProfile(lp, poolId);
        LpPositionProfile memory positionProfile = hook.getLpPositionProfile(positionId);

        assertTrue(profile.exists);
        assertEq(profile.firstActionBlock, block.number);
        assertEq(profile.lastActionBlock, block.number);
        assertEq(profile.activePoolCount, 1);
        assertEq(profile.lifetimePoolCount, 1);
        assertEq(profile.activePositionCount, 1);
        assertEq(profile.lifetimePositionCount, 1);
        assertEq(profile.addLiquidityCount, 1);
        assertEq(profile.removeLiquidityCount, 0);
        assertEq(hook.getLpCount(), 1);
        assertEq(hook.getLpAt(0), lp);
        assertEq(PoolId.unwrap(hook.getLpPoolAt(lp, 0)), PoolId.unwrap(poolId));
        assertEq(hook.getLpPositionAt(lp, 0), positionId);
        assertEq(hook.getLpPoolPositionAt(lp, poolId, 0), positionId);

        assertTrue(poolProfile.exists);
        assertEq(PoolId.unwrap(poolProfile.poolId), PoolId.unwrap(poolId));
        assertEq(poolProfile.currency0, Currency.unwrap(key.currency0));
        assertEq(poolProfile.currency1, Currency.unwrap(key.currency1));
        assertEq(poolProfile.activePositionCount, 1);
        assertEq(poolProfile.lifetimePositionCount, 1);
        assertEq(poolProfile.trackedLiquidity, uint128(uint256(LIQUIDITY_PARAMS.liquidityDelta)));
        assertGt(poolProfile.amount0Deposited, 0);
        assertGt(poolProfile.amount1Deposited, 0);
        assertEq(poolProfile.totalAmount0Deposited, poolProfile.amount0Deposited);
        assertEq(poolProfile.totalAmount1Deposited, poolProfile.amount1Deposited);

        assertTrue(positionProfile.exists);
        assertEq(positionProfile.owner, lp);
        assertTrue(positionProfile.active);
        assertEq(positionProfile.tickLower, LIQUIDITY_PARAMS.tickLower);
        assertEq(positionProfile.tickUpper, LIQUIDITY_PARAMS.tickUpper);
        assertEq(positionProfile.salt, LIQUIDITY_PARAMS.salt);
        assertEq(positionProfile.liquidity, uint128(uint256(LIQUIDITY_PARAMS.liquidityDelta)));
        assertEq(positionProfile.openedAtBlock, block.number);
        assertEq(positionProfile.closedAtBlock, 0);
        assertEq(positionProfile.totalAmount0Deposited, positionProfile.amount0Deposited);
        assertEq(positionProfile.totalAmount1Deposited, positionProfile.amount1Deposited);
    }

    function test_TracksClosedPositionMetadataAndHistoricalAmounts() public {
        PoolKey memory key = _initializeWhitelistedPool();
        PoolId poolId = key.toId();
        address lp = address(modifyLiquidityRouter);

        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        bytes32 positionId =
            hook.getPositionId(lp, key, LIQUIDITY_PARAMS.tickLower, LIQUIDITY_PARAMS.tickUpper, LIQUIDITY_PARAMS.salt);
        LpPositionProfile memory beforeClose = hook.getLpPositionProfile(positionId);

        vm.roll(block.number + 1);
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);

        LpProfile memory profile = hook.getLpProfile(lp);
        LpPoolProfile memory poolProfile = hook.getLpPoolProfile(lp, poolId);
        LpPositionProfile memory positionProfile = hook.getLpPositionProfile(positionId);

        assertEq(profile.activePoolCount, 0);
        assertEq(profile.lifetimePoolCount, 1);
        assertEq(profile.activePositionCount, 0);
        assertEq(profile.lifetimePositionCount, 1);
        assertEq(profile.addLiquidityCount, 1);
        assertEq(profile.removeLiquidityCount, 1);
        assertEq(profile.lastActionBlock, block.number);

        assertEq(poolProfile.activePositionCount, 0);
        assertEq(poolProfile.lifetimePositionCount, 1);
        assertEq(poolProfile.amount0Deposited, 0);
        assertEq(poolProfile.amount1Deposited, 0);
        assertEq(poolProfile.amount0Removed, beforeClose.amount0Deposited);
        assertEq(poolProfile.amount1Removed, beforeClose.amount1Deposited);
        assertEq(poolProfile.totalAmount0Deposited, beforeClose.amount0Deposited);
        assertEq(poolProfile.totalAmount1Deposited, beforeClose.amount1Deposited);
        assertEq(poolProfile.trackedLiquidity, 0);

        assertTrue(positionProfile.exists);
        assertFalse(positionProfile.active);
        assertEq(positionProfile.liquidity, 0);
        assertEq(positionProfile.amount0Deposited, 0);
        assertEq(positionProfile.amount1Deposited, 0);
        assertEq(positionProfile.amount0Removed, beforeClose.amount0Deposited);
        assertEq(positionProfile.amount1Removed, beforeClose.amount1Deposited);
        assertEq(positionProfile.openedAtBlock, beforeClose.openedAtBlock);
        assertEq(positionProfile.closedAtBlock, block.number);
    }

    function test_ReactivationDoesNotDoubleCountLifetimeIndexes() public {
        PoolKey memory key = _initializeWhitelistedPool();
        address lp = address(modifyLiquidityRouter);
        bytes32 positionId =
            hook.getPositionId(lp, key, LIQUIDITY_PARAMS.tickLower, LIQUIDITY_PARAMS.tickUpper, LIQUIDITY_PARAMS.salt);

        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        LpProfile memory profile = hook.getLpProfile(lp);
        LpPositionProfile memory positionProfile = hook.getLpPositionProfile(positionId);

        assertEq(hook.getLpCount(), 1);
        assertEq(hook.getLpPoolCount(lp), 1);
        assertEq(hook.getLpPositionCount(lp), 1);
        assertEq(hook.getLpPoolPositionCount(lp, key.toId()), 1);
        assertEq(profile.activePoolCount, 1);
        assertEq(profile.lifetimePoolCount, 1);
        assertEq(profile.activePositionCount, 1);
        assertEq(profile.lifetimePositionCount, 1);
        assertEq(profile.addLiquidityCount, 2);
        assertEq(profile.removeLiquidityCount, 1);
        assertTrue(positionProfile.active);
        assertEq(positionProfile.addLiquidityCount, 2);
        assertEq(positionProfile.removeLiquidityCount, 1);
        assertEq(positionProfile.closedAtBlock, 0);
    }

    function test_MultiplePositionsInSamePoolKeepOneActivePool() public {
        PoolKey memory key = _initializeWhitelistedPool();
        address lp = address(modifyLiquidityRouter);
        ModifyLiquidityParams memory secondPosition = ModifyLiquidityParams({
            tickLower: LIQUIDITY_PARAMS.tickLower,
            tickUpper: LIQUIDITY_PARAMS.tickUpper,
            liquidityDelta: LIQUIDITY_PARAMS.liquidityDelta,
            salt: bytes32(uint256(1))
        });
        ModifyLiquidityParams memory removeSecondPosition = ModifyLiquidityParams({
            tickLower: secondPosition.tickLower,
            tickUpper: secondPosition.tickUpper,
            liquidityDelta: -secondPosition.liquidityDelta,
            salt: secondPosition.salt
        });

        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, secondPosition, ZERO_BYTES);

        LpProfile memory profile = hook.getLpProfile(lp);
        LpPoolProfile memory poolProfile = hook.getLpPoolProfile(lp, key.toId());
        assertEq(profile.activePoolCount, 1);
        assertEq(profile.activePositionCount, 2);
        assertEq(profile.lifetimePositionCount, 2);
        assertEq(poolProfile.activePositionCount, 2);
        assertEq(hook.getLpPositionCount(lp), 2);
        assertEq(hook.getLpPoolPositionCount(lp, key.toId()), 2);

        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);

        profile = hook.getLpProfile(lp);
        poolProfile = hook.getLpPoolProfile(lp, key.toId());
        assertEq(profile.activePoolCount, 1);
        assertEq(profile.activePositionCount, 1);
        assertEq(poolProfile.activePositionCount, 1);

        modifyLiquidityRouter.modifyLiquidity(key, removeSecondPosition, ZERO_BYTES);

        profile = hook.getLpProfile(lp);
        poolProfile = hook.getLpPoolProfile(lp, key.toId());
        assertEq(profile.activePoolCount, 0);
        assertEq(profile.lifetimePoolCount, 1);
        assertEq(profile.activePositionCount, 0);
        assertEq(profile.lifetimePositionCount, 2);
        assertEq(poolProfile.activePositionCount, 0);
        assertEq(poolProfile.lifetimePositionCount, 2);
    }

    function test_TracksMultiplePoolsForLp() public {
        PoolKey memory firstPool = _initializeWhitelistedPool();
        PoolKey memory secondPool =
            PoolKey({currency0: token0, currency1: token1, fee: 500, tickSpacing: 10, hooks: IHooks(address(hook))});
        manager.initialize(secondPool, SQRT_PRICE_1_1);
        address lp = address(modifyLiquidityRouter);

        modifyLiquidityRouter.modifyLiquidity(firstPool, LIQUIDITY_PARAMS, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(secondPool, LIQUIDITY_PARAMS, ZERO_BYTES);

        LpProfile memory profile = hook.getLpProfile(lp);

        assertEq(hook.getLpCount(), 1);
        assertEq(hook.getLpPoolCount(lp), 2);
        assertEq(profile.activePoolCount, 2);
        assertEq(profile.lifetimePoolCount, 2);
        assertEq(profile.activePositionCount, 2);
        assertEq(profile.lifetimePositionCount, 2);
        assertEq(PoolId.unwrap(hook.getLpPoolAt(lp, 0)), PoolId.unwrap(firstPool.toId()));
        assertEq(PoolId.unwrap(hook.getLpPoolAt(lp, 1)), PoolId.unwrap(secondPool.toId()));
    }

    function test_TracksActiveAndTotalSwapVolumeForInRangePosition() public {
        PoolKey memory key = _initializeWhitelistedPool();
        address lp = address(modifyLiquidityRouter);

        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        swapRouter.swap(
            key,
            SwapParams({zeroForOne: true, amountSpecified: -10 ether, sqrtPriceLimitX96: SQRT_PRICE_1_2}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ZERO_BYTES
        );

        bytes32 positionId =
            hook.getPositionId(lp, key, LIQUIDITY_PARAMS.tickLower, LIQUIDITY_PARAMS.tickUpper, LIQUIDITY_PARAMS.salt);
        LpPositionProfile memory positionProfile = hook.getLpPositionProfile(positionId);

        assertGt(positionProfile.totalPoolVolume0, 0);
        assertGt(positionProfile.totalPoolVolume1, 0);
        assertEq(positionProfile.activePositionVolume0, positionProfile.totalPoolVolume0);
        assertEq(positionProfile.activePositionVolume1, positionProfile.totalPoolVolume1);
        assertEq(positionProfile.activeVolumePercentage0Bps, 10_000);
        assertEq(positionProfile.activeVolumePercentage1Bps, 10_000);
    }

    function test_DoesNotCountOutOfRangePositionAsActiveSwapVolume() public {
        PoolKey memory key = _initializeWhitelistedPool();
        address lp = address(modifyLiquidityRouter);
        ModifyLiquidityParams memory outOfRangePosition = ModifyLiquidityParams({
            tickLower: 600,
            tickUpper: 660,
            liquidityDelta: LIQUIDITY_PARAMS.liquidityDelta,
            salt: bytes32(uint256(1))
        });

        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, outOfRangePosition, ZERO_BYTES);

        swapRouter.swap(
            key,
            SwapParams({zeroForOne: true, amountSpecified: -10 ether, sqrtPriceLimitX96: SQRT_PRICE_1_2}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ZERO_BYTES
        );

        bytes32 inRangePositionId =
            hook.getPositionId(lp, key, LIQUIDITY_PARAMS.tickLower, LIQUIDITY_PARAMS.tickUpper, LIQUIDITY_PARAMS.salt);
        bytes32 outOfRangePositionId = hook.getPositionId(
            lp, key, outOfRangePosition.tickLower, outOfRangePosition.tickUpper, outOfRangePosition.salt
        );
        LpPositionProfile memory inRangePosition = hook.getLpPositionProfile(inRangePositionId);
        LpPositionProfile memory outOfRangeProfile = hook.getLpPositionProfile(outOfRangePositionId);

        assertGt(inRangePosition.activePositionVolume0, 0);
        assertGt(inRangePosition.activePositionVolume1, 0);
        assertEq(inRangePosition.activeVolumePercentage0Bps, 10_000);
        assertEq(inRangePosition.activeVolumePercentage1Bps, 10_000);

        assertGt(outOfRangeProfile.totalPoolVolume0, 0);
        assertGt(outOfRangeProfile.totalPoolVolume1, 0);
        assertEq(outOfRangeProfile.activePositionVolume0, 0);
        assertEq(outOfRangeProfile.activePositionVolume1, 0);
        assertEq(outOfRangeProfile.activeVolumePercentage0Bps, 0);
        assertEq(outOfRangeProfile.activeVolumePercentage1Bps, 0);
    }
}
