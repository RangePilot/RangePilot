# Deployments And Explorer

## Contents

- Usage rules
- X Layer mainnet
- X Layer testnet
- User Vault addresses
- Explorer verification
- Unverified contracts

## Usage Rules

This file maintains current RangePilot deployment addresses. A user installing the skill may not have the source tree or deployment JSON files, so workflows must be able to rely only on this file, user-provided addresses, Explorer pages, and ABI signatures.

Rules:

- Do not guess contracts from old chat history or similar-looking addresses.
- Before write transactions, confirm that chain, Factory, Hook, PoolManager, and StateView are on the same network.
- If the user provides a new deployment address in the current task, use the user's explicitly provided address and repeat it back before operating.
- If an address cannot be verified, stop write transactions.

## X Layer Mainnet

Chain:

```text
Name:       X Layer
OnchainOS: xlayer
Chain ID:  196
RPC:       https://rpc.xlayer.tech
Explorer:  https://www.okx.com/web3/explorer/xlayer
OKLink:    https://www.oklink.com/xlayer
```

Uniswap v4:

```text
PoolManager:      0x360e68faccca8ca495c1b759fd9eee466db9fb32
PositionManager:  0xcf1eafc6928dc385a342e7c6491d371d2871458b
StateView:        0x76fd297e2d437cd7f76d50f01afe6160f86e9990
```

RangePilot:

```text
VaultFactory:                0xE8c006b5d4A8a2b0CC886c947a8Fd5F1E0eB921A
ManagedLPHook:               0x29779a886523edEE78187f051635F7A969DC8a40
UserLPVault implementation:  0x8Aa7b9869Bf6E3566070395bFaE367Ad914BA9e4
HookCreate2Deployer:         0xF3d973b076B169E65202A0a0c5376A309f8A9B69
Owner:                       0x2eaE1C6Ff3e9e484eC31F24D0B9E1AAeC7ff0a32
```

Tokens:

```text
RPT / RangePilot: 0x799C5d3B2725FE35Ba19b3dbA90777DC2B7d43C4
```

Common USDt0:

```text
USDt0: 0x779ded0c9e1022225f8e0630b35a9b54be713736
```

## X Layer Testnet

OnchainOS testnet support may differ from mainnet support. Before write transactions, run `onchainos wallet chains` or ask the user to confirm the execution path.

```text
Name:      X Layer Testnet
Chain ID: 1952
RPC:      https://testrpc.xlayer.tech/terigon
```

Uniswap v4:

```text
PoolManager: 0x6df5DAE1e6216578e9eC63b239BFa6990AE6ed50
StateView:   0x1cf2f6b229E313bAC1174F9e6c6a5Cd567F07F3E
```

RangePilot:

```text
VaultFactory:                0x9f05221D3E653EC21911F4d91b3054A0E54027C6
ManagedLPHook:               0x483744FA9563EFaC32a3C7c73AfeBEFA55418a40
UserLPVault implementation:  0x2Bbc43C6409C7b203670630283139C25cB89358e
HookCreate2Deployer:         0x175DE2B40dCDe9020C48Ae5AcAbf849E84933C35
Owner:                       0x2eaE1C6Ff3e9e484eC31F24D0B9E1AAeC7ff0a32
```

## User Vault Addresses

Each owner has one Vault clone. Retrieve it with:

```bash
cast call <vaultFactory> "userVaults(address)(address)" <owner> --rpc-url <rpc>
```

Confirm the Vault:

```bash
cast call <vaultFactory> "isVault(address)(bool)" <vault> --rpc-url <rpc>
cast call <vault> "owner()(address)" --rpc-url <rpc>
cast call <vault> "aiOperator()(address)" --rpc-url <rpc>
cast call <vault> "factory()(address)" --rpc-url <rpc>
cast call <vault> "hook()(address)" --rpc-url <rpc>
cast call <vault> "poolManager()(address)" --rpc-url <rpc>
```

## Explorer Verification

Mainnet address pages:

```text
https://www.okx.com/web3/explorer/xlayer/address/<address>
https://www.oklink.com/xlayer/address/<address>
```

Verification checklist:

- The contract is on the correct network.
- The contract is verified.
- Contract Name matches: `VaultFactory`, `ManagedLPHook`, `UserLPVault`, `PoolManager`, or `StateView`.
- ABI contains the interfaces listed in this skill.
- For Vault clones, prefer Factory `isVault(vault)` and Vault `owner()` / `aiOperator()` checks.

## Unverified Contracts

Unverified does not always mean unusable, but it increases risk:

- Use this skill's ABI signatures and `cast call` for read-only confirmation.
- Ask the user for a deployment transaction hash, official deployment record, or Explorer link.
- Before write transactions, repeat the target address, chain, function, and sender.
- Stop if the address source is not trustworthy.
