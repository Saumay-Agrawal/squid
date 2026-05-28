// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {PoolMetrics} from "../src/types/PoolMetrics.sol";
import {PoolSummary} from "../src/types/PoolSummary.sol";
import {SquidTestBase} from "./base/SquidTestBase.sol";

contract SquidPoolMetricsTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

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

    function test_RegistersInitializedPoolsAndSupportsPagination() public {
        PoolKey memory firstKey = _initializeWhitelistedPool();
        PoolKey memory secondKey = _poolKey(token0, token1, 500, 10);
        manager.initialize(secondKey, SQRT_PRICE_1_1);

        assertEq(hook.getPoolCount(), 2);
        assertEq(PoolId.unwrap(hook.getPoolIdAt(0)), PoolId.unwrap(firstKey.toId()));
        assertEq(PoolId.unwrap(hook.getPoolIdAt(1)), PoolId.unwrap(secondKey.toId()));

        PoolId[] memory ids = hook.getPoolIds(0, 10);
        assertEq(ids.length, 2);
        assertEq(PoolId.unwrap(ids[0]), PoolId.unwrap(firstKey.toId()));
        assertEq(PoolId.unwrap(ids[1]), PoolId.unwrap(secondKey.toId()));

        ids = hook.getPoolIds(1, 1);
        assertEq(ids.length, 1);
        assertEq(PoolId.unwrap(ids[0]), PoolId.unwrap(secondKey.toId()));

        ids = hook.getPoolIds(2, 1);
        assertEq(ids.length, 0);
    }

    function test_DoesNotDuplicatePoolRegistryEntriesAfterActivity() public {
        PoolKey memory key = _initializeWhitelistedPool();

        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        assertEq(hook.getPoolCount(), 1);
        assertEq(PoolId.unwrap(hook.getPoolIdAt(0)), PoolId.unwrap(key.toId()));
    }

    function test_ReturnsPaginatedPoolSummaries() public {
        PoolKey memory firstKey = _initializeWhitelistedPool();
        modifyLiquidityRouter.modifyLiquidity(firstKey, LIQUIDITY_PARAMS, ZERO_BYTES);
        swapRouter.swap(
            firstKey,
            SwapParams({zeroForOne: true, amountSpecified: -10 ether, sqrtPriceLimitX96: SQRT_PRICE_1_2}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ZERO_BYTES
        );

        PoolKey memory secondKey = _poolKey(token0, token1, 500, 10);
        manager.initialize(secondKey, SQRT_PRICE_1_1);

        PoolSummary[] memory summaries = hook.getPoolSummaries(0, 10);
        assertEq(summaries.length, 2);
        assertEq(PoolId.unwrap(summaries[0].poolId), PoolId.unwrap(firstKey.toId()));
        assertEq(summaries[0].currency0, Currency.unwrap(firstKey.currency0));
        assertEq(summaries[0].currency1, Currency.unwrap(firstKey.currency1));
        assertEq(summaries[0].fee, firstKey.fee);
        assertEq(summaries[0].tickSpacing, firstKey.tickSpacing);
        assertEq(summaries[0].activeLpCount, 1);
        assertEq(summaries[0].activePositionCount, 1);
        assertEq(summaries[0].trackedLiquidity, uint128(uint256(LIQUIDITY_PARAMS.liquidityDelta)));
        assertEq(summaries[0].swapCount, 1);

        assertEq(PoolId.unwrap(summaries[1].poolId), PoolId.unwrap(secondKey.toId()));
        assertEq(summaries[1].fee, secondKey.fee);
        assertEq(summaries[1].tickSpacing, secondKey.tickSpacing);
        assertEq(summaries[1].activeLpCount, 0);
        assertEq(summaries[1].activePositionCount, 0);
        assertEq(summaries[1].trackedLiquidity, 0);
        assertEq(summaries[1].swapCount, 0);

        summaries = hook.getPoolSummaries(1, 1);
        assertEq(summaries.length, 1);
        assertEq(PoolId.unwrap(summaries[0].poolId), PoolId.unwrap(secondKey.toId()));
    }
}
