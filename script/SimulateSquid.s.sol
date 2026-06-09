// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseSquidSimulation} from "./BaseSquidSimulation.s.sol";

contract SimulateSquid is BaseSquidSimulation {
    function run() external returns (string memory artifactPath) {
        artifactPath = simulate();
    }

    function simulate() public returns (string memory artifactPath) {
        _resetSimulationState();
        _setUpSimulation();
        _seedEnvironment();

        artifactPath = _writeArtifact();
        _printSummary(artifactPath);
    }
}
