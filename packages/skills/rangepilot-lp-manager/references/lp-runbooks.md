# LP Runbooks

## 目录

- 通用执行框架
- 创建 Vault 并添加第一个 pool
- 给已有 Vault 添加 pool
- approve 和 deposit
- 读取 Vault 状态
- 生成并执行 rebalance
- collect fees
- withdraw
- revoke AI operator

## 通用执行框架

任何写操作都遵循：

1. 确认用户意图、chain、sender、合约地址。
2. 用 cast 或区块浏览器做 read-only 校验。
3. 编码 calldata。
4. 运行 `onchainos security tx-scan`。
5. 如果安全扫描允许，运行 `onchainos wallet contract-call`，首次不带 `--force`。
6. 如果返回 confirming，展示消息并等待用户确认。
7. 交易完成后读取状态验证。

## 创建 Vault 并添加第一个 pool

适用：用户首次使用 RangePilot。

收集：

- `owner`
- `aiOperator`
- `vaultFactory`
- `managedLPHook`
- tokenA/tokenB
- fee
- tickSpacing
- StrategyConfig

步骤：

1. 排序 token 得到 `token0/token1`。
2. 读取 `factory.userVaults(owner)`。如果已有 Vault，不要重复创建，改走“给已有 Vault 添加 pool”。
3. 构造 PoolKey：`(token0, token1, fee, tickSpacing, hook)`。
4. 编码 `createVaultAndAddPool` calldata。
5. 扫描并调用 Factory。
6. 完成后读取：
   ```bash
   cast call <factory> "userVaults(address)(address)" <owner> --rpc-url <rpc>
   cast call <vault> "poolCount()(uint256)" --rpc-url <rpc>
   cast call <vault> "poolIdAt(uint256)(bytes32)" 0 --rpc-url <rpc>
   ```
7. 校验 `isPoolEnabled(poolId)` 和 `hook.registeredVaultForPool(poolId, vault)`。

## 给已有 Vault 添加 pool

适用：owner 已经有 Vault，需要管理另一个资金池。

步骤：

1. 读取 `factory.userVaults(owner)`，确认非零。
2. 排序 token，构造 PoolKey。
3. 检查 PoolKey 使用的 hook 等于 `ManagedLPHook`。
4. 编码 `addPoolToVault(key, config)`。
5. 用 owner 钱包扫描并调用 Factory。
6. 交易后读取最新 `poolCount` 和 `poolIdAt(poolCount - 1)`。
7. 校验 `isPoolEnabled(poolId)` 与 Hook 注册状态。

## approve 和 deposit

适用：owner 将 token0/token1 存入某个 pool 子账户。

步骤：

1. 读取 Vault 的 PoolKey，确认 token0/token1。
2. 查询 owner 余额和 allowance：
   ```bash
   cast call <token0> "balanceOf(address)(uint256)" <owner> --rpc-url <rpc>
   cast call <token0> "allowance(address,address)(uint256)" <owner> <vault> --rpc-url <rpc>
   ```
3. 如果 allowance 不足，编码 ERC20 `approve(vault, amount)`。不要使用无限授权。
4. 对 token0/token1 分别扫描并调用 approve。
5. 编码 `deposit(poolId, amount0, amount1)`。
6. 用 owner 钱包扫描并调用 Vault。
7. 交易后读取 `getPoolBalance(poolId)`，确认 idle0/idle1 增加。

## 读取 Vault 状态

推荐读取项：

```bash
cast call <vault> "owner()(address)" --rpc-url <rpc>
cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
cast call <vault> "poolCount()(uint256)" --rpc-url <rpc>
cast call <vault> "poolIdAt(uint256)(bytes32)" <index> --rpc-url <rpc>
cast call <vault> "isPoolEnabled(bytes32)(bool)" <poolId> --rpc-url <rpc>
cast call <vault> "getPoolKey(bytes32)((address,address,uint24,int24,address))" <poolId> --rpc-url <rpc>
cast call <vault> "getStrategyConfig(bytes32)((int24,int24,int24,uint16,bool))" <poolId> --rpc-url <rpc>
cast call <vault> "getActivePosition(bytes32)((int24,int24,uint128,bytes32))" <poolId> --rpc-url <rpc>
cast call <vault> "getPoolBalance(bytes32)((uint256,uint256))" <poolId> --rpc-url <rpc>
cast call <vault> "lastRebalanceTimestamp(bytes32)(uint256)" <poolId> --rpc-url <rpc>
```

如果有 StateView：

```bash
cast call <stateView> "getSlot0(bytes32)(uint160,int24,uint24,uint24)" <poolId> --rpc-url <rpc>
```

## 生成并执行 rebalance

适用：AI operator 在用户策略边界内移动 LP range 或调整流动性。

前置读取：

- `owner`
- `aiOperator`
- 当前 sender
- `getStrategyConfig(poolId)`
- `getActivePosition(poolId)`
- `getPoolBalance(poolId)`
- `lastRebalanceTimestamp(poolId)`
- `usedNonces(poolId, nonce)`
- StateView 当前 tick
- Hook 注册状态

生成 RebalancePlan：

- `poolId`：目标 pool
- `newTickLower/newTickUpper`：必须按 tickSpacing 对齐
- `liquidityToRemove`：如果当前有 active liquidity，必须等于当前全部 liquidity；当前合约不支持部分移除
- `liquidityToAdd`：新 range 添加的 liquidity；撤仓时可以为 0
- `amount0Min/amount1Min`：移除流动性时最少收到
- `amount0Max/amount1Max`：添加流动性时最多花费
- `deadline`：推荐当前时间 + 300 秒
- `nonce`：未使用的新 nonce
- `reasonHash`：策略理由哈希，例如 `cast keccak "rebalance:<vault>:<poolId>:<nonce>:<reason>"`

执行：

1. 根据 `contract-interfaces.md` 编码 `rebalance`.
2. 运行 tx-scan。
3. 用 aiOperator 或 owner 钱包调用 Vault。
4. 交易后读取 activePosition 和 poolBalance。

## collect fees

适用：只收取当前 active position 的 accrued fees，保留在对应 pool 子账户。

步骤：

1. 确认 sender 是 aiOperator 或 owner。
2. 确认 activePosition.liquidity > 0。
3. 编码 `collectFees(poolId)`。
4. 扫描并调用 Vault。
5. 读取 `getPoolBalance(poolId)` 验证 idle 增加。

## withdraw

适用：owner 提取某个 pool 子账户的全部 idle 余额，并在有 active position 时先移除该 pool 的全部流动性。

步骤：

1. 必须由 owner 明确要求。
2. 编码 `withdraw((poolId, amount0Min, amount1Min, deadline))`。
3. `deadline` 推荐 5 分钟以内。
4. 扫描并用 owner 钱包调用 Vault。
5. 交易后读取 activePosition 和 poolBalance，确认该 pool 清空。

注意：`withdraw(pool A)` 不应影响 pool B。

## revoke AI operator

适用：用户要撤销 AI 管理权限。

步骤：

1. 必须由 owner 明确要求。
2. 编码 `revokeAIOperator()`。
3. 扫描并调用 Vault。
4. 读取 `aiOperator()`，确认变为 `0x0000000000000000000000000000000000000000`。
