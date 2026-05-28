# OnchainOS Operations

## Contents

- Prechecks
- Chain parameters
- Read-only wallet information
- Security scan
- contract-call write transactions
- Confirming responses
- DEX swap quote limitations
- Testnet
- Common templates

## Prechecks

Before using OnchainOS for the first time:

```bash
onchainos --version
onchainos wallet status
onchainos wallet addresses --chain xlayer
```

If the user is not logged in, guide them through the OnchainOS login flow. Never ask the user to paste private keys, seed phrases, or keystore passwords into chat.

If official OKX skills are installed locally, follow the stricter rules from the relevant OKX skill for wallet, swap, security scan, and gateway tasks. This file documents only the minimal RangePilot-specific interaction flow.

## Chain Parameters

X Layer mainnet:

```bash
--chain xlayer
```

Chain ID can also be used:

```bash
--chain 196
```

## Read-Only Wallet Information

View the current OnchainOS account:

```bash
onchainos wallet status
onchainos wallet addresses --chain xlayer
```

View balances:

```bash
onchainos wallet balance --chain xlayer
onchainos wallet balance --chain xlayer --token-address <token>
```

Note: OnchainOS may use AA or delegated execution paths. Contract permissions are based on `msg.sender`; do not assume `tx.origin` works. When setting a Vault `aiOperator`, use the EVM/X Layer address returned by `onchainos wallet addresses --chain xlayer`, and confirm permissions with a small or read-only check when possible.

## Security Scan

Every EVM write transaction must be scanned before sending:

```bash
onchainos security tx-scan \
  --chain xlayer \
  --from <sender> \
  --to <targetContract> \
  --data <calldata> \
  --value 0x0
```

Handling rules:

- `action == ""` or empty: continue.
- `action == "warn"`: show the risk and wait for explicit user confirmation.
- `action == "block"`: stop and do not send.
- Scan failure is not a safety pass. Explain the failure and ask whether to retry or continue without a scan result.

## contract-call Write Transactions

Use this for RangePilot contract writes:

```bash
onchainos wallet contract-call \
  --to <targetContract> \
  --chain xlayer \
  --from <sender> \
  --input-data <calldata> \
  --amt 0 \
  --biz-type defi \
  --strategy rangepilot
```

Rules:

- Do not include `--force` on the first attempt.
- Non-payable functions use `--amt 0`.
- `--to` is the actual called contract:
  - `PoolManager.initialize` -> PoolManager
  - `createVault` / `addPoolToVaultFor` -> VaultFactory
  - `approve` -> ERC20 token
  - `deposit` / `rebalance` / `collectFees` / `withdraw` -> UserLPVault
- Explicitly specify `--from` as owner or aiOperator to avoid using the wrong account.

## Confirming Responses

`onchainos wallet contract-call` may return a confirming response and exit with code 2.

Flow:

1. Show the returned message and confirmation requirement.
2. Ask the user explicitly whether to continue.
3. Only after the user confirms, rerun according to the CLI's next instruction, usually adding `--force`.
4. Stop if the user does not confirm.

Never add `--force` on the first call.

## DEX Swap Quote Limitations

Use the OnchainOS DEX aggregator to check whether a pool or token route may be indexed:

```bash
onchainos swap quote \
  --from <fromToken> \
  --to <toToken> \
  --readable-amount <amount> \
  --chain xlayer
```

Or execute:

```bash
onchainos swap execute \
  --from <fromToken> \
  --to <toToken> \
  --readable-amount <amount> \
  --chain xlayer \
  --wallet <onchainosWallet>
```

For RangePilot custom Uniswap v4 Hook pools:

- The OKX DEX aggregator may not immediately index new tokens or custom hook pools.
- `51006 Input value is too low` may mean the quote layer sees too little value or no valid token price.
- `82000 Insufficient liquidity` may mean the aggregator found no route; it does not necessarily mean StateView liquidity is 0.
- If aggregator quote fails, do not conclude the PoolManager pool is unusable. Read StateView `getLiquidity`, tick liquidity, Hook `swapCount`, and PoolManager events.
- Direct v4 swap testing usually requires a swap helper contract that implements `PoolManager.unlock` callback and settlement logic. Do not ask normal wallets to call `PoolManager.swap` directly.

## Testnet

For testnets:

- First check whether OnchainOS supports the target testnet.
  ```bash
  onchainos wallet chains
  ```
- If OnchainOS does not support testnet writes, do not switch to mainnet or use `cast send` without explicit user approval.
- Read-only checks can use `cast call` plus the testnet RPC.
- The write path must be confirmed by the user.

## Common Templates

### Scan And Call

```bash
onchainos security tx-scan \
  --chain xlayer \
  --from <sender> \
  --to <target> \
  --data <calldata> \
  --value 0x0

onchainos wallet contract-call \
  --to <target> \
  --chain xlayer \
  --from <sender> \
  --input-data <calldata> \
  --amt 0 \
  --biz-type defi \
  --strategy rangepilot
```

### View Transaction History

```bash
onchainos wallet history --chain xlayer --address <onchainosWallet>
onchainos wallet history --chain xlayer --address <onchainosWallet> --tx-hash <txHash>
```

### Check Transaction Status, Then Read On-Chain State

After broadcast, do not rely only on txHash. Run:

1. `onchainos wallet history` or Explorer to confirm `SUCCESS`.
2. `cast call` reads against Vault / Hook / StateView.
3. Summarize the state changes for the user.
