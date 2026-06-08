// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PositionPnL} from "../../src/types/PositionMetrics.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {TestToken} from "../helpers/TestTokens.sol";

contract SquidPositionPnLTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_positionPnLOpenMatchesCurrentPositionState() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        bytes32 positionId =
            hook.getPositionId(address(modifyLiquidityRouter), poolKey.toId(), params.tickLower, params.tickUpper, params.salt);
        PositionPnL memory pnl = hook.getPositionPnL(positionId);

        assertGt(pnl.principalAmount0, 0);
        assertGt(pnl.principalAmount1, 0);
        assertEq(pnl.feeAccumulated0, 0);
        assertEq(pnl.feeAccumulated1, 0);
        assertApproxEqAbs(pnl.currentAmount0, pnl.principalAmount0, 1);
        assertApproxEqAbs(pnl.currentAmount1, pnl.principalAmount1, 1);
        assertApproxEqAbs(pnl.netPnl0, 0, 1);
        assertApproxEqAbs(pnl.netPnl1, 0, 1);
    }

    function test_positionPnLReducesPrincipalProRataOnPartialRemove() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory addParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 3e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, addParams, "");

        bytes32 positionId = hook.getPositionId(
            address(modifyLiquidityRouter), poolKey.toId(), addParams.tickLower, addParams.tickUpper, addParams.salt
        );
        PositionPnL memory beforeRemove = hook.getPositionPnL(positionId);

        ModifyLiquidityParams memory removeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, removeParams, "");

        PositionPnL memory afterRemove = hook.getPositionPnL(positionId);
        assertEq(afterRemove.principalAmount0, beforeRemove.principalAmount0 - (beforeRemove.principalAmount0 / 3));
        assertEq(afterRemove.principalAmount1, beforeRemove.principalAmount1 - (beforeRemove.principalAmount1 / 3));
    }

    function test_positionPnLIncludesPendingFeesAfterSwap() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");
        swap(poolKey, true, -1e18, "");

        bytes32 positionId =
            hook.getPositionId(address(modifyLiquidityRouter), poolKey.toId(), params.tickLower, params.tickUpper, params.salt);
        PositionPnL memory pnl = hook.getPositionPnL(positionId);

        assertGt(pnl.feeAccumulated0 + pnl.feeAccumulated1, 0);
        assertTrue(pnl.currentAmount0 > pnl.principalAmount0 || pnl.currentAmount1 > pnl.principalAmount1);
    }
}
