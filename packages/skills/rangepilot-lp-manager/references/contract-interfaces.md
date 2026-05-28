# Contract Interfaces

## 目录

- Solidity 类型映射
- VaultFactory 写接口
- UserLPVault 读接口
- UserLPVault 写接口
- Hook 读接口
- ERC20 辅助接口
- cast calldata 示例

## Solidity 类型映射

在 cast 和 EVM calldata 中：

- `PoolId` 编码为 `bytes32`
- `Currency` 编码为 token address
- `IHooks` 编码为 hook address
- `PoolKey` 编码为 `(address currency0,address currency1,uint24 fee,int24 tickSpacing,address hooks)`
- `StrategyConfig` 编码为 `(int24 minWidth,int24 maxWidth,int24 maxTickMovePerRebalance,uint16 maxSlippageBps,bool allowOutOfRangePosition)`
- `RebalancePlan` 编码为 `(bytes32 poolId,int24 newTickLower,int24 newTickUpper,uint128 liquidityToRemove,uint128 liquidityToAdd,uint256 amount0Min,uint256 amount1Min,uint256 amount0Max,uint256 amount1Max,uint256 deadline,uint256 nonce,bytes32 reasonHash)`
- `WithdrawPlan` 编码为 `(bytes32 poolId,uint256 amount0Min,uint256 amount1Min,uint256 deadline)`

创建 PoolKey 前必须按地址排序 token：

- `token0 = min(tokenA, tokenB)`
- `token1 = max(tokenA, tokenB)`

`PoolKey.hooks` 必须等于 `ManagedLPHook` 地址。

## VaultFactory 写接口

```solidity
createVault(address owner, address aiOperator) returns (address vault)
createVaultAndAddPool(address owner, address aiOperator, PoolKey key, StrategyConfig config)
    returns (address vault, PoolId poolId)
addPoolToVault(PoolKey key, StrategyConfig config) returns (PoolId poolId)
```

权限：

- `msg.sender` 必须是 `owner`
- `createVault` 和 `createVaultAndAddPool` 对同一个 owner 只能成功一次
- `addPoolToVault` 使用 `msg.sender` 查找该 owner 的现有 Vault

## UserLPVault 读接口

```solidity
owner() returns (address)
aiOperator() returns (address)
poolCount() returns (uint256)
poolIdAt(uint256 index) returns (PoolId)
isPoolEnabled(PoolId poolId) returns (bool)
getPoolKey(PoolId poolId) returns (PoolKey)
getStrategyConfig(PoolId poolId) returns (StrategyConfig)
getActivePosition(PoolId poolId) returns (ActivePosition)
getPoolBalance(PoolId poolId) returns (PoolBalance)
lastRebalanceTimestamp(PoolId poolId) returns (uint256)
usedNonces(PoolId poolId, uint256 nonce) returns (bool)
```

`ActivePosition`：

```solidity
(int24 tickLower, int24 tickUpper, uint128 liquidity, bytes32 salt)
```

`PoolBalance`：

```solidity
(uint256 idle0, uint256 idle1)
```

## UserLPVault 写接口

```solidity
deposit(PoolId poolId, uint256 amount0, uint256 amount1)
rebalance(RebalancePlan plan) returns (int256 amount0Delta, int256 amount1Delta)
collectFees(PoolId poolId) returns (uint256 amount0, uint256 amount1)
withdraw(WithdrawPlan plan) returns (uint256 amount0, uint256 amount1)
emergencyExit(PoolId poolId) returns (uint256 amount0, uint256 amount1)
updateStrategyConfig(PoolId poolId, StrategyConfig newConfig)
updateAIOperator(address newOperator)
revokeAIOperator()
```

权限：

- `deposit`、`withdraw`、`emergencyExit`、`updateStrategyConfig`、`updateAIOperator`、`revokeAIOperator`：owner only
- `rebalance`、`collectFees`：owner 或 aiOperator

## Hook 读接口

```solidity
registeredVaultForPool(PoolId poolId, address vault) returns (bool)
swapCount(PoolId poolId) returns (uint256)
lastSwapTimestamp(PoolId poolId) returns (uint256)
factory() returns (address)
poolManager() returns (address)
```

## ERC20 辅助接口

```solidity
decimals() returns (uint8)
balanceOf(address account) returns (uint256)
allowance(address owner, address spender) returns (uint256)
approve(address spender, uint256 amount) returns (bool)
```

不要使用无限授权。按本次 deposit 需要的数量或用户明确指定的上限授权。

## cast calldata 示例

所有写交易编码完成后，先用 `onchainos security tx-scan` 扫描，再用 `onchainos wallet contract-call` 发送。

### ERC20 approve

```bash
cast calldata "approve(address,uint256)" \
  <vault> \
  <amount>
```

### createVaultAndAddPool

```bash
cast calldata \
  "createVaultAndAddPool(address,address,(address,address,uint24,int24,address),(int24,int24,int24,uint16,bool))" \
  <owner> \
  <aiOperator> \
  "(<token0>,<token1>,<fee>,<tickSpacing>,<hook>)" \
  "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"
```

### addPoolToVault

```bash
cast calldata \
  "addPoolToVault((address,address,uint24,int24,address),(int24,int24,int24,uint16,bool))" \
  "(<token0>,<token1>,<fee>,<tickSpacing>,<hook>)" \
  "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"
```

### deposit

```bash
cast calldata "deposit(bytes32,uint256,uint256)" \
  <poolId> \
  <amount0> \
  <amount1>
```

### rebalance

```bash
cast calldata \
  "rebalance((bytes32,int24,int24,uint128,uint128,uint256,uint256,uint256,uint256,uint256,uint256,bytes32))" \
  "(<poolId>,<newTickLower>,<newTickUpper>,<liquidityToRemove>,<liquidityToAdd>,<amount0Min>,<amount1Min>,<amount0Max>,<amount1Max>,<deadline>,<nonce>,<reasonHash>)"
```

### collectFees

```bash
cast calldata "collectFees(bytes32)" <poolId>
```

### withdraw

```bash
cast calldata \
  "withdraw((bytes32,uint256,uint256,uint256))" \
  "(<poolId>,<amount0Min>,<amount1Min>,<deadline>)"
```

### emergencyExit

```bash
cast calldata "emergencyExit(bytes32)" <poolId>
```

### updateStrategyConfig

```bash
cast calldata \
  "updateStrategyConfig(bytes32,(int24,int24,int24,uint16,bool))" \
  <poolId> \
  "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"
```

### updateAIOperator / revoke

```bash
cast calldata "updateAIOperator(address)" <newOperator>
cast calldata "revokeAIOperator()"
```
