// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library TokenSymbolResolver {
    uint256 internal constant SYMBOL_CALL_GAS = 30_000;
    uint256 internal constant MAX_SYMBOL_LENGTH = 32;

    function resolve(address token) internal view returns (string memory) {
        if (token == address(0)) return "NATIVE";

        (bool success, bytes memory data) = token.staticcall{gas: SYMBOL_CALL_GAS}(abi.encodeWithSignature("symbol()"));
        if (!success) return "UNKNOWN";

        return _decodeSymbol(data);
    }

    function _decodeSymbol(bytes memory data) private pure returns (string memory) {
        if (data.length == 32) {
            return _decodeBytes32(data);
        }

        if (data.length < 64) return "UNKNOWN";

        uint256 offset;
        uint256 length;
        assembly ("memory-safe") {
            offset := mload(add(data, 0x20))
            length := mload(add(data, 0x40))
        }

        if (offset != 32 || length == 0 || length > MAX_SYMBOL_LENGTH || data.length < 64 + length) {
            return "UNKNOWN";
        }

        bytes memory symbolBytes = new bytes(length);
        for (uint256 i; i < length; ++i) {
            symbolBytes[i] = data[64 + i];
        }

        return string(symbolBytes);
    }

    function _decodeBytes32(bytes memory data) private pure returns (string memory) {
        bytes32 value;
        assembly ("memory-safe") {
            value := mload(add(data, 0x20))
        }

        uint256 length;
        while (length < 32 && value[length] != 0) {
            unchecked {
                ++length;
            }
        }

        if (length == 0) return "UNKNOWN";

        bytes memory symbolBytes = new bytes(length);
        for (uint256 i; i < length; ++i) {
            symbolBytes[i] = value[i];
        }

        return string(symbolBytes);
    }
}
