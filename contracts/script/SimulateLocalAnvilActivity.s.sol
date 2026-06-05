// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {PoolDonateTest} from "@uniswap/v4-core/src/test/PoolDonateTest.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {Squid} from "../src/Squid.sol";
import {LpProfile, LpPositionProfile} from "../src/types/LpProfile.sol";
import {PoolMetrics} from "../src/types/PoolMetrics.sol";
import {PoolSummary} from "../src/types/PoolSummary.sol";

interface IModifyLiquidityLike {
    function modifyLiquidity(PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData)
        external
        payable;
}

contract SimulateLocalAnvilActivityScript is Script {
    using PoolIdLibrary for PoolKey;
    using stdJson for string;

    error ActivityInvariantFailed(string reason);

    uint256 internal constant EXPECTED_POOL_COUNT = 4;
    uint256 internal constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint160 internal constant SQRT_PRICE_1_2 = Constants.SQRT_PRICE_1_2;

    struct DeploymentArtifact {
        string rpcUrl;
        address squid;
        address modifyLiquidityRouter;
        address modifyLiquidityNoChecks;
        address auxiliaryModifyLiquidityRouter;
        address auxiliaryModifyLiquidityNoChecks;
        address swapRouter;
        address donateRouter;
        address usdc;
        address weth;
        bytes32[] poolIds;
        uint256[] fees;
        uint256[] tickSpacings;
    }

    DeploymentArtifact internal artifact;
    Squid internal hook;
    IModifyLiquidityLike internal router0;
    IModifyLiquidityLike internal router1;
    IModifyLiquidityLike internal router2;
    IModifyLiquidityLike internal router3;
    PoolSwapTest internal swapRouter;
    PoolDonateTest internal donateRouter;
    PoolKey internal poolA;
    PoolKey internal poolB;
    PoolKey internal poolC;
    PoolKey internal poolD;

    function run() external {
        artifact = _readArtifact();

        string memory rpcUrl = vm.envOr("ANVIL_RPC_URL", artifact.rpcUrl);
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", DEFAULT_ANVIL_PRIVATE_KEY);
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("SimulateLocalAnvilActivity: rpc url", rpcUrl);
        console2.log("SimulateLocalAnvilActivity: deployer", deployer);

        hook = Squid(artifact.squid);
        router0 = IModifyLiquidityLike(artifact.modifyLiquidityRouter);
        router1 = IModifyLiquidityLike(artifact.modifyLiquidityNoChecks);
        router2 = IModifyLiquidityLike(artifact.auxiliaryModifyLiquidityRouter);
        router3 = IModifyLiquidityLike(artifact.auxiliaryModifyLiquidityNoChecks);
        swapRouter = PoolSwapTest(artifact.swapRouter);
        donateRouter = PoolDonateTest(artifact.donateRouter);
        poolA = _poolKey(0);
        poolB = _poolKey(1);
        poolC = _poolKey(2);
        poolD = _poolKey(3);

        _checkFreshSeededState();

        vm.startBroadcast(deployerPrivateKey);
        _mintAndApprove(artifact.usdc, deployer);
        _mintAndApprove(artifact.weth, deployer);
        _openInitialPositions();
        vm.stopBroadcast();

        _increaseTime(rpcUrl, 15 minutes);

        vm.startBroadcast(deployerPrivateKey);
        _runMidpointActivity();
        vm.stopBroadcast();

        _increaseTime(rpcUrl, 15 minutes);

        vm.startBroadcast(deployerPrivateKey);
        _runFinalActivity();
        vm.stopBroadcast();

        _checkPostconditions();
    }

    function _checkFreshSeededState() private view {
        if (hook.getPoolCount() != EXPECTED_POOL_COUNT) {
            revert ActivityInvariantFailed("Expected fresh seeded state with exactly four pools");
        }

        PoolMetrics memory metricsA = hook.getPoolMetrics(poolA);
        PoolMetrics memory metricsB = hook.getPoolMetrics(poolB);
        PoolMetrics memory metricsC = hook.getPoolMetrics(poolC);
        PoolMetrics memory metricsD = hook.getPoolMetrics(poolD);
        PoolMetrics[EXPECTED_POOL_COUNT] memory metrics = [metricsA, metricsB, metricsC, metricsD];

        for (uint256 i = 0; i < EXPECTED_POOL_COUNT; i++) {
            if (
                !metrics[i].initialized || metrics[i].activeLpCount != 1 || metrics[i].lifetimeLpCount != 1
                    || metrics[i].activePositionCount != 1 || metrics[i].lifetimePositionCount != 1
                    || metrics[i].addLiquidityCount != 1 || metrics[i].removeLiquidityCount != 0
                    || metrics[i].trackedLiquidity == 0 || metrics[i].donateCount != 0
            ) {
                revert ActivityInvariantFailed("Simulation must start from the known seed baseline");
            }
        }

        if (metricsA.swapCount != 1 || metricsB.swapCount != 0 || metricsC.swapCount != 0 || metricsD.swapCount != 0) {
            revert ActivityInvariantFailed("Simulation must start from a freshly seeded Anvil chain");
        }

        LpProfile memory primaryRouter = hook.getLpProfile(artifact.modifyLiquidityRouter);
        LpProfile memory secondaryRouter = hook.getLpProfile(artifact.modifyLiquidityNoChecks);
        LpProfile memory tertiaryRouter = hook.getLpProfile(artifact.auxiliaryModifyLiquidityRouter);
        LpProfile memory quaternaryRouter = hook.getLpProfile(artifact.auxiliaryModifyLiquidityNoChecks);

        if (
            !primaryRouter.exists || primaryRouter.activePoolCount != EXPECTED_POOL_COUNT
                || primaryRouter.lifetimePoolCount != EXPECTED_POOL_COUNT
                || primaryRouter.activePositionCount != EXPECTED_POOL_COUNT
                || primaryRouter.lifetimePositionCount != EXPECTED_POOL_COUNT
                || primaryRouter.addLiquidityCount != EXPECTED_POOL_COUNT || primaryRouter.removeLiquidityCount != 0
                || secondaryRouter.exists || tertiaryRouter.exists || quaternaryRouter.exists
        ) {
            revert ActivityInvariantFailed("Simulation must start from the known router baseline");
        }
    }

    function _openInitialPositions() private {
        _modifyLiquidity(router0, poolA, _poolANarrow());
        _modifyLiquidity(router1, poolA, _poolAOverlap());
        _modifyLiquidity(router2, poolA, _poolAFringe());

        _modifyLiquidity(router1, poolB, _poolBDominant());
        _modifyLiquidity(router1, poolB, _poolBLifecycle());
        _modifyLiquidity(router2, poolB, _poolBFringe());
        _modifyLiquidity(router3, poolB, _poolBOverlap());

        _modifyLiquidity(router2, poolC, _poolCConcentrated());
        _modifyLiquidity(router0, poolC, _poolCWide());
        _modifyLiquidity(router3, poolC, _poolCOverlap());
        _modifyLiquidity(router1, poolC, _poolCFringe());

        _modifyLiquidity(router2, poolD, _poolDWide());
        _modifyLiquidity(router1, poolD, _poolDOverlap());
        _modifyLiquidity(router3, poolD, _poolDFringe());
    }

    function _runMidpointActivity() private {
        _swap(poolA, -2e15);
        donateRouter.donate(poolA, 1_000, 2_000, Constants.ZERO_BYTES);

        _swap(poolB, -15e14);
        _swap(poolC, -1e15);
    }

    function _runFinalActivity() private {
        _swap(poolD, -1e15);

        _modifyLiquidity(router1, poolB, _poolBDominantTopUp());
        _modifyLiquidity(router0, poolA, _poolANarrowRemove());
        _modifyLiquidity(router1, poolB, _poolBLifecycleRemove());
        _modifyLiquidity(router1, poolB, _poolBLifecycleReopen());
    }

    function _checkPostconditions() private view {
        if (hook.getPoolCount() != EXPECTED_POOL_COUNT) {
            revert ActivityInvariantFailed("Expected exactly four seeded pools");
        }
        if (hook.getLpCount() != 4) {
            revert ActivityInvariantFailed("Expected four LP identities after simulation");
        }

        PoolSummary[] memory summaries = hook.getPoolSummaries(0, 10);
        if (summaries.length != EXPECTED_POOL_COUNT) {
            revert ActivityInvariantFailed("Expected four pool summaries");
        }

        PoolMetrics memory metricsA = hook.getPoolMetrics(poolA);
        PoolMetrics memory metricsB = hook.getPoolMetrics(poolB);
        PoolMetrics memory metricsC = hook.getPoolMetrics(poolC);
        PoolMetrics memory metricsD = hook.getPoolMetrics(poolD);

        if (
            metricsA.trackedLiquidity == 0 || metricsB.trackedLiquidity == 0 || metricsC.trackedLiquidity == 0
                || metricsD.trackedLiquidity == 0
        ) {
            revert ActivityInvariantFailed("Expected all pools to retain tracked liquidity");
        }
        if (metricsA.swapCount == 0 || metricsB.swapCount == 0 || metricsC.swapCount == 0 || metricsD.swapCount == 0) {
            revert ActivityInvariantFailed("Expected swap activity in every pool");
        }
        if (
            metricsA.donateCount != 1 || metricsB.donateCount != 0 || metricsC.donateCount != 0
                || metricsD.donateCount != 0
        ) {
            revert ActivityInvariantFailed("Expected only pool A donate activity");
        }
        if (
            metricsA.activeLpCount != 3 || metricsA.activePositionCount != 3 || metricsB.activeLpCount != 4
                || metricsB.activePositionCount != 5 || metricsC.activeLpCount != 4 || metricsC.activePositionCount != 5
                || metricsD.activeLpCount != 4 || metricsD.activePositionCount != 4
        ) {
            revert ActivityInvariantFailed("Expected mixed LP topologies across the simulated pools");
        }
        if (metricsB.activePositionCount <= metricsA.activePositionCount) {
            revert ActivityInvariantFailed("Expected pool B to remain denser than pool A");
        }

        _checkLpProfiles();
        _checkRepresentativePositions();
    }

    function _checkLpProfiles() private view {
        LpProfile memory profile0 = hook.getLpProfile(artifact.modifyLiquidityRouter);
        LpProfile memory profile1 = hook.getLpProfile(artifact.modifyLiquidityNoChecks);
        LpProfile memory profile2 = hook.getLpProfile(artifact.auxiliaryModifyLiquidityRouter);
        LpProfile memory profile3 = hook.getLpProfile(artifact.auxiliaryModifyLiquidityNoChecks);

        if (
            profile0.activePoolCount != 4 || profile0.lifetimePoolCount != 4 || profile0.activePositionCount != 5
                || profile0.lifetimePositionCount != 6 || profile0.addLiquidityCount != 6
                || profile0.removeLiquidityCount != 1
        ) {
            revert ActivityInvariantFailed("Expected router zero to span every pool with one closed branch");
        }
        if (
            profile1.activePoolCount != 4 || profile1.lifetimePoolCount != 4 || profile1.activePositionCount != 5
                || profile1.lifetimePositionCount != 5 || profile1.addLiquidityCount != 7
                || profile1.removeLiquidityCount != 1
        ) {
            revert ActivityInvariantFailed("Expected router one to drive the densest pool topology");
        }
        if (
            profile2.activePoolCount != 4 || profile2.lifetimePoolCount != 4 || profile2.activePositionCount != 4
                || profile2.lifetimePositionCount != 4 || profile2.addLiquidityCount != 4
                || profile2.removeLiquidityCount != 0
        ) {
            revert ActivityInvariantFailed("Expected router two to stay active in every pool");
        }
        if (
            profile3.activePoolCount != 3 || profile3.lifetimePoolCount != 3 || profile3.activePositionCount != 3
                || profile3.lifetimePositionCount != 3 || profile3.addLiquidityCount != 3
                || profile3.removeLiquidityCount != 0
        ) {
            revert ActivityInvariantFailed("Expected router three to cover the asymmetric pools only");
        }
    }

    function _checkRepresentativePositions() private view {
        bytes32 poolAClosedId = hook.getPositionId(
            artifact.modifyLiquidityRouter,
            poolA,
            _poolANarrow().tickLower,
            _poolANarrow().tickUpper,
            _poolANarrow().salt
        );
        bytes32 poolAFringeId = hook.getPositionId(
            artifact.auxiliaryModifyLiquidityRouter,
            poolA,
            _poolAFringe().tickLower,
            _poolAFringe().tickUpper,
            _poolAFringe().salt
        );
        bytes32 poolBLifecycleId = hook.getPositionId(
            artifact.modifyLiquidityNoChecks,
            poolB,
            _poolBLifecycle().tickLower,
            _poolBLifecycle().tickUpper,
            _poolBLifecycle().salt
        );
        bytes32 poolCConcentratedId = hook.getPositionId(
            artifact.auxiliaryModifyLiquidityRouter,
            poolC,
            _poolCConcentrated().tickLower,
            _poolCConcentrated().tickUpper,
            _poolCConcentrated().salt
        );
        bytes32 poolDFringeId = hook.getPositionId(
            artifact.auxiliaryModifyLiquidityNoChecks,
            poolD,
            _poolDFringe().tickLower,
            _poolDFringe().tickUpper,
            _poolDFringe().salt
        );

        LpPositionProfile memory poolAClosed = hook.getLpPositionProfile(poolAClosedId);
        LpPositionProfile memory poolAFringe = hook.getLpPositionProfile(poolAFringeId);
        LpPositionProfile memory poolBLifecycle = hook.getLpPositionProfile(poolBLifecycleId);
        LpPositionProfile memory poolCConcentrated = hook.getLpPositionProfile(poolCConcentratedId);
        LpPositionProfile memory poolDFringe = hook.getLpPositionProfile(poolDFringeId);

        if (poolAClosed.active || poolAClosed.closedAtBlock == 0) {
            revert ActivityInvariantFailed("Expected pool A narrow position to be closed");
        }
        if (
            !poolBLifecycle.active || poolBLifecycle.addLiquidityCount != 2 || poolBLifecycle.removeLiquidityCount != 1
                || poolBLifecycle.closedAtBlock != 0
        ) {
            revert ActivityInvariantFailed("Expected pool B lifecycle position to be reopened");
        }
        if (
            !poolAFringe.active || poolAFringe.totalPoolVolume0 == 0 || poolAFringe.totalPoolVolume1 == 0
                || poolAFringe.activePositionVolume0 != 0 || poolAFringe.activePositionVolume1 != 0
                || poolAFringe.activeVolumePercentage0Bps != 0 || poolAFringe.activeVolumePercentage1Bps != 0
        ) {
            revert ActivityInvariantFailed("Expected pool A fringe position to stay out of range");
        }
        if (
            !poolCConcentrated.active || poolCConcentrated.activePositionVolume0 == 0
                || poolCConcentrated.activePositionVolume1 == 0
        ) {
            revert ActivityInvariantFailed("Expected pool C concentrated position to see active volume");
        }
        if (
            !poolDFringe.active || poolDFringe.totalPoolVolume0 == 0 || poolDFringe.totalPoolVolume1 == 0
                || poolDFringe.activePositionVolume0 != 0 || poolDFringe.activePositionVolume1 != 0
        ) {
            revert ActivityInvariantFailed("Expected pool D fringe position to remain inactive on swap volume");
        }
    }

    function _mintAndApprove(address token, address deployer) private {
        MockERC20(token).mint(deployer, 2 ** 200);
        MockERC20(token).approve(artifact.modifyLiquidityRouter, type(uint256).max);
        MockERC20(token).approve(artifact.modifyLiquidityNoChecks, type(uint256).max);
        MockERC20(token).approve(artifact.auxiliaryModifyLiquidityRouter, type(uint256).max);
        MockERC20(token).approve(artifact.auxiliaryModifyLiquidityNoChecks, type(uint256).max);
        MockERC20(token).approve(artifact.swapRouter, type(uint256).max);
        MockERC20(token).approve(artifact.donateRouter, type(uint256).max);
    }

    function _swap(PoolKey memory key, int256 amountSpecified) private {
        swapRouter.swap(
            key,
            SwapParams({zeroForOne: true, amountSpecified: amountSpecified, sqrtPriceLimitX96: SQRT_PRICE_1_2}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            Constants.ZERO_BYTES
        );
    }

    function _modifyLiquidity(IModifyLiquidityLike router, PoolKey memory key, ModifyLiquidityParams memory params)
        private
    {
        router.modifyLiquidity(key, params, Constants.ZERO_BYTES);
    }

    function _increaseTime(string memory rpcUrl, uint256 secondsToAdvance) private {
        vm.rpc(rpcUrl, "anvil_mine", string.concat("[1,", vm.toString(secondsToAdvance), "]"));
    }

    function _poolKey(uint256 index) private view returns (PoolKey memory) {
        Currency currency0 = Currency.wrap(artifact.usdc);
        Currency currency1 = Currency.wrap(artifact.weth);
        if (Currency.unwrap(currency0) > Currency.unwrap(currency1)) {
            (currency0, currency1) = (currency1, currency0);
        }

        return PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: uint24(artifact.fees[index]),
            tickSpacing: int24(int256(artifact.tickSpacings[index])),
            hooks: IHooks(artifact.squid)
        });
    }

    function _readArtifact() private view returns (DeploymentArtifact memory loadedArtifact) {
        string memory artifactPath = "deployments/local-anvil.json";
        if (!vm.exists(artifactPath)) {
            revert ActivityInvariantFailed("Missing deployments/local-anvil.json. Run the seed script first");
        }

        string memory json = vm.readFile(artifactPath);
        loadedArtifact.rpcUrl = json.readString(".rpcUrl");
        loadedArtifact.squid = json.readAddress(".squidAddress");
        loadedArtifact.modifyLiquidityRouter = json.readAddress(".modifyLiquidityRouterAddress");
        loadedArtifact.modifyLiquidityNoChecks = json.readAddress(".modifyLiquidityNoChecksAddress");
        loadedArtifact.auxiliaryModifyLiquidityRouter = json.readAddress(".auxiliaryModifyLiquidityRouterAddress");
        loadedArtifact.auxiliaryModifyLiquidityNoChecks = json.readAddress(".auxiliaryModifyLiquidityNoChecksAddress");
        loadedArtifact.swapRouter = json.readAddress(".swapRouterAddress");
        loadedArtifact.donateRouter = json.readAddress(".donateRouterAddress");
        loadedArtifact.usdc = json.readAddress(".usdcAddress");
        loadedArtifact.weth = json.readAddress(".wethAddress");
        loadedArtifact.poolIds = json.readBytes32Array(".seededPoolIds");
        loadedArtifact.fees = json.readUintArray(".seededPoolFees");
        loadedArtifact.tickSpacings = json.readUintArray(".seededPoolTickSpacings");

        if (
            loadedArtifact.poolIds.length != EXPECTED_POOL_COUNT || loadedArtifact.fees.length != EXPECTED_POOL_COUNT
                || loadedArtifact.tickSpacings.length != EXPECTED_POOL_COUNT
        ) {
            revert ActivityInvariantFailed("Expected four seeded pools in the deployment artifact");
        }
    }

    function _poolANarrow() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -240, tickUpper: 240, liquidityDelta: 6e17, salt: bytes32(uint256(1))});
    }

    function _poolANarrowRemove() private pure returns (ModifyLiquidityParams memory) {
        return
            ModifyLiquidityParams({tickLower: -240, tickUpper: 240, liquidityDelta: -6e17, salt: bytes32(uint256(1))});
    }

    function _poolAOverlap() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -180, tickUpper: 180, liquidityDelta: 7e17, salt: bytes32(uint256(2))});
    }

    function _poolAFringe() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: 600, tickUpper: 900, liquidityDelta: 4e17, salt: bytes32(uint256(3))});
    }

    function _poolBDominant() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -90, tickUpper: 90, liquidityDelta: 9e17, salt: bytes32(uint256(10))});
    }

    function _poolBDominantTopUp() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -90, tickUpper: 90, liquidityDelta: 2e17, salt: bytes32(uint256(10))});
    }

    function _poolBLifecycle() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -160, tickUpper: 40, liquidityDelta: 4e17, salt: bytes32(uint256(11))});
    }

    function _poolBLifecycleRemove() private pure returns (ModifyLiquidityParams memory) {
        return
            ModifyLiquidityParams({tickLower: -160, tickUpper: 40, liquidityDelta: -4e17, salt: bytes32(uint256(11))});
    }

    function _poolBLifecycleReopen() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -160, tickUpper: 40, liquidityDelta: 2e17, salt: bytes32(uint256(11))});
    }

    function _poolBOverlap() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -40, tickUpper: 140, liquidityDelta: 5e17, salt: bytes32(uint256(12))});
    }

    function _poolBFringe() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: 300, tickUpper: 500, liquidityDelta: 3e17, salt: bytes32(uint256(13))});
    }

    function _poolCConcentrated() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -75, tickUpper: 75, liquidityDelta: 5e17, salt: bytes32(uint256(20))});
    }

    function _poolCWide() private pure returns (ModifyLiquidityParams memory) {
        return
            ModifyLiquidityParams({tickLower: -180, tickUpper: 180, liquidityDelta: 7e17, salt: bytes32(uint256(21))});
    }

    function _poolCOverlap() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -40, tickUpper: 120, liquidityDelta: 4e17, salt: bytes32(uint256(22))});
    }

    function _poolCFringe() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: 200, tickUpper: 320, liquidityDelta: 2e17, salt: bytes32(uint256(23))});
    }

    function _poolDWide() private pure returns (ModifyLiquidityParams memory) {
        return
            ModifyLiquidityParams({tickLower: -1000, tickUpper: 1000, liquidityDelta: 9e17, salt: bytes32(uint256(30))});
    }

    function _poolDOverlap() private pure returns (ModifyLiquidityParams memory) {
        return
            ModifyLiquidityParams({tickLower: -600, tickUpper: 200, liquidityDelta: 6e17, salt: bytes32(uint256(31))});
    }

    function _poolDFringe() private pure returns (ModifyLiquidityParams memory) {
        return
            ModifyLiquidityParams({tickLower: 800, tickUpper: 1200, liquidityDelta: 5e17, salt: bytes32(uint256(32))});
    }
}
