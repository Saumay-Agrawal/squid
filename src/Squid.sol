// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";

import {SquidPoolMetrics} from "./base/SquidPoolMetrics.sol";
import {SquidPositionMetrics} from "./base/SquidPositionMetrics.sol";

contract Squid is BaseHook, SquidPoolMetrics, SquidPositionMetrics {
    constructor(IPoolManager _manager) BaseHook(_manager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions) {
        permissions.afterInitialize = true;
        permissions.afterAddLiquidity = true;
        permissions.afterRemoveLiquidity = true;
        permissions.afterSwap = true;
    }

    function _afterInitialize(address, PoolKey calldata key, uint160 sqrtPriceX96, int24)
        internal
        override
        returns (bytes4)
    {
        _registerPoolSummary(key, sqrtPriceX96);
        return IHooks.afterInitialize.selector;
    }

    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _recordPoolLiquidityAdded(key, params);
        _recordPositionOpenOrIncrease(sender, key, params);
        return (IHooks.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function _afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _recordPoolLiquidityRemoved(key, params);
        _recordPositionDecreaseOrClose(sender, key, params);
        return (IHooks.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        _recordPoolSwap(key);
        return (IHooks.afterSwap.selector, 0);
    }

    function _poolManager() internal view override(SquidPoolMetrics, SquidPositionMetrics) returns (IPoolManager) {
        return poolManager;
    }
}
