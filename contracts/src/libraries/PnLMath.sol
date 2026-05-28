// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

library PnLMath {
    uint256 internal constant Q128 = 1 << 128;
    uint256 internal constant BPS = 10_000;
    uint256 internal constant WAD = 1e18;

    error InvalidPrice();
    error ZeroHodlValue();
    error ValueTooLarge();

    function value(uint256 amount0, uint256 amount1, uint256 price0, uint256 price1) internal pure returns (uint256) {
        if (price0 == 0 || price1 == 0) revert InvalidPrice();
        return FullMath.mulDiv(amount0, price0, WAD) + FullMath.mulDiv(amount1, price1, WAD);
    }

    function impermanentLoss(
        uint256 deposited0,
        uint256 deposited1,
        uint256 current0,
        uint256 current1,
        uint256 price0,
        uint256 price1
    ) internal pure returns (uint256 hodlValue, uint256 lpValue, int256 il, int256 ilBps) {
        hodlValue = value(deposited0, deposited1, price0, price1);
        if (hodlValue == 0) revert ZeroHodlValue();

        lpValue = value(current0, current1, price0, price1);
        il = _signedDelta(lpValue, hodlValue);
        ilBps = (il * int256(BPS)) / _toInt256(hodlValue);
    }

    function amountsForLiquidity(uint160 sqrtPriceX96, int24 tickLower, int24 tickUpper, uint128 liquidity)
        internal
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtPriceAtTick(tickUpper);

        if (sqrtPriceX96 <= sqrtPriceLowerX96) {
            amount0 = amount0ForLiquidity(sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity);
        } else if (sqrtPriceX96 < sqrtPriceUpperX96) {
            amount0 = amount0ForLiquidity(sqrtPriceX96, sqrtPriceUpperX96, liquidity);
            amount1 = amount1ForLiquidity(sqrtPriceLowerX96, sqrtPriceX96, liquidity);
        } else {
            amount1 = amount1ForLiquidity(sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity);
        }
    }

    function amount0ForLiquidity(uint160 sqrtPriceAX96_, uint160 sqrtPriceBX96_, uint128 liquidity)
        internal
        pure
        returns (uint256)
    {
        if (sqrtPriceAX96_ > sqrtPriceBX96_) {
            (sqrtPriceAX96_, sqrtPriceBX96_) = (sqrtPriceBX96_, sqrtPriceAX96_);
        }

        return FullMath.mulDiv(
            uint256(liquidity) << FixedPoint96.RESOLUTION, sqrtPriceBX96_ - sqrtPriceAX96_, sqrtPriceBX96_
        ) / sqrtPriceAX96_;
    }

    function amount1ForLiquidity(uint160 sqrtPriceAX96_, uint160 sqrtPriceBX96_, uint128 liquidity)
        internal
        pure
        returns (uint256)
    {
        if (sqrtPriceAX96_ > sqrtPriceBX96_) {
            (sqrtPriceAX96_, sqrtPriceBX96_) = (sqrtPriceBX96_, sqrtPriceAX96_);
        }

        return FullMath.mulDiv(liquidity, sqrtPriceBX96_ - sqrtPriceAX96_, FixedPoint96.Q96);
    }

    function feesAccrued(
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal pure returns (uint256 fee0, uint256 fee1) {
        unchecked {
            fee0 = FullMath.mulDiv(feeGrowthInside0X128 - feeGrowthInside0LastX128, liquidity, Q128);
            fee1 = FullMath.mulDiv(feeGrowthInside1X128 - feeGrowthInside1LastX128, liquidity, Q128);
        }
    }

    function _signedDelta(uint256 a, uint256 b) private pure returns (int256) {
        return a >= b ? _toInt256(a - b) : -_toInt256(b - a);
    }

    function _toInt256(uint256 value_) private pure returns (int256) {
        if (value_ > uint256(type(int256).max)) revert ValueTooLarge();
        return int256(value_);
    }
}
