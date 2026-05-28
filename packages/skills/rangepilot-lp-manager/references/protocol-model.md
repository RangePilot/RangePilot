# Protocol Model

## Contents

- What RangePilot is
- Core contracts
- Multi-pool Vault
- Permission model
- Pool lifecycle
- Address sources
- Required pre-operation checks

## What RangePilot Is

RangePilot is an AI-managed LP system based on Uniswap v4 Hooks and user-owned Vaults. User funds enter the user's own `UserLPVault` clone. The AI operator uses an owner-authorized address to perform rebalance, collect fees, bind pools, and update strategy parameters through the Vault.

Current model:

- At most one Vault per owner.
- One Vault can manage multiple Uniswap v4 pools.
- Each pool maps to an independent subaccount inside the Vault.
- Funds are always held by the Vault; the AI operator never directly receives user assets.

## Core Contracts

### VaultFactory

Factory creates user Vaults and binds Uniswap v4 pools to Vaults.

Key responsibilities:

- `createVault(owner, aiOperator)`: create the owner's unique Vault.
- `createVaultAndAddPool(owner, aiOperator, key, config)`: create a Vault and bind the first pool.
- `addPoolToVault(key, config)`: bind a pool using the caller as owner.
- `addPoolToVaultFor(owner, key, config)`: owner or that owner's Vault aiOperator binds a pool for the owner.
- During create/bind, Factory asks Hook to register the Vault's LP permission for that pool.

### UserLPVault

Vault holds user tokens and manages multiple LP subaccounts by poolId.

Each pool subaccount stores:

- `PoolKey`
- `StrategyConfig`
- `ActivePosition`
- `PoolBalance(idle0, idle1)`
- `lastRebalanceTimestamp`
- `usedNonces[poolId][nonce]`

### ManagedLPHook

Shared Uniswap v4 Hook that protects LP entrypoints.

Responsibilities:

- Allow only registered Vaults to add/remove liquidity for a specific pool.
- Block liquidity modifications from non-registered Vault addresses.
- Record `swapCount(poolId)` and `lastSwapTimestamp(poolId)`.
- Does not hold user funds, execute strategies, or swap for users.

### Uniswap v4 PoolManager / StateView

- `PoolManager.initialize(key, sqrtPriceX96)` creates and initializes a v4 pool.
- `StateView.getSlot0(poolId)` and `getLiquidity(poolId)` read pool state.
- RangePilot Vault manages LP internally through `PoolManager.unlock -> modifyLiquidity`.

## Multi-Pool Vault

One Vault can bind multiple pools. Treat each pool as a separate account:

- idle0/idle1 for `poolId A` can only be used for rebalancing `poolId A`.
- nonce is independent per poolId.
- active position is independent per poolId.
- withdrawing one pool should not affect other pools.

Even if two pools use the same token pair, do not move balance from one pool to another.

## Permission Model

### owner

Owner can:

- Create Vault.
- deposit.
- withdraw / emergencyExit.
- updateAIOperator / revokeAIOperator.
- rebalance / collectFees.
- updateStrategyConfig.
- addPoolToVault / addPoolToVaultFor.

### aiOperator

aiOperator can:

- rebalance.
- collectFees.
- updateStrategyConfig.
- bind a pool for the owner through `VaultFactory.addPoolToVaultFor(owner, key, config)`.

aiOperator cannot:

- deposit.
- withdraw / emergencyExit.
- updateAIOperator / revokeAIOperator.
- create the owner's Vault.

## Pool Lifecycle

Typical sequence:

1. Choose tokenA/tokenB and sort them into `currency0/currency1` by address.
2. Build `PoolKey(currency0, currency1, fee, tickSpacing, managedLPHook)`.
3. Create the v4 pool with `PoolManager.initialize(key, sqrtPriceX96)`.
4. Get or calculate poolId.
5. Create a Vault, or read the owner's existing Vault.
6. Use Factory to bind the pool to the Vault and register Hook permission.
7. Owner approves token0/token1 to the Vault.
8. Owner calls Vault `deposit(poolId, amount0, amount1)`.
9. Owner or aiOperator calls Vault `rebalance(plan)` to add/adjust LP.
10. Later operations include collect fees, rebalance, and withdraw.

Important: creating a pool does not bind the Vault; binding the Vault does not deposit funds; deposit does not mean active LP already exists.

## Address Sources

Do not guess addresses. Priority:

1. Explicit user-provided address in the current task.
2. Deployed addresses maintained in `references/deployments-and-explorer.md`.
3. Verified contract page on Explorer.
4. Deployment JSON in the current workspace only as a helper, not as a skill prerequisite.

If any of the following are missing, ask the user or guide them to verify via Explorer:

- `vaultFactory`
- `managedLPHook`
- `poolManager`
- `stateView`
- user Vault
- owner
- aiOperator
- token0/token1
- RPC URL

## Required Pre-Operation Checks

Before write transactions:

- chain matches all addresses.
- sender has the required role.
- `PoolKey.hooks == ManagedLPHook`.
- token ordering is `currency0 < currency1`.
- Vault belongs to the current Factory: `factory.isVault(vault) == true`.
- Vault `factory()`, `hook()`, and `poolManager()` match deployment addresses.
- If the pool is expected to be bound: `vault.isPoolEnabled(poolId) == true`.
- Hook is registered: `hook.registeredVaultForPool(poolId, vault) == true`.
