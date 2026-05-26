// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

import {Position} from "./types/Position.sol";

import {TokenWhitelist} from "./libraries/TokenWhitelist.sol";
import {UnichainSupportedTokens} from "./libraries/UnichainSupportedTokens.sol";

// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Squid is BaseHook, TokenWhitelist, UnichainSupportedTokens, Ownable2Step {
    address[] public lps;
    mapping(address => Position) public lpPositions;

    constructor(IPoolManager _manager, address initialOwner) BaseHook(_manager) Ownable(initialOwner) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: true,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeInitialize(address, PoolKey calldata key, uint160) internal view override returns (bytes4) {
        _checkPoolCurrenciesAllowed(key);
        return (this.beforeInitialize.selector);
    }

    function _beforeAddLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        internal
        view
        override
        returns (bytes4)
    {
        _checkPoolCurrenciesAllowed(key);
        return (this.beforeAddLiquidity.selector);
    }

    function _beforeRemoveLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        internal
        view
        override
        returns (bytes4)
    {
        _checkPoolCurrenciesAllowed(key);
        return (this.beforeRemoveLiquidity.selector);
    }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata, bytes calldata)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        _checkPoolCurrenciesAllowed(key);
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _beforeDonate(address, PoolKey calldata key, uint256, uint256, bytes calldata)
        internal
        view
        override
        returns (bytes4)
    {
        _checkPoolCurrenciesAllowed(key);
        return (this.beforeDonate.selector);
    }

    function _checkPoolCurrenciesAllowed(PoolKey calldata key) internal view {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        _checkSupportedUnichainCurrency(token0);
        _checkSupportedUnichainCurrency(token1);

        if (
            (token0 != address(0) && !_isWhitelistedToken[token0])
                || (token1 != address(0) && !_isWhitelistedToken[token1])
        ) {
            revert PoolTokensNotWhitelisted(token0, token1);
        }
    }

    // function _afterAddLiquidity(
    //     address sender,
    //     PoolKey calldata key,
    //     ModifyLiquidityParams calldata params,
    //     BalanceDelta delta,
    //     BalanceDelta feesAccrued,
    //     bytes calldata hookData
    // ) internal override returns (bytes4, BalanceDelta) {

    //     lps.push(sender);
    //     lpPositions[sender] = Position({
    //         owner: sender,
    //         poolKey: key,
    //         poolId: key.toId(),
    //         token0: Currency.unwrap(key.currency0),
    //         token1: Currency.unwrap(key.currency1),
    //         amount0Deposited: _absInt128(delta.amount0()),
    //         amount1Deposited: _absInt128(delta.amount1()),
    //         amount0DepositedUSD: _absInt128(delta.amount0()) * price,
    //         amount1DepositedUSD: _absInt128(delta.amount1()) * price
    //     });

    //     return (this.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    // }

    /********* WHITELIST LOGIC *********/

    function addWhitelistedToken(address token) external onlyOwner {
        _checkSupportedUnichainToken(token);
        _addWhitelistedToken(token);
    }

    function removeWhitelistedToken(address token) external onlyOwner {
        _removeWhitelistedToken(token);
    }

    function setTokenWhitelisted(address token, bool allowed) external onlyOwner {
        if (allowed) {
            _checkSupportedUnichainToken(token);
        }
        _setTokenWhitelisted(token, allowed);
    }

    function addWhitelistedTokens(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            _checkSupportedUnichainToken(tokens[i]);
        }
        _addWhitelistedTokens(tokens);
    }

    function removeWhitelistedTokens(address[] calldata tokens) external onlyOwner {
        _removeWhitelistedTokens(tokens);
    }

    /********* UTILITY LOGIC *********/

    function _absInt128(int128 x) internal pure returns (uint256) {
        return x < 0 ? uint256(uint128(-x)) : uint256(uint128(x));
    }
}
