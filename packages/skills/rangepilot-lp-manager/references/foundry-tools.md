# Foundry / Cast Tools

## Contents

- Boundaries
- Selector and calldata
- poolId calculation
- Read-only queries
- StateView queries
- `eth_call` simulation
- Logs and transaction status
- Common troubleshooting

## Boundaries

This file requires only Foundry `cast`.

Recommended uses:

- Encode calldata.
- Compute selectors, poolIds, and reasonHash values.
- Read on-chain state.
- Simulate write functions with `eth_call`.
- Decode revert selectors or transaction logs.

Default write transactions should use OnchainOS. Do not broadcast with `cast send` unless the user explicitly asks for that execution path.

## Selector And Calldata

Query selectors:

```bash
cast sig "initialize((address,address,uint24,int24,address),uint160)"
cast sig "addPoolToVaultFor(address,(address,address,uint24,int24,address),(int24,int24,int24,uint16,bool))"
cast sig "deposit(bytes32,uint256,uint256)"
cast sig "rebalance((bytes32,int24,int24,uint128,uint128,uint256,uint256,uint256,uint256,uint256,uint256,bytes32))"
cast sig "updateStrategyConfig(bytes32,(int24,int24,int24,uint16,bool))"
```

Encode calldata:

```bash
cast calldata "<signature>" <args...>
```

reasonHash:

```bash
cast keccak "rangepilot:<action>:<vault>:<poolId>:<nonce>"
```

## poolId Calculation

`poolId = keccak256(abi.encode(currency0, currency1, fee, tickSpacing, hooks))`.

With cast:

```bash
ENCODED_KEY=$(cast abi-encode "f(address,address,uint24,int24,address)" \
  <currency0> \
  <currency1> \
  <fee> \
  <tickSpacing> \
  <hook>)

cast keccak $ENCODED_KEY
```

If shell variables are inconvenient, copy the output from `cast abi-encode` and pass it to `cast keccak`.

More reliable sources:

- Read `id` from the `PoolManager.Initialize` event.
- After the pool is bound to a Vault, read `poolCount()` and `poolIdAt(index)`.

## Read-Only Queries

### Factory

```bash
cast call <factory> "poolManager()(address)" --rpc-url <rpc>
cast call <factory> "hook()(address)" --rpc-url <rpc>
cast call <factory> "vaultImplementation()(address)" --rpc-url <rpc>
cast call <factory> "userVaults(address)(address)" <owner> --rpc-url <rpc>
cast call <factory> "isVault(address)(bool)" <vault> --rpc-url <rpc>
```

### Vault

```bash
cast call <vault> "owner()(address)" --rpc-url <rpc>
cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
cast call <vault> "factory()(address)" --rpc-url <rpc>
cast call <vault> "hook()(address)" --rpc-url <rpc>
cast call <vault> "poolManager()(address)" --rpc-url <rpc>
cast call <vault> "poolCount()(uint256)" --rpc-url <rpc>
cast call <vault> "poolIdAt(uint256)(bytes32)" <index> --rpc-url <rpc>
cast call <vault> "isPoolEnabled(bytes32)(bool)" <poolId> --rpc-url <rpc>
cast call <vault> "getPoolKey(bytes32)((address,address,uint24,int24,address))" <poolId> --rpc-url <rpc>
cast call <vault> "getStrategyConfig(bytes32)((int24,int24,int24,uint16,bool))" <poolId> --rpc-url <rpc>
cast call <vault> "getActivePosition(bytes32)((int24,int24,uint128,bytes32))" <poolId> --rpc-url <rpc>
cast call <vault> "getPoolBalance(bytes32)((uint256,uint256))" <poolId> --rpc-url <rpc>
cast call <vault> "lastRebalanceTimestamp(bytes32)(uint256)" <poolId> --rpc-url <rpc>
cast call <vault> "usedNonces(bytes32,uint256)(bool)" <poolId> <nonce> --rpc-url <rpc>
```

### Hook

```bash
cast call <hook> "factory()(address)" --rpc-url <rpc>
cast call <hook> "poolManager()(address)" --rpc-url <rpc>
cast call <hook> "registeredVaultForPool(bytes32,address)(bool)" <poolId> <vault> --rpc-url <rpc>
cast call <hook> "swapCount(bytes32)(uint256)" <poolId> --rpc-url <rpc>
cast call <hook> "lastSwapTimestamp(bytes32)(uint256)" <poolId> --rpc-url <rpc>
```

### ERC20

```bash
cast call <token> "symbol()(string)" --rpc-url <rpc>
cast call <token> "decimals()(uint8)" --rpc-url <rpc>
cast call <token> "balanceOf(address)(uint256)" <account> --rpc-url <rpc>
cast call <token> "allowance(address,address)(uint256)" <owner> <spender> --rpc-url <rpc>
```

## StateView Queries

```bash
cast call <stateView> "getSlot0(bytes32)(uint160,int24,uint24,uint24)" <poolId> --rpc-url <rpc>
cast call <stateView> "getLiquidity(bytes32)(uint128)" <poolId> --rpc-url <rpc>
cast call <stateView> "getTickLiquidity(bytes32,int24)(uint128,int128)" <poolId> <tick> --rpc-url <rpc>
cast call <stateView> "getPositionInfo(bytes32,address,int24,int24,bytes32)(uint128,uint256,uint256)" \
  <poolId> <vault> <tickLower> <tickUpper> <salt> --rpc-url <rpc>
```

If a pool is not initialized, `getSlot0` or direct PoolManager state reads may revert. Prefer StateView.

## `eth_call` Simulation

Simulation does not change on-chain state. Simulate critical calls before sending write transactions.

### PoolManager.initialize

```bash
cast call <poolManager> \
  "initialize((address,address,uint24,int24,address),uint160)(int24)" \
  "(<currency0>,<currency1>,<fee>,<tickSpacing>,<hook>)" \
  <sqrtPriceX96> \
  --from <sender> \
  --rpc-url <rpc>
```

### Vault.rebalance

```bash
cast call <vault> \
  "rebalance((bytes32,int24,int24,uint128,uint128,uint256,uint256,uint256,uint256,uint256,uint256,bytes32))(int256,int256)" \
  "(<poolId>,<lower>,<upper>,<removeLiq>,<addLiq>,<amount0Min>,<amount1Min>,<amount0Max>,<amount1Max>,<deadline>,<nonce>,<reasonHash>)" \
  --from <ownerOrAiOperator> \
  --rpc-url <rpc>
```

Returned `int256 amount0Delta/amount1Delta`:

- Negative usually means the Vault spent that token.
- Positive usually means the Vault received that token.

## Logs And Transaction Status

Get a receipt:

```bash
cast receipt <txHash> --rpc-url <rpc>
```

Useful events:

- PoolManager `Initialize`: confirm poolId, tick, and sqrtPriceX96.
- PoolManager `ModifyLiquidity`: confirm whether the Vault added or removed LP.
- PoolManager `Swap`: confirm whether the pool has seen swaps.
- Vault `PoolAdded`, `Deposited`, `Rebalanced`.
- Factory `VaultCreated`, `PoolAddedToVault`.
- Hook `VaultRegistered`, `SwapTelemetry`.

## Common Troubleshooting

Decode selector:

```bash
cast 4byte-decode <selector-or-revert-data>
```

Common error meanings:

- `CurrenciesOutOfOrderOrEqual`: PoolKey token ordering is wrong.
- `InvalidPoolHook`: `PoolKey.hooks` is not the current ManagedLPHook.
- `PoolNotEnabled`: pool is not bound to the Vault.
- `NotVaultManager`: sender calling `addPoolToVaultFor` is not owner or aiOperator.
- `NotOperator`: sender is not owner or aiOperator for the Vault write call.
- `NotOwner`: an owner-only function was called by a non-owner.
- `InsufficientIdleBalance`: the pool subaccount does not have enough idle tokens.
- `OutOfRangePosition`: current tick is outside the planned range and strategy disallows out-of-range positions.
- `TickMoveTooLarge`: moving an existing active position exceeds the strategy limit.
- `SlippageExceeded`: actual spent or received amounts violated the plan.
