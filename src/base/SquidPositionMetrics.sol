// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";

import {PositionSummary} from "../types/PositionMetrics.sol";

abstract contract SquidPositionMetrics {
    using PoolIdLibrary for PoolKey;

    error PositionNotTracked(bytes32 positionId);

    mapping(bytes32 positionId => PositionSummary) internal positionSummariesById;

    function getPositionSummary(bytes32 positionId) external view returns (PositionSummary memory summary) {
        summary = positionSummariesById[positionId];
        if (!summary.initialized) revert PositionNotTracked(positionId);
    }

    function getPositionId(address owner, PoolId poolId, int24 tickLower, int24 tickUpper, bytes32 salt)
        public
        pure
        returns (bytes32 positionId)
    {
        positionId = keccak256(abi.encode(owner, PoolId.unwrap(poolId), tickLower, tickUpper, salt));
    }

    function _recordPositionOpenOrIncrease(address owner, PoolKey calldata key, ModifyLiquidityParams calldata params)
        internal
    {
        _syncPositionSummary(owner, key, params);
    }

    function _recordPositionDecreaseOrClose(address owner, PoolKey calldata key, ModifyLiquidityParams calldata params)
        internal
    {
        _syncPositionSummary(owner, key, params);
    }

    function _syncPositionSummary(address owner, PoolKey calldata key, ModifyLiquidityParams calldata params) private {
        PoolId poolId = key.toId();
        bytes32 positionId = getPositionId(owner, poolId, params.tickLower, params.tickUpper, params.salt);
        PositionSummary storage summary = positionSummariesById[positionId];

        if (!summary.initialized) {
            summary.positionId = positionId;
            summary.initialized = true;
            summary.createdBlock = uint64(block.number);
            summary.createdTimestamp = uint64(block.timestamp);
            summary.owner = owner;
            summary.poolId = PoolId.unwrap(poolId);
            summary.tickLower = params.tickLower;
            summary.tickUpper = params.tickUpper;
            summary.salt = params.salt;
        }

        summary.updatedBlock = uint64(block.number);
        summary.updatedTimestamp = uint64(block.timestamp);
        bytes32 corePositionId = Position.calculatePositionKey(owner, params.tickLower, params.tickUpper, params.salt);
        summary.active = StateLibrary.getPositionLiquidity(_poolManager(), poolId, corePositionId) > 0;
    }

    function _poolManager() internal view virtual returns (IPoolManager);
}
