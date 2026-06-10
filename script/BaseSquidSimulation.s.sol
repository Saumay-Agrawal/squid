// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {SwapRouterNoChecks} from "@uniswap/v4-core/src/test/SwapRouterNoChecks.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolModifyLiquidityTestNoChecks} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTestNoChecks.sol";
import {PoolDonateTest} from "@uniswap/v4-core/src/test/PoolDonateTest.sol";
import {PoolTakeTest} from "@uniswap/v4-core/src/test/PoolTakeTest.sol";
import {PoolClaimsTest} from "@uniswap/v4-core/src/test/PoolClaimsTest.sol";
import {PoolNestedActionsTest} from "@uniswap/v4-core/src/test/PoolNestedActionsTest.sol";
import {ActionsRouter} from "@uniswap/v4-core/src/test/ActionsRouter.sol";
import {PoolAmounts, PoolLiquidity, PoolLPs, PoolPositions, PoolSummary, PoolTradeFlow} from "../src/types/PoolMetrics.sol";
import {PositionLiquidity, PositionPnL, PositionSummary} from "../src/types/PositionMetrics.sol";
import {Squid} from "../src/Squid.sol";
import {PoolModifyLiquidityTestWithMsgSender} from "../src/test/PoolModifyLiquidityTestWithMsgSender.sol";
import {BaseTestToken, MockUSDC} from "../test/helpers/TestTokens.sol";

abstract contract BaseSquidSimulation is Script, Deployers {
    using PoolIdLibrary for PoolKey;

    uint8 internal constant POOL_COUNT = 5;
    uint8 internal constant LP_COUNT = 8;
    uint8 internal constant TRADER_COUNT = 4;
    uint8 internal constant ACTION_PHASE_COUNT = 5;

    uint256 internal constant SMALL_USDC_BALANCE = 200_000 * 1e6;
    uint256 internal constant MEDIUM_USDC_BALANCE = 650_000 * 1e6;
    uint256 internal constant LARGE_USDC_BALANCE = 1_500_000 * 1e6;

    uint256 internal constant SMALL_ETH_BALANCE = 120 ether;
    uint256 internal constant MEDIUM_ETH_BALANCE = 325 ether;
    uint256 internal constant LARGE_ETH_BALANCE = 750 ether;

    struct PoolSeed {
        string label;
        uint24 fee;
        int24 tickSpacing;
        int24 initialTick;
        PoolKey key;
        bytes32 poolId;
    }

    struct LpSeed {
        address account;
        string label;
        string tier;
        string strategy;
        bool anchor;
        uint8 plannedPositions;
        uint256 usdcBalanceSeeded;
        uint256 ethBalanceSeeded;
    }

    struct TraderSeed {
        address account;
        string label;
        string strategy;
        uint8 preferredPoolIndex;
        bool netBuyEth;
        uint8 plannedSwaps;
        uint256 usdcBalanceSeeded;
        uint256 ethBalanceSeeded;
    }

    struct PositionSeed {
        string label;
        address lp;
        uint8 poolIndex;
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
        bytes32 positionId;
    }

    struct SwapSeed {
        string phase;
        string label;
        address trader;
        uint8 poolIndex;
        bool zeroForOne;
        int256 amountSpecified;
    }

    struct ScenarioAction {
        string phase;
        string actionType;
        string actor;
        uint8 poolIndex;
        int256 liquidityDelta;
        int256 amountSpecified;
        bool zeroForOne;
        bytes32 positionId;
    }

    Squid internal hook;
    PoolModifyLiquidityTestWithMsgSender internal msgSenderLiquidityRouter;
    MockUSDC internal usdcToken;

    address internal poolManagerOwner;
    address internal usdcMinter;

    PoolSeed[] internal poolSeeds;
    LpSeed[] internal lpSeeds;
    TraderSeed[] internal traderSeeds;
    PositionSeed[] internal positionSeeds;
    SwapSeed[] internal swapSeeds;
    ScenarioAction[] internal scenarioActions;

    function _resetSimulationState() internal {
        delete poolSeeds;
        delete lpSeeds;
        delete traderSeeds;
        delete positionSeeds;
        delete swapSeeds;
        delete scenarioActions;
        delete usdcToken;
    }

    function _setUpSimulation() internal {
        _deployScriptManagerAndRouters();

        uint160 flags = Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.AFTER_SWAP_FLAG;
        hook = Squid(address(uint160(type(uint160).max & clearAllHookPermissionsMask | flags)));
        deployCodeTo("Squid", abi.encode(manager), address(hook));

        msgSenderLiquidityRouter = new PoolModifyLiquidityTestWithMsgSender(manager);

        _deploySeedTokens();
        _seedLpRoster();
        _seedTraderRoster();
        _seedPoolConfigs();
        _prepareParticipants();
    }

    function _seedEnvironment() internal {
        _initializePools();
        _seedPositions();
        _runScenario();
    }

    function deployFreshManager() internal virtual override {
        poolManagerOwner = makeAddr("poolManagerOwner");
        manager = new PoolManager(poolManagerOwner);
    }

    function _deployScriptManagerAndRouters() internal {
        deployFreshManager();
        swapRouter = new PoolSwapTest(manager);
        swapRouterNoChecks = new SwapRouterNoChecks(manager);
        modifyLiquidityRouter = new PoolModifyLiquidityTest(manager);
        modifyLiquidityNoChecks = new PoolModifyLiquidityTestNoChecks(manager);
        donateRouter = new PoolDonateTest(manager);
        takeRouter = new PoolTakeTest(manager);
        claimsRouter = new PoolClaimsTest(manager);
        nestedActionRouter = new PoolNestedActionsTest(manager);
        feeController = makeAddr("feeController");
        actionsRouter = new ActionsRouter(manager);

        vm.prank(poolManagerOwner);
        manager.setProtocolFeeController(feeController);
    }

    function _deploySeedTokens() internal {
        usdcMinter = makeAddr("usdcMinter");
        usdcToken = new MockUSDC(usdcMinter);
    }

    function _seedLpRoster() internal {
        address[LP_COUNT + TRADER_COUNT] memory accounts = _anvilAccounts();
        uint8[LP_COUNT] memory positionCounts = [10, 9, 8, 6, 5, 4, 3, 2];
        string[LP_COUNT] memory strategies = [
            "anchor-wide",
            "anchor-staggered",
            "anchor-barbell",
            "active-mid",
            "active-ladder",
            "inventory-heavy",
            "defensive-wide",
            "tail-risk"
        ];

        for (uint8 i; i < LP_COUNT; ++i) {
            (uint256 usdcBalance, uint256 ethBalance, string memory tier) = _capitalProfileForLp(i);
            lpSeeds.push(
                LpSeed({
                    account: accounts[i],
                    label: string(abi.encodePacked("LP-", vm.toString(uint256(i + 1)))),
                    tier: tier,
                    strategy: strategies[i],
                    anchor: i < 3,
                    plannedPositions: positionCounts[i],
                    usdcBalanceSeeded: usdcBalance,
                    ethBalanceSeeded: ethBalance
                })
            );
        }
    }

    function _seedTraderRoster() internal {
        address[LP_COUNT + TRADER_COUNT] memory accounts = _anvilAccounts();

        traderSeeds.push(
            TraderSeed({
                account: accounts[LP_COUNT],
                label: "TR-1",
                strategy: "eth-momentum-buyer",
                preferredPoolIndex: 0,
                netBuyEth: true,
                plannedSwaps: 4,
                usdcBalanceSeeded: 900_000 * 1e6,
                ethBalanceSeeded: 80 ether
            })
        );
        traderSeeds.push(
            TraderSeed({
                account: accounts[LP_COUNT + 1],
                label: "TR-2",
                strategy: "eth-distributor",
                preferredPoolIndex: 2,
                netBuyEth: false,
                plannedSwaps: 4,
                usdcBalanceSeeded: 250_000 * 1e6,
                ethBalanceSeeded: 420 ether
            })
        );
        traderSeeds.push(
            TraderSeed({
                account: accounts[LP_COUNT + 2],
                label: "TR-3",
                strategy: "fee-arb-rotator",
                preferredPoolIndex: 1,
                netBuyEth: true,
                plannedSwaps: 5,
                usdcBalanceSeeded: 1_400_000 * 1e6,
                ethBalanceSeeded: 155 ether
            })
        );
        traderSeeds.push(
            TraderSeed({
                account: accounts[LP_COUNT + 3],
                label: "TR-4",
                strategy: "stress-seller",
                preferredPoolIndex: 4,
                netBuyEth: false,
                plannedSwaps: 3,
                usdcBalanceSeeded: 180_000 * 1e6,
                ethBalanceSeeded: 550 ether
            })
        );
    }

    function _seedPoolConfigs() internal {
        uint24[POOL_COUNT] memory fees = [uint24(500), uint24(1500), uint24(3000), uint24(5000), uint24(10000)];
        int24[POOL_COUNT] memory tickSpacings = [int24(10), int24(30), int24(60), int24(120), int24(200)];
        int24[POOL_COUNT] memory initialTicks =
            [int24(-196_800), int24(-196_560), int24(-196_260), int24(-196_080), int24(-195_800)];
        string[POOL_COUNT] memory labels = [
            "eth-usdc-tight",
            "eth-usdc-mid-tight",
            "eth-usdc-standard",
            "eth-usdc-wide",
            "eth-usdc-ultra-wide"
        ];

        for (uint8 i; i < POOL_COUNT; ++i) {
            PoolKey memory key = _buildPoolKey(address(0), address(usdcToken), fees[i], tickSpacings[i]);
            poolSeeds.push(
                PoolSeed({
                    label: labels[i],
                    fee: fees[i],
                    tickSpacing: tickSpacings[i],
                    initialTick: initialTicks[i],
                    key: key,
                    poolId: PoolId.unwrap(key.toId())
                })
            );
        }
    }

    function _prepareParticipants() internal {
        for (uint256 i; i < lpSeeds.length; ++i) {
            _prepareParticipant(lpSeeds[i].account, lpSeeds[i].usdcBalanceSeeded, lpSeeds[i].ethBalanceSeeded);
        }

        for (uint256 i; i < traderSeeds.length; ++i) {
            _prepareParticipant(
                traderSeeds[i].account, traderSeeds[i].usdcBalanceSeeded, traderSeeds[i].ethBalanceSeeded
            );
        }
    }

    function _prepareParticipant(address user, uint256 usdcBalance, uint256 ethBalance) internal {
        vm.prank(usdcMinter);
        usdcToken.mint(user, usdcBalance);
        vm.deal(user, ethBalance);

        vm.startPrank(user);
        BaseTestToken(address(usdcToken)).approve(address(swapRouter), type(uint256).max);
        BaseTestToken(address(usdcToken)).approve(address(msgSenderLiquidityRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _initializePools() internal {
        for (uint256 i; i < poolSeeds.length; ++i) {
            manager.initialize(poolSeeds[i].key, uint160(TickMath.getSqrtPriceAtTick(poolSeeds[i].initialTick)));
        }
    }

    function _seedPositions() internal {
        _recordPhaseMarker("bootstrap");

        for (uint8 lpIndex; lpIndex < LP_COUNT; ++lpIndex) {
            for (uint8 slot; slot < lpSeeds[lpIndex].plannedPositions; ++slot) {
                _seedPositionFor(lpIndex, slot, "bootstrap");
            }
        }
    }

    function _runScenario() internal {
        _runPriceDiscoveryPhase();
        _runHighFlowPhase();
        _runRebalancePhase();
        _runStressPhase();
        _runExitPhase();
    }

    function _runPriceDiscoveryPhase() internal {
        string memory phase = "price-discovery";
        _recordPhaseMarker(phase);

        _executeSwap(phase, "TR-1 early accumulation", traderSeeds[0], 0, false, -7_500 * 1e6);
        _executeSwap(phase, "TR-2 wide distribution", traderSeeds[1], 2, true, -3 ether);
        _executeSwap(phase, "TR-3 fee-tier probe", traderSeeds[2], 1, false, -6_500 * 1e6);
        _executeSwap(phase, "TR-4 defensive sale", traderSeeds[3], 4, true, -2 ether);
    }

    function _runHighFlowPhase() internal {
        string memory phase = "high-flow";
        _recordPhaseMarker(phase);

        _executeSwap(phase, "TR-1 tight follow-through", traderSeeds[0], 0, false, -9_000 * 1e6);
        _executeSwap(phase, "TR-3 mid-tight rotation", traderSeeds[2], 1, true, -2 ether);
        _executeSwap(phase, "TR-2 standard reload", traderSeeds[1], 2, false, -8_500 * 1e6);
        _executeSwap(phase, "TR-3 standard unwind", traderSeeds[2], 2, true, -2 ether);
    }

    function _runRebalancePhase() internal {
        string memory phase = "rebalance";
        _recordPhaseMarker(phase);

        _rebalancePosition(phase, 0, 0, int24(24), int24(-1), int256(18e14), "LP-1-rebalance-1");
        _rebalancePosition(phase, 3, 1, int24(14), int24(1), int256(12e14), "LP-4-rebalance-1");
        _partiallyExitPosition(phase, 1, 2, int256(16e14));
        _partiallyExitPosition(phase, 5, 1, int256(8e14));

        _executeSwap(phase, "TR-1 post-rebalance buy", traderSeeds[0], 0, false, -5_500 * 1e6);
        _executeSwap(phase, "TR-4 wide follow-up", traderSeeds[3], 3, true, -1 ether);
    }

    function _runStressPhase() internal {
        string memory phase = "stress";
        _recordPhaseMarker(phase);

        _executeSwap(phase, "TR-4 stress sale", traderSeeds[3], 4, true, -4 ether);
        _executeSwap(phase, "TR-2 standard pressure", traderSeeds[1], 2, true, -3 ether);
        _executeSwap(phase, "TR-3 opportunistic dip buy", traderSeeds[2], 1, false, -10_500 * 1e6);
    }

    function _runExitPhase() internal {
        string memory phase = "late-exit";
        _recordPhaseMarker(phase);

        _fullyExitPosition(phase, 7, 1);
        _fullyExitPosition(phase, 6, 0);
        _partiallyExitPosition(phase, 2, 3, int256(22e14));

        _executeSwap(phase, "TR-1 closing accumulation", traderSeeds[0], 0, false, -4_500 * 1e6);
        _executeSwap(phase, "TR-2 closeout sale", traderSeeds[1], 2, true, -1 ether);
    }

    function _seedPositionFor(uint8 lpIndex, uint8 slot, string memory phase) internal {
        LpSeed memory lp = lpSeeds[lpIndex];
        uint8 poolIndex = _poolIndexFor(lpIndex, slot, lp.anchor);
        int24 tickSpacing = poolSeeds[poolIndex].tickSpacing;
        int24 baseCenterUnits = poolSeeds[poolIndex].initialTick / tickSpacing;
        int24 widthUnits = _widthUnitsFor(lpIndex, slot, lp.anchor);
        int24 centerUnits = _centerUnitsFor(lpIndex, slot, lp.anchor);
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: (baseCenterUnits + centerUnits - widthUnits) * tickSpacing,
            tickUpper: (baseCenterUnits + centerUnits + widthUnits) * tickSpacing,
            liquidityDelta: int256(uint256(_liquidityFor(lpIndex, slot, lp.anchor))),
            salt: keccak256(abi.encodePacked("seed-position", lpIndex, slot))
        });

        _modifyLiquidityAs(lp.account, poolSeeds[poolIndex].key, params);
        _storePositionSeed(lp, poolIndex, params, _positionLabel(lp.label, slot));
        _recordLatestPositionOpen(phase, lp.label, poolIndex, params.liquidityDelta);
    }

    function _rebalancePosition(
        string memory phase,
        uint8 lpIndex,
        uint8 slot,
        int24 widthUnits,
        int24 centerUnits,
        int256 reopenLiquidity,
        string memory label
    ) internal {
        PositionSeed storage seededPosition = _positionSeedFor(lpSeeds[lpIndex].account, slot);
        _removeLiquidity(phase, lpSeeds[lpIndex].label, seededPosition, seededPosition.liquidityDelta / 2);

        int24 tickSpacing = poolSeeds[seededPosition.poolIndex].tickSpacing;
        int24 baseCenterUnits = poolSeeds[seededPosition.poolIndex].initialTick / tickSpacing;
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: (baseCenterUnits + centerUnits - widthUnits) * tickSpacing,
            tickUpper: (baseCenterUnits + centerUnits + widthUnits) * tickSpacing,
            liquidityDelta: reopenLiquidity,
            salt: keccak256(abi.encodePacked(label, block.chainid, positionSeeds.length))
        });

        _modifyLiquidityAs(lpSeeds[lpIndex].account, poolSeeds[seededPosition.poolIndex].key, params);
        _storePositionSeed(lpSeeds[lpIndex], seededPosition.poolIndex, params, label);
        _recordLatestPositionOpen(phase, lpSeeds[lpIndex].label, seededPosition.poolIndex, reopenLiquidity);
    }

    function _partiallyExitPosition(string memory phase, uint8 lpIndex, uint8 slot, int256 liquidityToRemove) internal {
        PositionSeed storage seededPosition = _positionSeedFor(lpSeeds[lpIndex].account, slot);
        _removeLiquidity(phase, lpSeeds[lpIndex].label, seededPosition, liquidityToRemove);
    }

    function _fullyExitPosition(string memory phase, uint8 lpIndex, uint8 slot) internal {
        PositionSeed storage seededPosition = _positionSeedFor(lpSeeds[lpIndex].account, slot);
        _removeLiquidity(phase, lpSeeds[lpIndex].label, seededPosition, seededPosition.liquidityDelta);
    }

    function _removeLiquidity(
        string memory phase,
        string memory actorLabel,
        PositionSeed storage seededPosition,
        int256 liquidityToRemove
    ) internal {
        if (liquidityToRemove <= 0) return;

        if (liquidityToRemove > seededPosition.liquidityDelta) {
            liquidityToRemove = seededPosition.liquidityDelta;
        }

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: seededPosition.tickLower,
            tickUpper: seededPosition.tickUpper,
            liquidityDelta: -liquidityToRemove,
            salt: seededPosition.salt
        });

        _modifyLiquidityAs(seededPosition.lp, poolSeeds[seededPosition.poolIndex].key, params);
        seededPosition.liquidityDelta -= liquidityToRemove;

        _recordScenarioAction(
            phase,
            liquidityToRemove == 0 ? "noop" : seededPosition.liquidityDelta == 0 ? "full-exit" : "partial-exit",
            actorLabel,
            seededPosition.poolIndex,
            -liquidityToRemove,
            0,
            false,
            seededPosition.positionId
        );
    }

    function _storePositionSeed(
        LpSeed memory lp,
        uint8 poolIndex,
        ModifyLiquidityParams memory params,
        string memory label
    ) internal {
        positionSeeds.push(
            PositionSeed({
                label: label,
                lp: lp.account,
                poolIndex: poolIndex,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityDelta: params.liquidityDelta,
                salt: params.salt,
                positionId: hook.getPositionId(
                    lp.account, poolSeeds[poolIndex].key.toId(), params.tickLower, params.tickUpper, params.salt
                )
            })
        );
    }

    function _recordLatestPositionOpen(string memory phase, string memory actor, uint8 poolIndex, int256 liquidityDelta)
        internal
    {
        PositionSeed storage seededPosition = positionSeeds[positionSeeds.length - 1];
        _recordScenarioAction(
            phase, "open-liquidity", actor, poolIndex, liquidityDelta, 0, false, seededPosition.positionId
        );
    }

    function _positionLabel(string memory lpLabel, uint8 slot) internal view returns (string memory) {
        return string(abi.encodePacked(lpLabel, "-p", vm.toString(uint256(slot + 1))));
    }

    function _executeSwap(
        string memory phase,
        string memory label,
        TraderSeed memory trader,
        uint8 poolIndex,
        bool zeroForOne,
        int256 amountSpecified
    ) internal {
        swapSeeds.push(
            SwapSeed({
                phase: phase,
                label: label,
                trader: trader.account,
                poolIndex: poolIndex,
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified
            })
        );

        vm.startPrank(trader.account);
        (uint160 currentSqrtPriceX96,,,) = hook.getCurrentPoolState(poolSeeds[poolIndex].key.toId());
        uint160 sqrtPriceLimitX96 = zeroForOne
            ? currentSqrtPriceX96 - uint160((currentSqrtPriceX96 - TickMath.MIN_SQRT_PRICE) / 4)
            : currentSqrtPriceX96 + uint160((TickMath.MAX_SQRT_PRICE - currentSqrtPriceX96) / 4);

        swapRouter.swap{value: zeroForOne ? uint256(-amountSpecified) : 0}(
            poolSeeds[poolIndex].key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        vm.stopPrank();

        _recordScenarioAction(phase, "swap", trader.label, poolIndex, 0, amountSpecified, zeroForOne, bytes32(0));
    }

    function _modifyLiquidityAs(address lp, PoolKey memory key, ModifyLiquidityParams memory params) internal {
        vm.startPrank(lp);

        if (params.liquidityDelta > 0) {
            msgSenderLiquidityRouter.modifyLiquidity{value: address(lp).balance}(key, params, "");
        } else {
            msgSenderLiquidityRouter.modifyLiquidity(key, params, "");
        }

        vm.stopPrank();
    }

    function _buildPoolKey(address tokenA, address tokenB, uint24 fee, int24 tickSpacing)
        internal
        view
        returns (PoolKey memory)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(hook))
        });
    }

    function _anvilAccounts() internal pure returns (address[LP_COUNT + TRADER_COUNT] memory accounts) {
        accounts[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        accounts[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        accounts[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        accounts[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        accounts[4] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        accounts[5] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        accounts[6] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
        accounts[7] = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;
        accounts[8] = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
        accounts[9] = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        accounts[10] = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
        accounts[11] = 0x71bE63f3384f5fb98995898A86B02Fb2426c5788;
    }

    function _capitalProfileForLp(uint8 lpIndex) internal pure returns (uint256 usdcBalance, uint256 ethBalance, string memory tier) {
        if (lpIndex < 3) return (LARGE_USDC_BALANCE, LARGE_ETH_BALANCE, "large");
        if (lpIndex < 6) return (MEDIUM_USDC_BALANCE, MEDIUM_ETH_BALANCE, "medium");
        return (SMALL_USDC_BALANCE, SMALL_ETH_BALANCE, "small");
    }

    function _poolIndexFor(uint8 lpIndex, uint8 slot, bool anchor) internal pure returns (uint8) {
        if (anchor) return uint8((lpIndex + slot) % POOL_COUNT);
        return uint8(((lpIndex * 3) + slot) % POOL_COUNT);
    }

    function _widthUnitsFor(uint8 lpIndex, uint8 slot, bool anchor) internal pure returns (int24) {
        uint8[5] memory anchorWidths = [uint8(28), uint8(18), uint8(12), uint8(22), uint8(15)];
        uint8[5] memory standardWidths = [uint8(18), uint8(12), uint8(9), uint8(14), uint8(7)];
        return int24(uint24(anchor ? anchorWidths[(lpIndex + slot) % 5] : standardWidths[(lpIndex + slot) % 5]));
    }

    function _centerUnitsFor(uint8 lpIndex, uint8 slot, bool anchor) internal pure returns (int24) {
        int24[5] memory anchorOffsets = [int24(0), int24(-1), int24(1), int24(0), int24(2)];
        int24[5] memory standardOffsets = [int24(0), int24(-2), int24(2), int24(-1), int24(1)];
        return anchor ? anchorOffsets[(lpIndex + slot) % 5] : standardOffsets[(lpIndex + slot) % 5];
    }

    function _liquidityFor(uint8 lpIndex, uint8 slot, bool anchor) internal pure returns (uint128) {
        uint128 base = anchor ? uint128(35e14) : uint128(14e14);
        uint128 tierBump = uint128(uint256(lpIndex < 3 ? 16e14 : lpIndex < 6 ? 8e14 : 3e14));
        uint128 slotBump = uint128(uint256((uint256(slot % 4) + 1) * 2e14));
        return base + tierBump + slotBump;
    }

    function _positionSeedFor(address lp, uint8 slot) internal view returns (PositionSeed storage seededPosition) {
        uint8 seen;
        for (uint256 i; i < positionSeeds.length; ++i) {
            if (positionSeeds[i].lp != lp) continue;
            if (seen == slot) return positionSeeds[i];
            unchecked {
                ++seen;
            }
        }

        revert("position seed not found");
    }

    function _recordPhaseMarker(string memory phase) internal {
        scenarioActions.push(
            ScenarioAction({
                phase: phase,
                actionType: "phase",
                actor: "system",
                poolIndex: type(uint8).max,
                liquidityDelta: 0,
                amountSpecified: 0,
                zeroForOne: false,
                positionId: bytes32(0)
            })
        );
    }

    function _recordScenarioAction(
        string memory phase,
        string memory actionType,
        string memory actor,
        uint8 poolIndex,
        int256 liquidityDelta,
        int256 amountSpecified,
        bool zeroForOne,
        bytes32 positionId
    ) internal {
        scenarioActions.push(
            ScenarioAction({
                phase: phase,
                actionType: actionType,
                actor: actor,
                poolIndex: poolIndex,
                liquidityDelta: liquidityDelta,
                amountSpecified: amountSpecified,
                zeroForOne: zeroForOne,
                positionId: positionId
            })
        );
    }

    function _writeArtifact() internal returns (string memory path) {
        string memory root = vm.projectRoot();
        string memory outputDir = string(abi.encodePacked(root, "/script/output"));
        path = string(abi.encodePacked(outputDir, "/anvil-simulation.json"));

        vm.writeJson(_artifactJson(), path);
    }

    function _artifactJson() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"format":"seed-v3",',
                '"runTimestamp":',
                vm.toString(block.timestamp),
                ',',
                '"chainId":',
                vm.toString(block.chainid),
                ',',
                '"contracts":',
                _contractsJson(),
                ',',
                '"seedManifest":',
                _seedManifestJson(),
                ',',
                '"market":',
                _marketJson(),
                ',',
                '"pools":',
                _poolsJson(),
                ',',
                '"positions":',
                _positionsJson(),
                "}"
            )
        );
    }

    function _contractsJson() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"poolManager":"',
                vm.toString(address(manager)),
                '",',
                '"squid":"',
                vm.toString(address(hook)),
                '",',
                '"modifyLiquidityRouter":"',
                vm.toString(address(msgSenderLiquidityRouter)),
                '",',
                '"swapRouter":"',
                vm.toString(address(swapRouter)),
                '",',
                '"swapRouterNoChecks":"',
                vm.toString(address(swapRouterNoChecks)),
                '",',
                '"actionsRouter":"',
                vm.toString(address(actionsRouter)),
                '"',
                "}"
            )
        );
    }

    function _seedManifestJson() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"description":"Deterministic ETH/USDC local market with seeded LP and trader personas for Squid demos.",',
                '"poolCount":',
                vm.toString(poolSeeds.length),
                ',',
                '"lpCount":',
                vm.toString(lpSeeds.length),
                ',',
                '"traderCount":',
                vm.toString(traderSeeds.length),
                ',',
                '"positionCount":',
                vm.toString(positionSeeds.length),
                ',',
                '"swapCount":',
                vm.toString(swapSeeds.length),
                ',',
                '"actionPhaseCount":',
                vm.toString(ACTION_PHASE_COUNT),
                ',',
                '"scenarioActionCount":',
                vm.toString(scenarioActions.length),
                ',',
                '"lpRoster":',
                _lpRosterJson(),
                ',',
                '"traderRoster":',
                _traderRosterJson(),
                "}"
            )
        );
    }

    function _marketJson() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"basePair":"ETH/USDC",',
                '"token0":"',
                vm.toString(address(0)),
                '",',
                '"token1":"',
                vm.toString(address(usdcToken)),
                '",',
                '"token0Symbol":"ETH",',
                '"token1Symbol":"USDC",',
                '"token0Decimals":18,',
                '"token1Decimals":6,',
                '"token0Native":true,',
                '"token1Native":false',
                "}"
            )
        );
    }

    function _lpRosterJson() internal view returns (string memory) {
        string memory rosterJson = "[";

        for (uint256 i; i < lpSeeds.length; ++i) {
            if (i > 0) rosterJson = string(abi.encodePacked(rosterJson, ","));
            rosterJson = string(
                abi.encodePacked(
                    rosterJson,
                    "{",
                    '"account":"',
                    vm.toString(lpSeeds[i].account),
                    '",',
                    '"label":"',
                    lpSeeds[i].label,
                    '",',
                    '"role":"lp",',
                    '"tier":"',
                    lpSeeds[i].tier,
                    '",',
                    '"strategy":"',
                    lpSeeds[i].strategy,
                    '",',
                    '"anchor":',
                    _boolToString(lpSeeds[i].anchor),
                    ',',
                    '"plannedPositions":',
                    vm.toString(uint256(lpSeeds[i].plannedPositions)),
                    ',',
                    '"usdcBalanceSeeded":',
                    vm.toString(lpSeeds[i].usdcBalanceSeeded),
                    ',',
                    '"ethBalanceSeeded":',
                    vm.toString(lpSeeds[i].ethBalanceSeeded),
                    "}"
                )
            );
        }

        return string(abi.encodePacked(rosterJson, "]"));
    }

    function _traderRosterJson() internal view returns (string memory) {
        string memory rosterJson = "[";

        for (uint256 i; i < traderSeeds.length; ++i) {
            if (i > 0) rosterJson = string(abi.encodePacked(rosterJson, ","));
            rosterJson = string(
                abi.encodePacked(
                    rosterJson,
                    "{",
                    '"account":"',
                    vm.toString(traderSeeds[i].account),
                    '",',
                    '"label":"',
                    traderSeeds[i].label,
                    '",',
                    '"role":"trader",',
                    '"strategy":"',
                    traderSeeds[i].strategy,
                    '",',
                    '"preferredPoolIndex":',
                    vm.toString(uint256(traderSeeds[i].preferredPoolIndex)),
                    ',',
                    '"netBuyEth":',
                    _boolToString(traderSeeds[i].netBuyEth),
                    ',',
                    '"plannedSwaps":',
                    vm.toString(uint256(traderSeeds[i].plannedSwaps)),
                    ',',
                    '"usdcBalanceSeeded":',
                    vm.toString(traderSeeds[i].usdcBalanceSeeded),
                    ',',
                    '"ethBalanceSeeded":',
                    vm.toString(traderSeeds[i].ethBalanceSeeded),
                    "}"
                )
            );
        }

        return string(abi.encodePacked(rosterJson, "]"));
    }

    function _poolSeedManifestJson() internal view returns (string memory) {
        string memory poolsJson = "[";

        for (uint256 i; i < poolSeeds.length; ++i) {
            if (i > 0) poolsJson = string(abi.encodePacked(poolsJson, ","));
            poolsJson = string(
                abi.encodePacked(
                    poolsJson,
                    "{",
                    '"index":',
                    vm.toString(i),
                    ',',
                    '"label":"',
                    poolSeeds[i].label,
                    '",',
                    '"poolId":"',
                    vm.toString(poolSeeds[i].poolId),
                    '",',
                    '"fee":',
                    vm.toString(poolSeeds[i].fee),
                    ',',
                    '"tickSpacing":',
                    vm.toString(int256(poolSeeds[i].tickSpacing)),
                    ',',
                    '"initialTick":',
                    vm.toString(int256(poolSeeds[i].initialTick)),
                    "}"
                )
            );
        }

        return string(abi.encodePacked(poolsJson, "]"));
    }

    function _positionSeedManifestJson() internal view returns (string memory) {
        string memory positionsJson = "[";

        for (uint256 i; i < positionSeeds.length; ++i) {
            if (i > 0) positionsJson = string(abi.encodePacked(positionsJson, ","));
            positionsJson = string(
                abi.encodePacked(
                    positionsJson,
                    "{",
                    '"label":"',
                    positionSeeds[i].label,
                    '",',
                    '"lp":"',
                    vm.toString(positionSeeds[i].lp),
                    '",',
                    '"poolIndex":',
                    vm.toString(uint256(positionSeeds[i].poolIndex)),
                    ',',
                    '"tickLower":',
                    vm.toString(int256(positionSeeds[i].tickLower)),
                    ',',
                    '"tickUpper":',
                    vm.toString(int256(positionSeeds[i].tickUpper)),
                    ',',
                    '"liquidityDelta":',
                    vm.toString(positionSeeds[i].liquidityDelta),
                    ',',
                    '"salt":"',
                    vm.toString(positionSeeds[i].salt),
                    '",',
                    '"positionId":"',
                    vm.toString(positionSeeds[i].positionId),
                    '"',
                    "}"
                )
            );
        }

        return string(abi.encodePacked(positionsJson, "]"));
    }

    function _swapSeedManifestJson() internal view returns (string memory) {
        string memory swapsJson = "[";

        for (uint256 i; i < swapSeeds.length; ++i) {
            if (i > 0) swapsJson = string(abi.encodePacked(swapsJson, ","));
            swapsJson = string(
                abi.encodePacked(
                    swapsJson,
                    "{",
                    '"phase":"',
                    swapSeeds[i].phase,
                    '",',
                    '"label":"',
                    swapSeeds[i].label,
                    '",',
                    '"trader":"',
                    vm.toString(swapSeeds[i].trader),
                    '",',
                    '"poolIndex":',
                    vm.toString(uint256(swapSeeds[i].poolIndex)),
                    ',',
                    '"zeroForOne":',
                    _boolToString(swapSeeds[i].zeroForOne),
                    ',',
                    '"amountSpecified":',
                    vm.toString(swapSeeds[i].amountSpecified),
                    "}"
                )
            );
        }

        return string(abi.encodePacked(swapsJson, "]"));
    }

    function _scenarioActionsJson() internal view returns (string memory) {
        string memory actionsJson = "[";

        for (uint256 i; i < scenarioActions.length; ++i) {
            if (i > 0) actionsJson = string(abi.encodePacked(actionsJson, ","));
            actionsJson = string(
                abi.encodePacked(
                    actionsJson,
                    "{",
                    '"phase":"',
                    scenarioActions[i].phase,
                    '",',
                    '"actionType":"',
                    scenarioActions[i].actionType,
                    '",',
                    '"actor":"',
                    scenarioActions[i].actor,
                    '",',
                    '"poolIndex":',
                    scenarioActions[i].poolIndex == type(uint8).max
                        ? "255"
                        : vm.toString(uint256(scenarioActions[i].poolIndex)),
                    ',',
                    '"liquidityDelta":',
                    vm.toString(scenarioActions[i].liquidityDelta),
                    ',',
                    '"amountSpecified":',
                    vm.toString(scenarioActions[i].amountSpecified),
                    ',',
                    '"zeroForOne":',
                    _boolToString(scenarioActions[i].zeroForOne),
                    ',',
                    '"positionId":"',
                    vm.toString(scenarioActions[i].positionId),
                    '"',
                    "}"
                )
            );
        }

        return string(abi.encodePacked(actionsJson, "]"));
    }

    function _poolsJson() internal view returns (string memory) {
        string memory poolsJson = "[";

        for (uint256 i; i < poolSeeds.length; ++i) {
            if (i > 0) poolsJson = string(abi.encodePacked(poolsJson, ","));
            poolsJson = string(abi.encodePacked(poolsJson, _poolSnapshotJson(i)));
        }

        return string(abi.encodePacked(poolsJson, "]"));
    }

    function _poolSnapshotJson(uint256 poolIndex) internal view returns (string memory) {
        PoolSeed storage pool = poolSeeds[poolIndex];
        PoolSummary memory poolSummary = hook.getPoolSummary(pool.key.toId());
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = hook.getCurrentPoolState(pool.key.toId());

        return string(
            abi.encodePacked(
                "{",
                '"index":',
                vm.toString(poolIndex),
                ',',
                '"label":"',
                pool.label,
                '",',
                '"poolId":"',
                vm.toString(pool.poolId),
                '",',
                '"config":',
                _poolConfigJson(pool),
                ',',
                '"lpAddresses":',
                _poolLpAddressesJson(uint8(poolIndex)),
                ',',
                '"finalState":{',
                '"poolSummary":',
                _poolSummaryJson(poolSummary),
                ',',
                '"currentPoolState":',
                _currentPoolStateJson(sqrtPriceX96, tick, protocolFee, lpFee),
                '}',
                "}"
            )
        );
    }

    function _poolConfigJson(PoolSeed storage pool) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"fee":',
                vm.toString(pool.fee),
                ',',
                '"tickSpacing":',
                vm.toString(int256(pool.tickSpacing)),
                ',',
                '"initialTick":',
                vm.toString(int256(pool.initialTick)),
                ',',
                '"hook":"',
                vm.toString(address(pool.key.hooks)),
                '"',
                "}"
            )
        );
    }

    function _poolLpAddressesJson(uint8 poolIndex) internal view returns (string memory) {
        string memory lpsJson = "[";
        bool first = true;

        for (uint256 i; i < lpSeeds.length; ++i) {
            if (!_lpHasPoolPosition(lpSeeds[i].account, poolIndex)) continue;
            if (!first) lpsJson = string(abi.encodePacked(lpsJson, ","));
            lpsJson = string(abi.encodePacked(lpsJson, '"', vm.toString(lpSeeds[i].account), '"'));
            first = false;
        }

        return string(abi.encodePacked(lpsJson, "]"));
    }

    function _positionsJson() internal view returns (string memory) {
        string memory positionsJson = "[";

        for (uint256 i; i < positionSeeds.length; ++i) {
            if (i > 0) positionsJson = string(abi.encodePacked(positionsJson, ","));
            positionsJson = string(abi.encodePacked(positionsJson, _positionSnapshotJson(positionSeeds[i])));
        }

        return string(abi.encodePacked(positionsJson, "]"));
    }

    function _positionSnapshotJson(PositionSeed storage position) internal view returns (string memory) {
        PositionSummary memory summary = hook.getPositionSummary(position.positionId);
        PositionLiquidity memory liquidity = hook.getPositionLiquidity(position.positionId);
        PositionPnL memory pnl = hook.getPositionPnL(position.positionId);

        return string(
            abi.encodePacked(
                "{",
                '"label":"',
                position.label,
                '",',
                '"lp":"',
                vm.toString(position.lp),
                '",',
                '"poolIndex":',
                vm.toString(uint256(position.poolIndex)),
                ',',
                '"poolLabel":"',
                poolSeeds[position.poolIndex].label,
                '",',
                '"positionId":"',
                vm.toString(position.positionId),
                '",',
                '"tickLower":',
                vm.toString(int256(position.tickLower)),
                ',',
                '"tickUpper":',
                vm.toString(int256(position.tickUpper)),
                ',',
                '"salt":"',
                vm.toString(position.salt),
                '",',
                '"seedLiquidityDelta":',
                vm.toString(position.liquidityDelta),
                ',',
                '"summary":',
                _positionSummaryJson(summary),
                ',',
                '"liquidity":',
                _positionLiquidityJson(liquidity),
                ',',
                '"pnl":',
                _positionPnlJson(pnl),
                "}"
            )
        );
    }

    function _poolSummaryJson(PoolSummary memory summary) internal view returns (string memory) {
        string memory metadataJson = string(
            abi.encodePacked(
                "{",
                '"poolId":"',
                vm.toString(summary.poolId),
                '",',
                '"initialized":',
                _boolToString(summary.initialized),
                ',',
                '"initializedBlock":',
                vm.toString(summary.initializedBlock),
                ',',
                '"initializedTimestamp":',
                vm.toString(summary.initializedTimestamp),
                ',',
                '"token0":"',
                vm.toString(summary.token0),
                '",',
                '"token1":"',
                vm.toString(summary.token1),
                '",',
                '"token0Symbol":"',
                summary.token0Symbol,
                '",',
                '"token1Symbol":"',
                summary.token1Symbol,
                '"'
            )
        );

        string memory metricsJson = string(
            abi.encodePacked(
                ',',
                '"fee":',
                vm.toString(summary.fee),
                ',',
                '"tickSpacing":',
                vm.toString(int256(summary.tickSpacing)),
                ',',
                '"initialSqrtPriceX96":',
                vm.toString(summary.initialSqrtPriceX96),
                ',',
                '"amounts":',
                _poolAmountsJson(summary.amounts),
                ',',
                '"liquidity":',
                _poolLiquidityJson(summary.liquidity),
                ',',
                '"lps":',
                _poolLpsJson(summary.lps),
                ',',
                '"positions":',
                _poolPositionsJson(summary.positions),
                ',',
                '"tradeFlow":',
                _poolTradeFlowJson(summary.tradeFlow),
                "}"
            )
        );

        return string(abi.encodePacked(metadataJson, metricsJson));
    }

    function _poolAmountsJson(PoolAmounts memory amounts) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"initialToken0Amount":',
                vm.toString(amounts.initialToken0Amount),
                ',',
                '"initialToken1Amount":',
                vm.toString(amounts.initialToken1Amount),
                ',',
                '"currentToken0Amount":',
                vm.toString(amounts.currentToken0Amount),
                ',',
                '"currentToken1Amount":',
                vm.toString(amounts.currentToken1Amount),
                ',',
                '"totalFeeAccruedToken0":',
                vm.toString(amounts.totalFeeAccruedToken0),
                ',',
                '"totalFeeAccruedToken1":',
                vm.toString(amounts.totalFeeAccruedToken1),
                "}"
            )
        );
    }

    function _poolLiquidityJson(PoolLiquidity memory liquidity) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"totalLiquidity":',
                vm.toString(liquidity.totalLiquidity),
                ',',
                '"activeLiquidity":',
                vm.toString(liquidity.activeLiquidity),
                ',',
                '"peakActiveLiquidity":',
                vm.toString(liquidity.peakActiveLiquidity),
                ',',
                '"totalLiquidityAtPeakActive":',
                vm.toString(liquidity.totalLiquidityAtPeakActive),
                ',',
                '"liquidityUtilisationBps":',
                vm.toString(liquidity.liquidityUtilisationBps),
                ',',
                '"peakLiquidityUtilisationBps":',
                vm.toString(liquidity.peakLiquidityUtilisationBps),
                "}"
            )
        );
    }

    function _poolLpsJson(PoolLPs memory lps) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"activeLpCount":',
                vm.toString(lps.activeLpCount),
                ',',
                '"lifetimeLpCount":',
                vm.toString(lps.lifetimeLpCount),
                ',',
                '"lpRetentionBps":',
                vm.toString(lps.lpRetentionBps),
                "}"
            )
        );
    }

    function _poolPositionsJson(PoolPositions memory positions) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"activePositionCount":',
                vm.toString(positions.activePositionCount),
                ',',
                '"totalPositionCount":',
                vm.toString(positions.totalPositionCount),
                ',',
                '"activePositionPercentageBps":',
                vm.toString(positions.activePositionPercentageBps),
                "}"
            )
        );
    }

    function _poolTradeFlowJson(PoolTradeFlow memory tradeFlow) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"totalSwapCount":',
                vm.toString(tradeFlow.totalSwapCount),
                ',',
                '"zeroToOneSwapCount":',
                vm.toString(tradeFlow.zeroToOneSwapCount),
                ',',
                '"oneToZeroSwapCount":',
                vm.toString(tradeFlow.oneToZeroSwapCount),
                ',',
                '"flowSkewnessBps":',
                vm.toString(tradeFlow.flowSkewnessBps),
                "}"
            )
        );
    }

    function _currentPoolStateJson(uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
        internal
        view
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                "{",
                '"sqrtPriceX96":',
                vm.toString(sqrtPriceX96),
                ',',
                '"tick":',
                vm.toString(int256(tick)),
                ',',
                '"protocolFee":',
                vm.toString(protocolFee),
                ',',
                '"lpFee":',
                vm.toString(lpFee),
                "}"
            )
        );
    }

    function _positionSummaryJson(PositionSummary memory summary) internal view returns (string memory) {
        string memory prefix = string(
            abi.encodePacked(
                "{",
                '"positionId":"',
                vm.toString(summary.positionId),
                '",',
                '"initialized":',
                _boolToString(summary.initialized),
                ',',
                '"active":',
                _boolToString(summary.active),
                ',',
                '"age":',
                vm.toString(summary.age),
                ',',
                '"createdBlock":',
                vm.toString(summary.createdBlock),
                ',',
                '"createdTimestamp":',
                vm.toString(summary.createdTimestamp),
                ',',
                '"updatedBlock":',
                vm.toString(summary.updatedBlock),
                ',',
                '"updatedTimestamp":',
                vm.toString(summary.updatedTimestamp)
            )
        );

        string memory suffix = string(
            abi.encodePacked(
                ',',
                '"owner":"',
                vm.toString(summary.owner),
                '",',
                '"coreOwner":"',
                vm.toString(summary.coreOwner),
                '",',
                '"poolId":"',
                vm.toString(summary.poolId),
                '",',
                '"tickLower":',
                vm.toString(int256(summary.tickLower)),
                ',',
                '"tickUpper":',
                vm.toString(int256(summary.tickUpper)),
                ',',
                '"salt":"',
                vm.toString(summary.salt),
                '"',
                "}"
            )
        );

        return string(abi.encodePacked(prefix, suffix));
    }

    function _positionLiquidityJson(PositionLiquidity memory liquidity) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"totalLiquidity":',
                vm.toString(liquidity.totalLiquidity),
                ',',
                '"activeLiquidity":',
                vm.toString(liquidity.activeLiquidity),
                ',',
                '"activeSwapVolume0":',
                vm.toString(liquidity.activeSwapVolume0),
                ',',
                '"activeSwapVolume1":',
                vm.toString(liquidity.activeSwapVolume1),
                ',',
                '"lifetimeSwapVolume0":',
                vm.toString(liquidity.lifetimeSwapVolume0),
                ',',
                '"lifetimeSwapVolume1":',
                vm.toString(liquidity.lifetimeSwapVolume1),
                "}"
            )
        );
    }

    function _positionPnlJson(PositionPnL memory pnl) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"principalAmount0":',
                vm.toString(pnl.principalAmount0),
                ',',
                '"principalAmount1":',
                vm.toString(pnl.principalAmount1),
                ',',
                '"currentAmount0":',
                vm.toString(pnl.currentAmount0),
                ',',
                '"currentAmount1":',
                vm.toString(pnl.currentAmount1),
                ',',
                '"feeAccumulated0":',
                vm.toString(pnl.feeAccumulated0),
                ',',
                '"feeAccumulated1":',
                vm.toString(pnl.feeAccumulated1),
                ',',
                '"netPnl0":',
                vm.toString(pnl.netPnl0),
                ',',
                '"netPnl1":',
                vm.toString(pnl.netPnl1),
                "}"
            )
        );
    }

    function _lpHasPoolPosition(address lp, uint8 poolIndex) internal view returns (bool) {
        for (uint256 i; i < positionSeeds.length; ++i) {
            if (positionSeeds[i].lp == lp && positionSeeds[i].poolIndex == poolIndex) return true;
        }
        return false;
    }

    function _boolToString(bool value) internal pure returns (string memory) {
        return value ? "true" : "false";
    }

    function _printSummary(string memory artifactPath) internal view {
        console2.log("Squid simulation artifact:", artifactPath);
        console2.log("PoolManager:", address(manager));
        console2.log("Squid:", address(hook));
        console2.log("USDC:", address(usdcToken));
        console2.log("Seeded pools:", poolSeeds.length);
        console2.log("Seeded LPs:", lpSeeds.length);
        console2.log("Seeded traders:", traderSeeds.length);
        console2.log("Tracked positions:", positionSeeds.length);
        console2.log("Tracked swaps:", swapSeeds.length);
    }
}
