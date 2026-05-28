---
name: rangepilot-lp-manager
description: Manage RangePilot LP positions with OKX OnchainOS CLI, cast/Foundry, and deployed RangePilot contract addresses: guide users through RangePilot Web vault onboarding, AI Operator setup, Uniswap v4 pool creation with ManagedLPHook, pool-to-vault binding, approve/deposit, rebalance generation and execution, fee collection, withdraw/emergency exit, AI operator and strategy updates, state reads, security scanning, and troubleshooting. Use when a user wants to interact with RangePilot VaultFactory/UserLPVault/ManagedLPHook/Uniswap v4 PoolManager through OnchainOS, or needs X Layer mainnet/testnet addresses, calldata, risk controls, or Explorer verification guidance.
license: MIT
metadata:
  author: rangepilot
  version: "0.2.0"
---

# RangePilot LP Manager

This skill guides agents to interact with RangePilot using only deployed contract addresses, ABI signatures, OnchainOS CLI, and cast/Foundry.

## Core Principles

- For any non-trivial RangePilot task, first read `references/overview.md`, then `references/requirements.md`.
- If the user is onboarding for the first time, needs to create a Vault, set an AI Operator, or does not know how to start, read `references/vault-onboarding.md` first.
- Prefer `onchainos wallet contract-call` for write transactions, and run `onchainos security tx-scan` before sending.
- Use `cast` mainly for calldata encoding, read-only queries, `eth_call` simulation, revert decoding, and log troubleshooting. Do not default to broadcasting with `cast send`.
- `SKILL.md` is only an entrypoint and index. Load reference files as needed; do not load every reference at once.
- For every pool operation, confirm that chain, PoolKey, poolId, Vault, Hook, Factory, and sender permissions are consistent.
- RangePilot is one Vault per owner, with multiple per-pool subaccounts. Each pool has independent idle balance, active position, nonce, and strategy config.
- Custom Uniswap v4 hook pools may not be indexed by the OKX DEX aggregator yet. Aggregator quote failure does not prove the on-chain pool is unusable.

## Document Index

- `references/overview.md`: Project overview, goals, contract roles, and full lifecycle. Read first.
- `references/requirements.md`: OKX OnchainOS skills, OnchainOS CLI, Foundry/cast, RPC, and wallet checks.
- `references/vault-onboarding.md`: First-time user onboarding flow. Guide users to the Web app, set AI Operator, create a Vault, choose a hook pool, deposit, then rebalance.
- `references/protocol-model.md`: Protocol model, roles, permissions, and state objects.
- `references/deployments-and-explorer.md`: Current deployment addresses, Explorer URLs, and address verification rules.
- `references/contract-interfaces.md`: ABI signatures, struct encoding, PoolManager initialize, and Factory/Vault/Hook interfaces.
- `references/onchainos-operations.md`: OnchainOS prechecks, security scan, contract-call, confirming responses, and swap quote limitations.
- `references/lp-runbooks.md`: End-to-end workflows for pool creation, Vault creation/querying, pool binding, deposit, rebalance, collect, and withdraw.
- `references/risk-controls.md`: Permission boundaries, approval rules, RebalancePlan checks, and failure handling.
- `references/foundry-tools.md`: cast command templates, poolId calculation, StateView queries, simulation, and log troubleshooting.

## Task Routing

- **Before any on-chain operation**: read `overview.md` and `requirements.md`.
- **First-time user onboarding / Vault initialization / AI operator setup**: read `vault-onboarding.md`, `protocol-model.md`, `deployments-and-explorer.md`, `contract-interfaces.md`, and `onchainos-operations.md`.
- **Direct contract-level Vault creation**: read `protocol-model.md`, `deployments-and-explorer.md`, `contract-interfaces.md`, `onchainos-operations.md`, and `lp-runbooks.md`.
- **Uniswap v4 pool creation / initial price calculation / Hook binding**: read `contract-interfaces.md`, `foundry-tools.md`, `lp-runbooks.md`, and `risk-controls.md`.
- **Bind a pool to a Vault**: read `protocol-model.md`, `contract-interfaces.md`, and `lp-runbooks.md`.
- **deposit / rebalance / collect / withdraw**: read `lp-runbooks.md`, `risk-controls.md`, and `onchainos-operations.md`.
- **State queries / troubleshooting / calldata or revert decoding**: read `foundry-tools.md` and `contract-interfaces.md`.
- **Deployment addresses or Explorer verification**: read `deployments-and-explorer.md`.
