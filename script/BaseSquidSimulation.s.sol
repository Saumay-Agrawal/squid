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
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
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
import {PoolLiquidity, PoolLPs, PoolPositions, PoolSummary, PoolTradeFlow} from "../src/types/PoolMetrics.sol";
import {PositionLiquidity, PositionPnL, PositionSummary} from "../src/types/PositionMetrics.sol";
import {Squid} from "../src/Squid.sol";
import {PoolModifyLiquidityTestWithMsgSender} from "../src/test/PoolModifyLiquidityTestWithMsgSender.sol";
import {BaseTestToken, TestToken} from "../test/helpers/TestTokens.sol";

abstract contract BaseSquidSimulation is Script, Deployers {
    using PoolIdLibrary for PoolKey;

    uint8 internal constant POOL_COUNT = 5;
    uint8 internal constant LP_COUNT = 10;
    int24 internal constant INITIAL_TICK = 0;
    uint256 internal constant SMALL_TIER_BALANCE = 250_000 ether;
    uint256 internal constant MEDIUM_TIER_BALANCE = 750_000 ether;
    uint256 internal constant LARGE_TIER_BALANCE = 2_000_000 ether;

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
        bool anchor;
        uint8 plannedPositions;
        uint256 usdBalanceSeeded;
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
        string label;
        address trader;
        uint8 poolIndex;
        bool zeroForOne;
        int256 amountSpecified;
    }

    Squid internal hook;
    PoolModifyLiquidityTestWithMsgSender internal msgSenderLiquidityRouter;
    TestToken internal usdToken;
    TestToken internal ethToken;

    address internal poolManagerOwner;
    address internal swapActor;

    PoolSeed[] internal poolSeeds;
    LpSeed[] internal lpSeeds;
    PositionSeed[] internal positionSeeds;
    SwapSeed[] internal swapSeeds;

    function _resetSimulationState() internal {
        delete poolSeeds;
        delete lpSeeds;
        delete positionSeeds;
        delete swapSeeds;
        delete usdToken;
        delete ethToken;
        delete swapActor;
    }

    function _setUpSimulation() internal {
        _deployScriptManagerAndRouters();

        uint160 flags = Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.AFTER_SWAP_FLAG;
        hook = Squid(address(uint160(type(uint160).max & clearAllHookPermissionsMask | flags)));
        deployCodeTo("Squid", abi.encode(manager), address(hook));

        msgSenderLiquidityRouter = new PoolModifyLiquidityTestWithMsgSender(manager);
        swapActor = address(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65);

        _deploySeedTokens();
        _seedLpRoster();
        _seedPoolConfigs();
        _prepareParticipants();
    }

    function _seedEnvironment() internal {
        _initializePools();
        _seedPositions();
        _seedSwaps();
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
        usdToken = new TestToken("Seed USD", "USD");
        ethToken = new TestToken("Seed ETH", "ETH");
    }

    function _seedLpRoster() internal {
        address[LP_COUNT] memory accounts = _anvilAccounts();
        uint8[LP_COUNT] memory positionCounts = [10, 9, 8, 6, 5, 4, 4, 3, 3, 2];

        for (uint8 i; i < LP_COUNT; ++i) {
            uint256 balance = _tierBalanceForIndex(i);
            lpSeeds.push(
                LpSeed({
                    account: accounts[i],
                    label: string(abi.encodePacked("LP-", vm.toString(uint256(i + 1)))),
                    tier: _tierNameForIndex(i),
                    anchor: i < 3,
                    plannedPositions: positionCounts[i],
                    usdBalanceSeeded: balance,
                    ethBalanceSeeded: balance
                })
            );
        }
    }

    function _seedPoolConfigs() internal {
        uint24[POOL_COUNT] memory fees = [uint24(500), uint24(1500), uint24(3000), uint24(5000), uint24(10000)];
        int24[POOL_COUNT] memory tickSpacings = [int24(10), int24(30), int24(60), int24(120), int24(200)];
        string[POOL_COUNT] memory labels = [
            "usd-eth-tight",
            "usd-eth-mid-tight",
            "usd-eth-standard",
            "usd-eth-wide",
            "usd-eth-ultra-wide"
        ];

        for (uint8 i; i < POOL_COUNT; ++i) {
            PoolKey memory key = _buildPoolKey(address(usdToken), address(ethToken), fees[i], tickSpacings[i]);
            poolSeeds.push(
                PoolSeed({
                    label: labels[i],
                    fee: fees[i],
                    tickSpacing: tickSpacings[i],
                    initialTick: INITIAL_TICK,
                    key: key,
                    poolId: PoolId.unwrap(key.toId())
                })
            );
        }
    }

    function _prepareParticipants() internal {
        _prepareParticipant(swapActor, SMALL_TIER_BALANCE);

        for (uint256 i; i < lpSeeds.length; ++i) {
            _prepareParticipant(lpSeeds[i].account, lpSeeds[i].usdBalanceSeeded);
        }
    }

    function _prepareParticipant(address user, uint256 balancePerToken) internal {
        BaseTestToken(address(usdToken)).mint(user, balancePerToken);
        BaseTestToken(address(ethToken)).mint(user, balancePerToken);

        vm.startPrank(user);
        BaseTestToken(address(usdToken)).approve(address(swapRouter), type(uint256).max);
        BaseTestToken(address(ethToken)).approve(address(swapRouter), type(uint256).max);
        BaseTestToken(address(usdToken)).approve(address(msgSenderLiquidityRouter), type(uint256).max);
        BaseTestToken(address(ethToken)).approve(address(msgSenderLiquidityRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _initializePools() internal {
        for (uint256 i; i < poolSeeds.length; ++i) {
            manager.initialize(poolSeeds[i].key, uint160(TickMath.getSqrtPriceAtTick(poolSeeds[i].initialTick)));
        }
    }

    function _seedPositions() internal {
        for (uint8 lpIndex; lpIndex < LP_COUNT; ++lpIndex) {
            for (uint8 slot; slot < lpSeeds[lpIndex].plannedPositions; ++slot) {
                _seedPositionFor(lpIndex, slot);
            }
        }
    }

    function _seedPositionFor(uint8 lpIndex, uint8 slot) internal {
        LpSeed memory lp = lpSeeds[lpIndex];
        uint8 poolIndex = _poolIndexFor(lpIndex, slot, lp.anchor);
        int24 tickSpacing = poolSeeds[poolIndex].tickSpacing;
        int24 widthUnits = _widthUnitsFor(lpIndex, slot, lp.anchor);
        int24 centerUnits = _centerUnitsFor(lpIndex, slot, lp.anchor);
        int24 tickLower = (centerUnits - widthUnits) * tickSpacing;
        int24 tickUpper = (centerUnits + widthUnits) * tickSpacing;
        int256 liquidityDelta = int256(uint256(_liquidityFor(lpIndex, slot, lp.anchor)));
        bytes32 salt = keccak256(abi.encodePacked("seed-position", lpIndex, slot));

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: salt
        });

        _modifyLiquidityAs(lp.account, poolSeeds[poolIndex].key, params);
        _storePositionSeed(lp, poolIndex, params, slot);
    }

    function _storePositionSeed(LpSeed memory lp, uint8 poolIndex, ModifyLiquidityParams memory params, uint8 slot) internal {
        positionSeeds.push(
            PositionSeed({
                label: _positionLabel(lp.label, slot),
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

    function _positionLabel(string memory lpLabel, uint8 slot) internal view returns (string memory) {
        return string(abi.encodePacked(lpLabel, "-p", vm.toString(uint256(slot + 1))));
    }

    function _seedSwaps() internal {
        _pushSwap("tight buy pressure", swapActor, 0, false, 0.02 ether);
        _pushSwap("standard sell pressure", swapActor, 2, true, 0.03 ether);
        _pushSwap("wide buy pressure", swapActor, 3, false, 0.015 ether);
        _pushSwap("mid-tight sell pressure", swapActor, 1, true, 0.025 ether);
        _pushSwap("ultra-wide buy pressure", swapActor, 4, false, 0.018 ether);

        for (uint256 i; i < swapSeeds.length; ++i) {
            vm.startPrank(swapSeeds[i].trader);
            swap(poolSeeds[swapSeeds[i].poolIndex].key, swapSeeds[i].zeroForOne, swapSeeds[i].amountSpecified, "");
            vm.stopPrank();
        }
    }

    function _pushSwap(string memory label, address trader, uint8 poolIndex, bool zeroForOne, int256 amountSpecified)
        internal
    {
        swapSeeds.push(
            SwapSeed({
                label: label,
                trader: trader,
                poolIndex: poolIndex,
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified
            })
        );
    }

    function _modifyLiquidityAs(address lp, PoolKey memory key, ModifyLiquidityParams memory params) internal {
        vm.startPrank(lp);
        msgSenderLiquidityRouter.modifyLiquidity(key, params, "");
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

    function _anvilAccounts() internal pure returns (address[LP_COUNT] memory accounts) {
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
    }

    function _tierBalanceForIndex(uint8 lpIndex) internal pure returns (uint256) {
        if (lpIndex < 3) return LARGE_TIER_BALANCE;
        if (lpIndex < 7) return MEDIUM_TIER_BALANCE;
        return SMALL_TIER_BALANCE;
    }

    function _tierNameForIndex(uint8 lpIndex) internal pure returns (string memory) {
        if (lpIndex < 3) return "large";
        if (lpIndex < 7) return "medium";
        return "small";
    }

    function _poolIndexFor(uint8 lpIndex, uint8 slot, bool anchor) internal pure returns (uint8) {
        if (anchor) return uint8((lpIndex + slot) % POOL_COUNT);
        return uint8(((lpIndex * 2) + slot) % POOL_COUNT);
    }

    function _widthUnitsFor(uint8 lpIndex, uint8 slot, bool anchor) internal pure returns (int24) {
        uint8[5] memory anchorWidths = [uint8(18), uint8(12), uint8(8), uint8(15), uint8(10)];
        uint8[5] memory standardWidths = [uint8(12), uint8(8), uint8(6), uint8(10), uint8(5)];
        return int24(uint24(anchor ? anchorWidths[(lpIndex + slot) % 5] : standardWidths[(lpIndex + slot) % 5]));
    }

    function _centerUnitsFor(uint8 lpIndex, uint8 slot, bool anchor) internal pure returns (int24) {
        int24[5] memory anchorOffsets = [int24(0), int24(-1), int24(1), int24(0), int24(0)];
        int24[5] memory standardOffsets = [int24(0), int24(-2), int24(2), int24(-1), int24(1)];
        return anchor ? anchorOffsets[(lpIndex + slot) % 5] : standardOffsets[(lpIndex + slot) % 5];
    }

    function _liquidityFor(uint8 lpIndex, uint8 slot, bool anchor) internal pure returns (uint128) {
        uint128 base = anchor ? uint128(4e18) : uint128(15e17);
        uint128 tierBump = uint128(uint256(lpIndex < 3 ? 15e17 : lpIndex < 7 ? 8e17 : 3e17));
        uint128 slotBump = uint128(uint256((uint256(slot % 4) + 1) * 2e17));
        return base + tierBump + slotBump;
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
                '"format":"seed-v2",',
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
                '"description":"Deterministic seeded USD/ETH environment for local Squid demos.",',
                '"poolCount":',
                vm.toString(poolSeeds.length),
                ',',
                '"lpCount":',
                vm.toString(lpSeeds.length),
                ',',
                '"positionCount":',
                vm.toString(positionSeeds.length),
                ',',
                '"swapCount":',
                vm.toString(swapSeeds.length),
                ',',
                '"lpRoster":',
                _lpRosterJson(),
                ',',
                '"poolSeeds":',
                _poolSeedManifestJson(),
                ',',
                '"positionSeeds":',
                _positionSeedManifestJson(),
                ',',
                '"swapSeeds":',
                _swapSeedManifestJson(),
                "}"
            )
        );
    }

    function _marketJson() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"basePair":"USD/ETH",',
                '"token0":"',
                vm.toString(address(usdToken)),
                '",',
                '"token1":"',
                vm.toString(address(ethToken)),
                '",',
                '"token0Symbol":"USD",',
                '"token1Symbol":"ETH"',
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
                    '"tier":"',
                    lpSeeds[i].tier,
                    '",',
                    '"anchor":',
                    _boolToString(lpSeeds[i].anchor),
                    ',',
                    '"plannedPositions":',
                    vm.toString(uint256(lpSeeds[i].plannedPositions)),
                    ',',
                    '"usdBalanceSeeded":',
                    vm.toString(lpSeeds[i].usdBalanceSeeded),
                    ',',
                    '"ethBalanceSeeded":',
                    vm.toString(lpSeeds[i].ethBalanceSeeded),
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
                _poolLpAddressesJson(poolIndex),
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

    function _poolLpAddressesJson(uint256 poolIndex) internal view returns (string memory) {
        string memory lpsJson = "[";
        bool first = true;

        for (uint256 i; i < lpSeeds.length; ++i) {
            if (!_lpHasPoolPosition(lpSeeds[i].account, uint8(poolIndex))) continue;
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
        string memory prefix = string(
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
                '",',
                '"fee":',
                vm.toString(summary.fee),
                ',',
                '"tickSpacing":',
                vm.toString(int256(summary.tickSpacing)),
                ',',
                '"initialSqrtPriceX96":',
                vm.toString(summary.initialSqrtPriceX96),
                ',',
                '"liquidity":',
                _poolLiquidityJson(summary.liquidity)
            )
        );

        string memory suffix = string(
            abi.encodePacked(
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

        return string(abi.encodePacked(prefix, suffix));
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
        console2.log("Seeded pools:", poolSeeds.length);
        console2.log("Seeded LPs:", lpSeeds.length);
        console2.log("Seeded positions:", positionSeeds.length);
    }
}
