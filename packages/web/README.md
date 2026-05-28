# RangePilot Web

React + Vite + wagmi frontend for inspecting RangePilot user Vaults on X Layer and X Layer testnet.

## Setup

```bash
npm install
cp .env.example .env
npm run dev
```

Wallet connection uses browser-injected wallets discovered through EIP-6963, such as OKX Wallet, MetaMask, Rabby, and other compatible wallets. No WalletConnect Project ID is required.

RangePilot contract addresses are intentionally environment-driven because the frontend subrepo should not assume local contract source or deployment state:

```bash
XLAYER_VAULT_FACTORY=
XLAYER_MANAGED_LP_HOOK=
XLAYER_TESTNET_VAULT_FACTORY=
XLAYER_TESTNET_MANAGED_LP_HOOK=
```

The app reads:

- `VaultFactory.userVaults(owner)`
- Vault owner/operator/pool metadata
- per-pool strategy config, active position, idle balances, last rebalance time
- hook registration state and swap telemetry when `ManagedLPHook` is configured
- current tick through `StateView` when available
