// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {UnichainSupportedTokens} from "../src/libraries/UnichainSupportedTokens.sol";
import {SquidTestBase} from "./base/SquidTestBase.sol";

contract SquidSupportedTokensTest is SquidTestBase {
    function test_AdminCanAddEverySupportedUnichainToken() public {
        address[] memory tokens = _supportedTokens();

        vm.startPrank(admin);
        for (uint256 i = 0; i < tokens.length; i++) {
            hook.addWhitelistedToken(tokens[i]);
            assertTrue(hook.isTokenWhitelisted(tokens[i]));
        }
        vm.stopPrank();
    }

    function test_RevertAddUnsupportedToken() public {
        address unsupported = Currency.unwrap(unlistedToken);

        vm.expectRevert(abi.encodeWithSelector(UnichainSupportedTokens.UnsupportedUnichainToken.selector, unsupported));
        vm.prank(admin);
        hook.addWhitelistedToken(unsupported);
    }

    function test_RevertUpdateUnsupportedTokenToWhitelisted() public {
        address unsupported = Currency.unwrap(unlistedToken);

        vm.expectRevert(abi.encodeWithSelector(UnichainSupportedTokens.UnsupportedUnichainToken.selector, unsupported));
        vm.prank(admin);
        hook.setTokenWhitelisted(unsupported, true);
    }

    function test_RevertBatchAddUnsupportedTokenAtomically() public {
        address[] memory tokens = new address[](2);
        tokens[0] = Currency.unwrap(token0);
        tokens[1] = Currency.unwrap(unlistedToken);

        vm.expectRevert(
            abi.encodeWithSelector(
                UnichainSupportedTokens.UnsupportedUnichainToken.selector, Currency.unwrap(unlistedToken)
            )
        );
        vm.prank(admin);
        hook.addWhitelistedTokens(tokens);

        assertFalse(hook.isTokenWhitelisted(tokens[0]));
        assertFalse(hook.isTokenWhitelisted(tokens[1]));
    }
}
