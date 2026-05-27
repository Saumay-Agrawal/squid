// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {CustomRevert} from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

import {Squid} from "../../src/Squid.sol";
import {TokenWhitelist} from "../../src/libraries/TokenWhitelist.sol";
import {UnichainSupportedTokens} from "../../src/libraries/UnichainSupportedTokens.sol";

contract SquidUnichainForkTest is Deployers {
    address internal constant UNICHAIN_V4_POOL_MANAGER = 0x1F98400000000000000000000000000000000004;
    uint256 internal constant DEFAULT_UNICHAIN_FORK_BLOCK = 44_000_000;

    Squid internal hook;

    address internal admin = makeAddr("admin");

    Currency internal usdc;
    Currency internal weth;

    function setUp() public {
        string memory rpcUrl = vm.envOr("UNICHAIN_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true, "set UNICHAIN_RPC_URL to run Unichain fork tests");
        }

        uint256 forkBlock = vm.envOr("UNICHAIN_FORK_BLOCK", DEFAULT_UNICHAIN_FORK_BLOCK);
        vm.createSelectFork(rpcUrl, forkBlock);

        assertGt(UNICHAIN_V4_POOL_MANAGER.code.length, 0, "PoolManager not deployed at pinned block");
        manager = IPoolManager(UNICHAIN_V4_POOL_MANAGER);

        uint160 flags = Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
            | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG;
        hook = Squid(address(uint160(type(uint160).max & clearAllHookPermissionsMask | flags)));
        deployCodeTo("Squid", abi.encode(manager, admin), address(hook));

        usdc = Currency.wrap(hook.USDC());
        weth = Currency.wrap(hook.WETH());
    }

    function testFork_SelectedTokenConstantsHaveCodeOnUnichain() public view {
        assertTrue(Currency.unwrap(usdc).code.length > 0, vm.toString(Currency.unwrap(usdc)));
        assertTrue(Currency.unwrap(weth).code.length > 0, vm.toString(Currency.unwrap(weth)));
    }

    function testFork_AdminCanWhitelistRealUnichainTokens() public {
        vm.startPrank(admin);
        hook.addWhitelistedToken(Currency.unwrap(usdc));
        hook.addWhitelistedToken(Currency.unwrap(weth));
        vm.stopPrank();

        assertTrue(hook.isTokenWhitelisted(Currency.unwrap(usdc)));
        assertTrue(hook.isTokenWhitelisted(Currency.unwrap(weth)));
    }

    function testFork_CanInitializePoolWithWhitelistedRealUnichainTokens() public {
        _whitelistPair(usdc, weth);

        PoolKey memory key = _poolKey(usdc, weth);
        int24 tick = manager.initialize(key, SQRT_PRICE_1_1);

        assertEq(tick, 0);
    }

    function testFork_RevertInitializePoolWhenRealTokensAreNotWhitelisted() public {
        PoolKey memory key = _poolKey(usdc, weth);

        _expectWrappedPoolTokenRevert(IHooks.beforeInitialize.selector, key);
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function testFork_RevertInitializePoolWithUnsupportedToken() public {
        address unsupported = address(0xBEEF);
        PoolKey memory key = _poolKey(Currency.wrap(unsupported), weth);

        _expectWrappedUnsupportedTokenRevert(IHooks.beforeInitialize.selector, unsupported);
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function _whitelistPair(Currency currency0, Currency currency1) internal {
        vm.startPrank(admin);
        hook.addWhitelistedToken(Currency.unwrap(currency0));
        hook.addWhitelistedToken(Currency.unwrap(currency1));
        vm.stopPrank();
    }

    function _poolKey(Currency currency0, Currency currency1) internal view returns (PoolKey memory) {
        return
            PoolKey({
                currency0: currency0, currency1: currency1, fee: 3000, tickSpacing: 60, hooks: IHooks(address(hook))
            });
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

    function _expectWrappedUnsupportedTokenRevert(bytes4 hookSelector, address token) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                hookSelector,
                abi.encodeWithSelector(UnichainSupportedTokens.UnsupportedUnichainToken.selector, token),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
    }
}
