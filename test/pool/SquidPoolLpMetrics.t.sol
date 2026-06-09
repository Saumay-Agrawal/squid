// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PoolSummary} from "../../src/types/PoolMetrics.sol";
import {PoolModifyLiquidityTestWithMsgSender} from "../../src/test/PoolModifyLiquidityTestWithMsgSender.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {BaseTestToken, TestToken} from "../helpers/TestTokens.sol";

contract SquidPoolLpMetricsTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_firstLpSetsActiveLifetimeAndRetention() public {
        (TestToken tokenA, TestToken tokenB, PoolKey memory poolKey, PoolModifyLiquidityTestWithMsgSender router) =
            _deployPoolWithRouter();
        address lp = _seedLp(address(router), address(tokenA), address(tokenB), "lp-alpha");

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});

        vm.prank(lp);
        router.modifyLiquidity(poolKey, params, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.lps.activeLpCount, 1);
        assertEq(summary.lps.lifetimeLpCount, 1);
        assertEq(summary.lps.lpRetentionBps, 10_000);
    }

    function test_multiplePositionsFromSameLpCountOnce() public {
        (TestToken tokenA, TestToken tokenB, PoolKey memory poolKey, PoolModifyLiquidityTestWithMsgSender router) =
            _deployPoolWithRouter();
        address lp = _seedLp(address(router), address(tokenA), address(tokenB), "lp-alpha");

        ModifyLiquidityParams memory firstParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory secondParams =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 1e18, salt: bytes32("beta")});

        vm.startPrank(lp);
        router.modifyLiquidity(poolKey, firstParams, "");
        router.modifyLiquidity(poolKey, secondParams, "");
        vm.stopPrank();

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.lps.activeLpCount, 1);
        assertEq(summary.lps.lifetimeLpCount, 1);
        assertEq(summary.lps.lpRetentionBps, 10_000);
    }

    function test_lpExitAndReentryPreservesLifetimeCount() public {
        (TestToken tokenA, TestToken tokenB, PoolKey memory poolKey, PoolModifyLiquidityTestWithMsgSender router) =
            _deployPoolWithRouter();
        address lp = _seedLp(address(router), address(tokenA), address(tokenB), "lp-alpha");

        ModifyLiquidityParams memory addParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory removeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("alpha")});

        vm.startPrank(lp);
        router.modifyLiquidity(poolKey, addParams, "");
        router.modifyLiquidity(poolKey, removeParams, "");
        vm.stopPrank();

        PoolSummary memory afterExit = hook.getPoolSummary(poolKey.toId());
        assertEq(afterExit.lps.activeLpCount, 0);
        assertEq(afterExit.lps.lifetimeLpCount, 1);
        assertEq(afterExit.lps.lpRetentionBps, 0);

        vm.prank(lp);
        router.modifyLiquidity(poolKey, addParams, "");

        PoolSummary memory afterReentry = hook.getPoolSummary(poolKey.toId());
        assertEq(afterReentry.lps.activeLpCount, 1);
        assertEq(afterReentry.lps.lifetimeLpCount, 1);
        assertEq(afterReentry.lps.lpRetentionBps, 10_000);
    }

    function test_multipleLpsTrackRetentionAcrossExit() public {
        (TestToken tokenA, TestToken tokenB, PoolKey memory poolKey, PoolModifyLiquidityTestWithMsgSender router) =
            _deployPoolWithRouter();
        address lpA = _seedLp(address(router), address(tokenA), address(tokenB), "lp-alpha");
        address lpB = _seedLp(address(router), address(tokenA), address(tokenB), "lp-beta");

        ModifyLiquidityParams memory lpAParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory lpBParams =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 1e18, salt: bytes32("beta")});
        ModifyLiquidityParams memory lpAExitParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("alpha")});

        vm.prank(lpA);
        router.modifyLiquidity(poolKey, lpAParams, "");

        vm.prank(lpB);
        router.modifyLiquidity(poolKey, lpBParams, "");

        PoolSummary memory afterBothEnter = hook.getPoolSummary(poolKey.toId());
        assertEq(afterBothEnter.lps.activeLpCount, 2);
        assertEq(afterBothEnter.lps.lifetimeLpCount, 2);
        assertEq(afterBothEnter.lps.lpRetentionBps, 10_000);

        vm.prank(lpA);
        router.modifyLiquidity(poolKey, lpAExitParams, "");

        PoolSummary memory afterOneExit = hook.getPoolSummary(poolKey.toId());
        assertEq(afterOneExit.lps.activeLpCount, 1);
        assertEq(afterOneExit.lps.lifetimeLpCount, 2);
        assertEq(afterOneExit.lps.lpRetentionBps, 5_000);
    }

    function _deployPoolWithRouter()
        private
        returns (
            TestToken tokenA,
            TestToken tokenB,
            PoolKey memory poolKey,
            PoolModifyLiquidityTestWithMsgSender router
        )
    {
        tokenA = new TestToken("Token A", "TKNA");
        tokenB = new TestToken("Token B", "TKNB");
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        router = new PoolModifyLiquidityTestWithMsgSender(manager);

        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));
    }

    function _seedLp(address router, address tokenA, address tokenB, string memory label) private returns (address lp) {
        lp = makeAddr(label);

        BaseTestToken(tokenA).mint(lp, 1 << 120);
        BaseTestToken(tokenB).mint(lp, 1 << 120);

        vm.startPrank(lp);
        BaseTestToken(tokenA).approve(router, type(uint256).max);
        BaseTestToken(tokenB).approve(router, type(uint256).max);
        vm.stopPrank();
    }
}
