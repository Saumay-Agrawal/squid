// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {CustomRevert} from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

import {TokenWhitelist} from "../src/libraries/TokenWhitelist.sol";
import {SquidTestBase} from "./base/SquidTestBase.sol";

contract SquidPoolInitializationTest is SquidTestBase {
    function test_CanInitializePoolWithWhitelistedTokens() public {
        _whitelistPair(token0, token1);

        PoolKey memory key = _poolKey(token0, token1);
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_CanInitializeNativeEthPoolWithWhitelistedSupportedToken() public {
        vm.prank(admin);
        hook.addWhitelistedToken(Currency.unwrap(token0));

        PoolKey memory key = _poolKey(Currency.wrap(address(0)), token0);
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_RevertInitializeNativeEthPoolWithUnsupportedToken() public {
        PoolKey memory key = _poolKey(Currency.wrap(address(0)), unlistedToken);

        _expectWrappedUnsupportedTokenRevert(IHooks.beforeInitialize.selector, Currency.unwrap(unlistedToken));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_RevertInitializePoolWhenEitherTokenIsNotWhitelisted() public {
        vm.prank(admin);
        hook.addWhitelistedToken(Currency.unwrap(token0));

        (Currency sorted0, Currency sorted1) = _sort(token0, unlistedToken);
        PoolKey memory key = _poolKey(sorted0, sorted1);

        _expectWrappedUnsupportedTokenRevert(IHooks.beforeInitialize.selector, Currency.unwrap(unlistedToken));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_RevertInitializePoolWhenBothTokensAreNotWhitelisted() public {
        (Currency sorted0, Currency sorted1) = _sort(token0, token1);
        PoolKey memory key = _poolKey(sorted0, sorted1);

        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                IHooks.beforeInitialize.selector,
                abi.encodeWithSelector(
                    TokenWhitelist.PoolTokensNotWhitelisted.selector, Currency.unwrap(sorted0), Currency.unwrap(sorted1)
                ),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        manager.initialize(key, SQRT_PRICE_1_1);
    }
}
