// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

abstract contract TokenWhitelist {

    mapping(address token => bool allowed) internal _isWhitelistedToken;
    address[] internal _whitelistedTokens;

    error TokenAlreadyWhitelisted(address token);
    error TokenNotWhitelisted(address token);
    error PoolTokensNotWhitelisted(address token0, address token1);
    error InvalidTokenAddress();

    event TokenWhitelisted(address indexed token);
    event TokenRemovedFromWhitelist(address indexed token);
    event TokenWhitelistUpdated(address indexed token, bool allowed);

    function isTokenWhitelisted(address token) public view returns (bool) {
        return _isWhitelistedToken[token];
    }

    function getWhitelistedTokens() public view returns (address[] memory) {
        return _whitelistedTokens;
    }

    function getWhitelistedTokenCount() public view returns (uint256) {
        return _whitelistedTokens.length;
    }

    function getWhitelistedTokenAt(uint256 index) public view returns (address) {
        return _whitelistedTokens[index];
    }

    function _addWhitelistedToken(address token) internal {
        if (token == address(0)) {
            revert InvalidTokenAddress();
        }

        if (_isWhitelistedToken[token]) {
            revert TokenAlreadyWhitelisted(token);
        }

        _isWhitelistedToken[token] = true;
        _whitelistedTokens.push(token);

        emit TokenWhitelisted(token);
        emit TokenWhitelistUpdated(token, true);
    }

    function _removeWhitelistedToken(address token) internal {
        if (!_isWhitelistedToken[token]) {
            revert TokenNotWhitelisted(token);
        }

        _isWhitelistedToken[token] = false;

        uint256 length = _whitelistedTokens.length;

        for (uint256 i = 0; i < length; i++) {
            if (_whitelistedTokens[i] == token) {
                _whitelistedTokens[i] = _whitelistedTokens[length - 1];
                _whitelistedTokens.pop();
                break;
            }
        }

        emit TokenRemovedFromWhitelist(token);
        emit TokenWhitelistUpdated(token, false);
    }

    function _setTokenWhitelisted(address token, bool allowed) internal {
        if (allowed) {
            _addWhitelistedToken(token);
        } else {
            _removeWhitelistedToken(token);
        }
    }

    function _addWhitelistedTokens(address[] calldata tokens) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            _addWhitelistedToken(tokens[i]);
        }
    }

    function _removeWhitelistedTokens(address[] calldata tokens) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            _removeWhitelistedToken(tokens[i]);
        }
    }

    function _checkTokenWhitelisted(address token) internal view {
        if (!_isWhitelistedToken[token]) {
            revert TokenNotWhitelisted(token);
        }
    }

    function _checkPoolTokensWhitelisted(PoolKey calldata key) internal view {
        
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        if (!_isWhitelistedToken[token0] || !_isWhitelistedToken[token1]) {
            revert PoolTokensNotWhitelisted(token0, token1);
        }
    }
}