import type { useConnect } from 'wagmi'

type Connectors = ReturnType<typeof useConnect>['connectors']

export type BrowserConnector = Connectors[number]

export function dedupeConnectors(connectors: Connectors): Connectors {
  const specificWallets = connectors.filter((connector) => connector.id !== 'injected')
  const baseConnectors = specificWallets.length > 0 ? specificWallets : connectors
  const seen = new Set<string>()

  return baseConnectors.filter((connector) => {
    const key = `${connector.id}:${connector.name}`
    if (seen.has(key)) {
      return false
    }

    seen.add(key)
    return true
  })
}
