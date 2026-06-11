// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISquidPoolGuard {
    function haltPoolLiquidityAdds(bytes32 poolId) external;
    function unhaltPoolLiquidityAdds(bytes32 poolId) external;
}

contract MockPoolGuardReceiver {
    event PoolGuarded(bytes32 poolId, uint32 activePositionPercentageBps, address reactVmId);
    event PoolUnguarded(bytes32 poolId, uint32 activePositionPercentageBps, address reactVmId);

    function guardPool(address reactVmId, address squid, bytes32 poolId, uint32 activePositionPercentageBps) external {
        ISquidPoolGuard(squid).haltPoolLiquidityAdds(poolId);
        emit PoolGuarded(poolId, activePositionPercentageBps, reactVmId);
    }

    function unguardPool(address reactVmId, address squid, bytes32 poolId, uint32 activePositionPercentageBps)
        external
    {
        ISquidPoolGuard(squid).unhaltPoolLiquidityAdds(poolId);
        emit PoolUnguarded(poolId, activePositionPercentageBps, reactVmId);
    }
}
