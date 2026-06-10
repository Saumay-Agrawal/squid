// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BaseTestToken {
    string public name;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name) {
        name = _name;
    }

    function decimals() public pure virtual returns (uint8) {
        return 18;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        return true;
    }

    function mint(address to, uint256 amount) external virtual {
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
    }
}

contract TestToken is BaseTestToken {
    string internal tokenSymbol;

    constructor(string memory _name, string memory _symbol) BaseTestToken(_name) {
        tokenSymbol = _symbol;
    }

    function symbol() external view returns (string memory) {
        return tokenSymbol;
    }
}

contract Bytes32SymbolToken is BaseTestToken {
    bytes32 internal tokenSymbol;

    constructor(string memory _name, bytes32 _symbol) BaseTestToken(_name) {
        tokenSymbol = _symbol;
    }

    function symbol() external view returns (bytes32) {
        return tokenSymbol;
    }
}

contract RevertingSymbolToken is BaseTestToken {
    constructor(string memory _name) BaseTestToken(_name) {}

    function symbol() external pure returns (string memory) {
        revert("symbol unavailable");
    }
}

contract MissingSymbolToken is BaseTestToken {
    constructor(string memory _name) BaseTestToken(_name) {}
}

contract MockUSDC is BaseTestToken {
    address public immutable minter;

    error UnauthorizedMinter(address caller);

    constructor(address _minter) BaseTestToken("Mock USD Coin") {
        minter = _minter;
    }

    function symbol() external pure returns (string memory) {
        return "USDC";
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external override {
        if (msg.sender != minter) revert UnauthorizedMinter(msg.sender);

        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
    }
}
