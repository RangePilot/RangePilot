# OnchainOS Operations

## 目录

- 先决检查
- chain 参数
- 安全扫描
- 合约调用
- confirming 响应
- 常用命令模板
- 测试网处理

## 先决检查

首次运行 `onchainos` 命令前：

1. 如果仓库存在 `.agents/skills/okx-agentic-wallet/_shared/preflight.md`，先读取并遵循其中的 preflight。
2. 确认 CLI 可用：
   ```bash
   onchainos --version
   ```
3. 查看钱包登录状态：
   ```bash
   onchainos wallet status
   ```
4. 查看当前链地址：
   ```bash
   onchainos wallet addresses --chain xlayer
   ```

如果用户尚未登录，让用户完成 OnchainOS 登录流程；不要让用户在聊天中粘贴私钥或助记词。

## chain 参数

X Layer 主网：

```bash
--chain xlayer
```

也可以使用 chainId：

```bash
--chain 196
```

如果用户要求测试网，而 OnchainOS 不识别该 chain，不要猜。先说明 OnchainOS 可能只支持主网或有限测试网，然后改用 cast read-only 查询；写交易路径必须让用户确认。

## 安全扫描

每笔 EVM 写交易在发送前都要执行：

```bash
onchainos security tx-scan \
  --chain <chain> \
  --from <sender> \
  --to <contract> \
  --data <calldata> \
  --value 0x0
```

处理规则：

- `action` 为空：可以继续。
- `action` 为 `warn`：展示风险点，必须得到用户明确确认后才继续。
- `action` 为 `block`：停止，不发送交易。
- 扫描命令失败：说明扫描未完成，询问用户是重试还是在无扫描结果下继续；用户不明确确认时停止。

## 合约调用

RangePilot 合约写操作使用：

```bash
onchainos wallet contract-call \
  --to <contract> \
  --chain <chain> \
  --input-data <calldata> \
  --amt 0 \
  --biz-type defi \
  --strategy rangepilot
```

规则：

- 首次调用不要带 `--force`。
- 非 payable 合约函数必须使用 `--amt 0` 或省略；不要附带 native token。
- `--to` 必须是本次要调用的合约：ERC20 approve 用 token 地址，Vault 操作用 Vault 地址，Factory 操作用 Factory 地址。
- 如果要指定 sender，使用 `--from <address>`，并确保该地址是 owner 或 aiOperator。

## confirming 响应

`wallet contract-call` 可能返回 confirming 响应并以 exit code 2 退出。处理流程：

1. 展示响应中的 `message`。
2. 明确问用户是否继续。
3. 用户确认后，按响应里的 `next` 指令重跑，一般是添加 `--force`。
4. 用户未确认或拒绝时停止。

永远不要在第一次 `wallet contract-call` 时主动加 `--force`。

## 常用命令模板

### 查询钱包状态

```bash
onchainos wallet status
onchainos wallet balance --chain xlayer
onchainos wallet addresses --chain xlayer
```

### 扫描并调用

```bash
onchainos security tx-scan \
  --chain xlayer \
  --from <sender> \
  --to <contract> \
  --data <calldata> \
  --value 0x0

onchainos wallet contract-call \
  --to <contract> \
  --chain xlayer \
  --input-data <calldata> \
  --amt 0 \
  --biz-type defi \
  --strategy rangepilot
```

### 查看交易历史

```bash
onchainos wallet history --chain xlayer
onchainos wallet history --chain xlayer --tx-hash <txHash> --address <address>
```

## 测试网处理

RangePilot 文档中可能存在 `xlayer-testnet` 部署或脚本，但 OnchainOS CLI 未必支持该 chain 名称。遇到测试网：

- 先尝试 `onchainos wallet chains` 查看支持列表。
- 如果不支持，用 `cast call` 读取链上状态。
- 写交易不要擅自切换到 `cast send`；只有用户明确要求并提供安全签名方式时才可考虑。
- 如果必须用 `cast send` 或其他方式广播，仍要先用 `cast call`/`eth_call` 模拟，并清楚说明这不是 OnchainOS 路径。
