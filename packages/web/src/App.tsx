import { useMemo, useState } from 'react'
import { useAccount, useChainId, useConnect, useDisconnect, useSwitchChain } from 'wagmi'
import { AppHeader } from './components/AppHeader'
import { CreateVaultPanel } from './components/CreateVaultPanel'
import { PoolsPanel } from './components/PoolsPanel'
import { StatusLine } from './components/StatusLine'
import { VaultPanel } from './components/VaultPanel'
import { defaultChainId, getSupportedChain, isSupportedChainId } from './config/chains'
import { getDeployment } from './config/contracts'
import { useVaultPortfolio } from './hooks/useVaultPortfolio'
import { dedupeConnectors } from './utils/connectors'
import { getReadState } from './utils/readState'

function App() {
  const walletChainId = useChainId()
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending: isConnectPending } = useConnect()
  const { disconnect } = useDisconnect()
  const { switchChain, isPending: isSwitchPending } = useSwitchChain()
  const [manualChainId, setManualChainId] = useState<number>()
  const selectedChainId =
    manualChainId ?? (isSupportedChainId(walletChainId) ? walletChainId : defaultChainId)

  const selectedChain = getSupportedChain(selectedChainId)
  const deployment = useMemo(() => getDeployment(selectedChainId), [selectedChainId])
  const browserConnectors = useMemo(() => dedupeConnectors(connectors), [connectors])
  const portfolio = useVaultPortfolio({
    owner: address,
    chainId: selectedChainId,
    deployment,
  })
  const vault = portfolio.data
  const isWalletOnSelectedChain = walletChainId === selectedChainId
  const readState = getReadState({
    isConnected,
    isMissingFactory: portfolio.isMissingFactory,
    isLoading: portfolio.isLoading,
    isFetching: portfolio.isFetching,
    error: portfolio.error,
    vaultAddress: vault?.vaultAddress,
  })

  function handleSelectChain(chainId: number) {
    setManualChainId(chainId)
    if (isConnected && walletChainId !== chainId) {
      switchChain({ chainId })
    }
  }

  function handleConnect(connector = browserConnectors[0]) {
    if (!connector) {
      return
    }

    connect({
      connector,
      chainId: selectedChainId,
    })
  }

  function handleSwitchChain() {
    switchChain({ chainId: selectedChainId })
  }

  const showCreateVaultPanel = isConnected && !portfolio.isLoading && !portfolio.error && !vault?.vaultAddress

  return (
    <main className="app-shell">
      <AppHeader
        address={address}
        browserConnectors={browserConnectors}
        isConnected={isConnected}
        isConnectPending={isConnectPending}
        isSwitchPending={isSwitchPending}
        selectedChainId={selectedChainId}
        onConnect={handleConnect}
        onDisconnect={() => disconnect()}
        onSelectChain={handleSelectChain}
      />

      <StatusLine
        hasPortfolio={Boolean(portfolio.data)}
        isConnected={isConnected}
        isSwitchPending={isSwitchPending}
        isWalletOnSelectedChain={isWalletOnSelectedChain}
        readState={readState}
        selectedChainName={selectedChain.name}
        onRefresh={() => {
          void portfolio.refetch()
        }}
        onSwitchChain={handleSwitchChain}
      />

      <section className="content-stack">
        {showCreateVaultPanel ? (
          <CreateVaultPanel
            owner={address}
            deployment={deployment}
            chainId={selectedChainId}
            chainName={selectedChain.name}
            isWalletOnSelectedChain={isWalletOnSelectedChain}
            isSwitchPending={isSwitchPending}
            onSwitchChain={handleSwitchChain}
            onVaultCreated={() => portfolio.refetch()}
          />
        ) : (
          <VaultPanel
            address={address}
            deployment={deployment}
            chainId={selectedChainId}
            isConnected={isConnected}
            isLoading={portfolio.isLoading}
            error={portfolio.error}
            vault={vault}
          />
        )}
        <PoolsPanel pools={vault?.pools ?? []} isLoading={portfolio.isLoading} chainId={selectedChainId} />
      </section>
    </main>
  )
}

export default App
