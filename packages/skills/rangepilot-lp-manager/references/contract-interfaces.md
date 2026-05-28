# Contract Interfaces

## Contents

- Type encoding
- Uniswap v4 PoolManager / StateView
- VaultFactory
- UserLPVault
- ManagedLPHook
- ERC20
- Calldata templates

## Type Encoding

Struct shapes for EVM/cast:

```text
PoolId           bytes32
PoolKey          (address currency0,address currency1,uint24 fee,int24 tickSpacing,address hooks)
StrategyConfig   (int24 minWidth,int24 maxWidth,int24 maxTickMovePerRebalance,uint16 maxSlippageBps,bool allowOutOfRangePosition)
ActivePosition   (int24 tickLower,int24 tickUpper,uint128 liquidity,bytes32 salt)
PoolBalance      (uint256 idle0,uint256 idle1)
RebalancePlan    (bytes32 poolId,int24 newTickLower,int24 newTickUpper,uint128 liquidityToRemove,uint128 liquidityToAdd,uint256 amount0Min,uint256 amount1Min,uint256 amount0Max,uint256 amount1Max,uint256 deadline,uint256 nonce,bytes32 reasonHash)
WithdrawPlan     (bytes32 poolId,uint256 amount0Min,uint256 amount1Min,uint256 deadline)
```

PoolKey rules:

- `currency0` must be the numerically smaller token address.
- `currency1` must be the numerically larger token address.
- `hooks` must be the current network's `ManagedLPHook`.
- RangePilot Vault does not support native currency; token addresses must not be `0x000...000`.

PoolId:

- `poolId = keccak256(abi.encode(PoolKey))`.
- The `PoolManager.Initialize` event emits `PoolId indexed id`.
- After the pool is bound to a Vault, it can also be read with `poolCount()` and `poolIdAt(index)`.

## Uniswap v4 PoolManager / StateView

### PoolManager Write Interface

```solidity
initialize(PoolKey key, uint160 sqrtPriceX96) returns (int24 tick)
```

Notes:

- Creates and initializes a v4 pool.
- `sqrtPriceX96` is not a constant; it must be derived from the initial price.
- The same PoolKey can be initialized only once. Calling it again after initialization reverts.

### PoolManager Events

```solidity
event Initialize(
    PoolId indexed id,
    Currency indexed currency0,
    Currency indexed currency1,
    uint24 fee,
    int24 tickSpacing,
    IHooks hooks,
    uint160 sqrtPriceX96,
    int24 tick
)

event Swap(
    PoolId indexed id,
    address indexed sender,
    int128 amount0,
    int128 amount1,
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 tick,
    uint24 fee
)
```

### StateView Read Interface

```solidity
getSlot0(PoolId poolId) returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
getLiquidity(PoolId poolId) returns (uint128 liquidity)
getTickLiquidity(PoolId poolId, int24 tick) returns (uint128 liquidityGross, int128 liquidityNet)
getPositionInfo(PoolId poolId, address owner, int24 tickLower, int24 tickUpper, bytes32 salt)
    returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128)
```

## VaultFactory

### Read Interface

```solidity
poolManager() returns (address)
hook() returns (address)
vaultImplementation() returns (address)
userVaults(address owner) returns (address vault)
isVault(address vault) returns (bool)
```

### Write Interface

```solidity
createVault(address owner, address aiOperator) returns (address vault)

createVaultAndAddPool(
    address owner,
    address aiOperator,
    PoolKey key,
    StrategyConfig config
) returns (address vault, PoolId poolId)

addPoolToVault(PoolKey key, StrategyConfig config) returns (PoolId poolId)

addPoolToVaultFor(
    address owner,
    PoolKey key,
    StrategyConfig config
) returns (PoolId poolId)
```

Permissions:

- `createVault` / `createVaultAndAddPool`: `msg.sender == owner`.
- `addPoolToVault`: uses `msg.sender` as the owner.
- `addPoolToVaultFor`: `msg.sender == owner` or `msg.sender == userVaults[owner].aiOperator()`.

## UserLPVault

### Read Interface

```solidity
owner() returns (address)
aiOperator() returns (address)
factory() returns (address)
hook() returns (address)
poolManager() returns (address)
poolCount() returns (uint256)
poolIdAt(uint256 index) returns (bytes32)
isPoolEnabled(bytes32 poolId) returns (bool)
getPoolKey(bytes32 poolId) returns (PoolKey)
getStrategyConfig(bytes32 poolId) returns (StrategyConfig)
getActivePosition(bytes32 poolId) returns (ActivePosition)
getPoolBalance(bytes32 poolId) returns (PoolBalance)
lastRebalanceTimestamp(bytes32 poolId) returns (uint256)
usedNonces(bytes32 poolId, uint256 nonce) returns (bool)
```

### Write Interface

```solidity
deposit(bytes32 poolId, uint256 amount0, uint256 amount1)
rebalance(RebalancePlan plan) returns (int256 amount0Delta, int256 amount1Delta)
collectFees(bytes32 poolId) returns (uint256 amount0, uint256 amount1)
withdraw(WithdrawPlan plan) returns (uint256 amount0, uint256 amount1)
emergencyExit(bytes32 poolId) returns (uint256 amount0, uint256 amount1)
updateStrategyConfig(bytes32 poolId, StrategyConfig newConfig)
updateAIOperator(address newOperator)
revokeAIOperator()
```

Permissions:

- Owner only: `deposit`, `withdraw`, `emergencyExit`, `updateAIOperator`, `revokeAIOperator`.
- Owner or aiOperator: `rebalance`, `collectFees`, `updateStrategyConfig`.

## ManagedLPHook

### Read Interface

```solidity
poolManager() returns (address)
owner() returns (address)
factory() returns (address)
registeredVaultForPool(bytes32 poolId, address vault) returns (bool)
swapCount(bytes32 poolId) returns (uint256)
lastSwapTimestamp(bytes32 poolId) returns (uint256)
```

### Behavior

- Hook `beforeAddLiquidity` and `beforeRemoveLiquidity` check whether the sender is a Vault registered for that pool.
- Hook `afterSwap` records swap telemetry.
- Do not ask non-Vault addresses to call `PoolManager.modifyLiquidity` directly; the Hook will block them.

## ERC20

```solidity
decimals() returns (uint8)
symbol() returns (string)
balanceOf(address account) returns (uint256)
allowance(address owner, address spender) returns (uint256)
approve(address spender, uint256 amount) returns (bool)
```

Approval rules:

- The spender is the user's own Vault, not Hook, Factory, or PoolManager.
- The amount should cover only this deposit or a user-confirmed upper limit.
- Do not default to unlimited approvals.

## Calldata Templates

### PoolManager.initialize

```bash
cast calldata \
  "initialize((address,address,uint24,int24,address),uint160)" \
  "(<currency0>,<currency1>,<fee>,<tickSpacing>,<hook>)" \
  <sqrtPriceX96>
```

### createVault

```bash
cast calldata "createVault(address,address)" <owner> <aiOperator>
```

### createVaultAndAddPool

```bash
cast calldata \
  "createVaultAndAddPool(address,address,(address,address,uint24,int24,address),(int24,int24,int24,uint16,bool))" \
  <owner> \
  <aiOperator> \
  "(<currency0>,<currency1>,<fee>,<tickSpacing>,<hook>)" \
  "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"
```

### addPoolToVault / addPoolToVaultFor

```bash
cast calldata \
  "addPoolToVault((address,address,uint24,int24,address),(int24,int24,int24,uint16,bool))" \
  "(<currency0>,<currency1>,<fee>,<tickSpacing>,<hook>)" \
  "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"

cast calldata \
  "addPoolToVaultFor(address,(address,address,uint24,int24,address),(int24,int24,int24,uint16,bool))" \
  <owner> \
  "(<currency0>,<currency1>,<fee>,<tickSpacing>,<hook>)" \
  "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"
```

### approve / deposit

```bash
cast calldata "approve(address,uint256)" <vault> <amount>
cast calldata "deposit(bytes32,uint256,uint256)" <poolId> <amount0> <amount1>
```

### rebalance

```bash
cast calldata \
  "rebalance((bytes32,int24,int24,uint128,uint128,uint256,uint256,uint256,uint256,uint256,uint256,bytes32))" \
  "(<poolId>,<newTickLower>,<newTickUpper>,<liquidityToRemove>,<liquidityToAdd>,<amount0Min>,<amount1Min>,<amount0Max>,<amount1Max>,<deadline>,<nonce>,<reasonHash>)"
```

### collect / withdraw / emergency

```bash
cast calldata "collectFees(bytes32)" <poolId>

cast calldata \
  "withdraw((bytes32,uint256,uint256,uint256))" \
  "(<poolId>,<amount0Min>,<amount1Min>,<deadline>)"

cast calldata "emergencyExit(bytes32)" <poolId>
```

### strategy / operator

```bash
cast calldata \
  "updateStrategyConfig(bytes32,(int24,int24,int24,uint16,bool))" \
  <poolId> \
  "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"

cast calldata "updateAIOperator(address)" <newOperator>
cast calldata "revokeAIOperator()"
```
