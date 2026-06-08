// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {SquidPoolMetrics} from "../../src/base/SquidPoolMetrics.sol";
import {PoolSummary} from "../../src/types/PoolMetrics.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {Bytes32SymbolToken, MissingSymbolToken, RevertingSymbolToken, TestToken} from "../helpers/TestTokens.sol";

contract SquidPoolInitializationTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    function test_afterInitializeStoresPoolMetrics() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        Bytes32SymbolToken tokenB = new Bytes32SymbolToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        uint160 initialPrice = uint160(TickMath.getSqrtPriceAtTick(120));

        manager.initialize(poolKey, initialPrice);

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.poolId, PoolId.unwrap(poolKey.toId()));
        assertTrue(summary.initialized);
        assertEq(summary.initializedBlock, uint64(block.number));
        assertEq(summary.initializedTimestamp, uint64(block.timestamp));
        assertEq(summary.token0, address(tokenA));
        assertEq(summary.token1, address(tokenB));
        assertEq(summary.token0Symbol, "TKNA");
        assertEq(summary.token1Symbol, "TKNB");
        assertEq(summary.fee, poolKey.fee);
        assertEq(summary.tickSpacing, poolKey.tickSpacing);
        assertEq(summary.initialSqrtPriceX96, initialPrice);
        assertEq(summary.liquidity.totalLiquidity, 0);
        assertEq(summary.liquidity.activeLiquidity, 0);
        assertEq(summary.liquidity.peakActiveLiquidity, 0);
    }

    function test_symbolFallbacksDoNotBlockInitialization() public {
        RevertingSymbolToken tokenA = new RevertingSymbolToken("Token A");
        MissingSymbolToken tokenB = new MissingSymbolToken("Token B");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.token0Symbol, "UNKNOWN");
        assertEq(summary.token1Symbol, "UNKNOWN");
    }

    function test_currentPriceReadsLivePoolState() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        PoolId poolId = poolKey.toId();
        uint160 initialPrice = uint160(TickMath.getSqrtPriceAtTick(0));

        manager.initialize(poolKey, initialPrice);

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32(0)});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        swap(poolKey, true, -1e16, "");

        (uint160 currentSqrtPriceX96,,,) = hook.getCurrentPoolState(poolId);
        assertTrue(currentSqrtPriceX96 != initialPrice);
        assertEq(hook.getCurrentSqrtPriceX96(poolId), currentSqrtPriceX96);

        PoolSummary memory stored = hook.getPoolSummary(poolId);
        assertEq(stored.initialSqrtPriceX96, initialPrice);
    }

    function test_twapViewRevertsUntilOracleSupportExists() public {
        vm.expectRevert(SquidPoolMetrics.TwapNotSupported.selector);
        hook.getTwapSqrtPriceX96(PoolId.wrap(bytes32(0)), 30 minutes);
    }
}
