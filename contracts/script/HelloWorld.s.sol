// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Script.sol";

contract HelloWorldScript is Script {
    function run() external pure {
        console2.log("HelloWorldScript: run()");
    }
}
