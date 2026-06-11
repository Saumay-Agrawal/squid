// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PoolSummary} from "../../src/types/PoolMetrics.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {TestToken} from "../helpers/TestTokens.sol";

contract SquidPoolTradeFlowMetricsTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_firstZeroToOneSwapUpdatesDirectionalCounts() public {
        PoolKey memory poolKey = _initializePoolWithActiveLiquidity();

        swap(poolKey, true, -1e16, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.tradeFlow.totalSwapCount, 1);
        assertEq(summary.tradeFlow.zeroToOneSwapCount, 1);
        assertEq(summary.tradeFlow.oneToZeroSwapCount, 0);
        assertEq(summary.tradeFlow.flowSkewnessBps, 10_000);
    }

    function test_firstOneToZeroSwapUpdatesDirectionalCounts() public {
        PoolKey memory poolKey = _initializePoolWithActiveLiquidity();

        swap(poolKey, false, -1e16, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.tradeFlow.totalSwapCount, 1);
        assertEq(summary.tradeFlow.zeroToOneSwapCount, 0);
        assertEq(summary.tradeFlow.oneToZeroSwapCount, 1);
        assertEq(summary.tradeFlow.flowSkewnessBps, 10_000);
    }

    function test_balancedBidirectionalFlowHasZeroSkewness() public {
        PoolKey memory poolKey = _initializePoolWithActiveLiquidity();

        swap(poolKey, true, -1e16, "");
        swap(poolKey, false, -1e16, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.tradeFlow.totalSwapCount, 2);
        assertEq(summary.tradeFlow.zeroToOneSwapCount, 1);
        assertEq(summary.tradeFlow.oneToZeroSwapCount, 1);
        assertEq(summary.tradeFlow.flowSkewnessBps, 0);
    }

    function test_imbalancedFlowReportsSkewness() public {
        PoolKey memory poolKey = _initializePoolWithActiveLiquidity();

        swap(poolKey, true, -1e16, "");
        swap(poolKey, true, -1e16, "");
        swap(poolKey, false, -1e16, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.tradeFlow.totalSwapCount, 3);
        assertEq(summary.tradeFlow.zeroToOneSwapCount, 2);
        assertEq(summary.tradeFlow.oneToZeroSwapCount, 1);
        assertEq(summary.tradeFlow.flowSkewnessBps, 10_000);
    }

    function test_stronglyImbalancedFlowCanExceedOneHundredPercentSkewness() public {
        PoolKey memory poolKey = _initializePoolWithActiveLiquidity();

        swap(poolKey, true, -1e16, "");
        swap(poolKey, true, -1e16, "");
        swap(poolKey, true, -1e16, "");
        swap(poolKey, true, -1e16, "");
        swap(poolKey, false, -1e16, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.tradeFlow.totalSwapCount, 5);
        assertEq(summary.tradeFlow.zeroToOneSwapCount, 4);
        assertEq(summary.tradeFlow.oneToZeroSwapCount, 1);
        assertEq(summary.tradeFlow.flowSkewnessBps, 30_000);
    }

    function _initializePoolWithActiveLiquidity() private returns (PoolKey memory poolKey) {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -600, tickUpper: 600, liquidityDelta: 1e24, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");
    }
}
