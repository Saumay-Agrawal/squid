// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {CustomRevert} from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {Squid} from "../src/Squid.sol";
import {TokenWhitelist} from "../src/libraries/TokenWhitelist.sol";

contract SquidTest is Test, Deployers {
    Squid public hook;

    address public admin = makeAddr("admin");
    address public nonAdmin = makeAddr("nonAdmin");

    Currency public token0;
    Currency public token1;
    Currency public unlistedToken;

    function setUp() public {
        deployFreshManagerAndRouters();

        (token0, token1) = deployMintAndApprove2Currencies();
        unlistedToken = deployMintAndApproveCurrency();

        uint160 flags = Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
            | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG;
        hook = Squid(address(uint160(type(uint160).max & clearAllHookPermissionsMask | flags)));
        deployCodeTo("Squid", abi.encode(manager, admin), address(hook));
    }

    function test_AdminCanAddRemoveAndUpdateWhitelistedTokens() public {
        address token = Currency.unwrap(token0);

        vm.startPrank(admin);
        hook.addWhitelistedToken(token);
        assertTrue(hook.isTokenWhitelisted(token));

        hook.removeWhitelistedToken(token);
        assertFalse(hook.isTokenWhitelisted(token));

        hook.setTokenWhitelisted(token, true);
        assertTrue(hook.isTokenWhitelisted(token));

        hook.setTokenWhitelisted(token, false);
        assertFalse(hook.isTokenWhitelisted(token));
        vm.stopPrank();
    }

    function test_AdminCanAddAndRemoveWhitelistedTokensInBatch() public {
        address[] memory tokens = new address[](2);
        tokens[0] = Currency.unwrap(token0);
        tokens[1] = Currency.unwrap(token1);

        vm.startPrank(admin);
        hook.addWhitelistedTokens(tokens);
        assertTrue(hook.isTokenWhitelisted(tokens[0]));
        assertTrue(hook.isTokenWhitelisted(tokens[1]));

        hook.removeWhitelistedTokens(tokens);
        assertFalse(hook.isTokenWhitelisted(tokens[0]));
        assertFalse(hook.isTokenWhitelisted(tokens[1]));
        vm.stopPrank();
    }

    function test_NonAdminCannotAddRemoveOrUpdateWhitelistedTokens() public {
        address token = Currency.unwrap(token0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.addWhitelistedToken(token);

        vm.prank(admin);
        hook.addWhitelistedToken(token);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.removeWhitelistedToken(token);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.setTokenWhitelisted(token, false);
    }

    function test_NonAdminCannotAddOrRemoveWhitelistedTokensInBatch() public {
        address[] memory tokens = new address[](2);
        tokens[0] = Currency.unwrap(token0);
        tokens[1] = Currency.unwrap(token1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.addWhitelistedTokens(tokens);

        vm.prank(admin);
        hook.addWhitelistedTokens(tokens);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.removeWhitelistedTokens(tokens);
    }

    function test_CanInitializePoolWithWhitelistedTokens() public {
        _whitelistPair(token0, token1);

        PoolKey memory key = _poolKey(token0, token1);
        manager.initialize(key, SQRT_PRICE_1_1);
    }

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

    function test_RevertInitializePoolWhenEitherTokenIsNotWhitelisted() public {
        vm.prank(admin);
        hook.addWhitelistedToken(Currency.unwrap(token0));

        (Currency sorted0, Currency sorted1) = _sort(token0, unlistedToken);
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

    function _whitelistPair(Currency currency0, Currency currency1) internal {
        vm.startPrank(admin);
        hook.addWhitelistedToken(Currency.unwrap(currency0));
        hook.addWhitelistedToken(Currency.unwrap(currency1));
        vm.stopPrank();
    }

    function _removeFromWhitelist(Currency currency) internal {
        vm.prank(admin);
        hook.removeWhitelistedToken(Currency.unwrap(currency));
    }

    function _initializeWhitelistedPool() internal returns (PoolKey memory key) {
        _whitelistPair(token0, token1);
        key = _poolKey(token0, token1);
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function _expectWrappedPoolTokenRevert(bytes4 hookSelector, PoolKey memory key) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                hookSelector,
                abi.encodeWithSelector(
                    TokenWhitelist.PoolTokensNotWhitelisted.selector,
                    Currency.unwrap(key.currency0),
                    Currency.unwrap(key.currency1)
                ),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
    }

    function _poolKey(Currency currency0, Currency currency1) internal view returns (PoolKey memory) {
        return
            PoolKey({
                currency0: currency0, currency1: currency1, fee: 3000, tickSpacing: 60, hooks: IHooks(address(hook))
            });
    }

    function _sort(Currency currencyA, Currency currencyB) internal pure returns (Currency, Currency) {
        return Currency.unwrap(currencyA) < Currency.unwrap(currencyB) ? (currencyA, currencyB) : (currencyB, currencyA);
    }
}
