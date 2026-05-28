import type { Address, Hash } from 'viem'
import { getSupportedChain } from '../config/chains'

export function explorerAddress(chainId: number, address: Address | undefined) {
  if (!address) {
    return undefined
  }

  const chain = getSupportedChain(chainId)
  return `${chain.blockExplorers?.default.url}/address/${address}`
}

export function explorerTransaction(chainId: number, hash: Hash | undefined) {
  if (!hash) {
    return undefined
  }

  const chain = getSupportedChain(chainId)
  return `${chain.blockExplorers?.default.url}/tx/${hash}`
}
