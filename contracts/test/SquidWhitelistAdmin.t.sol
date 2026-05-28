// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {SquidTestBase} from "./base/SquidTestBase.sol";

contract SquidWhitelistAdminTest is SquidTestBase {
    function test_AdminCanAddRemoveAndUpdateWhitelistedTokens() public {
        address token = Currency.unwrap(token0);

        vm.startPrank(admin);
        hook.addWhitelistedToken(token);
        assertTrue(hook.isTokenWhitelisted(token));

        hook.removeWhitelistedToken(token);
        assertFalse(hook.isTokenWhitelisted(token));

        hook.setTokenWhitelisted(token, true);
        assertTrue(hook.isTokenWhitelisted(token));

        hook.setTokenWhitelisted(token, false);
        assertFalse(hook.isTokenWhitelisted(token));
        vm.stopPrank();
    }

    function test_AdminCanAddAndRemoveWhitelistedTokensInBatch() public {
        address[] memory tokens = new address[](2);
        tokens[0] = Currency.unwrap(token0);
        tokens[1] = Currency.unwrap(token1);

        vm.startPrank(admin);
        hook.addWhitelistedTokens(tokens);
        assertTrue(hook.isTokenWhitelisted(tokens[0]));
        assertTrue(hook.isTokenWhitelisted(tokens[1]));

        hook.removeWhitelistedTokens(tokens);
        assertFalse(hook.isTokenWhitelisted(tokens[0]));
        assertFalse(hook.isTokenWhitelisted(tokens[1]));
        vm.stopPrank();
    }

    function test_NonAdminCannotAddRemoveOrUpdateWhitelistedTokens() public {
        address token = Currency.unwrap(token0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.addWhitelistedToken(token);

        vm.prank(admin);
        hook.addWhitelistedToken(token);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.removeWhitelistedToken(token);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.setTokenWhitelisted(token, false);
    }

    function test_NonAdminCannotAddOrRemoveWhitelistedTokensInBatch() public {
        address[] memory tokens = new address[](2);
        tokens[0] = Currency.unwrap(token0);
        tokens[1] = Currency.unwrap(token1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.addWhitelistedTokens(tokens);

        vm.prank(admin);
        hook.addWhitelistedTokens(tokens);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonAdmin));
        vm.prank(nonAdmin);
        hook.removeWhitelistedTokens(tokens);
    }
}
