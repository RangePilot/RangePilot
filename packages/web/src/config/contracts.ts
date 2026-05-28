import { isAddress, zeroAddress, type Address } from 'viem'
import { xLayer, xLayerTestnet } from './chains'

export type DeploymentConfig = {
  vaultFactory?: Address
  managedLPHook?: Address
  poolManager?: Address
  stateView?: Address
}

const MAINNET_POOL_MANAGER = '0x360e68faccca8ca495c1b759fd9eee466db9fb32'
const MAINNET_STATE_VIEW = '0x76fd297e2d437cd7f76d50f01afe6160f86e9990'
const MAINNET_VAULT_FACTORY = '0xE8c006b5d4A8a2b0CC886c947a8Fd5F1E0eB921A'
const MAINNET_MANAGED_LP_HOOK = '0x29779a886523edEE78187f051635F7A969DC8a40'
const TESTNET_VAULT_FACTORY = '0x9f05221D3E653EC21911F4d91b3054A0E54027C6'
const TESTNET_MANAGED_LP_HOOK = '0x483744FA9563EFaC32a3C7c73AfeBEFA55418a40'
const TESTNET_POOL_MANAGER = '0x6df5DAE1e6216578e9eC63b239BFa6990AE6ed50'
const TESTNET_STATE_VIEW = '0x1cf2f6b229E313bAC1174F9e6c6a5Cd567F07F3E'

function readAddress(key: string, fallback?: string): Address | undefined {
  const value = import.meta.env[key] || fallback

  if (typeof value !== 'string') {
    return undefined
  }

  const trimmed = value.trim()
  if (!trimmed || trimmed === zeroAddress || !isAddress(trimmed)) {
    return undefined
  }

  return trimmed as Address
}

export const deploymentsByChainId: Record<number, DeploymentConfig> = {
  [xLayer.id]: {
    vaultFactory: readAddress('XLAYER_VAULT_FACTORY', MAINNET_VAULT_FACTORY),
    managedLPHook: readAddress('XLAYER_MANAGED_LP_HOOK', MAINNET_MANAGED_LP_HOOK),
    poolManager: readAddress('XLAYER_POOL_MANAGER', MAINNET_POOL_MANAGER),
    stateView: readAddress('XLAYER_STATE_VIEW', MAINNET_STATE_VIEW),
  },
  [xLayerTestnet.id]: {
    vaultFactory: readAddress('XLAYER_TESTNET_VAULT_FACTORY', TESTNET_VAULT_FACTORY),
    managedLPHook: readAddress('XLAYER_TESTNET_MANAGED_LP_HOOK', TESTNET_MANAGED_LP_HOOK),
    poolManager: readAddress('XLAYER_TESTNET_POOL_MANAGER', TESTNET_POOL_MANAGER),
    stateView: readAddress('XLAYER_TESTNET_STATE_VIEW', TESTNET_STATE_VIEW),
  },
}

export function getDeployment(chainId: number): DeploymentConfig {
  return deploymentsByChainId[chainId] ?? {}
}
