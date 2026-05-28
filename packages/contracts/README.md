# RangePilot Contracts

RangePilot 是基于 Uniswap v4 Hook + 每用户独立 Vault 的 AI-managed LP 管理系统。AI operator 只能通过用户 Vault 执行受限 rebalance，不能提款、不能修改风险参数、不能绕过 Vault 直接管理用户资金。

## 架构

- `ManagedLPHook`: 唯一共享 Hook，可管理多个使用该 Hook 初始化的 v4 pool。Hook 按 `poolId => vault` 注册表限制 add/remove liquidity，只接受已注册 Vault。
- `VaultFactory`: 使用 OpenZeppelin `Clones` 创建每用户唯一 Vault，并在 Hook 中按 pool 注册该 Vault。
- `UserLPVault`: 持有用户 token，直接作为 v4 periphery 调用 `PoolManager.unlock -> modifyLiquidity`。每个 Vault 可管理多个 pool；每个 pool 拥有独立策略、active range、nonce、cooldown 和 idle 资金子账户。

## 当前 MVP 限制

- 只支持 ERC20/ERC20 pool，暂不支持 native currency pool。
- 每个 owner 暂时只能创建一个 Vault。
- 每个 pool 仍只管理一个 active range；一个 Vault 可以添加多个 pool。
- `emergencyExit` 会跳过 slippage 检查，但仍只能由 owner 调用。
- v4 Hook pool 必须用 `ManagedLPHook` 初始化，RangePilot 不能接管已经用其他 Hook 或无 Hook 初始化的 pool。
- Vault 内部按 poolId 记账；同一组 token 的不同 pool 也不能互相挪用 idle 余额。

## 测试

```bash
forge fmt
forge build
forge test
```

## X Layer 主网 v4 地址

X Layer 主网已有 Uniswap v4 部署，可直接把 `POOL_MANAGER` 设置为：

```text
PoolManager:     0x360e68faccca8ca495c1b759fd9eee466db9fb32
PositionManager: 0xcf1eafc6928dc385a342e7c6491d371d2871458b
StateView:       0x76fd297e2d437cd7f76d50f01afe6160f86e9990
```

RangePilot 当前直接使用 `PoolManager`，不依赖 `PositionManager` 管理 LP。

## X Layer Testnet 专用部署脚本

测试网脚本统一放在 `script/xlayer-testnet/` 下：

- `DeployUniSwap.s.sol`: 部署最小可用 Uniswap v4 `PoolManager` + `StateView`，写入 `deployments/xlayer-testnet.json`
- `DeployHookAndVault.s.sol`: 部署 RangePilot `ManagedLPHook`、`UserLPVault` implementation 和 `VaultFactory`，写入同一个 `deployments/xlayer-testnet.json`
- `CreateVault.s.sol`: 通过测试网 `VaultFactory` 创建用户 Vault clone，并写入同一个 `deployments/xlayer-testnet.json`
- `CreatePoolAndBindVault.s.sol`: 初始化新的 Hook pool，并把该 pool 注册到 `TESTNET_VAULT_ADDRESS` 指向的 Vault，写入同一个 `deployments/xlayer-testnet.json`

### 部署 X Layer Testnet v4

如果测试网没有 v4，先部署最小可用 v4 core + StateView：

```bash
export V4_INITIAL_OWNER=<owner>

forge script script/xlayer-testnet/DeployUniSwap.s.sol:DeployXLayerTestnetUniswap \
  --rpc-url <xlayer-testnet-rpc> \
  --broadcast
```

如果使用 fish shell，需要导出变量：

```fish
set -gx V4_INITIAL_OWNER <owner>
```

脚本也支持在未设置 `V4_INITIAL_OWNER` 时回退读取 `RANGEPILOT_OWNER`。

脚本会写入 `deployments/xlayer-testnet.json` 的 `uniswapV4` 分组。

### 部署 X Layer Testnet RangePilot Hook + Vault

`RANGEPILOT_OWNER` 必须是广播交易的签名者，因为脚本会在部署后调用 `hook.setFactory(...)`。

脚本会按优先级读取 `PoolManager`：

1. `POOL_MANAGER`
2. `XLAYER_TESTNET_POOL_MANAGER`
3. `deployments/xlayer-testnet.json` 中的 `uniswapV4.poolManager`

```bash
export RANGEPILOT_OWNER=<owner>

forge script script/xlayer-testnet/DeployHookAndVault.s.sol:DeployXLayerTestnetHookAndVault \
  --rpc-url <xlayer-testnet-rpc> \
  --broadcast
```

脚本会通过 CREATE2 helper 挖出带 v4 Hook flags 的 `ManagedLPHook` 地址，并写入 `deployments/xlayer-testnet.json` 的 `rangePilot` 分组。

### 创建 X Layer Testnet 用户 Vault

脚本会按优先级读取 `VaultFactory`：

1. `VAULT_FACTORY`
2. `XLAYER_TESTNET_VAULT_FACTORY`
3. `deployments/xlayer-testnet.json` 中的 `rangePilot.vaultFactory`

```bash
export VAULT_OWNER=<owner>
export AI_OPERATOR=<operator> # 可选，默认 address(0)

forge script script/xlayer-testnet/CreateVault.s.sol:CreateXLayerTestnetVault \
  --rpc-url <xlayer-testnet-rpc> \
  --broadcast
```

脚本会写入 `deployments/xlayer-testnet.json` 的 `latestVault` 分组。

### 创建 X Layer Testnet Pool 并绑定到已有 Vault

`TESTNET_VAULT_ADDRESS` 必须是已经由当前 `VaultFactory` 创建的 Vault。由于 `VaultFactory.addPoolToVault` 按 `msg.sender` 查找 Vault，广播交易的签名账户必须是该 Vault 的 owner；脚本会用 `TESTNET_VAULT_ADDRESS` 校验目标 Vault，防止把 pool 绑定到错误账户。

脚本会按优先级读取 `PoolManager`、`ManagedLPHook` 和 `VaultFactory`：

1. 显式 env：`POOL_MANAGER`、`MANAGED_LP_HOOK`、`VAULT_FACTORY`
2. 测试网 env：`XLAYER_TESTNET_POOL_MANAGER`、`XLAYER_TESTNET_MANAGED_LP_HOOK`、`XLAYER_TESTNET_VAULT_FACTORY`
3. `deployments/xlayer-testnet.json` 中的 `uniswapV4` / `rangePilot` 分组

```bash
# packages/contracts/.env 已经写入 TESTNET_TOKEN_A=USDT0、TESTNET_TOKEN_B=USDC_TEST。
# 如果要绑定到不同 Vault，只需要更新 .env 里的 TESTNET_VAULT_ADDRESS。

forge script script/xlayer-testnet/CreatePoolAndBindVault.s.sol:CreateXLayerTestnetPoolAndBindVault \
  --rpc-url <xlayer-testnet-rpc> \
  --account <vault-owner-account> \
  --broadcast
```

该测试网脚本固定使用 `POOL_FEE=100`、`TICK_SPACING=1`、`SQRT_PRICE_X96=79228162514264337593543950336`。如果同一个 PoolKey 已经初始化，脚本会跳过 `PoolManager.initialize` 并继续绑定 Vault；如果 Vault 已经绑定该 pool，则跳过重复添加。策略参数可选，默认值为 `MIN_WIDTH=60`、`MAX_WIDTH=600`、`MAX_TICK_MOVE_PER_REBALANCE=120`、`MAX_SLIPPAGE_BPS=500`、`MIN_REBALANCE_INTERVAL=3600`、`ALLOW_OUT_OF_RANGE_POSITION=false`。执行成功后，脚本会写入 `deployments/xlayer-testnet.json` 的 `latestPool` 分组。

## 部署 RangePilot

`RANGEPILOT_OWNER` 必须是广播交易的签名者，因为脚本会在部署后调用 `hook.setFactory(...)`。

```bash
export POOL_MANAGER=<pool-manager>
export RANGEPILOT_OWNER=<owner>

forge script script/DeployRangePilot.s.sol:DeployRangePilot \
  --rpc-url <rpc-url> \
  --broadcast
```

脚本会通过 CREATE2 helper 挖出带 v4 Hook flags 的 `ManagedLPHook` 地址，并写入 `deployments/rangepilot-latest.json`。

## 初始化 RangePilot Pool

```bash
export POOL_MANAGER=<pool-manager>
export MANAGED_LP_HOOK=<hook>
export TOKEN_A=<token-a>
export TOKEN_B=<token-b>
export POOL_FEE=3000
export TICK_SPACING=60
export SQRT_PRICE_X96=79228162514264337593543950336

forge script script/InitializeRangePilotPool.s.sol:InitializeRangePilotPool \
  --rpc-url <rpc-url> \
  --broadcast
```

## 创建 Vault 并添加第一个 Pool

`VAULT_OWNER` 必须是广播交易的签名者。脚本会调用 `createVaultAndAddPool`，创建用户 Vault 并把第一个 pool 注册到 Hook。脚本内默认策略为：`minWidth=60`、`maxWidth=600`、`maxTickMovePerRebalance=120`、`maxSlippageBps=500`、`minRebalanceInterval=1 hours`、不允许 out-of-range position。

```bash
export VAULT_FACTORY=<factory>
export VAULT_OWNER=<owner>
export AI_OPERATOR=<operator>
export MANAGED_LP_HOOK=<hook>
export TOKEN_A=<token-a>
export TOKEN_B=<token-b>
export POOL_FEE=3000
export TICK_SPACING=60

forge script script/CreateVault.s.sol:CreateVault \
  --rpc-url <rpc-url> \
  --broadcast
```

之后 owner approve Vault 并调用 `deposit(poolId, amount0, amount1)`；AI operator 或 owner 可以调用 `rebalance(RebalancePlan{poolId: ...})`，费用通过 `collectFees(poolId)` 留在该 pool 子账户，提款只能由 owner 调用 `withdraw(WithdrawPlan{poolId: ...})` 或 `emergencyExit(poolId)`。

## 为已有 Vault 添加 Pool

同一个 owner 已经有 Vault 后，可以继续通过 Factory 添加 pool：

```bash
export VAULT_FACTORY=<factory>
export MANAGED_LP_HOOK=<hook>
export TOKEN_A=<token-a>
export TOKEN_B=<token-b>
export POOL_FEE=500
export TICK_SPACING=10

forge script script/AddPoolToVault.s.sol:AddPoolToVault \
  --rpc-url <rpc-url> \
  --broadcast
```

添加成功后，Factory 会调用 Vault 写入该 pool 的配置，再调用 Hook 注册 `registeredVaultForPool[poolId][vault]`。后续 deposit、rebalance、collectFees、withdraw 都必须显式传入 poolId。
