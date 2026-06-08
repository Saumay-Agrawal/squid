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
import {PositionSummary, PositionPnL} from "../src/types/PositionMetrics.sol";

contract SquidTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    Squid internal hook;

    function setUp() public {
        deployFreshManagerAndRouters();

        uint160 flags = Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.AFTER_SWAP_FLAG;
        hook = Squid(address(uint160(type(uint160).max & clearAllHookPermissionsMask | flags)));
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
        assertEq(summary.liquidity.totalLiquidity, 0);
        assertEq(summary.liquidity.activeLiquidity, 0);
        assertEq(summary.liquidity.peakActiveLiquidity, 0);
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

    function test_addLiquidityUpdatesPoolLiquidityMetrics() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.liquidity.totalLiquidity, 1e18);
        assertEq(summary.liquidity.activeLiquidity, 1e18);
        assertEq(summary.liquidity.peakActiveLiquidity, 1e18);
    }

    function test_outOfRangeLiquidityOnlyAffectsTotalLiquidity() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.liquidity.totalLiquidity, 1e18);
        assertEq(summary.liquidity.activeLiquidity, 0);
        assertEq(summary.liquidity.peakActiveLiquidity, 0);
    }

    function test_removeLiquidityUpdatesTotalAndActiveLiquidity() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory addParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 3e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, addParams, "");

        ModifyLiquidityParams memory removeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, removeParams, "");

        PoolSummary memory summary = hook.getPoolSummary(poolKey.toId());
        assertEq(summary.liquidity.totalLiquidity, 2e18);
        assertEq(summary.liquidity.activeLiquidity, 2e18);
        assertEq(summary.liquidity.peakActiveLiquidity, 3e18);
    }

    function test_swapRefreshesActiveLiquidityAndPreservesPeak() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory currentRangeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory upperRangeParams =
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 2e18, salt: bytes32("beta")});

        modifyLiquidityRouter.modifyLiquidity(poolKey, currentRangeParams, "");
        modifyLiquidityRouter.modifyLiquidity(poolKey, upperRangeParams, "");

        PoolSummary memory beforeSwap = hook.getPoolSummary(poolKey.toId());
        assertEq(beforeSwap.liquidity.totalLiquidity, 3e18);
        assertEq(beforeSwap.liquidity.activeLiquidity, 1e18);
        assertEq(beforeSwap.liquidity.peakActiveLiquidity, 1e18);

        swap(poolKey, true, -1e18, "");

        PoolSummary memory afterSwap = hook.getPoolSummary(poolKey.toId());
        assertEq(afterSwap.liquidity.totalLiquidity, 3e18);
        assertEq(afterSwap.liquidity.activeLiquidity, 0);
        assertEq(afterSwap.liquidity.peakActiveLiquidity, 1e18);
    }

    function test_twapViewRevertsUntilOracleSupportExists() public {
        vm.expectRevert(SquidPoolMetrics.TwapNotSupported.selector);
        hook.getTwapSqrtPriceX96(PoolId.wrap(bytes32(0)), 30 minutes);
    }

    function test_afterAddLiquidityStoresPositionMetrics() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        bytes32 positionId =
            hook.getPositionId(address(modifyLiquidityRouter), poolKey.toId(), params.tickLower, params.tickUpper, params.salt);
        PositionSummary memory summary = hook.getPositionSummary(positionId);

        assertEq(summary.positionId, positionId);
        assertTrue(summary.initialized);
        assertTrue(summary.active);
        assertEq(summary.createdBlock, uint64(block.number));
        assertEq(summary.createdTimestamp, uint64(block.timestamp));
        assertEq(summary.updatedBlock, uint64(block.number));
        assertEq(summary.updatedTimestamp, uint64(block.timestamp));
        assertEq(summary.owner, address(modifyLiquidityRouter));
        assertEq(summary.poolId, PoolId.unwrap(poolKey.toId()));
        assertEq(summary.tickLower, params.tickLower);
        assertEq(summary.tickUpper, params.tickUpper);
        assertEq(summary.salt, params.salt);
    }

    function test_sameCanonicalPositionUpdatesSingleRecord() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        bytes32 positionId =
            hook.getPositionId(address(modifyLiquidityRouter), poolKey.toId(), params.tickLower, params.tickUpper, params.salt);
        PositionSummary memory initialSummary = hook.getPositionSummary(positionId);

        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        params.liquidityDelta = 2e18;
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        PositionSummary memory updatedSummary = hook.getPositionSummary(positionId);
        assertEq(updatedSummary.positionId, initialSummary.positionId);
        assertEq(updatedSummary.createdBlock, initialSummary.createdBlock);
        assertEq(updatedSummary.createdTimestamp, initialSummary.createdTimestamp);
        assertEq(updatedSummary.updatedBlock, uint64(block.number));
        assertEq(updatedSummary.updatedTimestamp, uint64(block.timestamp));
        assertTrue(updatedSummary.active);
    }

    function test_differentSaltCreatesDistinctPositionRecord() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory firstParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        ModifyLiquidityParams memory secondParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("beta")});

        modifyLiquidityRouter.modifyLiquidity(poolKey, firstParams, "");
        modifyLiquidityRouter.modifyLiquidity(poolKey, secondParams, "");

        bytes32 firstPositionId = hook.getPositionId(
            address(modifyLiquidityRouter), poolKey.toId(), firstParams.tickLower, firstParams.tickUpper, firstParams.salt
        );
        bytes32 secondPositionId = hook.getPositionId(
            address(modifyLiquidityRouter), poolKey.toId(), secondParams.tickLower, secondParams.tickUpper, secondParams.salt
        );

        assertTrue(firstPositionId != secondPositionId);
        assertEq(hook.getPositionSummary(firstPositionId).salt, firstParams.salt);
        assertEq(hook.getPositionSummary(secondPositionId).salt, secondParams.salt);
    }

    function test_positionRemainsActiveAfterPartialRemovalAndClosesAfterFullRemoval() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory addParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 3e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, addParams, "");

        bytes32 positionId = hook.getPositionId(
            address(modifyLiquidityRouter), poolKey.toId(), addParams.tickLower, addParams.tickUpper, addParams.salt
        );

        ModifyLiquidityParams memory partialRemoveParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, partialRemoveParams, "");
        assertTrue(hook.getPositionSummary(positionId).active);

        ModifyLiquidityParams memory fullRemoveParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -2e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, fullRemoveParams, "");
        assertFalse(hook.getPositionSummary(positionId).active);
    }

    function test_positionPnLOpenMatchesCurrentPositionState() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        bytes32 positionId =
            hook.getPositionId(address(modifyLiquidityRouter), poolKey.toId(), params.tickLower, params.tickUpper, params.salt);
        PositionPnL memory pnl = hook.getPositionPnL(positionId);

        assertGt(pnl.principalAmount0, 0);
        assertGt(pnl.principalAmount1, 0);
        assertEq(pnl.feeAccumulated0, 0);
        assertEq(pnl.feeAccumulated1, 0);
        assertApproxEqAbs(pnl.currentAmount0, pnl.principalAmount0, 1);
        assertApproxEqAbs(pnl.currentAmount1, pnl.principalAmount1, 1);
        assertApproxEqAbs(pnl.netPnl0, 0, 1);
        assertApproxEqAbs(pnl.netPnl1, 0, 1);
    }

    function test_positionPnLReducesPrincipalProRataOnPartialRemove() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory addParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 3e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, addParams, "");

        bytes32 positionId = hook.getPositionId(
            address(modifyLiquidityRouter), poolKey.toId(), addParams.tickLower, addParams.tickUpper, addParams.salt
        );
        PositionPnL memory beforeRemove = hook.getPositionPnL(positionId);

        ModifyLiquidityParams memory removeParams =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, removeParams, "");

        PositionPnL memory afterRemove = hook.getPositionPnL(positionId);
        assertEq(afterRemove.principalAmount0, beforeRemove.principalAmount0 - (beforeRemove.principalAmount0 / 3));
        assertEq(afterRemove.principalAmount1, beforeRemove.principalAmount1 - (beforeRemove.principalAmount1 / 3));
    }

    function test_positionPnLIncludesPendingFeesAfterSwap() public {
        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        PoolKey memory poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32("alpha")});
        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");
        swap(poolKey, true, -1e18, "");

        bytes32 positionId =
            hook.getPositionId(address(modifyLiquidityRouter), poolKey.toId(), params.tickLower, params.tickUpper, params.salt);
        PositionPnL memory pnl = hook.getPositionPnL(positionId);

        assertGt(pnl.feeAccumulated0 + pnl.feeAccumulated1, 0);
        assertTrue(pnl.currentAmount0 > pnl.principalAmount0 || pnl.currentAmount1 > pnl.principalAmount1);
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
