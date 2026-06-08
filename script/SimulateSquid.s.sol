// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {TestToken} from "../test/helpers/TestTokens.sol";
import {BaseSquidSimulation} from "./BaseSquidSimulation.s.sol";

contract SimulateSquid is BaseSquidSimulation {
    function run() external returns (string memory artifactPath) {
        artifactPath = simulate();
    }

    function simulate() public returns (string memory artifactPath) {
        _resetSimulationState();
        _setUpSimulation();

        _runBalancedActiveScenario();
        _runUpperRangeScenario();
        _runMixedRotationScenario();

        artifactPath = _writeArtifact();
        _printSummary(artifactPath);
    }

    function _runBalancedActiveScenario() internal {
        (TestToken tokenA, TestToken tokenB) =
            _deployScenarioTokens("Balanced Dollar", "bUSD", "Balanced Ether", "bETH");

        _prepareParticipant(lpAlice, address(tokenA), address(tokenB));
        _prepareParticipant(lpBob, address(tokenA), address(tokenB));
        _prepareParticipant(trader, address(tokenA), address(tokenB));

        (ScenarioResult storage scenario, PoolKey memory key) = _newScenario(
            "balanced-active-pool",
            "Wide and narrow positions start in range, then a swap and partial removal update active liquidity.",
            address(tokenA),
            address(tokenB)
        );

        _initializeScenarioPool(scenario, key, 0);
        _addLiquidity(
            scenario,
            lpAlice,
            key,
            ModifyLiquidityParams({tickLower: -240, tickUpper: 240, liquidityDelta: 5e18, salt: bytes32("alice-wide")}),
            "alice wide add"
        );
        _addLiquidity(
            scenario,
            lpBob,
            key,
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 2e18, salt: bytes32("bob-narrow")}),
            "bob narrow add"
        );
        _swapScenario(scenario, trader, key, true, -1e16, "small price move");
        _removeLiquidity(
            scenario,
            lpAlice,
            key,
            ModifyLiquidityParams({tickLower: -240, tickUpper: 240, liquidityDelta: -1e18, salt: bytes32("alice-wide")}),
            "alice partial remove"
        );
    }

    function _runUpperRangeScenario() internal {
        (TestToken tokenA, TestToken tokenB) =
            _deployScenarioTokens("Upper Range Dollar", "uUSD", "Upper Range Ether", "uETH");

        _prepareParticipant(lpAlice, address(tokenA), address(tokenB));
        _prepareParticipant(lpCarol, address(tokenA), address(tokenB));
        _prepareParticipant(trader, address(tokenA), address(tokenB));

        (ScenarioResult storage scenario, PoolKey memory key) = _newScenario(
            "upper-range-liquidity",
            "Mixes in-range base liquidity with an upper-range LP, then swaps into that region and closes one position.",
            address(tokenA),
            address(tokenB)
        );

        _initializeScenarioPool(scenario, key, 0);
        _addLiquidity(
            scenario,
            lpAlice,
            key,
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e24, salt: bytes32("alice-base")}),
            "alice base add"
        );
        _addLiquidity(
            scenario,
            lpCarol,
            key,
            ModifyLiquidityParams({tickLower: 120, tickUpper: 240, liquidityDelta: 1e24, salt: bytes32("carol-upper")}),
            "carol upper add"
        );
        _swapScenario(scenario, trader, key, true, -1e18, "cross current range");
        _removeLiquidity(
            scenario,
            lpAlice,
            key,
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e24, salt: bytes32("alice-base")}),
            "alice full remove"
        );
    }

    function _runMixedRotationScenario() internal {
        (TestToken tokenA, TestToken tokenB) =
            _deployScenarioTokens("Rotation Dollar", "rUSD", "Rotation Ether", "rETH");

        _prepareParticipant(lpAlice, address(tokenA), address(tokenB));
        _prepareParticipant(lpBob, address(tokenA), address(tokenB));
        _prepareParticipant(lpCarol, address(tokenA), address(tokenB));
        _prepareParticipant(trader, address(tokenA), address(tokenB));

        (ScenarioResult storage scenario, PoolKey memory key) = _newScenario(
            "mixed-range-rotation",
            "Creates multiple LPs with overlapping and disjoint ranges, then rotates price and partially removes liquidity.",
            address(tokenA),
            address(tokenB)
        );

        _initializeScenarioPool(scenario, key, 0);
        _addLiquidity(
            scenario,
            lpAlice,
            key,
            ModifyLiquidityParams({tickLower: -300, tickUpper: 300, liquidityDelta: 4e18, salt: bytes32("alice-wide")}),
            "alice wide add"
        );
        _addLiquidity(
            scenario,
            lpBob,
            key,
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 3e18, salt: bytes32("bob-tight")}),
            "bob tight add"
        );
        _addLiquidity(
            scenario,
            lpCarol,
            key,
            ModifyLiquidityParams({tickLower: 120, tickUpper: 360, liquidityDelta: 2e18, salt: bytes32("carol-upper")}),
            "carol upper add"
        );
        _addLiquidity(
            scenario,
            lpBob,
            key,
            ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: bytes32("bob-second")}),
            "bob second position add"
        );
        _swapScenario(scenario, trader, key, true, -5e17, "first rotation swap");
        _swapScenario(scenario, trader, key, false, -4e17, "second rotation swap");
        _removeLiquidity(
            scenario,
            lpBob,
            key,
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32("bob-tight")}),
            "bob partial remove"
        );
    }
}
