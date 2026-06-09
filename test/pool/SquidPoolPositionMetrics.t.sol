// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PoolSummary} from "../../src/types/PoolMetrics.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {TestToken} from "../helpers/TestTokens.sol";

contract SquidPoolPositionMetricsTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_firstInRangePositionUpdatesActiveAndTotalCounts() public {
        PoolKey memory poolKey = _initializePool();

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.positions.activePositionCount, 1);
        assertEq(summary.positions.totalPositionCount, 1);
        assertEq(summary.positions.activePositionPercentageBps, 10_000);
    }

    function test_firstOutOfRangePositionOnlyUpdatesTotalCount() public {
        PoolKey memory poolKey = _initializePool();

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.positions.activePositionCount, 0);
        assertEq(summary.positions.totalPositionCount, 1);
        assertEq(summary.positions.activePositionPercentageBps, 0);
    }

    function test_multiplePositionsAreCountedIndependently() public {
        PoolKey memory poolKey = _initializePool();

        ModifyLiquidityParams memory activeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory inactiveParams =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 1e18, salt: bytes32("beta")});

        modifyLiquidityRouter.modifyLiquidity(poolKey, activeParams, "");
        modifyLiquidityRouter.modifyLiquidity(poolKey, inactiveParams, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.positions.activePositionCount, 1);
        assertEq(summary.positions.totalPositionCount, 2);
        assertEq(summary.positions.activePositionPercentageBps, 5_000);
    }

    function test_fullClosePreservesTotalCountAndRemovesActiveCount() public {
        PoolKey memory poolKey = _initializePool();

        ModifyLiquidityParams memory addParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory removeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("alpha")});

        modifyLiquidityRouter.modifyLiquidity(poolKey, addParams, "");
        modifyLiquidityRouter.modifyLiquidity(poolKey, removeParams, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.positions.activePositionCount, 0);
        assertEq(summary.positions.totalPositionCount, 1);
        assertEq(summary.positions.activePositionPercentageBps, 0);
    }

    function test_swapMovingOutOfRangeUpdatesActivePositionCount() public {
        PoolKey memory poolKey = _initializePool();

        ModifyLiquidityParams memory currentRangeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory upperRangeParams =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 1e18, salt: bytes32("beta")});

        modifyLiquidityRouter.modifyLiquidity(poolKey, currentRangeParams, "");
        modifyLiquidityRouter.modifyLiquidity(poolKey, upperRangeParams, "");

        PoolSummary memory beforeSwap = hook.getPoolSummary(poolKey.toId());
        assertEq(beforeSwap.positions.activePositionCount, 1);
        assertEq(beforeSwap.positions.totalPositionCount, 2);
        assertEq(beforeSwap.positions.activePositionPercentageBps, 5_000);

        swap(poolKey, true, -1e18, "");

        PoolSummary memory afterSwap = hook.getPoolSummary(poolKey.toId());
        assertEq(afterSwap.positions.activePositionCount, 0);
        assertEq(afterSwap.positions.totalPositionCount, 2);
        assertEq(afterSwap.positions.activePositionPercentageBps, 0);
    }

    function test_swapMovingIntoRangeUpdatesActivePositionCount() public {
        PoolKey memory poolKey = _initializePool();

        ModifyLiquidityParams memory upperRangeParams =
            ModifyLiquidityParams({tickLower: 60, tickUpper: 240, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory currentRangeParams =
            ModifyLiquidityParams({tickLower: -180, tickUpper: 180, liquidityDelta: 1e18, salt: bytes32("beta")});

        modifyLiquidityRouter.modifyLiquidity(poolKey, upperRangeParams, "");
        modifyLiquidityRouter.modifyLiquidity(poolKey, currentRangeParams, "");

        PoolSummary memory beforeSwap = hook.getPoolSummary(poolKey.toId());
        assertEq(beforeSwap.positions.activePositionCount, 1);
        assertEq(beforeSwap.positions.totalPositionCount, 2);
        assertEq(beforeSwap.positions.activePositionPercentageBps, 5_000);

        swap(poolKey, false, -1e16, "");

        PoolSummary memory afterSwap = hook.getPoolSummary(poolKey.toId());
        assertEq(afterSwap.positions.activePositionCount, 2);
        assertEq(afterSwap.positions.totalPositionCount, 2);
        assertEq(afterSwap.positions.activePositionPercentageBps, 10_000);
    }

    function _initializePool() private returns (PoolKey memory poolKey) {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));
    }
}
