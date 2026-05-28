// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    ActivePosition,
    PoolBalance,
    RebalancePlan,
    StrategyConfig,
    WithdrawPlan
} from "../libraries/RangePilotTypes.sol";

interface IRangePilotVault {
    function owner() external view returns (address);
    function aiOperator() external view returns (address);
    function poolCount() external view returns (uint256);
    function poolIdAt(uint256 index) external view returns (PoolId);
    function isPoolEnabled(PoolId poolId) external view returns (bool);
    function getPoolKey(PoolId poolId) external view returns (PoolKey memory);
    function getStrategyConfig(PoolId poolId) external view returns (StrategyConfig memory);
    function getActivePosition(PoolId poolId) external view returns (ActivePosition memory);
    function getPoolBalance(PoolId poolId) external view returns (PoolBalance memory);
    function lastRebalanceTimestamp(PoolId poolId) external view returns (uint256);
    function usedNonces(PoolId poolId, uint256 nonce) external view returns (bool);

    function initializeFromFactory(
        address owner_,
        address aiOperator_,
        address factory_,
        address hook_,
        IPoolManager poolManager_
    ) external;

    function addPool(PoolKey calldata key, StrategyConfig calldata config_) external returns (PoolId);
    function deposit(PoolId poolId, uint256 amount0, uint256 amount1) external;
    function rebalance(RebalancePlan calldata plan) external returns (int256 amount0Delta, int256 amount1Delta);
    function collectFees(PoolId poolId) external returns (uint256 amount0, uint256 amount1);
    function withdraw(WithdrawPlan calldata plan) external returns (uint256 amount0, uint256 amount1);
    function emergencyExit(PoolId poolId) external returns (uint256 amount0, uint256 amount1);
    function updateStrategyConfig(PoolId poolId, StrategyConfig calldata newConfig) external;
    function updateAIOperator(address newOperator) external;
    function revokeAIOperator() external;
}
