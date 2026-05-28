# Overview

## What This Project Does

RangePilot is an AI-managed LP system for Uniswap v4 concentrated liquidity. Users deposit funds into their own Vault. The AI operator uses controlled contract interfaces to help users create or bind pools, adjust LP ranges, collect fees, and rebalance within user-defined strategy boundaries.

The project is not a generic swap frontend. Its goal is to let AI manage user LP positions safely:

- Users retain ownership of funds.
- Each owner has one independent Vault clone.
- One Vault can manage multiple Uniswap v4 pools.
- Each pool has independent idle balance, active position, strategy config, and nonce.
- The AI operator never directly holds user funds; it can only perform allowed actions through the Vault.

## Why This Agent Skill Exists

RangePilot's primary operator is an AI agent. The agent needs to know:

- How to use OKX OnchainOS to send contract calls after security scanning.
- How to use cast/Foundry to encode calldata, read on-chain state, and simulate transactions.
- How to create a Uniswap v4 pool with RangePilot `ManagedLPHook`.
- How to bind a pool to a user Vault.
- How to generate `RebalancePlan` from idle balances and current price.
- How to explain aggregator quote failures, hook permission failures, tick range failures, and related issues.

Users installing this skill may not have the RangePilot source code. Therefore the docs are based on contract addresses, ABI signatures, Explorer pages, and standard tools.

## Core User Flow

### 1. Create Or Confirm Vault

After connecting a wallet, the user creates a Vault for the owner and sets `aiOperator`. The `aiOperator` is usually the agent's OnchainOS EVM/X Layer address.

Relevant contracts:

- `VaultFactory.createVault(owner, aiOperator)`
- `VaultFactory.userVaults(owner)`
- `UserLPVault.owner()`
- `UserLPVault.aiOperator()`

### 2. Create A Hooked Uniswap v4 Pool

The agent builds a `PoolKey` from token pair, fee, tickSpacing, and initial price, then calls `PoolManager.initialize`.

Key points:

- Token addresses must be sorted as `currency0 < currency1`.
- `hooks` must be the current network's RangePilot `ManagedLPHook`.
- `sqrtPriceX96` is calculated from initial price; it is not a constant.
- poolId is `keccak256(abi.encode(PoolKey))`, and can also be read from the `Initialize` event.

### 3. Bind Pool To Vault

After pool creation, the PoolKey must be bound to the user's Vault through `VaultFactory`. During binding, Factory registers that Vault's LP permissions with Hook.

Relevant contracts:

- `VaultFactory.addPoolToVault(...)`
- `VaultFactory.addPoolToVaultFor(owner, ...)`
- `UserLPVault.isPoolEnabled(poolId)`
- `ManagedLPHook.registeredVaultForPool(poolId, vault)`

### 4. Deposit

The owner approves token0/token1 to the Vault, then calls:

```solidity
UserLPVault.deposit(poolId, amount0, amount1)
```

After deposit, funds enter that pool's idle balance, but are not active LP yet.

### 5. Rebalance / Add LP

Owner or aiOperator reads current tick, idle balance, strategy config, and active position, then generates `RebalancePlan` and calls:

```solidity
UserLPVault.rebalance(plan)
```

For the first LP add:

- `liquidityToRemove = 0`
- `liquidityToAdd` is calculated from current price, tick range, idle0, and idle1
- Actual spending ratio is determined by Uniswap v4 price and range; it cannot be arbitrarily specified

When an active position already exists:

- The current contract requires removing the full old position liquidity in one rebalance
- The new range must satisfy `maxTickMovePerRebalance`

### 6. Fees, Strategy Updates, Exit

Owner or aiOperator can:

- `collectFees(poolId)`
- `updateStrategyConfig(poolId, newConfig)`

Owner can:

- `withdraw(plan)`
- `emergencyExit(poolId)`
- `updateAIOperator(newOperator)`
- `revokeAIOperator()`

## Contract Role Map

```text
owner
  |
  |- creates UserLPVault through VaultFactory
  |
  |- deposits token0/token1 into UserLPVault
  |
  |- may set aiOperator

aiOperator
  |
  |- can bind pool through VaultFactory.addPoolToVaultFor
  |- can update strategy config
  |- can rebalance LP position
  |- can collect fees

UserLPVault
  |
  |- holds user funds
  |- stores per-pool idle balances and active positions
  |- modifies liquidity through PoolManager.unlock

ManagedLPHook
  |
  |- verifies registered vaults for add/remove liquidity
  |- records swap telemetry

PoolManager / StateView
  |
  |- initializes v4 pools
  |- executes swaps and liquidity changes
  |- exposes pool state through StateView
```

## Default Agent Workflow

1. Read this file first to understand the objective.
2. Read `requirements.md` to confirm tools.
3. Load the task-specific reference file.
4. For every write transaction, read state, encode calldata, simulate, and run security scan.
5. Send with OnchainOS.
6. After the transaction, read on-chain state and explain the result to the user.

## Current Known Limitations

- OKX DEX aggregator may not immediately index custom RPT or custom v4 Hook pools.
- Aggregator quote errors such as `Input value is too low` or `Insufficient liquidity` do not prove there is no on-chain liquidity.
- Direct v4 swap testing usually requires a dedicated unlock callback / settlement helper contract.
- Agents should not call `PoolManager.modifyLiquidity` directly to bypass Vault.
- Agents should not design permission logic around `tx.origin`; contract permissions are based on `msg.sender`.
