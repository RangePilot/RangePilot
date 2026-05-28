---
name: rangepilot-lp-manager
description: 使用 OKX OnchainOS CLI、cast 和 RangePilot 已部署合约地址帮助用户创建 Vault、添加 Uniswap v4 pool、授权、存入资金、读取状态、生成并执行 rebalance plan、collect fees、withdraw、revoke AI operator，并执行交易扫描和 LP 风控。适用于用户要求管理 RangePilot LP 头寸、调用 VaultFactory/UserLPVault/ManagedLPHook、编码 calldata、通过 onchainos wallet contract-call 发送交易、用 XLayer Explorer 查看已验证合约、或排查 RangePilot 合约交互失败的场景。
license: MIT
metadata:
  author: rangepilot
  version: "0.1.0"
---

# RangePilot LP Manager

本 skill 指导 agent 通过 OKX OnchainOS、cast 和 RangePilot 已部署合约地址与协议交互。RangePilot 是基于 Uniswap v4 Hook + 每用户独立 Vault 的 AI-managed LP 系统：每个用户一个 Vault，Vault 内部按 `poolId` 管理多个 pool 子账户。

## 核心规则

- 先判断当前任务需要哪些参考文件，只读取相关文件。
- 所有写交易优先使用 `onchainos wallet contract-call`，并且先做 `onchainos security tx-scan`。
- 不假设 agent 安装 skill 后拥有 RangePilot 源码。所有流程必须能仅凭合约地址、ABI 签名和区块浏览器完成。
- cast 默认只用于 calldata 编码、read-only 查询和模拟；不要绕过 OnchainOS 随意广播。
- AI operator 只能执行 `rebalance` 和 `collectFees`。提款、紧急退出、修改策略、修改 operator 必须由 owner 明确要求并由 owner 钱包执行。
- 不使用无限授权，不调用任意外部 calldata executor，不直接调用 `PoolManager.modifyLiquidity` 绕过 Vault。
- `rebalance` 的 `deadline` 应很短，推荐 5 分钟以内。
- 每个 pool 的资金、nonce、cooldown 独立。绝不能把 pool A 的 idle 余额用于 pool B。

## 参考文件索引

- 架构、角色、部署文件读取：`references/protocol-model.md`
- 部署地址占位和 XLayer Explorer 查看方式：`references/deployments-and-explorer.md`
- 合约接口、结构体、ABI/cast 编码：`references/contract-interfaces.md`
- OnchainOS 钱包、扫描、确认流：`references/onchainos-operations.md`
- 常见 LP 管理工作流：`references/lp-runbooks.md`
- rebalance 计划和风控规则：`references/risk-controls.md`
- cast 辅助工具：`references/foundry-tools.md`

## 任务到文件的路由

- 用户要创建 Vault、添加 pool、deposit、rebalance、collect、withdraw：先读 `protocol-model.md`、`deployments-and-explorer.md`、`lp-runbooks.md`、`onchainos-operations.md`、`contract-interfaces.md`。
- 用户要生成或审查 RebalancePlan：读 `risk-controls.md`、`contract-interfaces.md`、`foundry-tools.md`。
- 用户只要查状态、排查错误、解码 calldata 或 revert：读 `contract-interfaces.md`、`foundry-tools.md`。
- 用户问安全边界、AI operator 能不能做某件事：读 `risk-controls.md`。
- 用户问部署地址、合约验证、如何在浏览器看源码或 ABI：读 `deployments-and-explorer.md`。

## 默认链和目录

- Skill 目录：`packages/skills/rangepilot-lp-manager`
- 默认生产链：X Layer，OnchainOS chain 参数用 `xlayer`，chainId 为 `196`。
- 测试网如果 OnchainOS 不支持，不要猜 chain 参数；使用 cast read-only 查询，写交易前向用户确认执行路径。
