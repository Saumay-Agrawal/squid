// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct PnLReport {
    uint256 currentAmount0;
    uint256 currentAmount1;
    uint256 hodlValue;
    uint256 lpValue;
    int256 impermanentLoss;
    int256 impermanentLossBps;
    uint256 feeAmount0;
    uint256 feeAmount1;
    uint256 feeValue;
}
