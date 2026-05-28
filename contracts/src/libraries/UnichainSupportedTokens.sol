// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract UnichainSupportedTokens {
    address public constant UNI = 0x8f187aA05619a017077f5308904739877ce9eA21;
    address public constant USDC = 0x078D782b760474a361dDA0AF3839290b0EF57AD6;
    address public constant USDT0 = 0x9151434b16b9763660705744891fA906F660EcC5;
    address public constant S_USDC = 0x14D9143BeCC348920b68D123e7945dB49a016C6e;
    address public constant S_USDS = 0xA06b10Db9F390990364A3984C04FaDf1c13691b5;
    address public constant USDS = 0x7E10036Acc4B56d4dFCa3b77810356CE52313F9C;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant WSTETH = 0xc02fE7317D4eb8753a02c35fe019786854A92001;
    address public constant RSETH = 0xc3eACf0612346366Db554C991D7858716db09f58;
    address public constant WEETH = 0x7DCC39B4d1C53CB31e1aBc0e358b43987FEF80f7;
    address public constant EZETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address public constant KBTC = 0x73E0C0d45E048D25Fc26Fa3159b0aA04BfA4Db98;
    address public constant WBTC_OFT = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
    address public constant WBTC_BRIDGED = 0x927B51f251480a681271180DA4de28D44EC4AfB8;
    address public constant SOL_WORMHOLE = 0xbdE8A5331E8Ac4831cf8ea9e42e229219EafaB97;
    address public constant JUP_WORMHOLE = 0xbe51A5e8FA434F09663e8fB4CCe79d0B2381Afad;
    address public constant WIF_WORMHOLE = 0x97Fadb3D000b953360FD011e173F12cDDB5d70Fa;
    address public constant HYPE_WORMHOLE = 0x15D0e0c55a3E7eE67152aD7E89acf164253Ff68d;
    address public constant BONK_WORMHOLE = 0xBbE97f3522101e5B6976cBf77376047097BA837F;

    error UnsupportedUnichainToken(address token);

    function isSupportedUnichainToken(address token) public pure returns (bool) {
        return token == UNI || token == USDC || token == USDT0 || token == S_USDC || token == S_USDS || token == USDS
            || token == WETH || token == WSTETH || token == RSETH || token == WEETH || token == EZETH || token == KBTC
            || token == WBTC_OFT || token == WBTC_BRIDGED || token == SOL_WORMHOLE || token == JUP_WORMHOLE
            || token == WIF_WORMHOLE || token == HYPE_WORMHOLE || token == BONK_WORMHOLE;
    }

    function isSupportedUnichainCurrency(address token) public pure returns (bool) {
        return token == address(0) || isSupportedUnichainToken(token);
    }

    function _checkSupportedUnichainToken(address token) internal pure {
        if (!isSupportedUnichainToken(token)) {
            revert UnsupportedUnichainToken(token);
        }
    }

    function _checkSupportedUnichainCurrency(address token) internal pure {
        if (!isSupportedUnichainCurrency(token)) {
            revert UnsupportedUnichainToken(token);
        }
    }
}
