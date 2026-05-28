# Risk Controls

## 目录

- 绝对禁止
- 角色和权限
- 授权风控
- RebalancePlan 风控
- 交易风控
- 失败处理

## 绝对禁止

Agent 绝不能：

- 提款到非 owner 地址。
- 未经 owner 明确要求调用 `withdraw` 或 `emergencyExit`。
- 未经 owner 明确要求调用 `updateStrategyConfig`、`updateAIOperator`、`revokeAIOperator`。
- 使用无限 ERC20 授权。
- 直接调用 `PoolManager` 管理用户头寸。
- 对未启用或未注册的 pool 执行 rebalance。
- 把一个 pool 的 idle 资金用于另一个 pool。
- 在安全扫描 `block` 时继续发送交易。
- 在交易模拟或扫描失败后静默广播。
- 第一次 `onchainos wallet contract-call` 就添加 `--force`。

## 角色和权限

写交易前必须确认当前 sender：

- `owner` 可以执行所有 owner 操作。
- `aiOperator` 只能执行 `rebalance` 和 `collectFees`。
- 其他地址不能操作 Vault。

检查：

```bash
cast call <vault> "owner()(address)" --rpc-url <rpc>
cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
onchainos wallet addresses --chain <chain>
```

如果当前 OnchainOS 钱包不是所需角色，停止并让用户切换账户。

## 授权风控

ERC20 approve 规则：

- spender 必须是用户自己的 Vault 地址。
- amount 只覆盖本次 deposit 或用户明确指定的上限。
- 不要用 `type(uint256).max`。
- approve 前先查 allowance，足够则不重复授权。
- approve calldata 必须先做 tx-scan。

## RebalancePlan 风控

生成计划前必须验证：

### Pool 状态

- `isPoolEnabled(poolId) == true`
- `registeredVaultForPool(poolId, vault) == true`
- PoolKey 的 hook 等于 ManagedLPHook
- token0/token1 与用户指定 pool 一致

### Tick

- `newTickLower < newTickUpper`
- lower/upper 都在 Uniswap v4 TickMath 范围内
- lower/upper 都能被 `tickSpacing` 整除
- width = upper - lower
- `minWidth <= width <= maxWidth`
- 如果 `allowOutOfRangePosition == false`，当前 tick 必须在 `[newTickLower, newTickUpper)` 内

### 移动幅度

如果当前有 active position：

- `abs(newTickLower - oldTickLower) <= maxTickMovePerRebalance`
- `abs(newTickUpper - oldTickUpper) <= maxTickMovePerRebalance`

### 流动性

当前合约规则：

- 如果 active liquidity > 0，`liquidityToRemove` 必须等于当前全部 liquidity。
- 不支持部分移除旧 position。
- `liquidityToAdd == 0 && liquidityToRemove == 0` 会 revert。
- 添加流动性前必须确保该 pool 的 `idle0/idle1` 足够。

### nonce

- `usedNonces(poolId, nonce) == false`
- nonce 按 pool 独立，不同 pool 可以使用相同 nonce。

### deadline

- 推荐 `deadline = now + 300`。
- 不要使用长 deadline。
- 如果用户长时间未确认，重新生成 calldata 和 deadline。

### slippage

链上用 `amount0Min/amount1Min` 和 `amount0Max/amount1Max` 执行保护：

- remove liquidity：实际收到必须 >= `amount0Min/amount1Min`
- add liquidity：实际花费必须 <= `amount0Max/amount1Max`

当前合约保留 `maxSlippageBps` 字段，但不会自动根据报价计算 bps。Agent 必须在生成 plan 时离线使用 `maxSlippageBps` 计算安全的 min/max。不能把 `amount0Min/amount1Min` 随意设为 0，除非用户明确接受且该场景确实是初次加仓、不涉及移除流动性。

## 交易风控

每个写交易：

1. 用 cast 编码 calldata。
2. 用 `onchainos security tx-scan` 扫描。
3. 如有 `warn`，展示风险并等待用户确认。
4. 如有 `block`，停止。
5. 用 `onchainos wallet contract-call` 首次不带 `--force`。
6. 如有 confirming，展示 message，用户确认后再按 next 加 `--force`。
7. 交易后读取状态验证。

## 失败处理

常见 revert：

- `NotOwner`：sender 不是 owner。
- `NotOperator`：sender 不是 aiOperator 或 owner。
- `PoolNotEnabled`：pool 未添加到 Vault。
- `InsufficientIdleBalance`：该 pool 子账户余额不足，不能挪用其他 pool。
- `NonceAlreadyUsed`：该 pool 的 nonce 已使用。
- `InvalidTickRange`：tick 或 width 不合规。
- `TickMoveTooLarge`：超出 maxTickMovePerRebalance。
- `OutOfRangePosition`：策略不允许 out-of-range。
- `SlippageExceeded`：实际收支超出 plan 限制。

失败后不要自动放宽风控参数。向用户解释原因，重新读取状态，再生成新的 plan。
