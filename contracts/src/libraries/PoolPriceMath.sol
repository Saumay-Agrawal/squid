// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FullMath} from "v4-core/libraries/FullMath.sol";

library PoolPriceMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant BPS = 10_000;
    uint256 internal constant Q192 = 2 ** 192;

    function spotPriceX18(uint160 sqrtPriceX96) internal pure returns (uint256) {
        return FullMath.mulDiv(uint256(sqrtPriceX96), uint256(sqrtPriceX96) * WAD, Q192);
    }

    function volatilityBps(uint256 spotPrice, uint256 twapPrice) internal pure returns (uint256) {
        if (twapPrice == 0 || spotPrice == twapPrice) return 0;

        uint256 delta = spotPrice > twapPrice ? spotPrice - twapPrice : twapPrice - spotPrice;
        return FullMath.mulDiv(delta, BPS, twapPrice);
    }
}
