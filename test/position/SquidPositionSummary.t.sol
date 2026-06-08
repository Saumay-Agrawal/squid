// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PositionSummary} from "../../src/types/PositionMetrics.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {TestToken} from "../helpers/TestTokens.sol";

contract SquidPositionSummaryTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_afterAddLiquidityStoresPositionMetrics() public {
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
        PositionSummary memory summary = hook.getPositionSummary(positionId);

        assertEq(summary.positionId, positionId);
        assertTrue(summary.initialized);
        assertTrue(summary.active);
        assertEq(summary.createdBlock, uint64(block.number));
        assertEq(summary.createdTimestamp, uint64(block.timestamp));
        assertEq(summary.updatedBlock, uint64(block.number));
        assertEq(summary.updatedTimestamp, uint64(block.timestamp));
        assertEq(summary.owner, address(modifyLiquidityRouter));
        assertEq(summary.poolId, PoolId.unwrap(poolKey.toId()));
        assertEq(summary.tickLower, params.tickLower);
        assertEq(summary.tickUpper, params.tickUpper);
        assertEq(summary.salt, params.salt);
    }

    function test_sameCanonicalPositionUpdatesSingleRecord() public {
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
        PositionSummary memory initialSummary = hook.getPositionSummary(positionId);

        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        params.liquidityDelta = 2e18;
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        PositionSummary memory updatedSummary = hook.getPositionSummary(positionId);
        assertEq(updatedSummary.positionId, initialSummary.positionId);
        assertEq(initialSummary.age, 0);
        assertEq(updatedSummary.createdBlock, initialSummary.createdBlock);
        assertEq(updatedSummary.createdTimestamp, initialSummary.createdTimestamp);
        assertEq(updatedSummary.updatedBlock, uint64(block.number));
        assertEq(updatedSummary.updatedTimestamp, uint64(block.timestamp));
        assertEq(updatedSummary.age, 1);
        assertTrue(updatedSummary.active);
    }

    function test_differentSaltCreatesDistinctPositionRecord() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory firstParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory secondParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("beta")});

        modifyLiquidityRouter.modifyLiquidity(poolKey, firstParams, "");
        modifyLiquidityRouter.modifyLiquidity(poolKey, secondParams, "");

        bytes32 firstPositionId = hook.getPositionId(
            address(modifyLiquidityRouter), poolKey.toId(), firstParams.tickLower, firstParams.tickUpper, firstParams.salt
        );
        bytes32 secondPositionId = hook.getPositionId(
            address(modifyLiquidityRouter), poolKey.toId(), secondParams.tickLower, secondParams.tickUpper, secondParams.salt
        );

        assertTrue(firstPositionId != secondPositionId);
        assertEq(hook.getPositionSummary(firstPositionId).salt, firstParams.salt);
        assertEq(hook.getPositionSummary(secondPositionId).salt, secondParams.salt);
    }

    function test_positionRemainsActiveAfterPartialRemovalAndClosesAfterFullRemoval() public {
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

        ModifyLiquidityParams memory partialRemoveParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, partialRemoveParams, "");
        assertTrue(hook.getPositionSummary(positionId).active);

        ModifyLiquidityParams memory fullRemoveParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -2e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, fullRemoveParams, "");
        assertFalse(hook.getPositionSummary(positionId).active);
    }
}
