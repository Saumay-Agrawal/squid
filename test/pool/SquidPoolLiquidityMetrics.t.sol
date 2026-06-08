// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PoolSummary} from "../../src/types/PoolMetrics.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {TestToken} from "../helpers/TestTokens.sol";

contract SquidPoolLiquidityMetricsTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_addLiquidityUpdatesPoolLiquidityMetrics() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.liquidity.totalLiquidity, 1e18);
        assertEq(summary.liquidity.activeLiquidity, 1e18);
        assertEq(summary.liquidity.peakActiveLiquidity, 1e18);
    }

    function test_outOfRangeLiquidityOnlyAffectsTotalLiquidity() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.liquidity.totalLiquidity, 1e18);
        assertEq(summary.liquidity.activeLiquidity, 0);
        assertEq(summary.liquidity.peakActiveLiquidity, 0);
    }

    function test_removeLiquidityUpdatesTotalAndActiveLiquidity() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory addParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 3e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, addParams, "");

        ModifyLiquidityParams memory removeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, removeParams, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.liquidity.totalLiquidity, 2e18);
        assertEq(summary.liquidity.activeLiquidity, 2e18);
        assertEq(summary.liquidity.peakActiveLiquidity, 3e18);
    }

    function test_swapRefreshesActiveLiquidityAndPreservesPeak() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory currentRangeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory upperRangeParams =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 2e18, salt: bytes32("beta")});

        modifyLiquidityRouter.modifyLiquidity(poolKey, currentRangeParams, "");
        modifyLiquidityRouter.modifyLiquidity(poolKey, upperRangeParams, "");

        PoolSummary memory beforeSwap = hook.getPoolSummary(poolKey.toId());
        assertEq(beforeSwap.liquidity.totalLiquidity, 3e18);
        assertEq(beforeSwap.liquidity.activeLiquidity, 1e18);
        assertEq(beforeSwap.liquidity.peakActiveLiquidity, 1e18);

        swap(poolKey, true, -1e18, "");

        PoolSummary memory afterSwap = hook.getPoolSummary(poolKey.toId());
        assertEq(afterSwap.liquidity.totalLiquidity, 3e18);
        assertEq(afterSwap.liquidity.activeLiquidity, 0);
        assertEq(afterSwap.liquidity.peakActiveLiquidity, 1e18);
    }
}
