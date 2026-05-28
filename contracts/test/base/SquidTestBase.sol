// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {CustomRevert} from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

import {Squid} from "../../src/Squid.sol";
import {TokenWhitelist} from "../../src/libraries/TokenWhitelist.sol";
import {UnichainSupportedTokens} from "../../src/libraries/UnichainSupportedTokens.sol";

abstract contract SquidTestBase is Test, Deployers {
    Squid public hook;

    address public admin = makeAddr("admin");
    address public nonAdmin = makeAddr("nonAdmin");

    Currency public token0;
    Currency public token1;
    Currency public unlistedToken;

    function setUp() public virtual {
        deployFreshManagerAndRouters();

        uint160 flags = Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
            | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG | Hooks.AFTER_DONATE_FLAG;
        hook = Squid(address(uint160(type(uint160).max & clearAllHookPermissionsMask | flags)));
        deployCodeTo("Squid", abi.encode(manager, admin), address(hook));

        token0 = Currency.wrap(hook.USDC());
        token1 = Currency.wrap(hook.WETH());
        _installSupportedMockToken(Currency.unwrap(token0));
        _installSupportedMockToken(Currency.unwrap(token1));

        unlistedToken = deployMintAndApproveCurrency();
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

    function _installSupportedMockToken(address token) internal {
        MockERC20 mock = new MockERC20("Supported", "SPT", 18);
        vm.etch(token, address(mock).code);
        MockERC20(token).mint(address(this), 2 ** 255);

        address[9] memory toApprove = [
            address(swapRouter),
            address(swapRouterNoChecks),
            address(modifyLiquidityRouter),
            address(modifyLiquidityNoChecks),
            address(donateRouter),
            address(takeRouter),
            address(claimsRouter),
            address(nestedActionRouter.executor()),
            address(actionsRouter)
        ];

        for (uint256 i = 0; i < toApprove.length; i++) {
            MockERC20(token).approve(toApprove[i], type(uint256).max);
        }
    }

    function _supportedTokens() internal view returns (address[] memory tokens) {
        tokens = new address[](19);
        tokens[0] = hook.UNI();
        tokens[1] = hook.USDC();
        tokens[2] = hook.USDT0();
        tokens[3] = hook.S_USDC();
        tokens[4] = hook.S_USDS();
        tokens[5] = hook.USDS();
        tokens[6] = hook.WETH();
        tokens[7] = hook.WSTETH();
        tokens[8] = hook.RSETH();
        tokens[9] = hook.WEETH();
        tokens[10] = hook.EZETH();
        tokens[11] = hook.KBTC();
        tokens[12] = hook.WBTC_OFT();
        tokens[13] = hook.WBTC_BRIDGED();
        tokens[14] = hook.SOL_WORMHOLE();
        tokens[15] = hook.JUP_WORMHOLE();
        tokens[16] = hook.WIF_WORMHOLE();
        tokens[17] = hook.HYPE_WORMHOLE();
        tokens[18] = hook.BONK_WORMHOLE();
    }

    function _poolKey(Currency currency0, Currency currency1) internal view returns (PoolKey memory) {
        return _poolKey(currency0, currency1, 3000, 60);
    }

    function _poolKey(Currency currency0, Currency currency1, uint24 fee, int24 tickSpacing)
        internal
        view
        returns (PoolKey memory)
    {
        return
            PoolKey({currency0: currency0, currency1: currency1, fee: fee, tickSpacing: tickSpacing, hooks: IHooks(address(hook))});
    }

    function _sort(Currency currencyA, Currency currencyB) internal pure returns (Currency, Currency) {
        return Currency.unwrap(currencyA) < Currency.unwrap(currencyB) ? (currencyA, currencyB) : (currencyB, currencyA);
    }
}
