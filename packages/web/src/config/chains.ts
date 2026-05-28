import { defineChain } from 'viem'

const xLayerRpcUrl = import.meta.env.XLAYER_RPC_URL || 'https://rpc.xlayer.tech'
const xLayerTestnetRpcUrl =
  import.meta.env.XLAYER_TESTNET_RPC_URL || 'https://testrpc.xlayer.tech/terigon'

export const xLayer = defineChain({
  id: 196,
  name: 'X Layer',
  nativeCurrency: {
    decimals: 18,
    name: 'OKB',
    symbol: 'OKB',
  },
  rpcUrls: {
    default: {
      http: [xLayerRpcUrl],
    },
  },
  blockExplorers: {
    default: {
      name: 'OKX Explorer',
      url: 'https://www.okx.com/web3/explorer/xlayer',
    },
  },
})

export const xLayerTestnet = defineChain({
  id: 1952,
  name: 'X Layer Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'OKB',
    symbol: 'OKB',
  },
  rpcUrls: {
    default: {
      http: [xLayerTestnetRpcUrl],
    },
  },
  blockExplorers: {
    default: {
      name: 'OKX Explorer',
      url: 'https://www.okx.com/web3/explorer/xlayer-test',
    },
  },
  testnet: true,
})

export const supportedChains = [xLayer, xLayerTestnet] as const
export const defaultChainId = xLayerTestnet.id

export function getSupportedChain(chainId: number | undefined) {
  return supportedChains.find((chain) => chain.id === chainId) ?? xLayerTestnet
}

export function isSupportedChainId(chainId: number | undefined) {
  return supportedChains.some((chain) => chain.id === chainId)
}
