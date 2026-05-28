// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {PoolMetrics} from "../src/types/PoolMetrics.sol";
import {SquidTestBase} from "./base/SquidTestBase.sol";

contract SquidPoolMetricsTest is SquidTestBase {
    function test_TracksPoolInitializationMetrics() public {
        PoolKey memory key = _initializeWhitelistedPool();

        PoolMetrics memory metrics = hook.getPoolMetrics(key);

        assertTrue(metrics.initialized);
        assertEq(metrics.currency0, Currency.unwrap(key.currency0));
        assertEq(metrics.currency1, Currency.unwrap(key.currency1));
        assertEq(metrics.fee, key.fee);
        assertEq(metrics.tickSpacing, key.tickSpacing);
        assertEq(metrics.initialSqrtPriceX96, SQRT_PRICE_1_1);
        assertEq(metrics.initialTick, 0);
        assertEq(metrics.initializedAtBlock, block.number);
    }

    function test_TracksLiquidityMetricsForActiveAndLifetimeState() public {
        PoolKey memory key = _initializeWhitelistedPool();

        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        PoolMetrics memory metrics = hook.getPoolMetrics(key);
        assertEq(metrics.activeLpCount, 1);
        assertEq(metrics.lifetimeLpCount, 1);
        assertEq(metrics.activePositionCount, 1);
        assertEq(metrics.lifetimePositionCount, 1);
        assertEq(metrics.trackedLiquidity, uint128(uint256(LIQUIDITY_PARAMS.liquidityDelta)));
        assertEq(metrics.addLiquidityCount, 1);
        assertEq(metrics.removeLiquidityCount, 0);
        assertGt(metrics.amount0Deposited, 0);
        assertGt(metrics.amount1Deposited, 0);

        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);

        metrics = hook.getPoolMetrics(key);
        assertEq(metrics.activeLpCount, 0);
        assertEq(metrics.lifetimeLpCount, 1);
        assertEq(metrics.activePositionCount, 0);
        assertEq(metrics.lifetimePositionCount, 1);
        assertEq(metrics.trackedLiquidity, 0);
        assertEq(metrics.addLiquidityCount, 1);
        assertEq(metrics.removeLiquidityCount, 1);
        assertEq(metrics.amount0Deposited, 0);
        assertEq(metrics.amount1Deposited, 0);
    }

    function test_DoesNotDoubleCountLifetimeLpOrPositionOnReactivation() public {
        PoolKey memory key = _initializeWhitelistedPool();

        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        PoolMetrics memory metrics = hook.getPoolMetrics(key);
        assertEq(metrics.activeLpCount, 1);
        assertEq(metrics.lifetimeLpCount, 1);
        assertEq(metrics.activePositionCount, 1);
        assertEq(metrics.lifetimePositionCount, 1);
        assertEq(metrics.addLiquidityCount, 2);
        assertEq(metrics.removeLiquidityCount, 1);
    }

    function test_TracksMultiplePositionsWithoutDoubleCountingActiveLp() public {
        PoolKey memory key = _initializeWhitelistedPool();
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

        PoolMetrics memory metrics = hook.getPoolMetrics(key);
        assertEq(metrics.activeLpCount, 1);
        assertEq(metrics.lifetimeLpCount, 1);
        assertEq(metrics.activePositionCount, 2);
        assertEq(metrics.lifetimePositionCount, 2);

        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);

        metrics = hook.getPoolMetrics(key);
        assertEq(metrics.activeLpCount, 1);
        assertEq(metrics.activePositionCount, 1);

        modifyLiquidityRouter.modifyLiquidity(key, removeSecondPosition, ZERO_BYTES);

        metrics = hook.getPoolMetrics(key);
        assertEq(metrics.activeLpCount, 0);
        assertEq(metrics.lifetimeLpCount, 1);
        assertEq(metrics.activePositionCount, 0);
        assertEq(metrics.lifetimePositionCount, 2);
    }

    function test_TracksSwapAndDonateMetrics() public {
        PoolKey memory key = _initializeWhitelistedPool();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        donateRouter.donate(key, 1_000, 2_000, ZERO_BYTES);
        swapRouter.swap(
            key,
            SwapParams({zeroForOne: true, amountSpecified: -10 ether, sqrtPriceLimitX96: SQRT_PRICE_1_2}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ZERO_BYTES
        );

        PoolMetrics memory metrics = hook.getPoolMetrics(key);
        assertEq(metrics.swapCount, 1);
        assertGt(metrics.volume0, 0);
        assertGt(metrics.volume1, 0);
        assertEq(metrics.donateCount, 1);
        assertEq(metrics.amount0Donated, 1_000);
        assertEq(metrics.amount1Donated, 2_000);
    }
}
