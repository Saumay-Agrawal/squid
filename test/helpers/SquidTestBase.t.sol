// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

import {Squid} from "../../src/Squid.sol";
import {BaseTestToken} from "./TestTokens.sol";

abstract contract SquidTestBase is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    Squid internal hook;

    function setUp() public virtual {
        deployFreshManagerAndRouters();

        uint160 flags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_INITIALIZE_FLAG
            | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG;
        hook = Squid(address(uint160(type(uint160).max & clearAllHookPermissionsMask | flags)));
        deployCodeTo("Squid", abi.encode(manager, address(this)), address(hook));
    }

    function _buildPoolKey(address tokenA, address tokenB) internal view returns (PoolKey memory) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
    }

    function _mintAndApprove(address token) internal {
        BaseTestToken(token).mint(address(this), 1 << 120);
        BaseTestToken(token).approve(address(swapRouter), type(uint256).max);
        BaseTestToken(token).approve(address(swapRouterNoChecks), type(uint256).max);
        BaseTestToken(token).approve(address(modifyLiquidityRouter), type(uint256).max);
        BaseTestToken(token).approve(address(modifyLiquidityNoChecks), type(uint256).max);
        BaseTestToken(token).approve(address(donateRouter), type(uint256).max);
        BaseTestToken(token).approve(address(takeRouter), type(uint256).max);
        BaseTestToken(token).approve(address(claimsRouter), type(uint256).max);
        BaseTestToken(token).approve(address(nestedActionRouter.executor()), type(uint256).max);
        BaseTestToken(token).approve(address(actionsRouter), type(uint256).max);
    }
}
