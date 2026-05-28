// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {PnLMath} from "../libraries/PnLMath.sol";
import {Position} from "../types/Position.sol";
import {PnLReport} from "../types/PnLReport.sol";

abstract contract SquidPositionTracker {
    using PoolIdLibrary for PoolKey;

    error PositionNotTracked(bytes32 positionId);
    error InvalidLiquidityDelta();

    address[] public lps;
    bytes32[] public positionIds;
    mapping(bytes32 positionId => Position) internal positions;

    function getPositionId(address owner, PoolKey calldata key, int24 tickLower, int24 tickUpper, bytes32 salt)
        public
        pure
        returns (bytes32)
    {
        PoolKey memory keyMemory = key;
        return _positionId(owner, keyMemory.toId(), tickLower, tickUpper, salt);
    }

    function getCurrentPositionAmounts(bytes32 positionId) public view returns (uint256 amount0, uint256 amount1) {
        Position storage position = positions[positionId];
        if (!position.active) revert PositionNotTracked(positionId);

        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(_poolManager(), position.poolId);
        return PnLMath.amountsForLiquidity(sqrtPriceX96, position.tickLower, position.tickUpper, position.liquidity);
    }

    function getTrackedPosition(bytes32 positionId)
        external
        view
        returns (
            address owner,
            PoolId poolId,
            address token0,
            address token1,
            int24 tickLower,
            int24 tickUpper,
            bytes32 salt,
            uint128 liquidity,
            uint256 amount0Deposited,
            uint256 amount1Deposited,
            bool active
        )
    {
        Position storage position = positions[positionId];
        if (!position.active) revert PositionNotTracked(positionId);
        return (
            position.owner,
            position.poolId,
            position.token0,
            position.token1,
            position.tickLower,
            position.tickUpper,
            position.salt,
            position.liquidity,
            position.amount0Deposited,
            position.amount1Deposited,
            position.active
        );
    }

    function getPositionPnL(bytes32 positionId, uint256 price0, uint256 price1)
        external
        view
        returns (PnLReport memory report)
    {
        Position storage position = positions[positionId];
        if (!position.active) revert PositionNotTracked(positionId);

        (report.currentAmount0, report.currentAmount1) = getCurrentPositionAmounts(positionId);
        _fillImpermanentLoss(report, position, price0, price1);

        (uint256 fee0Live, uint256 fee1Live) = _liveFees(position);
        report.feeAmount0 = position.fee0Accrued + fee0Live;
        report.feeAmount1 = position.fee1Accrued + fee1Live;
        report.feeValue = PnLMath.value(report.feeAmount0, report.feeAmount1, price0, price1);
    }

    function _trackLiquidityChange(
        address owner,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta
    ) internal {
        if (params.liquidityDelta == 0) return;

        PoolKey memory keyMemory = key;
        PoolId poolId = keyMemory.toId();
        bytes32 positionId = _positionId(owner, poolId, params.tickLower, params.tickUpper, params.salt);
        Position storage position = positions[positionId];

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            StateLibrary.getFeeGrowthInside(_poolManager(), poolId, params.tickLower, params.tickUpper);

        if (position.active) {
            _accrueFees(position, feeGrowthInside0X128, feeGrowthInside1X128);
        } else {
            _initializePosition(position, positionId, owner, poolId, keyMemory, params);
        }

        uint128 oldLiquidity = position.liquidity;
        (uint128 liveLiquidity,,) =
            StateLibrary.getPositionInfo(_poolManager(), poolId, owner, params.tickLower, params.tickUpper, params.salt);
        position.liquidity = liveLiquidity;

        if (params.liquidityDelta > 0) {
            _increaseDeposits(position, delta);
        } else {
            _decreaseDeposits(position, params.liquidityDelta, oldLiquidity, liveLiquidity);
        }

        position.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1X128;
    }

    function _poolManager() internal view virtual returns (IPoolManager);

    function _fillImpermanentLoss(PnLReport memory report, Position storage position, uint256 price0, uint256 price1)
        private
        view
    {
        (uint256 hodlValue, uint256 lpValue, int256 impermanentLoss, int256 impermanentLossBps) = PnLMath.impermanentLoss(
            position.amount0Deposited,
            position.amount1Deposited,
            report.currentAmount0,
            report.currentAmount1,
            price0,
            price1
        );
        report.hodlValue = hodlValue;
        report.lpValue = lpValue;
        report.impermanentLoss = impermanentLoss;
        report.impermanentLossBps = impermanentLossBps;
    }

    function _initializePosition(
        Position storage position,
        bytes32 positionId,
        address owner,
        PoolId poolId,
        PoolKey memory key,
        ModifyLiquidityParams calldata params
    ) private {
        lps.push(owner);
        positionIds.push(positionId);
        position.owner = owner;
        position.poolId = poolId;
        position.poolKey = key;
        position.token0 = Currency.unwrap(key.currency0);
        position.token1 = Currency.unwrap(key.currency1);
        position.tickLower = params.tickLower;
        position.tickUpper = params.tickUpper;
        position.salt = params.salt;
        position.active = true;
    }

    function _increaseDeposits(Position storage position, BalanceDelta delta) private {
        position.amount0Deposited += _absInt128(delta.amount0());
        position.amount1Deposited += _absInt128(delta.amount1());
    }

    function _decreaseDeposits(
        Position storage position,
        int256 liquidityDelta,
        uint128 oldLiquidity,
        uint128 liveLiquidity
    ) private {
        uint128 removedLiquidity = _absInt256ToUint128(liquidityDelta);
        if (removedLiquidity > oldLiquidity) revert InvalidLiquidityDelta();
        if (oldLiquidity > 0) {
            position.amount0Deposited -= (position.amount0Deposited * removedLiquidity) / oldLiquidity;
            position.amount1Deposited -= (position.amount1Deposited * removedLiquidity) / oldLiquidity;
        }
        if (liveLiquidity == 0) {
            position.active = false;
        }
    }

    function _accrueFees(Position storage position, uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
        private
    {
        (uint256 fee0, uint256 fee1) = PnLMath.feesAccrued(
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            feeGrowthInside0X128,
            feeGrowthInside1X128
        );
        position.fee0Accrued += fee0;
        position.fee1Accrued += fee1;
    }

    function _liveFees(Position storage position) private view returns (uint256 fee0, uint256 fee1) {
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            StateLibrary.getFeeGrowthInside(_poolManager(), position.poolId, position.tickLower, position.tickUpper);
        return PnLMath.feesAccrued(
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            feeGrowthInside0X128,
            feeGrowthInside1X128
        );
    }

    function _absInt128(int128 x) private pure returns (uint256) {
        return x < 0 ? uint256(uint128(-x)) : uint256(uint128(x));
    }

    function _absInt256ToUint128(int256 x) private pure returns (uint128) {
        if (x == type(int256).min) revert InvalidLiquidityDelta();
        uint256 absValue = x < 0 ? uint256(-x) : uint256(x);
        if (absValue > type(uint128).max) revert InvalidLiquidityDelta();
        return uint128(absValue);
    }

    function _positionId(address owner, PoolId poolId, int24 tickLower, int24 tickUpper, bytes32 salt)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(owner, poolId, tickLower, tickUpper, salt));
    }
}
