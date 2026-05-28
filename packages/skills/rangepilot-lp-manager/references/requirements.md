# Requirements

## Contents

- When to read this file
- Required tools
- OnchainOS skills check
- OnchainOS CLI check
- Foundry check
- Network and wallet checks
- Missing tool handling

## When To Read This File

Before any RangePilot on-chain operation, the agent must read this file and complete the checks. Purely explanatory questions can skip actual commands, but calldata generation, on-chain state queries, transaction sending, pool creation, Vault binding, or rebalance require tool availability.

## Required Tools

RangePilot agent operations require:

- OKX OnchainOS skills: wallet, contract-call, security scan, DEX quote, transaction history workflows.
- OnchainOS CLI: `wallet contract-call`, `security tx-scan`, `wallet balance`, and related commands.
- Foundry: `cast` is required; `forge` is recommended.
- A working X Layer RPC.
- A logged-in OnchainOS wallet, or another user-confirmed execution path.

## OnchainOS Skills Check

First confirm that OKX OnchainOS skills are installed. Recommended checks in the current project:

```bash
test -f .agents/skills/okx-agentic-wallet/SKILL.md
test -f .agents/skills/okx-onchain-gateway/SKILL.md
test -f .agents/skills/okx-security/SKILL.md
test -f .agents/skills/okx-dex-swap/SKILL.md
```

If these files are missing, also check whether OKX skills are installed in the agent's global skill root. Do not assume a fixed directory across environments.

If not installed, run from the project root:

```bash
npx skills add okx/onchainos-skills
```

GitHub source is also acceptable:

```bash
npx skills add https://github.com/okx/onchainos-skills
```

After installation, re-check `.agents/skills/okx-*`, and load the relevant OKX skill when needed:

- Wallet, contract-call, history: `okx-agentic-wallet`
- Security scan: `okx-security`
- Transaction simulation/broadcast: `okx-onchain-gateway`
- swap quote / execute: `okx-dex-swap`

If `npx skills add` fails due to network or permissions, explain the failure and stop write transactions. Do not bypass the safety workflow.

## OnchainOS CLI Check

Confirm the CLI works:

```bash
onchainos --version
onchainos wallet status
onchainos wallet addresses --chain xlayer
```

Requirements:

- `onchainos --version` prints a version.
- `wallet status` shows a logged-in wallet, or prompts the user to log in.
- `wallet addresses --chain xlayer` returns the address used for `aiOperator` or transaction sending.

If not logged in:

- Guide the user through OnchainOS login.
- Do not ask the user to paste private keys, seed phrases, OTPs, or keystore passwords into chat.

## Foundry Check

Confirm Foundry works:

```bash
cast --version
forge --version
```

Minimum requirements:

- `cast` is required for calldata encoding, selectors, keccak, read-only calls, and `eth_call` simulation.
- `forge` is recommended for local scripts or tests.

These common commands should work:

```bash
cast sig "deposit(bytes32,uint256,uint256)"
cast calldata "revokeAIOperator()"
cast keccak "rangepilot:check"
```

If Foundry is unavailable, ask the user to install Foundry. Common installation:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

After installation, reopen the shell or reload PATH, then rerun `cast --version` and `forge --version`.

## Network And Wallet Checks

Mainnet defaults:

```text
OnchainOS chain: xlayer
RPC: https://rpc.xlayer.tech
Chain ID: 196
```

Read-chain check:

```bash
cast block latest --rpc-url https://rpc.xlayer.tech
```

Wallet check:

```bash
onchainos wallet balance --chain xlayer
```

If the task involves mainnet write transactions, confirm:

- The user explicitly wants to execute on X Layer mainnet.
- The OnchainOS wallet is owner or aiOperator.
- The wallet has enough native gas, or OnchainOS supports the relevant gas flow.

## Missing Tool Handling

Order of handling:

1. Missing OKX OnchainOS skills: run `npx skills add okx/onchainos-skills`.
2. Missing OnchainOS CLI: ask the user to install or fix OnchainOS CLI.
3. Missing Foundry/cast: ask the user to install Foundry.
4. Missing RPC/network: do not send write transactions; wait for a working RPC or network recovery.
5. Wallet not logged in or wrong address: wait for the user to log in, switch wallet, or update the Vault `aiOperator`.

Do not skip security scans, calldata simulation, or switch to an unconfirmed broadcast path just to continue.
