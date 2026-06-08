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
import {PoolSummary} from "../src/types/PoolMetrics.sol";
import {PositionLiquidity, PositionPnL, PositionSummary} from "../src/types/PositionMetrics.sol";
import {Squid} from "../src/Squid.sol";
import {PoolModifyLiquidityTestWithMsgSender} from "../src/test/PoolModifyLiquidityTestWithMsgSender.sol";
import {BaseTestToken, TestToken} from "../test/helpers/TestTokens.sol";

abstract contract BaseSquidSimulation is Script, Deployers {
    using PoolIdLibrary for PoolKey;

    struct ActionEntry {
        string actionType;
        address actor;
        string details;
    }

    struct PositionRef {
        address lp;
        bytes32 positionId;
        int24 tickLower;
        int24 tickUpper;
        bytes32 salt;
    }

    struct ScenarioResult {
        string name;
        string description;
        PoolKey key;
        address token0;
        address token1;
        address[] lps;
        ActionEntry[] actions;
        PositionRef[] positions;
    }

    Squid internal hook;
    PoolModifyLiquidityTestWithMsgSender internal msgSenderLiquidityRouter;

    address internal lpAlice;
    address internal lpBob;
    address internal lpCarol;
    address internal trader;
    address internal poolManagerOwner;

    ScenarioResult[] internal scenarioResults;

    function _resetSimulationState() internal {
        delete scenarioResults;
    }

    function _setUpSimulation() internal {
        _deployScriptManagerAndRouters();

        uint160 flags = Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.AFTER_SWAP_FLAG;
        hook = Squid(address(uint160(type(uint160).max & clearAllHookPermissionsMask | flags)));
        deployCodeTo("Squid", abi.encode(manager), address(hook));

        msgSenderLiquidityRouter = new PoolModifyLiquidityTestWithMsgSender(manager);

        lpAlice = makeAddr("lpAlice");
        lpBob = makeAddr("lpBob");
        lpCarol = makeAddr("lpCarol");
        trader = makeAddr("scenarioTrader");
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

    function _prepareParticipant(address user, address token0, address token1) internal {
        BaseTestToken(token0).mint(user, 1 << 120);
        BaseTestToken(token1).mint(user, 1 << 120);

        vm.startPrank(user);
        BaseTestToken(token0).approve(address(swapRouter), type(uint256).max);
        BaseTestToken(token1).approve(address(swapRouter), type(uint256).max);
        BaseTestToken(token0).approve(address(msgSenderLiquidityRouter), type(uint256).max);
        BaseTestToken(token1).approve(address(msgSenderLiquidityRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _newScenario(string memory name, string memory description, address tokenA, address tokenB)
        internal
        returns (ScenarioResult storage scenario, PoolKey memory key)
    {
        scenario = scenarioResults.push();
        scenario.name = name;
        scenario.description = description;

        key = _buildPoolKey(tokenA, tokenB);
        scenario.key = key;
        scenario.token0 = Currency.unwrap(key.currency0);
        scenario.token1 = Currency.unwrap(key.currency1);
    }

    function _trackLp(ScenarioResult storage scenario, address lp) internal {
        for (uint256 i; i < scenario.lps.length; ++i) {
            if (scenario.lps[i] == lp) return;
        }

        scenario.lps.push(lp);
    }

    function _logAction(ScenarioResult storage scenario, string memory actionType, address actor, string memory details)
        internal
    {
        scenario.actions.push(ActionEntry({actionType: actionType, actor: actor, details: details}));
    }

    function _trackPosition(
        ScenarioResult storage scenario,
        address lp,
        PoolKey memory key,
        ModifyLiquidityParams memory params
    ) internal returns (bytes32 positionId) {
        positionId = hook.getPositionId(lp, key.toId(), params.tickLower, params.tickUpper, params.salt);

        for (uint256 i; i < scenario.positions.length; ++i) {
            if (scenario.positions[i].positionId == positionId) return positionId;
        }

        scenario.positions.push(
            PositionRef({
                lp: lp,
                positionId: positionId,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                salt: params.salt
            })
        );
    }

    function _initializeScenarioPool(ScenarioResult storage scenario, PoolKey memory key, int24 tick) internal {
        manager.initialize(key, uint160(TickMath.getSqrtPriceAtTick(tick)));
        _logAction(
            scenario,
            "initialize",
            address(0),
            string(abi.encodePacked("tick=", vm.toString(int256(tick))))
        );
    }

    function _addLiquidity(
        ScenarioResult storage scenario,
        address lp,
        PoolKey memory key,
        ModifyLiquidityParams memory params,
        string memory label
    ) internal {
        _trackLp(scenario, lp);
        vm.startPrank(lp);
        msgSenderLiquidityRouter.modifyLiquidity(key, params, "");
        vm.stopPrank();

        bytes32 positionId = _trackPosition(scenario, lp, key, params);
        _logAction(
            scenario,
            "addLiquidity",
            lp,
            string(
                abi.encodePacked(
                    label,
                    " positionId=",
                    vm.toString(positionId),
                    " range=[",
                    vm.toString(int256(params.tickLower)),
                    ",",
                    vm.toString(int256(params.tickUpper)),
                    "] liquidityDelta=",
                    vm.toString(params.liquidityDelta)
                )
            )
        );
    }

    function _removeLiquidity(
        ScenarioResult storage scenario,
        address lp,
        PoolKey memory key,
        ModifyLiquidityParams memory params,
        string memory label
    ) internal {
        _trackLp(scenario, lp);
        vm.startPrank(lp);
        msgSenderLiquidityRouter.modifyLiquidity(key, params, "");
        vm.stopPrank();

        bytes32 positionId = _trackPosition(scenario, lp, key, params);
        _logAction(
            scenario,
            "removeLiquidity",
            lp,
            string(
                abi.encodePacked(
                    label,
                    " positionId=",
                    vm.toString(positionId),
                    " liquidityDelta=",
                    vm.toString(params.liquidityDelta)
                )
            )
        );
    }

    function _swapScenario(
        ScenarioResult storage scenario,
        address actor,
        PoolKey memory key,
        bool zeroForOne,
        int256 amountSpecified,
        string memory label
    ) internal {
        vm.startPrank(actor);
        swap(key, zeroForOne, amountSpecified, "");
        vm.stopPrank();

        _logAction(
            scenario,
            "swap",
            actor,
            string(
                abi.encodePacked(
                    label,
                    " zeroForOne=",
                    _boolToString(zeroForOne),
                    " amountSpecified=",
                    vm.toString(amountSpecified)
                )
            )
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
                '"runTimestamp":',
                vm.toString(block.timestamp),
                ',',
                '"chainId":',
                vm.toString(block.chainid),
                ',',
                '"contracts":',
                _contractsJson(),
                ',',
                '"scenarios":',
                _scenariosJson(),
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

    function _scenariosJson() internal view returns (string memory) {
        string memory scenariosJson = "[";

        for (uint256 i; i < scenarioResults.length; ++i) {
            if (i > 0) scenariosJson = string(abi.encodePacked(scenariosJson, ","));
            scenariosJson = string(abi.encodePacked(scenariosJson, _scenarioJson(scenarioResults[i])));
        }

        return string(abi.encodePacked(scenariosJson, "]"));
    }

    function _scenarioJson(ScenarioResult storage scenario) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"name":"',
                scenario.name,
                '",',
                '"description":"',
                scenario.description,
                '",',
                '"pool":',
                _poolJson(scenario),
                ',',
                '"lpAddresses":',
                _lpAddressesJson(scenario),
                ',',
                '"actions":',
                _actionsJson(scenario),
                ',',
                '"finalState":',
                _finalStateJson(scenario),
                "}"
            )
        );
    }

    function _poolJson(ScenarioResult storage scenario) internal view returns (string memory) {
        PoolId poolId = scenario.key.toId();

        return string(
            abi.encodePacked(
                "{",
                '"poolId":"',
                vm.toString(PoolId.unwrap(poolId)),
                '",',
                '"token0":"',
                vm.toString(scenario.token0),
                '",',
                '"token1":"',
                vm.toString(scenario.token1),
                '",',
                '"fee":',
                vm.toString(scenario.key.fee),
                ',',
                '"tickSpacing":',
                vm.toString(uint256(uint24(scenario.key.tickSpacing))),
                ',',
                '"hook":"',
                vm.toString(address(scenario.key.hooks)),
                '"',
                "}"
            )
        );
    }

    function _lpAddressesJson(ScenarioResult storage scenario) internal view returns (string memory) {
        string memory lpsJson = "[";

        for (uint256 i; i < scenario.lps.length; ++i) {
            if (i > 0) lpsJson = string(abi.encodePacked(lpsJson, ","));
            lpsJson = string(abi.encodePacked(lpsJson, '"', vm.toString(scenario.lps[i]), '"'));
        }

        return string(abi.encodePacked(lpsJson, "]"));
    }

    function _actionsJson(ScenarioResult storage scenario) internal view returns (string memory) {
        string memory actionsJson = "[";

        for (uint256 i; i < scenario.actions.length; ++i) {
            if (i > 0) actionsJson = string(abi.encodePacked(actionsJson, ","));
            actionsJson = string(
                abi.encodePacked(
                    actionsJson,
                    "{",
                    '"type":"',
                    scenario.actions[i].actionType,
                    '",',
                    '"actor":"',
                    vm.toString(scenario.actions[i].actor),
                    '",',
                    '"details":"',
                    scenario.actions[i].details,
                    '"',
                    "}"
                )
            );
        }

        return string(abi.encodePacked(actionsJson, "]"));
    }

    function _finalStateJson(ScenarioResult storage scenario) internal view returns (string memory) {
        PoolId poolId = scenario.key.toId();
        PoolSummary memory poolSummary = hook.getPoolSummary(poolId);
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = hook.getCurrentPoolState(poolId);

        return string(
            abi.encodePacked(
                "{",
                '"poolSummary":',
                _poolSummaryJson(poolSummary),
                ',',
                '"currentPoolState":',
                _currentPoolStateJson(sqrtPriceX96, tick, protocolFee, lpFee),
                ',',
                '"positions":',
                _positionsJson(scenario),
                "}"
            )
        );
    }

    function _poolSummaryJson(PoolSummary memory summary) internal view returns (string memory) {
        return string(
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
                vm.toString(uint256(uint24(summary.tickSpacing))),
                ',',
                '"initialSqrtPriceX96":',
                vm.toString(summary.initialSqrtPriceX96),
                ',',
                '"liquidity":',
                _poolLiquidityJson(summary.liquidity.totalLiquidity, summary.liquidity.activeLiquidity, summary.liquidity.peakActiveLiquidity),
                "}"
            )
        );
    }

    function _poolLiquidityJson(uint128 totalLiquidity, uint128 activeLiquidity, uint128 peakActiveLiquidity)
        internal
        view
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                "{",
                '"totalLiquidity":',
                vm.toString(totalLiquidity),
                ',',
                '"activeLiquidity":',
                vm.toString(activeLiquidity),
                ',',
                '"peakActiveLiquidity":',
                vm.toString(peakActiveLiquidity),
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

    function _positionsJson(ScenarioResult storage scenario) internal view returns (string memory) {
        string memory positionsJson = "[";

        for (uint256 i; i < scenario.positions.length; ++i) {
            if (i > 0) positionsJson = string(abi.encodePacked(positionsJson, ","));
            positionsJson = string(abi.encodePacked(positionsJson, _positionSnapshotJson(scenario.positions[i])));
        }

        return string(abi.encodePacked(positionsJson, "]"));
    }

    function _positionSnapshotJson(PositionRef storage position) internal view returns (string memory) {
        PositionSummary memory summary = hook.getPositionSummary(position.positionId);
        PositionLiquidity memory liquidity = hook.getPositionLiquidity(position.positionId);
        PositionPnL memory pnl = hook.getPositionPnL(position.positionId);

        return string(
            abi.encodePacked(
                "{",
                '"lp":"',
                vm.toString(position.lp),
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

    function _boolToString(bool value) internal pure returns (string memory) {
        return value ? "true" : "false";
    }

    function _deployScenarioTokens(string memory tokenAName, string memory tokenASymbol, string memory tokenBName, string memory tokenBSymbol)
        internal
        returns (TestToken tokenA, TestToken tokenB)
    {
        tokenA = new TestToken(tokenAName, tokenASymbol);
        tokenB = new TestToken(tokenBName, tokenBSymbol);
    }

    function _printSummary(string memory artifactPath) internal view {
        console2.log("Squid simulation artifact:", artifactPath);
        console2.log("PoolManager:", address(manager));
        console2.log("Squid:", address(hook));
        console2.log("Tracked scenarios:", scenarioResults.length);
    }
}
