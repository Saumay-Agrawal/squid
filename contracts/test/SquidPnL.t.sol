// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {SquidPositionTracker} from "../src/base/SquidPositionTracker.sol";
import {PnLReport} from "../src/types/PnLReport.sol";
import {SquidTestBase} from "./base/SquidTestBase.sol";

contract SquidPnLTest is SquidTestBase {
    uint256 internal constant ONE = 1e18;

    function test_TracksPositionAndReportsNoIlAtEntryPrice() public {
        PoolKey memory key = _initializeWhitelistedPool();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        bytes32 positionId = hook.getPositionId(
            address(modifyLiquidityRouter),
            key,
            LIQUIDITY_PARAMS.tickLower,
            LIQUIDITY_PARAMS.tickUpper,
            LIQUIDITY_PARAMS.salt
        );

        (
            address owner,,,,
            int24 tickLower,
            int24 tickUpper,,
            uint128 liquidity,
            uint256 amount0Deposited,
            uint256 amount1Deposited,
            bool active
        ) = hook.getTrackedPosition(positionId);

        assertEq(owner, address(modifyLiquidityRouter));
        assertEq(tickLower, LIQUIDITY_PARAMS.tickLower);
        assertEq(tickUpper, LIQUIDITY_PARAMS.tickUpper);
        assertEq(liquidity, uint128(uint256(LIQUIDITY_PARAMS.liquidityDelta)));
        assertTrue(active);

        (uint256 current0, uint256 current1) = hook.getCurrentPositionAmounts(positionId);
        assertApproxEqAbs(current0, amount0Deposited, 1);
        assertApproxEqAbs(current1, amount1Deposited, 1);

        PnLReport memory report = hook.getPositionPnL(positionId, ONE, ONE);
        assertApproxEqAbs(report.hodlValue, report.lpValue, 2);
        assertApproxEqAbs(uint256(_abs(report.impermanentLoss)), 0, 2);
        assertEq(report.feeAmount0, 0);
        assertEq(report.feeAmount1, 0);
    }

    function test_ReportsFeesSeparatelyFromImpermanentLoss() public {
        PoolKey memory key = _initializeWhitelistedPool();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        bytes32 positionId = hook.getPositionId(
            address(modifyLiquidityRouter),
            key,
            LIQUIDITY_PARAMS.tickLower,
            LIQUIDITY_PARAMS.tickUpper,
            LIQUIDITY_PARAMS.salt
        );

        donateRouter.donate(key, 1_000, 2_000, ZERO_BYTES);

        PnLReport memory report = hook.getPositionPnL(positionId, ONE, ONE);
        assertApproxEqAbs(report.hodlValue, report.lpValue, 2);
        assertApproxEqAbs(uint256(_abs(report.impermanentLoss)), 0, 2);
        assertGt(report.feeAmount0, 0);
        assertGt(report.feeAmount1, 0);
        assertEq(report.feeValue, report.feeAmount0 + report.feeAmount1);
    }

    function test_ReportsNegativeImpermanentLossAfterPriceMove() public {
        PoolKey memory key = _initializeWhitelistedPool();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        bytes32 positionId = hook.getPositionId(
            address(modifyLiquidityRouter),
            key,
            LIQUIDITY_PARAMS.tickLower,
            LIQUIDITY_PARAMS.tickUpper,
            LIQUIDITY_PARAMS.salt
        );

        swapRouter.swap(
            key,
            SwapParams({zeroForOne: true, amountSpecified: -10 ether, sqrtPriceLimitX96: SQRT_PRICE_1_2}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ZERO_BYTES
        );

        PnLReport memory report = hook.getPositionPnL(positionId, ONE, 2 * ONE);
        assertLt(report.impermanentLoss, 0);
        assertLt(report.impermanentLossBps, 0);
        assertGt(report.feeAmount0, 0);
        assertGt(report.lpValue, 0);
        assertGt(report.hodlValue, report.lpValue);
    }

    function test_RevertPnLForUntrackedPosition() public {
        bytes32 positionId = keccak256("missing");

        vm.expectRevert(abi.encodeWithSelector(SquidPositionTracker.PositionNotTracked.selector, positionId));
        hook.getPositionPnL(positionId, ONE, ONE);
    }

    function _abs(int256 value) internal pure returns (uint256) {
        return value < 0 ? uint256(-value) : uint256(value);
    }
}
