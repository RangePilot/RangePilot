# Risk Controls

## Contents

- Absolute prohibitions
- Permission risk controls
- Pool creation risk controls
- Approval and deposit risk controls
- RebalancePlan risk controls
- StrategyConfig risk controls
- Transaction sending risk controls
- Failure handling

## Absolute Prohibitions

The agent must never:

- Call `withdraw` or `emergencyExit` unless the owner explicitly asks.
- Send withdrawn funds to a non-owner address.
- Use unlimited ERC20 approve unless the user explicitly requests it and confirms the risk.
- Ask a non-Vault address to `modifyLiquidity` directly and bypass RangePilot.
- Rebalance a pool that is not bound or not registered in Hook.
- Use pool A's idle balance for pool B.
- Continue sending a transaction when tx-scan returns `block`.
- Silently broadcast after scan failure or simulation failure.
- Add `--force` on the first OnchainOS `contract-call`.
- Conclude that an on-chain pool does not exist or has no liquidity only because OKX DEX aggregator quote failed.

## Permission Risk Controls

Before write transactions, read:

```bash
cast call <vault> "owner()(address)" --rpc-url <rpc>
cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
onchainos wallet addresses --chain xlayer
```

Permission table:

| Operation | Contract | Allowed sender |
|---|---|---|
| createVault | VaultFactory | owner |
| createVaultAndAddPool | VaultFactory | owner |
| addPoolToVault | VaultFactory | owner itself |
| addPoolToVaultFor | VaultFactory | owner or aiOperator |
| deposit | UserLPVault | owner |
| rebalance | UserLPVault | owner or aiOperator |
| collectFees | UserLPVault | owner or aiOperator |
| updateStrategyConfig | UserLPVault | owner or aiOperator |
| withdraw | UserLPVault | owner |
| emergencyExit | UserLPVault | owner |
| updateAIOperator / revokeAIOperator | UserLPVault | owner |

If the OnchainOS wallet address is not the required role, stop and ask the user to switch wallets or update the Vault `aiOperator`.

## Pool Creation Risk Controls

Before creating a Uniswap v4 pool, confirm:

- tokenA/tokenB are ERC20 tokens and addresses are different.
- `currency0/currency1` are sorted by address.
- `PoolKey.hooks` is the current network's RangePilot `ManagedLPHook`.
- fee and tickSpacing match the user's target.
- `sqrtPriceX96` is calculated from the initial price, not treated as a constant.
- The PoolKey is not initialized yet, or the user explicitly knows that the pool already exists.

`sqrtPriceX96` direction:

- Uniswap v4 price uses raw token units.
- `price = amount1Raw / amount0Raw`.
- `sqrtPriceX96 = sqrt(price) * 2^96`.
- Token decimals affect raw price. Do not use only human-readable amount ratios.

## Approval And deposit Risk Controls

approve:

- spender must be the user's Vault.
- amount must not exceed this deposit's requirement or the user-specified cap.
- Check allowance before approving.
- Handle token0 and token1 separately.
- deposit only after approval succeeds.

deposit:

- Can only be called by owner.
- amount0/amount1 correspond to PoolKey currency0/currency1, not the user's spoken tokenA/tokenB order.
- amount0 and amount1 must not both be 0.
- deposit only creates idle balance; it does not create active LP.

## RebalancePlan Risk Controls

Before generating a plan, read:

- Vault owner / aiOperator.
- `isPoolEnabled(poolId)`.
- Hook `registeredVaultForPool(poolId, vault)`.
- `getPoolKey(poolId)`.
- `getStrategyConfig(poolId)`.
- `getActivePosition(poolId)`.
- `getPoolBalance(poolId)`.
- StateView `getSlot0(poolId)`.
- `usedNonces(poolId, nonce)`.

### Tick Checks

- `newTickLower < newTickUpper`.
- lower/upper are within Uniswap v4 tick bounds.
- lower/upper are divisible by `tickSpacing`.
- width = `newTickUpper - newTickLower`.
- `minWidth <= width <= maxWidth`.
- If `allowOutOfRangePosition == false`, current tick must be in `[newTickLower, newTickUpper)`.
- The first active position is not limited by `maxTickMovePerRebalance`.
- If active liquidity already exists, lower/upper movement relative to the old position must not exceed `maxTickMovePerRebalance`.

### Liquidity Checks

- If current active liquidity > 0, `liquidityToRemove` must equal the full current liquidity.
- The current contract does not support partial removal of the old active position.
- `liquidityToAdd == 0 && liquidityToRemove == 0` will revert.
- Before adding liquidity, ensure this pool's idle0/idle1 can cover `amount0Max/amount1Max`.

### nonce / deadline

- nonce is per-pool.
- `usedNonces(poolId, nonce)` must be false.
- Recommended deadline is within 5 minutes.
- If user confirmation takes too long, regenerate deadline and calldata.

### slippage

On-chain checks:

- remove: actual received amount0/amount1 must be >= `amount0Min/amount1Min`.
- add: actual spent amount0/amount1 must be <= `amount0Max/amount1Max`.

`maxSlippageBps` is a strategy field; the contract does not automatically calculate min/max for the agent. The agent must incorporate it when generating a plan. For first add without removal, `amount0Min/amount1Min` may be 0. For migration of an existing position, do not casually set them to 0.

## StrategyConfig Risk Controls

In the current MVP, both owner and aiOperator can call `updateStrategyConfig`.

Before changing config:

- Explain how the new parameters change risk.
- Avoid raising `maxSlippageBps` too high without a reason.
- Avoid enabling `allowOutOfRangePosition` without a reason.
- After modification, read `getStrategyConfig(poolId)` to confirm it took effect.

Suggested defaults:

```text
minWidth: 60
maxWidth: 600
maxTickMovePerRebalance: 120
maxSlippageBps: 500
allowOutOfRangePosition: false
```

Adjust by pool tickSpacing. If tickSpacing is greater than 1, all tick widths and bounds must align.

## Transaction Sending Risk Controls

For every write transaction:

1. Read state and confirm preconditions.
2. Encode calldata.
3. Simulate with `cast call` when needed.
4. Run `onchainos security tx-scan`.
5. After a safe scan, send with `onchainos wallet contract-call`; do not use `--force` on the first attempt.
6. If a confirming response appears, wait for user confirmation.
7. After the transaction, read state and verify.

## Failure Handling

Common errors:

- `NotOwner`: sender is not owner.
- `NotOperator`: sender is not owner or aiOperator.
- `NotVaultManager`: Factory `addPoolToVaultFor` sender is not owner/aiOperator.
- `VaultAlreadyExists`: owner already has a Vault; proceed to pool binding.
- `VaultNotFound`: owner has no Vault.
- `InvalidPoolHook`: PoolKey.hooks is wrong.
- `PoolAlreadyEnabled`: the pool is already bound.
- `PoolNotEnabled`: the Vault has not enabled the pool.
- `InsufficientIdleBalance`: deposit is insufficient or pool balance is too low.
- `NonceAlreadyUsed`: nonce was already used.
- `InvalidTickRange`: tick order, tickSpacing, or width is wrong.
- `OutOfRangePosition`: current tick is not inside the range.
- `TickMoveTooLarge`: existing active position moved too far.
- `SlippageExceeded`: min/max amount protection triggered.

After failure, read on-chain state again before changing anything. Do not automatically relax risk parameters.
