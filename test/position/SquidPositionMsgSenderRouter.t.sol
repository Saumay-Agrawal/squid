// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PositionSummary} from "../../src/types/PositionMetrics.sol";
import {PoolModifyLiquidityTestWithMsgSender} from "../../src/test/PoolModifyLiquidityTestWithMsgSender.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {BaseTestToken, TestToken} from "../helpers/TestTokens.sol";

contract SquidPositionMsgSenderRouterTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_msgSenderAwareRouterTracksLpAndCoreOwnerSeparately() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");

        address lp = makeAddr("lp");
        PoolModifyLiquidityTestWithMsgSender router = new PoolModifyLiquidityTestWithMsgSender(manager);

        BaseTestToken(address(tokenA)).mint(lp, 1 << 120);
        BaseTestToken(address(tokenB)).mint(lp, 1 << 120);

        vm.startPrank(lp);
        BaseTestToken(address(tokenA)).approve(address(router), type(uint256).max);
        BaseTestToken(address(tokenB)).approve(address(router), type(uint256).max);
        vm.stopPrank();

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});

        vm.startPrank(lp);
        router.modifyLiquidity(poolKey, params, "");
        vm.stopPrank();

        bytes32 positionId = hook.getPositionId(lp, poolKey.toId(), params.tickLower, params.tickUpper, params.salt);
        PositionSummary memory summary = hook.getPositionSummary(positionId);

        assertEq(summary.owner, lp);
        assertEq(summary.coreOwner, address(router));
        assertTrue(summary.active);
    }
}
