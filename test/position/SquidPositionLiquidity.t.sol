// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PositionLiquidity} from "../../src/types/PositionMetrics.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {TestToken} from "../helpers/TestTokens.sol";

contract SquidPositionLiquidityTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_positionLiquidityTracksTotalAndActiveLiquidity() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory inRangeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 3e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, inRangeParams, "");

        bytes32 inRangePositionId = hook.getPositionId(
            address(modifyLiquidityRouter), poolKey.toId(), inRangeParams.tickLower, inRangeParams.tickUpper, inRangeParams.salt
        );
        PositionLiquidity memory inRangeLiquidity = hook.getPositionLiquidity(inRangePositionId);
        assertEq(inRangeLiquidity.totalLiquidity, 3e18);
        assertEq(inRangeLiquidity.activeLiquidity, 3e18);

        ModifyLiquidityParams memory outOfRangeParams =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 2e18, salt: bytes32("beta")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, outOfRangeParams, "");

        bytes32 outOfRangePositionId = hook.getPositionId(
            address(modifyLiquidityRouter),
            poolKey.toId(),
            outOfRangeParams.tickLower,
            outOfRangeParams.tickUpper,
            outOfRangeParams.salt
        );
        PositionLiquidity memory outOfRangeLiquidity = hook.getPositionLiquidity(outOfRangePositionId);
        assertEq(outOfRangeLiquidity.totalLiquidity, 2e18);
        assertEq(outOfRangeLiquidity.activeLiquidity, 0);
    }

    function test_swapRefreshesPositionActiveLiquidity() public {
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

        assertEq(hook.getPositionLiquidity(positionId).activeLiquidity, 1e18);

        swap(poolKey, true, -1e18, "");

        assertEq(hook.getPositionLiquidity(positionId).totalLiquidity, 1e18);
        assertEq(hook.getPositionLiquidity(positionId).activeLiquidity, 0);
    }

    function test_positionSwapVolumesTrackLifetimeAndActiveRange() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory activeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e24, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, activeParams, "");

        ModifyLiquidityParams memory inactiveParams =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 1e24, salt: bytes32("beta")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, inactiveParams, "");

        bytes32 activePositionId = hook.getPositionId(
            address(modifyLiquidityRouter), poolKey.toId(), activeParams.tickLower, activeParams.tickUpper, activeParams.salt
        );
        bytes32 inactivePositionId = hook.getPositionId(
            address(modifyLiquidityRouter),
            poolKey.toId(),
            inactiveParams.tickLower,
            inactiveParams.tickUpper,
            inactiveParams.salt
        );

        swap(poolKey, true, -1e16, "");

        PositionLiquidity memory activeAfterFirstSwap = hook.getPositionLiquidity(activePositionId);
        PositionLiquidity memory inactiveAfterFirstSwap = hook.getPositionLiquidity(inactivePositionId);

        assertGt(activeAfterFirstSwap.lifetimeSwapVolume0 + activeAfterFirstSwap.lifetimeSwapVolume1, 0);
        assertGt(activeAfterFirstSwap.activeSwapVolume0 + activeAfterFirstSwap.activeSwapVolume1, 0);
        assertGt(activeAfterFirstSwap.activeLiquidity, 0);
        assertEq(inactiveAfterFirstSwap.activeSwapVolume0 + inactiveAfterFirstSwap.activeSwapVolume1, 0);
        assertEq(
            inactiveAfterFirstSwap.lifetimeSwapVolume0 + inactiveAfterFirstSwap.lifetimeSwapVolume1,
            activeAfterFirstSwap.lifetimeSwapVolume0 + activeAfterFirstSwap.lifetimeSwapVolume1
        );
    }
}
