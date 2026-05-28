# Deployments And Explorer

## 目录

- 使用原则
- X Layer 主网地址
- X Layer 测试网地址
- 用户 Vault 地址
- XLayer Explorer 查看合约
- 合约未验证时怎么办

## 使用原则

此文件是 skill 内部维护的部署地址索引。Agent 安装 skill 后不一定拥有 RangePilot 源码或部署 JSON，因此不要要求读取源码目录。

规则：

- 地址为空或占位时，必须向用户索取或让用户提供 explorer 链接。
- 不要根据旧聊天、缓存、相似项目或合约名猜地址。
- 写交易前必须确认 chain 和地址属于同一网络。
- 如果合约已在 explorer 验证，优先用 explorer 的 Contract/Read/Write/ABI 页面核对接口。

## X Layer 主网地址

Chain：

- 名称：X Layer
- OnchainOS chain：`xlayer`
- chainId：`196`
- Explorer：`https://www.oklink.com/xlayer`

RangePilot：

```text
VaultFactory:                <待部署后填写>
ManagedLPHook:               <待部署后填写>
UserLPVault implementation:  <待部署后填写>
HookCreate2Deployer:         <待部署后填写>
```

Uniswap v4：

```text
PoolManager:      0x360e68faccca8ca495c1b759fd9eee466db9fb32
PositionManager:  0xcf1eafc6928dc385a342e7c6491d371d2871458b
StateView:        0x76fd297e2d437cd7f76d50f01afe6160f86e9990
```

## X Layer 测试网地址

OnchainOS 未必支持测试网 chain 参数。写交易前必须确认可用执行路径。

```text
VaultFactory:                <待部署后填写>
ManagedLPHook:               <待部署后填写>
UserLPVault implementation:  <待部署后填写>
PoolManager:                 <待部署后填写>
StateView:                   <待部署后填写>
Explorer:                    <待确认>
```

## 用户 Vault 地址

每个 owner 有自己的 Vault clone。获取方式：

- 用户直接提供 Vault 地址。
- 通过 Factory 查询：

```bash
cast call <vaultFactory> "userVaults(address)(address)" <owner> --rpc-url <rpc>
```

确认：

```bash
cast call <vaultFactory> "isVault(address)(bool)" <vault> --rpc-url <rpc>
cast call <vault> "owner()(address)" --rpc-url <rpc>
cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
```

## XLayer Explorer 查看合约

主网浏览器地址格式：

```text
https://www.oklink.com/xlayer/address/<contract-address>
```

使用方法：

1. 打开地址页面。
2. 查看 Contract/合约 标签是否已验证。
3. 如果已验证，检查：
   - Contract Name 是否是 `VaultFactory`、`ManagedLPHook` 或 `UserLPVault`
   - ABI 是否包含本 skill 的接口
   - Read Contract 中的 `owner`、`factory`、`poolManager` 等是否符合预期
   - Write Contract 函数是否与本 skill 的 calldata 签名一致
4. 对 Vault clone：
   - explorer 可能显示为 proxy/clone 或字节码很短
   - 需要结合 Factory 的 `isVault(vault)` 和 Vault 的 `owner()` 确认

如果用户提供 explorer 链接，先从链接中提取地址和 chain，再继续操作。

## 合约未验证时怎么办

如果 explorer 尚未验证合约：

- 仍可用本 skill 中的 ABI 签名和 `cast call` 读取状态。
- 不要声称已经核验源码。
- 写交易前必须更严格确认地址来源：部署交易、官方公告、用户提供的部署记录或 Factory 查询结果。
- 如果地址来源不可信，停止写交易。
