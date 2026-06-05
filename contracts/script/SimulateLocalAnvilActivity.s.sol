// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolModifyLiquidityTestNoChecks} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTestNoChecks.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {PoolDonateTest} from "@uniswap/v4-core/src/test/PoolDonateTest.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {Squid} from "../src/Squid.sol";
import {LpProfile, LpPositionProfile} from "../src/types/LpProfile.sol";
import {PoolMetrics} from "../src/types/PoolMetrics.sol";
import {PoolSummary} from "../src/types/PoolSummary.sol";

contract SimulateLocalAnvilActivityScript is Script {
    using PoolIdLibrary for PoolKey;
    using stdJson for string;

    error ActivityInvariantFailed(string reason);

    uint256 internal constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint160 internal constant SQRT_PRICE_1_2 = Constants.SQRT_PRICE_1_2;
    uint160 internal constant SQRT_PRICE_2_1 = Constants.SQRT_PRICE_2_1;

    struct DeploymentArtifact {
        string rpcUrl;
        address squid;
        address modifyLiquidityRouter;
        address modifyLiquidityNoChecks;
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
    PoolModifyLiquidityTest internal modifyLiquidityRouter;
    PoolModifyLiquidityTestNoChecks internal modifyLiquidityNoChecks;
    PoolSwapTest internal swapRouter;
    PoolDonateTest internal donateRouter;
    PoolKey internal poolOne;
    PoolKey internal poolTwo;

    function run() external {
        artifact = _readArtifact();

        string memory rpcUrl = vm.envOr("ANVIL_RPC_URL", artifact.rpcUrl);
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", DEFAULT_ANVIL_PRIVATE_KEY);
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("SimulateLocalAnvilActivity: rpc url", rpcUrl);
        console2.log("SimulateLocalAnvilActivity: deployer", deployer);

        hook = Squid(artifact.squid);
        modifyLiquidityRouter = PoolModifyLiquidityTest(artifact.modifyLiquidityRouter);
        modifyLiquidityNoChecks = PoolModifyLiquidityTestNoChecks(artifact.modifyLiquidityNoChecks);
        swapRouter = PoolSwapTest(artifact.swapRouter);
        donateRouter = PoolDonateTest(artifact.donateRouter);
        poolOne = _poolKey(0);
        poolTwo = _poolKey(1);

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
        if (hook.getPoolCount() != 2) {
            revert ActivityInvariantFailed("Expected fresh seeded state with exactly two pools");
        }

        PoolMetrics memory poolOneMetrics = hook.getPoolMetrics(poolOne);
        PoolMetrics memory poolTwoMetrics = hook.getPoolMetrics(poolTwo);
        if (
            poolOneMetrics.swapCount != 1 || poolTwoMetrics.swapCount != 0 || poolOneMetrics.donateCount != 0
                || poolTwoMetrics.donateCount != 0
        ) {
            revert ActivityInvariantFailed("Simulation must start from a freshly seeded Anvil chain");
        }

        LpProfile memory routerOneProfile = hook.getLpProfile(artifact.modifyLiquidityRouter);
        LpProfile memory routerTwoProfile = hook.getLpProfile(artifact.modifyLiquidityNoChecks);
        if (
            !routerOneProfile.exists || routerOneProfile.activePoolCount != 2 || routerOneProfile.lifetimePoolCount != 2
                || routerOneProfile.activePositionCount != 2 || routerOneProfile.lifetimePositionCount != 2
                || routerOneProfile.addLiquidityCount != 2 || routerOneProfile.removeLiquidityCount != 0
                || routerTwoProfile.exists
        ) {
            revert ActivityInvariantFailed("Simulation must start from the known seed baseline");
        }
    }

    function _openInitialPositions() private {
        modifyLiquidityRouter.modifyLiquidity(poolOne, _basePosition(), Constants.ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolOne, _secondPosition(), Constants.ZERO_BYTES);
        modifyLiquidityNoChecks.modifyLiquidity(poolOne, _routerTwoPosition(), Constants.ZERO_BYTES);
        modifyLiquidityNoChecks.modifyLiquidity(poolTwo, _poolTwoPosition(), Constants.ZERO_BYTES);
    }

    function _runMidpointActivity() private {
        swapRouter.swap(
            poolOne,
            SwapParams({zeroForOne: true, amountSpecified: -2e15, sqrtPriceLimitX96: SQRT_PRICE_1_2}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            Constants.ZERO_BYTES
        );
        donateRouter.donate(poolOne, 1_000, 2_000, Constants.ZERO_BYTES);
    }

    function _runFinalActivity() private {
        swapRouter.swap(
            poolTwo,
            SwapParams({zeroForOne: false, amountSpecified: -1e15, sqrtPriceLimitX96: SQRT_PRICE_2_1}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            Constants.ZERO_BYTES
        );
        modifyLiquidityNoChecks.modifyLiquidity(poolTwo, _poolTwoTopUp(), Constants.ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolOne, _secondPositionRemove(), Constants.ZERO_BYTES);
        modifyLiquidityNoChecks.modifyLiquidity(poolOne, _routerTwoPositionRemove(), Constants.ZERO_BYTES);
        modifyLiquidityNoChecks.modifyLiquidity(poolOne, _routerTwoReopen(), Constants.ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolOne, _basePosition(), Constants.ZERO_BYTES);
    }

    function _checkPostconditions() private view {
        if (hook.getPoolCount() != 2) {
            revert ActivityInvariantFailed("Expected exactly two seeded pools");
        }

        PoolSummary[] memory summaries = hook.getPoolSummaries(0, 10);
        if (summaries.length != 2) {
            revert ActivityInvariantFailed("Expected two pool summaries");
        }

        PoolMetrics memory poolOneMetrics = hook.getPoolMetrics(poolOne);
        PoolMetrics memory poolTwoMetrics = hook.getPoolMetrics(poolTwo);
        if (poolOneMetrics.trackedLiquidity == 0 || poolTwoMetrics.trackedLiquidity == 0) {
            revert ActivityInvariantFailed("Expected both pools to retain tracked liquidity");
        }
        if (poolOneMetrics.swapCount == 0 || poolTwoMetrics.swapCount == 0) {
            revert ActivityInvariantFailed("Expected swap activity in both pools");
        }
        if (poolOneMetrics.donateCount == 0) {
            revert ActivityInvariantFailed("Expected pool one donate activity");
        }
        if (poolOneMetrics.spotPriceX18 == 0 || poolOneMetrics.twapPriceX18 == 0) {
            revert ActivityInvariantFailed("Expected pool one price metrics to be populated");
        }
        LpProfile memory routerOneProfile = hook.getLpProfile(artifact.modifyLiquidityRouter);
        LpProfile memory routerTwoProfile = hook.getLpProfile(artifact.modifyLiquidityNoChecks);
        if (
            routerOneProfile.activePoolCount != 2 || routerOneProfile.lifetimePoolCount != 2
                || routerOneProfile.activePositionCount != 2 || routerOneProfile.lifetimePositionCount != 3
        ) {
            revert ActivityInvariantFailed("Expected router one to retain the seed baseline plus one closed position");
        }
        if (routerTwoProfile.activePoolCount != 2 || routerTwoProfile.lifetimePoolCount != 2) {
            revert ActivityInvariantFailed("Expected router two to remain active across both pools");
        }

        ModifyLiquidityParams memory basePosition = _basePosition();
        ModifyLiquidityParams memory secondPosition = _secondPosition();
        ModifyLiquidityParams memory routerTwoPosition = _routerTwoPosition();
        ModifyLiquidityParams memory poolTwoPosition = _poolTwoPosition();

        bytes32 routerOneBasePositionId = hook.getPositionId(
            artifact.modifyLiquidityRouter,
            poolOne,
            basePosition.tickLower,
            basePosition.tickUpper,
            basePosition.salt
        );
        bytes32 routerOneClosedPositionId = hook.getPositionId(
            artifact.modifyLiquidityRouter,
            poolOne,
            secondPosition.tickLower,
            secondPosition.tickUpper,
            secondPosition.salt
        );
        bytes32 routerTwoPoolOnePositionId = hook.getPositionId(
            artifact.modifyLiquidityNoChecks,
            poolOne,
            routerTwoPosition.tickLower,
            routerTwoPosition.tickUpper,
            routerTwoPosition.salt
        );
        bytes32 routerTwoPoolTwoPositionId = hook.getPositionId(
            artifact.modifyLiquidityNoChecks,
            poolTwo,
            poolTwoPosition.tickLower,
            poolTwoPosition.tickUpper,
            poolTwoPosition.salt
        );

        LpPositionProfile memory routerOneBase = hook.getLpPositionProfile(routerOneBasePositionId);
        LpPositionProfile memory routerOneClosed = hook.getLpPositionProfile(routerOneClosedPositionId);
        LpPositionProfile memory routerTwoPoolOne = hook.getLpPositionProfile(routerTwoPoolOnePositionId);
        LpPositionProfile memory routerTwoPoolTwo = hook.getLpPositionProfile(routerTwoPoolTwoPositionId);

        if (!routerOneBase.active || routerOneBase.totalPoolVolume0 == 0 || routerOneBase.activePositionVolume0 == 0) {
            revert ActivityInvariantFailed("Expected active router one position with tracked volume");
        }
        if (routerOneClosed.active || routerOneClosed.closedAtBlock == 0) {
            revert ActivityInvariantFailed("Expected router one second position to be closed");
        }
        if (!routerTwoPoolOne.active || routerTwoPoolOne.addLiquidityCount < 2 || routerTwoPoolOne.removeLiquidityCount != 1) {
            revert ActivityInvariantFailed("Expected router two pool one position reactivation");
        }
        if (!routerTwoPoolTwo.active || routerTwoPoolTwo.totalPoolVolume1 == 0) {
            revert ActivityInvariantFailed("Expected router two pool two position to observe swap volume");
        }
    }

    function _mintAndApprove(address token, address deployer) private {
        MockERC20(token).mint(deployer, 2 ** 200);
        MockERC20(token).approve(artifact.modifyLiquidityRouter, type(uint256).max);
        MockERC20(token).approve(artifact.modifyLiquidityNoChecks, type(uint256).max);
        MockERC20(token).approve(artifact.swapRouter, type(uint256).max);
        MockERC20(token).approve(artifact.donateRouter, type(uint256).max);
    }

    function _increaseTime(string memory rpcUrl, uint256 secondsToAdvance) private {
        vm.rpc(
            rpcUrl,
            "anvil_mine",
            string.concat("[1,", vm.toString(secondsToAdvance), "]")
        );
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
        loadedArtifact.swapRouter = json.readAddress(".swapRouterAddress");
        loadedArtifact.donateRouter = json.readAddress(".donateRouterAddress");
        loadedArtifact.usdc = json.readAddress(".usdcAddress");
        loadedArtifact.weth = json.readAddress(".wethAddress");
        loadedArtifact.poolIds = json.readBytes32Array(".seededPoolIds");
        loadedArtifact.fees = json.readUintArray(".seededPoolFees");
        loadedArtifact.tickSpacings = json.readUintArray(".seededPoolTickSpacings");

        if (
            loadedArtifact.poolIds.length != 2 || loadedArtifact.fees.length != 2
                || loadedArtifact.tickSpacings.length != 2
        ) {
            revert ActivityInvariantFailed("Expected two seeded pools in the deployment artifact");
        }
    }

    function _basePosition() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32(0)});
    }

    function _secondPosition() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -240, tickUpper: 240, liquidityDelta: 5e17, salt: bytes32(uint256(1))});
    }

    function _secondPositionRemove() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -240, tickUpper: 240, liquidityDelta: -5e17, salt: bytes32(uint256(1))});
    }

    function _routerTwoPosition() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -180, tickUpper: 180, liquidityDelta: 7e17, salt: bytes32(uint256(2))});
    }

    function _routerTwoPositionRemove() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -180, tickUpper: 180, liquidityDelta: -7e17, salt: bytes32(uint256(2))});
    }

    function _routerTwoReopen() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -180, tickUpper: 180, liquidityDelta: 4e17, salt: bytes32(uint256(2))});
    }

    function _poolTwoPosition() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: 9e17, salt: bytes32(uint256(3))});
    }

    function _poolTwoTopUp() private pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: 1e17, salt: bytes32(uint256(3))});
    }
}
