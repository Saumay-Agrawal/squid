// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IReactive} from "./interfaces/IReactive.sol";

contract MockReactiveContract is IReactive {
    uint64 internal constant CALLBACK_GAS_LIMIT = 300_000;

    uint256 public immutable destinationChainId;
    address public immutable callback;
    address public immutable squid;
    address public immutable reactVmId;

    uint256 internal constant BREACH_EVENT_SELECTOR =
        uint256(keccak256("PoolActivePositionThresholdBreached(bytes32,uint32,uint32,uint32)"));
    uint256 internal constant RECOVERY_EVENT_SELECTOR =
        uint256(keccak256("PoolActivePositionThresholdRecovered(bytes32,uint32,uint32,uint32)"));

    address public lastCallbackTarget;
    bytes public lastCallbackPayload;

    error UnsupportedReactiveEvent(uint256 topic0);
    error CallbackExecutionFailed();

    constructor(uint256 _destinationChainId, address _callback, address _squid, address _reactVmId) {
        destinationChainId = _destinationChainId;
        callback = _callback;
        squid = _squid;
        reactVmId = _reactVmId;
    }

    function react(LogRecord calldata log) external {
        (bytes32 poolId,,, uint32 activePositionPercentageBps) = abi.decode(log.data, (bytes32, uint32, uint32, uint32));

        bytes memory payload;

        if (log.topic_0 == BREACH_EVENT_SELECTOR) {
            payload = abi.encodeWithSignature(
                "guardPool(address,address,bytes32,uint32)", reactVmId, squid, poolId, activePositionPercentageBps
            );
        } else if (log.topic_0 == RECOVERY_EVENT_SELECTOR) {
            payload = abi.encodeWithSignature(
                "unguardPool(address,address,bytes32,uint32)", reactVmId, squid, poolId, activePositionPercentageBps
            );
        } else {
            revert UnsupportedReactiveEvent(log.topic_0);
        }

        lastCallbackTarget = callback;
        lastCallbackPayload = payload;

        emit Callback(destinationChainId, callback, CALLBACK_GAS_LIMIT, payload);
    }

    function executeLastCallback() external {
        (bool ok,) = lastCallbackTarget.call(lastCallbackPayload);
        if (!ok) revert CallbackExecutionFailed();
    }
}
