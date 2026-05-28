# Protocol Model

## 目录

- RangePilot 是什么
- 合约角色
- 多 pool Vault 模型
- 地址来源
- 必须确认的信息

## RangePilot 是什么

RangePilot 是一个基于 Uniswap v4 Hook + 用户独立 Vault 的 LP 管理系统。用户资金放在自己的 `UserLPVault` clone 中；AI operator 只是在用户设定的边界内执行 LP rebalance。

当前架构不再是“一 Vault 一 pool”。一个 owner 仍只有一个 Vault，但该 Vault 可以添加多个 Uniswap v4 pool。Vault 内部按 `poolId` 保存独立的 `PoolAccount`：

- `PoolKey`
- `StrategyConfig`
- `ActivePosition`
- `PoolBalance(idle0, idle1)`
- `lastRebalanceTimestamp`
- `usedNonces[poolId][nonce]`

## 合约角色

### ManagedLPHook

共享 Hook，绑定到使用该 Hook 初始化的 Uniswap v4 pool。

职责：

- 只允许已注册 Vault 对指定 `poolId` add/remove liquidity。
- 验证 tick range 和 tick spacing。
- 记录 LP 操作和 swap telemetry。
- 不持有资金，不执行策略。

### VaultFactory

创建每用户唯一 Vault，并给已有 Vault 添加 pool。

核心入口：

- `createVault(owner, aiOperator)`
- `createVaultAndAddPool(owner, aiOperator, key, config)`
- `addPoolToVault(key, config)`

### UserLPVault

持有用户资金并管理多个 pool 子账户。

权限：

- owner：`deposit`、`withdraw`、`emergencyExit`、`updateStrategyConfig`、`updateAIOperator`、`revokeAIOperator`
- aiOperator 或 owner：`rebalance`、`collectFees`
- Factory：`addPool`

## 多 pool Vault 模型

每个 pool 都有自己的 token 对、策略、头寸和 idle 余额。即使两个 pool 使用同一对 token，也不能互相挪用余额。

Agent 在任何写操作前必须确认：

- 当前 `poolId` 已在 Vault 中启用：`isPoolEnabled(poolId) == true`
- Hook 已注册 Vault：`registeredVaultForPool(poolId, vault) == true`
- 当前钱包角色匹配操作权限
- 当前操作只影响用户指定的 pool

## 地址来源

不要假设安装 skill 的 agent 拥有 RangePilot 源码仓库、`packages/contracts` 目录或部署 JSON。地址来源按优先级：

- 用户明确提供的地址。
- `references/deployments-and-explorer.md` 中维护的已部署地址。
- XLayer Explorer 上已验证的合约页面。
- 如果当前工作区恰好包含项目源码和 deployment 文件，可以辅助读取，但不能把它作为 skill 的必要前提。

如果缺少以下地址，向用户索取或引导用户到 XLayer Explorer 确认，不要猜：

- `vaultFactory`
- `managedLPHook`
- `userLPVaultImplementation`
- 用户自己的 `vault`
- `stateView`
- `poolManager`
- RPC URL

## 必须确认的信息

创建或管理 pool 前收集：

- chain：默认 `xlayer`，测试网需确认 OnchainOS 是否支持
- owner 地址
- aiOperator 地址
- Factory 地址
- Hook 地址
- tokenA/tokenB 地址
- fee，如 `3000`
- tickSpacing，如 `60`
- StrategyConfig
- 是否已有 Vault

生成 RebalancePlan 前收集：

- vault 地址
- poolId
- 当前 tick
- activePosition
- pool idle balance
- StrategyConfig
- 上次 rebalance 时间
- nonce 是否已用
- 用户目标：加仓、撤仓、移动 range、收窄/放宽、只 collect fees 等
