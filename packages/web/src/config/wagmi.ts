import { createConfig, http } from 'wagmi'
import { injected } from 'wagmi/connectors'
import { supportedChains, xLayer, xLayerTestnet } from './chains'

export const wagmiConfig = createConfig({
  chains: supportedChains,
  multiInjectedProviderDiscovery: true,
  connectors: [
    injected({
      shimDisconnect: true,
      unstable_shimAsyncInject: 1_000,
    }),
  ],
  transports: {
    [xLayer.id]: http(xLayer.rpcUrls.default.http[0]),
    [xLayerTestnet.id]: http(xLayerTestnet.rpcUrls.default.http[0]),
  },
})
