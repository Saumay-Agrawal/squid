// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {SquidTestBase} from "./base/SquidTestBase.sol";

contract SquidLifecycleWhitelistTest is SquidTestBase {
    function test_RevertAddLiquidityAfterTokenRemovedFromWhitelist() public {
        PoolKey memory key = _initializeWhitelistedPool();

        _removeFromWhitelist(token0);

        _expectWrappedPoolTokenRevert(IHooks.beforeAddLiquidity.selector, key);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_RevertRemoveLiquidityAfterTokenRemovedFromWhitelist() public {
        PoolKey memory key = _initializeWhitelistedPool();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        _removeFromWhitelist(token0);

        _expectWrappedPoolTokenRevert(IHooks.beforeRemoveLiquidity.selector, key);
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_RevertSwapAfterTokenRemovedFromWhitelist() public {
        PoolKey memory key = _initializeWhitelistedPool();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        _removeFromWhitelist(token0);

        _expectWrappedPoolTokenRevert(IHooks.beforeSwap.selector, key);
        swapRouter.swap(
            key,
            SwapParams({zeroForOne: true, amountSpecified: -100, sqrtPriceLimitX96: SQRT_PRICE_1_2}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ZERO_BYTES
        );
    }

    function test_RevertDonateAfterTokenRemovedFromWhitelist() public {
        PoolKey memory key = _initializeWhitelistedPool();

        _removeFromWhitelist(token0);

        _expectWrappedPoolTokenRevert(IHooks.beforeDonate.selector, key);
        donateRouter.donate(key, 100, 100, ZERO_BYTES);
    }
}
