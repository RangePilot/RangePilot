# Cast Tools

## 目录

- 使用边界
- selector
- calldata 编码
- read-only 查询
- StateView 查询
- 模拟和排错

## 使用边界

本文件只使用 Foundry 的 `cast` 命令，不要求存在 RangePilot 源码目录。

cast 在本 skill 中主要用于：

- selector 查询
- calldata 编码
- read-only 链上查询
- eth_call 模拟
- 解码 revert 或日志

写交易优先通过 OnchainOS。不要在没有用户明确授权的情况下使用 `cast send` 广播交易。

## selector

查询 selector：

```bash
cast sig "rebalance((bytes32,int24,int24,uint128,uint128,uint256,uint256,uint256,uint256,uint256,uint256,bytes32))"
cast sig "deposit(bytes32,uint256,uint256)"
cast sig "withdraw((bytes32,uint256,uint256,uint256))"
cast sig "collectFees(bytes32)"
cast sig "addPoolToVault((address,address,uint24,int24,address),(int24,int24,int24,uint16,uint32,bool))"
```

已知 selector：

```text
deposit(bytes32,uint256,uint256): 0x278f2ab8
rebalance((bytes32,int24,int24,uint128,uint128,uint256,uint256,uint256,uint256,uint256,uint256,bytes32)): 0xe9735495
collectFees(bytes32): 0x817db73b
withdraw((bytes32,uint256,uint256,uint256)): 0x07e0839f
addPoolToVault((address,address,uint24,int24,address),(int24,int24,int24,uint16,uint32,bool)): 0xaebbd90a
```

## calldata 编码

用 `cast calldata` 编码，然后交给 OnchainOS：

```bash
CALLDATA=$(cast calldata "deposit(bytes32,uint256,uint256)" <poolId> <amount0> <amount1>)
```

如果 shell 不适合保存变量，直接复制输出到：

```bash
onchainos security tx-scan --chain xlayer --from <sender> --to <vault> --data <calldata> --value 0x0
onchainos wallet contract-call --to <vault> --chain xlayer --input-data <calldata> --amt 0 --biz-type defi --strategy rangepilot
```

## read-only 查询

常用：

```bash
cast call <factory> "userVaults(address)(address)" <owner> --rpc-url <rpc>
cast call <factory> "isVault(address)(bool)" <vault> --rpc-url <rpc>

cast call <vault> "owner()(address)" --rpc-url <rpc>
cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
cast call <vault> "poolCount()(uint256)" --rpc-url <rpc>
cast call <vault> "poolIdAt(uint256)(bytes32)" <index> --rpc-url <rpc>
cast call <vault> "getPoolKey(bytes32)((address,address,uint24,int24,address))" <poolId> --rpc-url <rpc>
cast call <vault> "getStrategyConfig(bytes32)((int24,int24,int24,uint16,uint32,bool))" <poolId> --rpc-url <rpc>
cast call <vault> "getActivePosition(bytes32)((int24,int24,uint128,bytes32))" <poolId> --rpc-url <rpc>
cast call <vault> "getPoolBalance(bytes32)((uint256,uint256))" <poolId> --rpc-url <rpc>
cast call <vault> "usedNonces(bytes32,uint256)(bool)" <poolId> <nonce> --rpc-url <rpc>

cast call <hook> "registeredVaultForPool(bytes32,address)(bool)" <poolId> <vault> --rpc-url <rpc>
```

ERC20：

```bash
cast call <token> "decimals()(uint8)" --rpc-url <rpc>
cast call <token> "balanceOf(address)(uint256)" <owner> --rpc-url <rpc>
cast call <token> "allowance(address,address)(uint256)" <owner> <vault> --rpc-url <rpc>
```

## StateView 查询

如果部署地址文件或用户提供 StateView：

```bash
cast call <stateView> "getSlot0(bytes32)(uint160,int24,uint24,uint24)" <poolId> --rpc-url <rpc>
cast call <stateView> "getLiquidity(bytes32)(uint128)" <poolId> --rpc-url <rpc>
cast call <stateView> "getPositionInfo(bytes32,address,int24,int24,bytes32)(uint128,uint256,uint256)" \
  <poolId> <vault> <tickLower> <tickUpper> <salt> --rpc-url <rpc>
```

`getSlot0` 返回：

- `sqrtPriceX96`
- `tick`
- `protocolFee`
- `lpFee`

## 模拟和排错

可以用 `cast call` 对非 view 函数做 eth_call 模拟，不会改链上状态。例如：

```bash
cast call <vault> \
  "rebalance((bytes32,int24,int24,uint128,uint128,uint256,uint256,uint256,uint256,uint256,uint256,bytes32))(int256,int256)" \
  "(<poolId>,<lower>,<upper>,<removeLiq>,<addLiq>,<amount0Min>,<amount1Min>,<amount0Max>,<amount1Max>,<deadline>,<nonce>,<reasonHash>)" \
  --from <aiOperator> \
  --rpc-url <rpc>
```

如果 revert：

```bash
cast 4byte-decode <selector-or-revert-data>
```

常见做法：

- 先查询 `owner()` / `aiOperator()` 判断权限。
- 查询 `isPoolEnabled(poolId)` 与 Hook 注册状态。
- 查询 `usedNonces(poolId, nonce)` 和 `lastRebalanceTimestamp(poolId)`。
- 查询 `getStrategyConfig(poolId)` 验证 tick width、tick move 和 cooldown。
