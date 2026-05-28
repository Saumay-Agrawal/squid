// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolModifyLiquidityTestNoChecks} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTestNoChecks.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {SwapRouterNoChecks} from "@uniswap/v4-core/src/test/SwapRouterNoChecks.sol";
import {PoolDonateTest} from "@uniswap/v4-core/src/test/PoolDonateTest.sol";
import {PoolTakeTest} from "@uniswap/v4-core/src/test/PoolTakeTest.sol";
import {PoolClaimsTest} from "@uniswap/v4-core/src/test/PoolClaimsTest.sol";
import {PoolNestedActionsTest} from "@uniswap/v4-core/src/test/PoolNestedActionsTest.sol";
import {ActionsRouter} from "@uniswap/v4-core/src/test/ActionsRouter.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";

import {Squid} from "../src/Squid.sol";
import {UnichainSupportedTokens} from "../src/libraries/UnichainSupportedTokens.sol";
import {HookMiner} from "../lib/v4-hooks-public/src/utils/HookMiner.sol";

contract SeedLocalAnvilScript is Script, UnichainSupportedTokens {
    using PoolIdLibrary for PoolKey;

    error SeedInvariantFailed(string reason);

    uint256 internal constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    uint160 internal constant SQRT_PRICE_1_1 = Constants.SQRT_PRICE_1_1;
    uint160 internal constant SQRT_PRICE_1_2 = Constants.SQRT_PRICE_1_2;
    int24 internal constant DEFAULT_TICK_LOWER = -120;
    int24 internal constant DEFAULT_TICK_UPPER = 120;
    int128 internal constant DEFAULT_LIQUIDITY_DELTA = 1e18;

    struct DeploymentResult {
        address deployer;
        address squid;
        address poolManager;
        address usdc;
        address weth;
        PoolId firstPoolId;
        PoolId secondPoolId;
    }

    PoolManager internal manager;
    PoolModifyLiquidityTest internal modifyLiquidityRouter;
    PoolModifyLiquidityTestNoChecks internal modifyLiquidityNoChecks;
    SwapRouterNoChecks internal swapRouterNoChecks;
    PoolSwapTest internal swapRouter;
    PoolDonateTest internal donateRouter;
    PoolTakeTest internal takeRouter;
    PoolClaimsTest internal claimsRouter;
    PoolNestedActionsTest internal nestedActionRouter;
    ActionsRouter internal actionsRouter;

    function run() external {
        string memory rpcUrl = vm.envOr("ANVIL_RPC_URL", string("http://127.0.0.1:8545"));
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", DEFAULT_ANVIL_PRIVATE_KEY);
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("SeedLocalAnvil: project root", vm.projectRoot());
        console2.log("SeedLocalAnvil: rpc url", rpcUrl);
        console2.log("SeedLocalAnvil: deployer", deployer);

        _runPreflightChecks();
        console2.log("SeedLocalAnvil: stage installSupportedTokenCode");
        _installSupportedTokenCode(rpcUrl);

        console2.log("SeedLocalAnvil: starting broadcast");
        vm.startBroadcast(deployerPrivateKey);

        console2.log("SeedLocalAnvil: stage deployManagerAndRouters");
        _deployManagerAndRouters(deployer);
        console2.log("SeedLocalAnvil: stage deployAndSeedSquid");
        DeploymentResult memory deployment = _deployAndSeedSquid(deployer);

        vm.stopBroadcast();
        console2.log("SeedLocalAnvil: broadcast complete");

        console2.log("SeedLocalAnvil: stage writeDeploymentArtifact");
        _writeDeploymentArtifact(rpcUrl, deployment);
        console2.log("SeedLocalAnvil: completed successfully");
    }

    function _runPreflightChecks() private view {
        console2.log("SeedLocalAnvil: stage preflightChecks");
    }

    function _deployAndSeedSquid(address deployer) private returns (DeploymentResult memory deployment) {
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                | Hooks.BEFORE_DONATE_FLAG | Hooks.AFTER_DONATE_FLAG
        );

        bytes memory constructorArgs = abi.encode(IPoolManager(address(manager)), deployer);
        (address expectedHookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(Squid).creationCode, constructorArgs);

        Squid hook = new Squid{salt: salt}(IPoolManager(address(manager)), deployer);
        require(address(hook) == expectedHookAddress, "SeedLocalAnvil: unexpected hook address");

        address usdc = hook.USDC();
        address weth = hook.WETH();

        _mintAndApproveSupportedToken(usdc, deployer);
        _mintAndApproveSupportedToken(weth, deployer);

        hook.addWhitelistedToken(usdc);
        hook.addWhitelistedToken(weth);

        Currency currency0 = Currency.wrap(usdc);
        Currency currency1 = Currency.wrap(weth);

        PoolKey memory firstPool = _poolKey(currency0, currency1, hook, 3000, 60);
        PoolKey memory secondPool = _poolKey(currency0, currency1, hook, 500, 10);

        manager.initialize(firstPool, SQRT_PRICE_1_1);
        manager.initialize(secondPool, SQRT_PRICE_1_1);

        ModifyLiquidityParams memory liquidityParams = ModifyLiquidityParams({
            tickLower: DEFAULT_TICK_LOWER,
            tickUpper: DEFAULT_TICK_UPPER,
            liquidityDelta: DEFAULT_LIQUIDITY_DELTA,
            salt: bytes32(0)
        });

        modifyLiquidityRouter.modifyLiquidity(firstPool, liquidityParams, Constants.ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(secondPool, liquidityParams, Constants.ZERO_BYTES);

        swapRouter.swap(
            firstPool,
            SwapParams({zeroForOne: true, amountSpecified: -1e15, sqrtPriceLimitX96: SQRT_PRICE_1_2}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            Constants.ZERO_BYTES
        );

        deployment = DeploymentResult({
            deployer: deployer,
            squid: address(hook),
            poolManager: address(manager),
            usdc: usdc,
            weth: weth,
            firstPoolId: firstPool.toId(),
            secondPoolId: secondPool.toId()
        });
    }

    function _deployManagerAndRouters(address deployer) private {
        manager = new PoolManager(deployer);
        swapRouter = new PoolSwapTest(manager);
        swapRouterNoChecks = new SwapRouterNoChecks(manager);
        modifyLiquidityRouter = new PoolModifyLiquidityTest(manager);
        modifyLiquidityNoChecks = new PoolModifyLiquidityTestNoChecks(manager);
        donateRouter = new PoolDonateTest(manager);
        takeRouter = new PoolTakeTest(manager);
        claimsRouter = new PoolClaimsTest(manager);
        nestedActionRouter = new PoolNestedActionsTest(manager);
        actionsRouter = new ActionsRouter(manager);

        manager.setProtocolFeeController(address(0xFEE));
    }

    function _poolKey(Currency currency0, Currency currency1, Squid hook, uint24 fee, int24 tickSpacing)
        private
        pure
        returns (PoolKey memory)
    {
        if (Currency.unwrap(currency0) > Currency.unwrap(currency1)) {
            (currency0, currency1) = (currency1, currency0);
        }

        return PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(hook))
        });
    }

    function _mintAndApproveSupportedToken(address token, address deployer) private {
        MockERC20(token).mint(deployer, 2 ** 255);

        address[9] memory toApprove = [
            address(swapRouter),
            address(swapRouterNoChecks),
            address(modifyLiquidityRouter),
            address(modifyLiquidityNoChecks),
            address(donateRouter),
            address(takeRouter),
            address(claimsRouter),
            address(nestedActionRouter.executor()),
            address(actionsRouter)
        ];

        for (uint256 i = 0; i < toApprove.length; i++) {
            MockERC20(token).approve(toApprove[i], type(uint256).max);
        }
    }

    function _installSupportedTokenCode(string memory rpcUrl) private {
        MockERC20 mock = new MockERC20("Supported", "SPT", 18);
        bytes memory runtimeCode = address(mock).code;
        address[2] memory supportedTokens = [USDC, WETH];

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            console2.log("SeedLocalAnvil: setting token code", supportedTokens[i]);
            string memory params = string.concat(
                "[\"",
                vm.toString(supportedTokens[i]),
                "\",\"",
                vm.toString(runtimeCode),
                "\"]"
            );
            vm.rpc(rpcUrl, "anvil_setCode", params);
        }
    }

    function _writeDeploymentArtifact(string memory rpcUrl, DeploymentResult memory deployment) private {
        string memory objectKey = "localAnvil";
        string memory artifactPath = "deployments/local-anvil.json";

        vm.createDir("deployments", true);
        if (!vm.isDir("deployments")) {
            revert SeedInvariantFailed("Failed to create deployments directory inside foundry root");
        }
        vm.serializeUint(objectKey, "chainId", block.chainid);
        vm.serializeString(objectKey, "rpcUrl", rpcUrl);
        vm.serializeAddress(objectKey, "deployer", deployment.deployer);
        vm.serializeAddress(objectKey, "squidAddress", deployment.squid);
        vm.serializeAddress(objectKey, "poolManagerAddress", deployment.poolManager);
        vm.serializeAddress(objectKey, "usdcAddress", deployment.usdc);
        vm.serializeAddress(objectKey, "wethAddress", deployment.weth);

        bytes32[] memory poolIds = new bytes32[](2);
        poolIds[0] = PoolId.unwrap(deployment.firstPoolId);
        poolIds[1] = PoolId.unwrap(deployment.secondPoolId);
        vm.serializeBytes32(objectKey, "seededPoolIds", poolIds);

        uint256[] memory fees = new uint256[](2);
        fees[0] = 3000;
        fees[1] = 500;
        vm.serializeUint(objectKey, "seededPoolFees", fees);

        uint256[] memory tickSpacings = new uint256[](2);
        tickSpacings[0] = 60;
        tickSpacings[1] = 10;
        string memory json = vm.serializeUint(objectKey, "seededPoolTickSpacings", tickSpacings);

        vm.writeJson(json, artifactPath);
        if (!vm.exists(artifactPath)) {
            revert SeedInvariantFailed("Artifact file was not created after writeJson");
        }
        console2.log("SeedLocalAnvil: wrote artifact", artifactPath);
    }
}
