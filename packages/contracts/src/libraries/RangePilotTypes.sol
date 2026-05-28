// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

struct StrategyConfig {
    int24 minWidth;
    int24 maxWidth;
    int24 maxTickMovePerRebalance;
    uint16 maxSlippageBps;
    bool allowOutOfRangePosition;
}

struct PoolBalance {
    uint256 idle0;
    uint256 idle1;
}

struct ActivePosition {
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    bytes32 salt;
}

struct RebalancePlan {
    PoolId poolId;
    int24 newTickLower;
    int24 newTickUpper;
    uint128 liquidityToRemove;
    uint128 liquidityToAdd;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 amount0Max;
    uint256 amount1Max;
    uint256 deadline;
    uint256 nonce;
    bytes32 reasonHash;
}

struct WithdrawPlan {
    PoolId poolId;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
}
