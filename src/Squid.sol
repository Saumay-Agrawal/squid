// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";

import {SquidPoolMetrics} from "./base/SquidPoolMetrics.sol";
import {SquidPositionMetrics} from "./base/SquidPositionMetrics.sol";

contract Squid is BaseHook, SquidPoolMetrics, SquidPositionMetrics {
    error PoolAddLiquidityHalted(bytes32 poolId);
    error UnauthorizedPoolGuardOperator(address caller);

    address public poolGuardOperator;

    constructor(IPoolManager _manager, address _poolGuardOperator) BaseHook(_manager) {
        poolGuardOperator = _poolGuardOperator;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions) {
        permissions.beforeAddLiquidity = true;
        permissions.afterInitialize = true;
        permissions.afterAddLiquidity = true;
        permissions.afterRemoveLiquidity = true;
        permissions.afterSwap = true;
    }

    function setPoolGuardOperator(address newPoolGuardOperator) external {
        address currentOperator = poolGuardOperator;
        if (currentOperator != address(0) && msg.sender != currentOperator) {
            revert UnauthorizedPoolGuardOperator(msg.sender);
        }

        poolGuardOperator = newPoolGuardOperator;
    }

    function haltPoolLiquidityAdds(bytes32 poolId) external {
        _onlyPoolGuardOperator();
        _requirePoolRegistered(PoolId.wrap(poolId));
        _setPoolAddLiquidityHalted(PoolId.wrap(poolId), true);
    }

    function unhaltPoolLiquidityAdds(bytes32 poolId) external {
        _onlyPoolGuardOperator();
        _requirePoolRegistered(PoolId.wrap(poolId));
        _setPoolAddLiquidityHalted(PoolId.wrap(poolId), false);
    }

    function _beforeAddLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        internal
        override
        returns (bytes4)
    {
        PoolId poolId = key.toId();
        if (_isPoolAddLiquidityHalted(poolId)) revert PoolAddLiquidityHalted(PoolId.unwrap(poolId));
        return IHooks.beforeAddLiquidity.selector;
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
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _recordPoolLiquidityAdded(key, params, delta, feesAccrued);
        _recordPositionOpenOrIncrease(sender, key, params, delta, feesAccrued);
        return (IHooks.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function _afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _recordPoolLiquidityRemoved(key, params, delta, feesAccrued);
        _recordPositionDecreaseOrClose(sender, key, params, delta, feesAccrued);
        return (IHooks.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        _recordPoolSwap(key, params, delta);
        _recordPositionSwap(key, params, delta);
        return (IHooks.afterSwap.selector, 0);
    }

    function _poolManager() internal view override(SquidPoolMetrics, SquidPositionMetrics) returns (IPoolManager) {
        return poolManager;
    }

    function _recordPoolLpPositionLiquidityChange(
        PoolId poolId,
        address owner,
        uint128 liquidityBefore,
        uint128 liquidityAfter
    ) internal override(SquidPoolMetrics, SquidPositionMetrics) {
        SquidPoolMetrics._recordPoolLpPositionLiquidityChange(poolId, owner, liquidityBefore, liquidityAfter);
    }

    function _recordPoolPositionCreated(PoolId poolId) internal override(SquidPoolMetrics, SquidPositionMetrics) {
        SquidPoolMetrics._recordPoolPositionCreated(poolId);
    }

    function _recordPoolPositionActivityChange(PoolId poolId, bool wasActive, bool isActive)
        internal
        override(SquidPoolMetrics, SquidPositionMetrics)
    {
        SquidPoolMetrics._recordPoolPositionActivityChange(poolId, wasActive, isActive);
    }

    function _onlyPoolGuardOperator() private view {
        if (msg.sender != poolGuardOperator) revert UnauthorizedPoolGuardOperator(msg.sender);
    }
}
