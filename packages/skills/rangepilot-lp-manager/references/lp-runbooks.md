# LP Runbooks

## Contents

- General execution framework
- Create a Uniswap v4 pool with RangePilot Hook
- Create a Vault
- Bind a pool to a Vault
- approve and deposit
- First LP add / rebalance
- liquidityToAdd calculation
- Move an existing LP range
- collect fees
- updateStrategyConfig
- withdraw / emergencyExit
- Swap availability checks
- State checklist

## General Execution Framework

Use the same flow for all write operations:

1. Clarify the user's goal, chain, sender, and target contract.
2. Confirm addresses from deployment docs or user input.
3. Read prerequisite state with `cast call`.
4. Encode the transaction with `cast calldata`.
5. Simulate critical write operations with `cast call`.
6. Run `onchainos security tx-scan`.
7. Send with `onchainos wallet contract-call`; do not use `--force` on the first attempt.
8. If the CLI returns a confirming response, show the message and wait for explicit user confirmation.
9. After the transaction, read state again and verify the result.

## Create A Uniswap v4 Pool With RangePilot Hook

Use this when the user wants to create a new v4 pool with RangePilot `ManagedLPHook`.

Collect:

- chain
- tokenA/tokenB
- fee
- tickSpacing
- `sqrtPriceX96`
- PoolManager
- ManagedLPHook
- sender

Steps:

1. Query token decimals and convert the human-readable initial price to raw token units.
2. Sort addresses:
   ```text
   currency0 = min(tokenA, tokenB)
   currency1 = max(tokenA, tokenB)
   ```
3. Build PoolKey:
   ```text
   (currency0, currency1, fee, tickSpacing, managedLPHook)
   ```
4. Calculate or confirm `sqrtPriceX96`:
   ```text
   rawPrice = amount1Raw / amount0Raw
   sqrtPriceX96 = sqrt(rawPrice) * 2^96
   ```
5. Encode:
   ```bash
   cast calldata \
     "initialize((address,address,uint24,int24,address),uint160)" \
     "(<currency0>,<currency1>,<fee>,<tickSpacing>,<hook>)" \
     <sqrtPriceX96>
   ```
6. Scan and call PoolManager.
7. After success, read poolId from the `Initialize` event or calculate poolId with `foundry-tools.md`.
8. Check with StateView:
   ```bash
   cast call <stateView> "getSlot0(bytes32)(uint160,int24,uint24,uint24)" <poolId> --rpc-url <rpc>
   ```

Notes:

- Pool creation only initializes price; it does not grant Vault permissions.
- Pool creation does not add liquidity.
- If the PoolKey is already initialized, initialize will fail; move directly to Vault binding.

## Create A Vault

Use this when the user does not yet have a Vault.

Collect:

- owner
- aiOperator
- VaultFactory
- sender must be owner

Steps:

1. Check whether a Vault already exists:
   ```bash
   cast call <factory> "userVaults(address)(address)" <owner> --rpc-url <rpc>
   ```
2. If a Vault already exists, stop creation and use the existing Vault.
3. Encode:
   ```bash
   cast calldata "createVault(address,address)" <owner> <aiOperator>
   ```
4. Scan and call Factory.
5. After success, read:
   ```bash
   cast call <factory> "userVaults(address)(address)" <owner> --rpc-url <rpc>
   cast call <vault> "owner()(address)" --rpc-url <rpc>
   cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
   ```

## Bind A Pool To A Vault

Use this when a pool already exists, or PoolKey is known, and the Vault needs permission to manage LP.

Collect:

- owner
- vault
- aiOperator
- Factory
- Hook
- PoolKey
- StrategyConfig
- sender: owner or aiOperator

Steps:

1. Get the Vault:
   ```bash
   cast call <factory> "userVaults(address)(address)" <owner> --rpc-url <rpc>
   ```
2. Validate the Vault:
   ```bash
   cast call <factory> "isVault(address)(bool)" <vault> --rpc-url <rpc>
   cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
   cast call <vault> "factory()(address)" --rpc-url <rpc>
   cast call <vault> "hook()(address)" --rpc-url <rpc>
   ```
3. Calculate poolId.
4. If `isPoolEnabled(poolId) == true`, do not bind again.
5. If sender is owner, encode:
   ```bash
   cast calldata \
     "addPoolToVault((address,address,uint24,int24,address),(int24,int24,int24,uint16,bool))" \
     "(<currency0>,<currency1>,<fee>,<tickSpacing>,<hook>)" \
     "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"
   ```
6. If sender is aiOperator, encode:
   ```bash
   cast calldata \
     "addPoolToVaultFor(address,(address,address,uint24,int24,address),(int24,int24,int24,uint16,bool))" \
     <owner> \
     "(<currency0>,<currency1>,<fee>,<tickSpacing>,<hook>)" \
     "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"
   ```
7. Scan and call Factory.
8. After success, confirm:
   ```bash
   cast call <vault> "isPoolEnabled(bytes32)(bool)" <poolId> --rpc-url <rpc>
   cast call <hook> "registeredVaultForPool(bytes32,address)(bool)" <poolId> <vault> --rpc-url <rpc>
   ```

## approve And deposit

Use this when the owner deposits tokens into one pool subaccount in the Vault.

Steps:

1. Read PoolKey and confirm currency0/currency1.
2. Convert user-entered amounts to raw amounts.
3. For token0 and token1, query balance and allowance:
   ```bash
   cast call <token> "balanceOf(address)(uint256)" <owner> --rpc-url <rpc>
   cast call <token> "allowance(address,address)(uint256)" <owner> <vault> --rpc-url <rpc>
   ```
4. If allowance is insufficient, owner approves the Vault:
   ```bash
   cast calldata "approve(address,uint256)" <vault> <amount>
   ```
5. After approval confirmation, call deposit:
   ```bash
   cast calldata "deposit(bytes32,uint256,uint256)" <poolId> <amount0> <amount1>
   ```
6. After success, read:
   ```bash
   cast call <vault> "getPoolBalance(bytes32)((uint256,uint256))" <poolId> --rpc-url <rpc>
   ```

Notes:

- deposit only increases idle balance; it does not automatically add LP.
- `amount0/amount1` order must match PoolKey, not the user's spoken token order.

## First LP Add / Rebalance

Use this when the Vault has deposited funds, the pool is bound, and active liquidity is 0.

Pre-reads:

```bash
cast call <vault> "getPoolBalance(bytes32)((uint256,uint256))" <poolId> --rpc-url <rpc>
cast call <vault> "getActivePosition(bytes32)((int24,int24,uint128,bytes32))" <poolId> --rpc-url <rpc>
cast call <vault> "getStrategyConfig(bytes32)((int24,int24,int24,uint16,bool))" <poolId> --rpc-url <rpc>
cast call <stateView> "getSlot0(bytes32)(uint160,int24,uint24,uint24)" <poolId> --rpc-url <rpc>
```

Plan generation:

1. Choose a tick range that satisfies StrategyConfig.
2. For the first active liquidity add, `maxTickMovePerRebalance` does not apply.
3. Calculate `liquidityToAdd` from current price, range, idle0, and idle1.
4. Set:
   ```text
   liquidityToRemove = 0
   amount0Min = 0
   amount1Min = 0
   amount0Max = idle0 or a more conservative cap
   amount1Max = idle1 or a more conservative cap
   deadline = now + 300
   nonce = unused random/time nonce
   reasonHash = cast keccak "initial-rebalance:<vault>:<poolId>:<nonce>"
   ```
5. Encode `rebalance(plan)`.
6. Simulate with `cast call` and confirm deltas are reasonable.
7. Run security scan and call the Vault as owner or aiOperator.
8. After success, read activePosition, poolBalance, and StateView liquidity.

Important:

- The agent cannot freely specify "how many tokens to use"; actual spending is determined by current price and tick range.
- If the deposit ratio does not match current price and range, one side may remain idle.
- To use both sides more closely, adjust the tick range or update StrategyConfig first.

## liquidityToAdd Calculation

When building `RebalancePlan`, `liquidityToAdd` must match current price, range, and Vault idle balances. Prefer a reliable Uniswap v4/v3 liquidity math library. If no library is available, calculate conservatively with the formulas below and confirm spending with `cast call`.

Symbols:

```text
Q96 = 2^96
S = current sqrtPriceX96
A = sqrtPriceX96 at tickLower
B = sqrtPriceX96 at tickUpper
amount0 = available token0 raw amount
amount1 = available token1 raw amount
```

Tick to sqrt price:

```text
sqrtPriceX96AtTick(tick) = sqrt(1.0001^tick) * 2^96
```

In production, integer rounding rules matter. If no on-chain/library helper is available, use high-precision decimal math, round conservatively, and make `cast call` simulation the final source of truth.

When current price is in range, `A < S < B`:

```text
liquidity0 = floor(amount0 * S * B / ((B - S) * Q96))
liquidity1 = floor(amount1 * Q96 / (S - A))
liquidityToAdd = min(liquidity0, liquidity1)
```

Expected spending:

```text
spent0 = ceil(liquidityToAdd * (B - S) * Q96 / (S * B))
spent1 = ceil(liquidityToAdd * (S - A) / Q96)
```

When price is out of range:

- `S <= A`: the position uses only token0.
- `S >= B`: the position uses only token1.
- If `allowOutOfRangePosition == false`, the Vault rejects out-of-range positions.

Conservative rules:

- Round `liquidityToAdd` down.
- To avoid max amount failures from rounding, reduce it by another 0.1%-1%.
- `amount0Max/amount1Max` must not exceed that pool's idle balance.
- After encoding, simulate with `cast call`, read returned deltas, and confirm actual spending does not exceed max.

## Move An Existing LP Range

Use this when an active position already exists and the range or liquidity should change.

Steps:

1. Read the old active position.
2. `liquidityToRemove` must equal the full old `activePosition.liquidity`.
3. The new range must satisfy:
   - Width is within min/max.
   - If out-of-range positions are not allowed, current tick is inside the new range.
   - Movement of lower/upper relative to the old lower/upper does not exceed `maxTickMovePerRebalance`.
4. Calculate `liquidityToAdd` from expected balances after removal plus existing idle.
5. Set `amount0Min/amount1Min` to protect received amounts during removal.
6. Set `amount0Max/amount1Max` to protect spending during add.
7. Simulate, scan, and send.

## collect fees

Use this when owner or aiOperator collects fees from the current active position into Vault idle.

Steps:

1. Confirm active liquidity > 0.
2. Encode:
   ```bash
   cast calldata "collectFees(bytes32)" <poolId>
   ```
3. Scan and call the Vault.
4. Read poolBalance and confirm idle balance increased.

## updateStrategyConfig

Use this when owner or aiOperator adjusts strategy boundaries for a pool.

Steps:

1. Read the old config.
2. Explain the impact of the new parameters.
3. Encode:
   ```bash
   cast calldata \
     "updateStrategyConfig(bytes32,(int24,int24,int24,uint16,bool))" \
     <poolId> \
     "(<minWidth>,<maxWidth>,<maxTickMovePerRebalance>,<maxSlippageBps>,<allowOutOfRangePosition>)"
   ```
4. Scan and call the Vault.
5. Read the new config.

## withdraw / emergencyExit

### withdraw

Use this when the owner withdraws funds for a pool. If there is an active position, the Vault first removes that position, then sends that pool's idle funds to the owner.

Encode:

```bash
cast calldata \
  "withdraw((bytes32,uint256,uint256,uint256))" \
  "(<poolId>,<amount0Min>,<amount1Min>,<deadline>)"
```

Only owner can call. After success, confirm active liquidity is 0 and poolBalance is cleared for that pool.

### emergencyExit

Use this only for emergency exits without min amount protection.

```bash
cast calldata "emergencyExit(bytes32)" <poolId>
```

The owner must explicitly request it. Prefer withdraw; use emergencyExit only in urgent scenarios.

## Swap Availability Checks

Read-only aggregator quote:

```bash
onchainos swap quote \
  --from <tokenIn> \
  --to <tokenOut> \
  --readable-amount <amount> \
  --chain xlayer
```

Interpretation:

- Quote succeeds: continue evaluating price impact and execution.
- `Input value is too low`: amount may be too small, token may lack a valid price, or the aggregator may not have indexed it.
- `Insufficient liquidity`: the aggregator may not have found a route; check on-chain StateView.

On-chain confirmation:

```bash
cast call <stateView> "getLiquidity(bytes32)(uint128)" <poolId> --rpc-url <rpc>
cast call <hook> "swapCount(bytes32)(uint256)" <poolId> --rpc-url <rpc>
```

Direct v4 swap requires unlock callback and settlement logic. Without a dedicated helper, do not ask a normal wallet to call `PoolManager.swap` directly.

## State Checklist

After each operation, read at least the relevant items:

```bash
cast call <vault> "getPoolBalance(bytes32)((uint256,uint256))" <poolId> --rpc-url <rpc>
cast call <vault> "getActivePosition(bytes32)((int24,int24,uint128,bytes32))" <poolId> --rpc-url <rpc>
cast call <stateView> "getSlot0(bytes32)(uint160,int24,uint24,uint24)" <poolId> --rpc-url <rpc>
cast call <stateView> "getLiquidity(bytes32)(uint128)" <poolId> --rpc-url <rpc>
cast call <hook> "registeredVaultForPool(bytes32,address)(bool)" <poolId> <vault> --rpc-url <rpc>
```
