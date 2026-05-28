# RangePilot Contracts

Foundry package for the RangePilot protocol contracts. The root README covers the product overview, public deployments, and user-facing flow; this file only documents the contract workspace.

## Layout

```text
src/
  ManagedLPHook.sol
  UserLPVault.sol
  VaultFactory.sol
  RangePilotToken.sol
  deploy/
  interfaces/
  libraries/

script/
  xlayer/
  xlayer-testnet/

deployments/
  xlayer.json
  xlayer-testnet.json
```

## Contract Roles

- `ManagedLPHook`: shared Uniswap v4 hook that allows add/remove liquidity only from registered Vaults and records swap telemetry.
- `UserLPVault`: user-owned vault clone. It holds tokens, tracks per-pool idle balances and active positions, and executes `rebalance` through Uniswap v4 `PoolManager.unlock`.
- `VaultFactory`: creates one Vault per owner and binds PoolKeys to Vaults. Owner or the Vault's `aiOperator` can call `addPoolToVaultFor`.
- `RangePilotToken`: standard ERC20 token named `RangePilot` with symbol `RPT`.

Current MVP permissions:

- Owner only: `deposit`, `withdraw`, `emergencyExit`, `updateAIOperator`, `revokeAIOperator`.
- Owner or AI operator: `rebalance`, `collectFees`, `updateStrategyConfig`.
- Owner or AI operator through Factory: `addPoolToVaultFor`.

## Build And Test

Run from `packages/contracts`:

```bash
forge fmt
forge build
forge test
```

The package uses Solidity `0.8.26`, optimizer runs `200`, and `via_ir = true`.

## Deployment Records

Current deployment records live in:

```text
deployments/xlayer.json
deployments/xlayer-testnet.json
```

Use these JSON files as the local source of truth for scripts. The root README contains the public Explorer links.

## Mainnet Scripts

### Deploy Hook And Vault

Deploys:

- `HookCreate2Deployer`
- `ManagedLPHook`
- `UserLPVault` implementation
- `VaultFactory`

It writes the `rangePilot` section of `deployments/xlayer.json`.

```bash
export RANGEPILOT_OWNER=<owner>

forge script script/xlayer/DeployHookAndVault.s.sol:DeployXLayerHookAndVault \
  --rpc-url $XLAYER_RPC_URL \
  --account <account> \
  --broadcast
```

PoolManager is resolved in this order:

1. `POOL_MANAGER`
2. `XLAYER_POOL_MANAGER`
3. `deployments/xlayer.json -> uniswapV4.poolManager`

### Deploy RPT

Deploys `RangePilotToken` and writes `tokens.rangePilot` in `deployments/xlayer.json`.

```bash
forge script script/xlayer/DeployRangePilotToken.s.sol:DeployXLayerRangePilotToken \
  --rpc-url $XLAYER_RPC_URL \
  --account <account> \
  --broadcast
```

## Testnet Scripts

### Deploy Testnet Uniswap v4

Deploys the minimal testnet `PoolManager` and `StateView`, then writes `uniswapV4` in `deployments/xlayer-testnet.json`.

```bash
export V4_INITIAL_OWNER=<owner>

forge script script/xlayer-testnet/DeployUniSwap.s.sol:DeployXLayerTestnetUniswap \
  --rpc-url $XLAYER_TESTNET_RPC_URL \
  --account <account> \
  --broadcast
```

### Deploy Testnet Hook And Vault

Deploys RangePilot hook/vault/factory contracts and writes the `rangePilot` section of `deployments/xlayer-testnet.json`.

```bash
export RANGEPILOT_OWNER=<owner>

forge script script/xlayer-testnet/DeployHookAndVault.s.sol:DeployXLayerTestnetHookAndVault \
  --rpc-url $XLAYER_TESTNET_RPC_URL \
  --account <account> \
  --broadcast
```

PoolManager is resolved in this order:

1. `POOL_MANAGER`
2. `XLAYER_TESTNET_POOL_MANAGER`
3. `deployments/xlayer-testnet.json -> uniswapV4.poolManager`

### Create Testnet Vault

Creates a Vault for `VAULT_OWNER`. `AI_OPERATOR` is optional and defaults to `address(0)`.

```bash
export VAULT_OWNER=<owner>
export AI_OPERATOR=<operator>

forge script script/xlayer-testnet/CreateVault.s.sol:CreateXLayerTestnetVault \
  --rpc-url $XLAYER_TESTNET_RPC_URL \
  --account <vault-owner-account> \
  --broadcast
```

This script logs the created Vault but does not write a `latestVault` field.

### Create Testnet Pool, Bind Vault, Add Initial Liquidity If Needed

Uses `.env` defaults:

```text
TESTNET_TOKEN_A
TESTNET_TOKEN_B
TESTNET_VAULT_ADDRESS
```

The script uses fixed testnet pool parameters:

```text
fee:            100
tickSpacing:    1
sqrtPriceX96:   79228162514264337593543950336
initial range:  [-100, 100]
initial amount: 5_000_000 token0 + 5_000_000 token1
```

Behavior:

- If the PoolKey is not initialized, it initializes the pool.
- If the Vault is not bound, it calls `addPoolToVault`.
- If the pool and Vault position have no liquidity, it deposits the initial token amounts from the broadcaster and calls `rebalance`.
- The broadcaster must be the Vault owner.
- It does not write a `latestPool` field.

```bash
forge script script/xlayer-testnet/CreatePoolAndBindVault.s.sol:CreateXLayerTestnetPoolAndBindVault \
  --rpc-url $XLAYER_TESTNET_RPC_URL \
  --account <vault-owner-account> \
  --broadcast
```

Optional strategy env vars:

```text
MIN_WIDTH
MAX_WIDTH
MAX_TICK_MOVE_PER_REBALANCE
MAX_SLIPPAGE_BPS
ALLOW_OUT_OF_RANGE_POSITION
```

## Notes

- RangePilot supports ERC20/ERC20 pools only; native currency pools are not supported.
- PoolKey `hooks` must be the deployed `ManagedLPHook`.
- Vault balances are isolated by `poolId`, even when two pools use the same token pair.
- User-created Vaults are minimal clones; verify the implementation and use Factory/Vault read calls to validate each clone.
