# Vault Onboarding

## Goal

This file guides an agent through the first-time RangePilot setup flow for normal users. The goal is not to perform every on-chain action on behalf of the user, but to clearly separate owner-only steps, agent-executable steps, and the preconditions required before rebalance.

User entrypoint:

```text
https://www.rangepilot.xyz
```

## Core Principles

- Users create Vaults, set AI Operator, approve, and deposit through the Web app.
- The agent uses its own OnchainOS EVM address as `aiOperator`, and must clearly tell the user that address.
- Only after the agent has been set as the Vault `aiOperator` can it bind pools for that owner, execute rebalance, collect fees, or update strategy parameters.
- The agent must not perform withdraw, emergency exit, revoke AI Operator, or update AI Operator for the user. Those actions must be performed by the owner.
- After a pool is bound to the Vault, there are still no funds the agent can operate on. The user must deposit first, then the agent can rebalance with the Vault's idle balance.
- Never ask the user for private keys, seed phrases, keystore passwords, OTPs, or browser wallet signing screenshots.

## Agent Prechecks

Before guiding the user, read:

- `requirements.md`
- `deployments-and-explorer.md`
- `protocol-model.md`
- `contract-interfaces.md`

Confirm:

- OnchainOS CLI is available.
- OnchainOS wallet is logged in.
- Foundry `cast` is available.
- Target chain is X Layer mainnet or X Layer testnet.
- Factory, Hook, and PoolManager match the user's selected chain.

Get the agent's OnchainOS EVM address:

```bash
onchainos wallet addresses --chain xlayer
```

If the environment uses a singular CLI command, try:

```bash
onchainos wallet address
```

When showing it to the user, use clear wording:

```text
My OnchainOS EVM address is: 0x...
Please enter this address as AI Operator when creating your Vault on the RangePilot website.
```

## First-Time Vault Creation

When the user does not yet have a RangePilot Vault, guide them to:

1. Visit `https://www.rangepilot.xyz`.
2. Connect their browser wallet.
3. Switch to the target network, for example X Layer.
4. Enter the AI Operator address in the create Vault panel.
5. Use the agent's OnchainOS EVM address as AI Operator.
6. Click create Vault and confirm the wallet transaction.

After the user finishes, ask for one of:

- owner wallet address, or
- Vault creation transaction hash, or
- the chain the user selected.

Then query the Vault through Factory:

```bash
cast call <vaultFactory> "userVaults(address)(address)" <owner> --rpc-url <rpc>
```

Verify:

```bash
cast call <vaultFactory> "isVault(address)(bool)" <vault> --rpc-url <rpc>
cast call <vault> "owner()(address)" --rpc-url <rpc>
cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
cast call <vault> "factory()(address)" --rpc-url <rpc>
cast call <vault> "hook()(address)" --rpc-url <rpc>
cast call <vault> "poolManager()(address)" --rpc-url <rpc>
```

Only continue with AI-operator actions if `aiOperator()` equals the agent's OnchainOS EVM address.

If `aiOperator()` does not match:

- Tell the user which AI Operator is currently set on the Vault.
- Ask the owner to update AI Operator through the Web app or contract.
- Do not attempt pool binding or rebalance from the wrong address.

## Ask Which Pool To Bind

After Vault creation, ask which Uniswap v4 pool with RangePilot `ManagedLPHook` should be bound to the Vault.

Recommended question:

```text
Which pool with the RangePilot LP Hook do you want to bind to this Vault?
Please provide the poolId, or provide token0/token1, fee, tickSpacing, and hook address.
```

The user may provide only a pair, for example:

```text
USDT / RPT
```

In that case, the agent must fill in or query:

- token0 / token1 addresses, in sorted PoolKey order.
- fee.
- tickSpacing.
- hooks address.
- poolId.
- whether the pool has already been initialized.

Before binding, confirm:

```bash
cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
cast call <vault> "isPoolEnabled(bytes32)(bool)" <poolId> --rpc-url <rpc>
cast call <hook> "registeredVaultForPool(bytes32,address)(bool)" <poolId> <vault> --rpc-url <rpc>
```

PoolKey `hooks` must equal the current chain's RangePilot `ManagedLPHook`. If the pool was not created with this hook, do not treat it as a RangePilot-managed pool.

## Agent Binds Pool To Vault

When the agent is the Vault `aiOperator`, it can call Factory:

```solidity
addPoolToVaultFor(owner, key, config)
```

Before executing, read the "Bind A Pool To A Vault" section in `lp-runbooks.md`, and apply permission and parameter checks from `risk-controls.md`.

After successful binding, verify:

```bash
cast call <vault> "isPoolEnabled(bytes32)(bool)" <poolId> --rpc-url <rpc>
cast call <hook> "registeredVaultForPool(bytes32,address)(bool)" <poolId> <vault> --rpc-url <rpc>
cast call <vault> "getStrategyConfig(bytes32)((int24,int24,int24,uint16,bool))" <poolId> --rpc-url <rpc>
```

Then tell the user:

```text
The pool is now bound to your Vault. Next, please deposit tokens into this pool's Vault subaccount on the website. After deposit, those funds become idle balance, and I can rebalance them into an LP position.
```

## Guide The User To deposit

The agent must clearly tell the user:

- deposit is owner-only.
- Tokens still go into the user's own Vault; they are not transferred to the agent.
- After deposit, funds are idle balance and are not active LP yet.
- The agent can rebalance only after the user deposits funds into the Vault.

Recommended user steps:

1. Visit `https://www.rangepilot.xyz`.
2. Connect the owner wallet.
3. Select the newly created Vault.
4. Find the bound pool.
5. Enter token0 and token1 deposit amounts.
6. Confirm approve and deposit transactions.

Token order reminder:

```text
Note that Vault deposit amount0/amount1 follows PoolKey token0/token1 order, which may not match the spoken pair order. I will confirm token0 and token1 first.
```

After the user deposits, read idle balance:

```bash
cast call <vault> "getPoolBalance(bytes32)((uint256,uint256))" <poolId> --rpc-url <rpc>
```

If idle balance is 0 or insufficient:

- Do not rebalance.
- Tell the user the current Vault subaccount balance is insufficient.
- Guide the user to deposit more or reduce the planned liquidity.

## Confirmation Before Rebalance

Only continue to rebalance if all conditions are met:

- Vault exists.
- `aiOperator()` equals the agent's OnchainOS EVM address, or owner explicitly executes rebalance themselves.
- Pool is bound to the Vault.
- Hook has registered the Vault.
- User has deposited, and the target pool subaccount has enough idle balance.
- Agent has read current tick, strategy config, and active position.
- RebalancePlan satisfies `risk-controls.md`.

Recommended confirmation:

```text
I have confirmed your Vault, AI Operator, pool binding, and idle balance. Next I will generate a RebalancePlan from the current tick and your strategy limits, run a security scan, and ask for confirmation before execution.
```

## User Communication Templates

### User Is Just Starting

```text
Please visit https://www.rangepilot.xyz and connect your X Layer wallet.
I will give you my OnchainOS EVM address; enter it as AI Operator when creating your Vault.
```

### Provide AI Operator

```text
My OnchainOS EVM address is: 0x...
Please enter it in the AI Operator field and create the Vault. After the transaction confirms, send me your wallet address or transaction hash so I can verify the Vault.
```

### Ask For Pool

```text
Your Vault has been created and verified. Which pool with the RangePilot LP Hook do you want to bind?
You can provide poolId; if you do not know it, provide token0/token1, fee, tickSpacing, and hook address.
```

### Reminder Before deposit

```text
After the pool is bound, you still need to deposit tokens into the Vault. Only after deposit will the funds enter this pool's idle balance, so I can rebalance them into an LP position.
```

### After deposit, Before Rebalance

```text
I will read the Vault idle balance, current tick, active position, and strategy parameters first. If the balance matches the allowed strategy range, I will generate a rebalance plan and run a security scan.
```

## Common Blocking Cases

| Case | Agent response |
|---|---|
| User has no Vault | Guide them to create a Vault on the website and set the agent's OnchainOS EVM address |
| AI Operator mismatch | Stop AI-operator actions and ask the owner to update AI Operator |
| User provided a pool without RangePilot hook | Do not bind it as a RangePilot-managed pool; ask for a PoolKey with ManagedLPHook |
| Pool is bound but no deposit | Ask the user to deposit; do not rebalance |
| deposit balance is insufficient | Explain the current idle balance and ask the user to deposit more or reduce liquidity |
| User asks agent to withdraw | Refuse to execute it and explain that withdraw must be performed by owner |
