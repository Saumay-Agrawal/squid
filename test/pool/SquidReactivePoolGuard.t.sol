// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CustomRevert} from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {Squid} from "../../src/Squid.sol";
import {MockReactiveContract} from "../../src/reactive/MockReactiveContract.sol";
import {MockPoolGuardReceiver} from "../../src/reactive/MockPoolGuardReceiver.sol";
import {IReactive} from "../../src/reactive/interfaces/IReactive.sol";
import {PoolSummary} from "../../src/types/PoolMetrics.sol";
import {SquidTestBase} from "../helpers/SquidTestBase.t.sol";
import {TestToken} from "../helpers/TestTokens.sol";

contract SquidReactivePoolGuardTest is SquidTestBase {
    using PoolIdLibrary for PoolKey;

    uint256 internal constant LOCAL_CHAIN_ID = 31337;
    int256 internal constant BREACH_SWAP_AMOUNT = -1e17;
    bytes32 internal constant BREACH_EVENT_SELECTOR =
        keccak256("PoolActivePositionThresholdBreached(bytes32,uint32,uint32,uint32)");
    bytes32 internal constant RECOVERY_EVENT_SELECTOR =
        keccak256("PoolActivePositionThresholdRecovered(bytes32,uint32,uint32,uint32)");

    MockReactiveContract internal reactiveContract;
    MockPoolGuardReceiver internal receiver;
    PoolKey internal poolKey;

    function setUp() public override {
        super.setUp();

        TestToken tokenA = new TestToken("Token A", "TKNA");
        TestToken tokenB = new TestToken("Token B", "TKNB");
        _mintAndApprove(address(tokenA));
        _mintAndApprove(address(tokenB));

        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        manager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));

        receiver = new MockPoolGuardReceiver();
        reactiveContract = new MockReactiveContract(LOCAL_CHAIN_ID, address(receiver), address(hook), address(0xBEEF));
        hook.setPoolGuardOperator(address(receiver));

        _seedGuardablePool();
    }

    function test_reactiveCallbackHaltsAndUnhaltsLiquidityAdds() public {
        Vm.Log memory breachLog = _captureSingleThresholdLog(true, BREACH_SWAP_AMOUNT, BREACH_EVENT_SELECTOR);

        reactiveContract.react(_toReactiveLogRecord(breachLog));
        reactiveContract.executeLastCallback();

        PoolId poolId = poolKey.toId();
        assertTrue(hook.isPoolAddLiquidityHalted(poolId));
        assertTrue(hook.isPoolActivePositionThresholdBreached(poolId));

        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                IHooks.beforeAddLiquidity.selector,
                abi.encodeWithSelector(Squid.PoolAddLiquidityHalted.selector, PoolId.unwrap(poolId)),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        _addLiquidity(-60, 60, 1e18, bytes32("blocked-add"));

        Vm.Log memory recoveryLog = _captureRecoveryThresholdLog();

        reactiveContract.react(_toReactiveLogRecord(recoveryLog));
        reactiveContract.executeLastCallback();

        assertFalse(hook.isPoolAddLiquidityHalted(poolId));
        assertFalse(hook.isPoolActivePositionThresholdBreached(poolId));

        _addLiquidity(-60, 60, 1e18, bytes32("allowed-add"));
    }

    function test_breachEventDoesNotRepeatWhilePoolRemainsBelowThreshold() public {
        _captureSingleThresholdLog(true, BREACH_SWAP_AMOUNT, BREACH_EVENT_SELECTOR);

        vm.recordLogs();
        _addLiquidity(120, 240, 1e18, bytes32("still-below"));
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(_countThresholdLogs(entries, BREACH_EVENT_SELECTOR), 0);
        assertEq(_countThresholdLogs(entries, RECOVERY_EVENT_SELECTOR), 0);
    }

    function test_poolDoesNotRecoverWhileStillBelowThreshold() public {
        _captureSingleThresholdLog(true, BREACH_SWAP_AMOUNT, BREACH_EVENT_SELECTOR);

        PoolSummary memory summaryAfterBreach = hook.getPoolSummary(poolKey.toId());
        assertEq(summaryAfterBreach.positions.activePositionPercentageBps, 2000);

        vm.recordLogs();
        _addLiquidity(-6000, 6000, 1e18, bytes32("partial-recovery"));
        Vm.Log[] memory entries = vm.getRecordedLogs();

        PoolSummary memory summaryInDeadband = hook.getPoolSummary(poolKey.toId());
        assertEq(summaryInDeadband.positions.activePositionPercentageBps, 3333);

        assertEq(_countThresholdLogs(entries, RECOVERY_EVENT_SELECTOR), 0);
        assertTrue(hook.isPoolActivePositionThresholdBreached(poolKey.toId()));
    }

    function _seedGuardablePool() internal {
        _addLiquidity(-6000, 6000, 5e18, bytes32("anchor"));
        _addLiquidity(-60, 60, 1e18, bytes32("narrow-1"));
        _addLiquidity(-60, 60, 1e18, bytes32("narrow-2"));
        _addLiquidity(-60, 60, 1e18, bytes32("narrow-3"));
        _addLiquidity(-60, 60, 1e18, bytes32("narrow-4"));
    }

    function _addLiquidity(int24 tickLower, int24 tickUpper, int256 liquidityDelta, bytes32 salt) internal {
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: liquidityDelta,
                salt: salt
            }),
            ""
        );
    }

    function _captureSingleThresholdLog(bool zeroForOne, int256 amountSpecified, bytes32 expectedTopic)
        internal
        returns (Vm.Log memory selectedLog)
    {
        vm.recordLogs();
        swap(poolKey, zeroForOne, amountSpecified, "");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 matchCount;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].emitter == address(hook) && entries[i].topics.length > 0 && entries[i].topics[0] == expectedTopic) {
                selectedLog = entries[i];
                matchCount += 1;
            }
        }

        assertEq(matchCount, 1);
    }

    function _captureRecoveryThresholdLog() internal returns (Vm.Log memory selectedLog) {
        for (uint256 i; i < 12; ++i) {
            vm.recordLogs();
            swap(poolKey, false, -1e16, "");
            Vm.Log[] memory entries = vm.getRecordedLogs();

            for (uint256 j; j < entries.length; ++j) {
                if (
                    entries[j].emitter == address(hook) && entries[j].topics.length > 0
                        && entries[j].topics[0] == RECOVERY_EVENT_SELECTOR
                ) {
                    return entries[j];
                }
            }
        }

        assertTrue(false);
    }

    function _countThresholdLogs(Vm.Log[] memory entries, bytes32 topic) internal view returns (uint256 count) {
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].emitter == address(hook) && entries[i].topics.length > 0 && entries[i].topics[0] == topic) {
                count += 1;
            }
        }
    }

    function _toReactiveLogRecord(Vm.Log memory entry) internal view returns (IReactive.LogRecord memory record) {
        record.chain_id = block.chainid;
        record._contract = entry.emitter;
        record.topic_0 = uint256(entry.topics[0]);
        record.topic_1 = entry.topics.length > 1 ? uint256(entry.topics[1]) : 0;
        record.topic_2 = entry.topics.length > 2 ? uint256(entry.topics[2]) : 0;
        record.topic_3 = entry.topics.length > 3 ? uint256(entry.topics[3]) : 0;
        record.data = entry.data;
        record.block_number = block.number;
        record.op_code = 0;
        record.block_hash = uint256(blockhash(block.number - 1));
        record.tx_hash = 0;
        record.log_index = 0;
    }
}
