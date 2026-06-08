// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {Squid} from "../src/Squid.sol";
import {SquidPoolMetrics} from "../src/base/SquidPoolMetrics.sol";
import {PoolSummary} from "../src/types/PoolMetrics.sol";

contract SquidTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    Squid internal hook;

    function setUp() public {
        deployFreshManagerAndRouters();

        hook = Squid(address(uint160(type(uint160).max & clearAllHookPermissionsMask | Hooks.AFTER_INITIALIZE_FLAG)));
        deployCodeTo("Squid", abi.encode(manager), address(hook));
    }

    function test_afterInitializeStoresPoolMetrics() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        Bytes32SymbolToken tokenB = new Bytes32SymbolToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        uint160 initialPrice = uint160(TickMath.getSqrtPriceAtTick(120));

        manager.initialize(poolKey, initialPrice);

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.poolId, PoolId.unwrap(poolKey.toId()));
        assertTrue(summary.initialized);
        assertEq(summary.initializedBlock, uint64(block.number));
        assertEq(summary.initializedTimestamp, uint64(block.timestamp));
        assertEq(summary.token0, address(tokenA));
        assertEq(summary.token1, address(tokenB));
        assertEq(summary.token0Symbol, "TKNA");
        assertEq(summary.token1Symbol, "TKNB");
        assertEq(summary.fee, poolKey.fee);
        assertEq(summary.tickSpacing, poolKey.tickSpacing);
        assertEq(summary.initialSqrtPriceX96, initialPrice);
    }

    function test_symbolFallbacksDoNotBlockInitialization() public {
        RevertingSymbolToken tokenA = new RevertingSymbolToken("Token A");
        MissingSymbolToken tokenB = new MissingSymbolToken("Token B");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.token0Symbol, "UNKNOWN");
        assertEq(summary.token1Symbol, "UNKNOWN");
    }

    function test_currentPriceReadsLivePoolState() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        PoolId poolId = poolKey.toId();
        uint160 initialPrice = uint160(TickMath.getSqrtPriceAtTick(0));

        manager.initialize(poolKey, initialPrice);

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32(0)});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        swap(poolKey, true, -1e16, "");

        (uint160 currentSqrtPriceX96,,,) = hook.getCurrentPoolState(poolId);
        assertTrue(currentSqrtPriceX96 != initialPrice);
        assertEq(hook.getCurrentSqrtPriceX96(poolId), currentSqrtPriceX96);

        PoolSummary memory stored = hook.getPoolSummary(poolId);
        assertEq(stored.initialSqrtPriceX96, initialPrice);
    }

    function test_twapViewRevertsUntilOracleSupportExists() public {
        vm.expectRevert(SquidPoolMetrics.TwapNotSupported.selector);
        hook.getTwapSqrtPriceX96(PoolId.wrap(bytes32(0)), 30 minutes);
    }

    function _buildPoolKey(address tokenA, address tokenB) internal view returns (PoolKey memory) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
    }

    function _mintAndApprove(address token) internal {
        BaseTestToken(token).mint(address(this), 1 << 120);
        BaseTestToken(token).approve(address(swapRouter), type(uint256).max);
        BaseTestToken(token).approve(address(swapRouterNoChecks), type(uint256).max);
        BaseTestToken(token).approve(address(modifyLiquidityRouter), type(uint256).max);
        BaseTestToken(token).approve(address(modifyLiquidityNoChecks), type(uint256).max);
        BaseTestToken(token).approve(address(donateRouter), type(uint256).max);
        BaseTestToken(token).approve(address(takeRouter), type(uint256).max);
        BaseTestToken(token).approve(address(claimsRouter), type(uint256).max);
        BaseTestToken(token).approve(address(nestedActionRouter.executor()), type(uint256).max);
        BaseTestToken(token).approve(address(actionsRouter), type(uint256).max);
    }
}

contract BaseTestToken {
    string public name;
    uint8 public immutable DECIMALS = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name) {
        name = _name;
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

    function mint(address to, uint256 amount) external {
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
